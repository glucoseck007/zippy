import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zippy/components/custom_input.dart';
import 'package:zippy/constants/screen_size.dart';
import 'package:zippy/design/app_colors.dart';
import 'package:zippy/design/app_typography.dart';
import 'package:zippy/models/entity/request/order_request.dart';
import 'package:zippy/providers/auth/auth_provider.dart';
import 'package:zippy/providers/core/theme_provider.dart';
import 'package:zippy/providers/robot/robot_provider.dart';
import 'package:zippy/screens/home.dart';
import 'package:zippy/services/order/order_service.dart';
import 'package:zippy/state/auth/auth_state.dart';
import 'package:zippy/utils/navigation_manager.dart';
import 'package:zippy/widgets/gif_view.dart';

class BookingScreen extends ConsumerStatefulWidget {
  const BookingScreen({super.key});

  @override
  ConsumerState<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends ConsumerState<BookingScreen> {
  final TextEditingController _productNameController = TextEditingController();
  String _selectedRoom = ''; // Selected delivery room

  // Generate room list from DE-104 to DE-128
  final List<String> _roomOptions = List.generate(
    25, // 128 - 104 + 1 = 25 rooms
    (index) => 'DE-${104 + index}',
  );

  String? _selectedRobotId;
  String? _selectedContainerCode;

  // Form progress tracking
  int _currentStep = 0;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _selectedRoom = _roomOptions[0]; // Initialize with first room option
  }

  @override
  void dispose() {
    _productNameController.dispose();
    super.dispose();
  }

  // Move to next step
  void _nextStep() {
    if (_currentStep == 0) {
      // Step 1: Validate product name
      if (_formKey.currentState!.validate()) {
        setState(() {
          _currentStep++;
        });
      }
    } else if (_currentStep == 1) {
      // Step 2: Validate room selection and move to step 3
      if (_selectedRoom.isNotEmpty) {
        setState(() {
          _currentStep++;
        });
        // Load robots when entering step 3
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final robotState = ref.read(robotProvider);
          if (!robotState.isLoaded && !robotState.isLoading) {
            ref.read(robotProvider.notifier).loadRobots();
          }
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('booking.room_selection_required')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else if (_currentStep == 2) {
      // Step 3: Validate robot selection and load robots if not already loaded
      final robotState = ref.read(robotProvider);
      if (!robotState.isLoaded && !robotState.isLoading) {
        // Load robots first
        ref.read(robotProvider.notifier).loadRobots();
        return;
      }

      if (_selectedRobotId != null && _selectedRobotId!.isNotEmpty) {
        setState(() {
          _currentStep++;
          // Reset container selection when robot changes
          _selectedContainerCode = null;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('booking.robot_selection_required')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else if (_currentStep == 3) {
      // Step 4: Validate container selection and submit
      if (_selectedContainerCode != null &&
          _selectedContainerCode!.isNotEmpty) {
        _submitBooking();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('booking.container_selection_required')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Go back to previous step
  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
    } else {
      NavigationManager.navigateBackWithSlideTransition(
        context,
        const HomeScreen(),
      );
    }
  }

  // Submit the booking
  Future<void> _submitBooking() async {
    final robotState = ref.read(robotProvider);
    final authState = ref.read(authProvider);

    if (!robotState.isLoaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('booking.robot_data_not_loaded')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check if user is authenticated
    if (!authState.isAuthenticated || authState.user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('auth.login_required')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Get selected robot details from the robot state
    final allRobots = [...robotState.freeRobots, ...robotState.busyRobots];
    final selectedRobot = allRobots.firstWhere(
      (robot) => robot.robotCode == _selectedRobotId,
      orElse: () => throw Exception('Selected robot not found'),
    );

    // Get selected container details
    final selectedContainer = selectedRobot.freeContainers.firstWhere(
      (container) => container.containerCode == _selectedContainerCode,
      orElse: () => throw Exception('Selected container not found'),
    );

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Expanded(child: Text(tr('booking.creating_order'))),
          ],
        ),
      ),
    );

    try {
      // Create the order request
      final orderRequest = OrderRequest(
        username: authState.user!.username,
        productName: _productNameController.text.trim(),
        robotCode: selectedRobot.robotCode,
        robotContainerCode: selectedContainer.containerCode,
        endpoint: _selectedRoom,
      );

      // Call the order creation API
      final orderResponse = await OrderService.createOrder(orderRequest);

      // Close loading dialog
      if (context.mounted) {
        Navigator.pop(context);
      }

      if (orderResponse != null && orderResponse.success) {
        // Order created successfully
        _showOrderSuccessDialog(
          orderResponse,
          selectedRobot,
          selectedContainer,
        );
      } else {
        // Order creation failed
        _showOrderErrorDialog(
          orderResponse?.message ?? tr('booking.order_creation_failed'),
        );
      }
    } catch (e) {
      // Close loading dialog
      if (context.mounted) {
        Navigator.pop(context);
      }

      // Show error dialog
      _showOrderErrorDialog(tr('booking.order_network_error'));
    }
  }

  void _showOrderSuccessDialog(
    orderResponse,
    selectedRobot,
    selectedContainer,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('booking.success_title')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr('booking.order_created_successfully')),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    '${tr('booking.product_label')}: ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Expanded(child: Text(_productNameController.text)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    '${tr('booking.room_label')}: ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Expanded(child: Text(_selectedRoom)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    '${tr('booking.robot_label')}: ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Expanded(child: Text(selectedRobot.displayName)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    '${tr('booking.container_label')}: ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Expanded(child: Text(selectedContainer.displayName)),
                ],
              ),
              if (orderResponse.data?.status != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      '${tr('booking.order_status')}: ',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Expanded(
                      child: Text(_translateStatus(orderResponse.data!.status)),
                    ),
                  ],
                ),
              ],
              if (orderResponse.data?.estimatedDeliveryTime != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      '${tr('booking.estimated_delivery')}: ',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Expanded(
                      child: Text(orderResponse.data!.estimatedDeliveryTime!),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              NavigationManager.navigateBackWithSlideTransition(
                context,
                const HomeScreen(),
              );
            },
            child: Text(tr('booking.common.ok')),
          ),
        ],
      ),
    );
  }

  // Helper function to translate status values
  String _translateStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return tr('booking.status_pending');
      case 'active':
        return tr('booking.status_active');
      case 'completed':
        return tr('booking.status_completed');
      case 'cancelled':
        return tr('booking.status_cancelled');
      default:
        return status; // Return original if no translation found
    }
  }

  void _showOrderErrorDialog(String errorMessage) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('booking.order_creation_failed')),
        content: Text(errorMessage),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
            },
            child: Text(tr('booking.try_again')),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              NavigationManager.navigateBackWithSlideTransition(
                context,
                const HomeScreen(),
              );
            },
            child: Text(tr('booking.back_to_home')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeProvider);
    bool isDarkMode = themeState.isDarkMode;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          tr('booking.title'),
          style: isDarkMode
              ? AppTypography.dmHeading.copyWith(fontWeight: FontWeight.w500)
              : AppTypography.heading.copyWith(fontWeight: FontWeight.w500),
        ),
        leading: Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios),
            onPressed: _previousStep,
          ),
        ),
      ),
      body: SafeArea(
        bottom: true, // Ensure the SafeArea accounts for bottom system bars
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            16.0,
            16.0,
            16.0,
            24.0,
          ), // Extra padding at the bottom
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Add bottom margin to handle possible overflow
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Animated progress indicators
                        Row(
                          children: List.generate(4, (index) {
                            // Different color for each step
                            Color indicatorColor;
                            if (index == 0) {
                              indicatorColor = Color(
                                0xffFA4032,
                              ); // First step: Red
                            } else if (index == 1) {
                              indicatorColor = Color(
                                0xffFA812F,
                              ); // Second step: Orange
                            } else if (index == 2) {
                              indicatorColor = Color(
                                0xffFAB12F,
                              ); // Third step: Yellow
                            } else {
                              indicatorColor = Color(
                                0xff2ECC71,
                              ); // Fourth step: Green
                            }

                            return Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4.0,
                                ),
                                child: LinearProgressIndicator(
                                  value: _currentStep >= index ? 1.0 : 0.0,
                                  backgroundColor: isDarkMode
                                      ? AppColors.dmCardColor
                                      : AppColors.cardColor.withOpacity(0.3),
                                  color: indicatorColor,
                                  minHeight: 5,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            );
                          }),
                        ),

                        const SizedBox(height: 16),

                        // Step indicator text
                        Text(
                          '${tr('booking.step')} ${_currentStep + 1} ${tr('booking.of')} 4',
                          style: isDarkMode
                              ? AppTypography.dmSubTitleText
                              : AppTypography.subTitleText,
                        ),

                        const SizedBox(height: 24),

                        // Step content
                        _buildCurrentStep(isDarkMode),

                        const SizedBox(height: 36),

                        // Next button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _nextStep,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.buttonColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              _currentStep == 3
                                  ? tr('booking.submit')
                                  : tr('booking.next'),
                              style: AppTypography.buttonText,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Build the current step's content
  Widget _buildCurrentStep(bool isDarkMode) {
    switch (_currentStep) {
      case 0:
        return _buildProductInfoStep(isDarkMode);
      case 1:
        return _buildRoomSelectionStep(isDarkMode);
      case 2:
        return _buildRobotSelectionStep(isDarkMode);
      case 3:
        return _buildContainerSelectionStep(isDarkMode);
      default:
        return Container();
    }
  }

  // Step 1: Product Info
  Widget _buildProductInfoStep(bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GifView(
          image: const AssetImage('assets/icons/delivery-truck.gif'),
          width: ScreenSize.width(context) * 0.6,
          height: ScreenSize.height(context) * 0.15,
          fit: BoxFit.cover,
          color: const Color(0xff8DBCC7),
          colorBlendMode: BlendMode.srcIn,
        ),
        const SizedBox(height: 32),
        CustomInput(
          labelKey: 'booking.product_name',
          hintKey: 'booking.product_name_hint',
          controller: _productNameController,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return tr('booking.product_name_required');
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        Text(
          tr('booking.product_info_desc'),
          textAlign: TextAlign.center,
          style: isDarkMode
              ? AppTypography.dmBodyText.copyWith(color: Colors.grey[400])
              : AppTypography.bodyText.copyWith(color: Colors.grey[600]),
        ),
      ],
    );
  } // Step 2: Room Selection

  Widget _buildRoomSelectionStep(bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          tr('booking.select_room'),
          style: isDarkMode
              ? AppTypography.dmSubTitleText
              : AppTypography.subTitleText,
        ),
        const SizedBox(height: 8),
        // Description text for room selection
        Text(
          tr('booking.room_selection_desc'),
          style: isDarkMode
              ? AppTypography.dmBodyText.copyWith(color: Colors.grey[400])
              : AppTypography.bodyText.copyWith(color: Colors.grey[600]),
        ),
        const SizedBox(height: 16),

        // Room grid layout
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5, // 5 rooms per row
            childAspectRatio: 1.5,
            crossAxisSpacing: 8.0,
            mainAxisSpacing: 8.0,
          ),
          itemCount: _roomOptions.length,
          itemBuilder: (context, index) {
            final room = _roomOptions[index];
            final isSelected = room == _selectedRoom;

            return InkWell(
              onTap: () {
                setState(() {
                  _selectedRoom = room;
                });
              },
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.buttonColor
                      : (isDarkMode
                            ? AppColors.dmCardColor
                            : AppColors.cardColor.withOpacity(0.2)),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.buttonColor
                        : (isDarkMode ? Colors.white24 : Colors.black12),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    room,
                    style:
                        (isDarkMode
                                ? AppTypography.dmBodyText
                                : AppTypography.bodyText)
                            .copyWith(
                              color: isSelected
                                  ? Colors.white
                                  : (isDarkMode
                                        ? Colors.white
                                        : Colors.black87),
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              fontSize: 12,
                            ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // Step 3: Robot Selection
  Widget _buildRobotSelectionStep(bool isDarkMode) {
    final robotState = ref.watch(robotProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          tr('booking.select_robot'),
          style: isDarkMode
              ? AppTypography.dmSubTitleText
              : AppTypography.subTitleText,
        ),
        const SizedBox(height: 8),
        Text(
          tr('booking.robot_selection_desc'),
          style: isDarkMode
              ? AppTypography.dmBodyText.copyWith(color: Colors.grey[400])
              : AppTypography.bodyText.copyWith(color: Colors.grey[600]),
        ),
        const SizedBox(height: 16),

        // Loading state
        if (robotState.isLoading)
          Center(
            child: Column(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(tr('booking.loading_robots')),
              ],
            ),
          )
        // Error state
        else if (robotState.isError)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.withOpacity(0.3), width: 1),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red, size: 30),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        robotState.errorMessage ??
                            tr('booking.error_loading_robots'),
                        style:
                            (isDarkMode
                                    ? AppTypography.dmBodyText
                                    : AppTypography.bodyText)
                                .copyWith(color: Colors.red),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    ref.read(robotProvider.notifier).loadRobots();
                  },
                  child: Text(tr('booking.retry')),
                ),
              ],
            ),
          )
        // Loaded state
        else if (robotState.isLoaded) ...[
          // Available Robots Section
          if (robotState.freeRobots.isNotEmpty) ...[
            Text(
              '${tr('booking.available_robots')} (${robotState.freeRobots.length})',
              style:
                  (isDarkMode
                          ? AppTypography.dmSubTitleText
                          : AppTypography.subTitleText)
                      .copyWith(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
            ),
            const SizedBox(height: 12),

            ...robotState.freeRobots.map((robot) {
              final isSelected = robot.robotCode == _selectedRobotId;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedRobotId = robot.robotCode;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (isDarkMode
                                ? AppColors.dmSelectedColor
                                : AppColors.selectedColor)
                          : (isDarkMode
                                ? AppColors.dmCardColor
                                : AppColors.cardColor.withOpacity(0.2)),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.buttonColor
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.smart_toy,
                            color: Colors.green,
                            size: 30,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                robot.displayName,
                                style:
                                    (isDarkMode
                                            ? AppTypography.dmSubTitleText
                                            : AppTypography.subTitleText)
                                        .copyWith(
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.w600,
                                        ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.battery_std,
                                    size: 16,
                                    color: (robot.batteryLevel ?? 75) > 70
                                        ? Colors.green
                                        : (robot.batteryLevel ?? 75) > 30
                                        ? Colors.orange
                                        : Colors.red,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${robot.batteryLevel ?? 75}%',
                                    style: isDarkMode
                                        ? AppTypography.dmBodyText
                                        : AppTypography.bodyText,
                                  ),
                                  const SizedBox(width: 16),
                                  const Icon(
                                    Icons.location_on,
                                    size: 16,
                                    color: Colors.blue,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      robot.currentLocation ??
                                          tr('booking.unknown'),
                                      style: isDarkMode
                                          ? AppTypography.dmBodyText
                                          : AppTypography.bodyText,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.access_time,
                                    size: 16,
                                    color: Colors.orange,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${tr('booking.eta')}: ${robot.estimatedArrival ?? tr('booking.unknown')}',
                                    style:
                                        (isDarkMode
                                                ? AppTypography.dmBodyText
                                                : AppTypography.bodyText)
                                            .copyWith(
                                              color: Colors.orange,
                                              fontWeight: FontWeight.w500,
                                            ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          Container(
                            width: 30,
                            height: 30,
                            decoration: const BoxDecoration(
                              color: AppColors.buttonColor,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ],

          // No available robots message
          if (robotState.freeRobots.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.orange.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning, color: Colors.orange, size: 30),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tr('booking.no_robots_title'),
                              style:
                                  (isDarkMode
                                          ? AppTypography.dmSubTitleText
                                          : AppTypography.subTitleText)
                                      .copyWith(
                                        color: Colors.orange,
                                        fontWeight: FontWeight.bold,
                                      ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              tr('booking.no_robots_description'),
                              style:
                                  (isDarkMode
                                          ? AppTypography.dmBodyText
                                          : AppTypography.bodyText)
                                      .copyWith(color: Colors.orange),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            ref.read(robotProvider.notifier).loadRobots();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                          ),
                          child: Text(tr('booking.retry')),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            NavigationManager.navigateBackWithSlideTransition(
                              context,
                              const HomeScreen(),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey,
                            foregroundColor: Colors.white,
                          ),
                          child: Text(tr('booking.back_to_home')),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          if (robotState.busyRobots.isNotEmpty) ...[
            const SizedBox(height: 20),
            // Busy Robots Section (for demo)
            Text(
              '${tr('booking.busy_robots')} (${robotState.busyRobots.length})',
              style:
                  (isDarkMode
                          ? AppTypography.dmSubTitleText
                          : AppTypography.subTitleText)
                      .copyWith(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            ...robotState.busyRobots.map((robot) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.red.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.smart_toy,
                          color: Colors.red,
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              robot.displayName,
                              style:
                                  (isDarkMode
                                          ? AppTypography.dmSubTitleText
                                          : AppTypography.subTitleText)
                                      .copyWith(
                                        color: Colors.red,
                                        fontWeight: FontWeight.w600,
                                      ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${tr('booking.currently_at')}: ${robot.currentLocation ?? tr('booking.unknown')}',
                              style:
                                  (isDarkMode
                                          ? AppTypography.dmBodyText
                                          : AppTypography.bodyText)
                                      .copyWith(
                                        color: Colors.red.withOpacity(0.8),
                                      ),
                            ),
                            Text(
                              '${tr('booking.available_in')}: ${robot.estimatedArrival ?? tr('booking.unknown')}',
                              style:
                                  (isDarkMode
                                          ? AppTypography.dmBodyText
                                          : AppTypography.bodyText)
                                      .copyWith(
                                        color: Colors.red.withOpacity(0.8),
                                      ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ],
        ]
        // Initial state - show button to load robots
        else ...[
          Center(
            child: Column(
              children: [
                const Icon(Icons.smart_toy, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(tr('booking.select_robot')),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    ref.read(robotProvider.notifier).loadRobots();
                  },
                  child: Text(tr('booking.loading_robots')),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // Step 4: Container Selection
  Widget _buildContainerSelectionStep(bool isDarkMode) {
    final robotState = ref.watch(robotProvider);

    if (!robotState.isLoaded || _selectedRobotId == null) {
      return Center(child: Text(tr('booking.please_select_robot_first')));
    }

    // Get selected robot details from the robot state
    final allRobots = [...robotState.freeRobots, ...robotState.busyRobots];
    final selectedRobot = allRobots.firstWhere(
      (robot) => robot.robotCode == _selectedRobotId,
      orElse: () => throw Exception('Selected robot not found'),
    );

    // Get containers for the selected robot
    final containers = selectedRobot.freeContainers;
    final freeContainers = containers
        .where((container) => container.isAvailable)
        .toList();
    final occupiedContainers = containers
        .where((container) => !container.isAvailable)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Robot info header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDarkMode
                ? AppColors.dmCardColor.withOpacity(0.5)
                : AppColors.cardColor.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.buttonColor.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.smart_toy,
                  color: Colors.green,
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${tr('booking.selected_robot')}: ${selectedRobot.displayName}',
                      style:
                          (isDarkMode
                                  ? AppTypography.dmSubTitleText
                                  : AppTypography.subTitleText)
                              .copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${tr('booking.eta')}: ${selectedRobot.estimatedArrival ?? tr('booking.unknown')}',
                      style: isDarkMode
                          ? AppTypography.dmBodyText
                          : AppTypography.bodyText,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        Text(
          tr('booking.select_container'),
          style: isDarkMode
              ? AppTypography.dmSubTitleText
              : AppTypography.subTitleText,
        ),
        const SizedBox(height: 8),
        Text(
          tr('booking.container_selection_desc'),
          style: isDarkMode
              ? AppTypography.dmBodyText.copyWith(color: Colors.grey[400])
              : AppTypography.bodyText.copyWith(color: Colors.grey[600]),
        ),
        const SizedBox(height: 16),

        // Available Containers Section
        if (freeContainers.isNotEmpty) ...[
          Text(
            '${tr('booking.available_containers')} (${freeContainers.length})',
            style:
                (isDarkMode
                        ? AppTypography.dmSubTitleText
                        : AppTypography.subTitleText)
                    .copyWith(color: Colors.green, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          ...freeContainers.map((container) {
            final isSelected =
                container.containerCode == _selectedContainerCode;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: InkWell(
                onTap: () {
                  setState(() {
                    _selectedContainerCode = container.containerCode;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isDarkMode
                              ? AppColors.dmSelectedColor
                              : AppColors.selectedColor)
                        : (isDarkMode
                              ? AppColors.dmCardColor
                              : AppColors.cardColor.withOpacity(0.2)),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.buttonColor
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.inventory_2,
                          color: Colors.blue,
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              container.displayName,
                              style:
                                  (isDarkMode
                                          ? AppTypography.dmSubTitleText
                                          : AppTypography.subTitleText)
                                      .copyWith(
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.w600,
                                      ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.scale,
                                  size: 16,
                                  color: Colors.orange,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${tr('booking.capacity')}: ${container.capacity ?? '5kg'}',
                                  style: isDarkMode
                                      ? AppTypography.dmBodyText
                                      : AppTypography.bodyText,
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.straighten,
                                  size: 16,
                                  color: Colors.purple,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${tr('booking.size')}: ${container.dimensions ?? '30x20x15cm'}',
                                  style: isDarkMode
                                      ? AppTypography.dmBodyText
                                      : AppTypography.bodyText,
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.check_circle_outline,
                                  size: 16,
                                  color: Colors.green,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${tr('booking.status')}: ${tr('booking.status_available')}',
                                  style: isDarkMode
                                      ? AppTypography.dmBodyText
                                      : AppTypography.bodyText,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        Container(
                          width: 30,
                          height: 30,
                          decoration: const BoxDecoration(
                            color: AppColors.buttonColor,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ],

        if (freeContainers.isEmpty) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.orange.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning, color: Colors.orange, size: 30),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    tr('booking.no_containers_available'),
                    style:
                        (isDarkMode
                                ? AppTypography.dmBodyText
                                : AppTypography.bodyText)
                            .copyWith(color: Colors.orange),
                  ),
                ),
              ],
            ),
          ),
        ],

        if (occupiedContainers.isNotEmpty) ...[
          const SizedBox(height: 20),

          // Occupied Containers Section (for info)
          Text(
            tr('booking.occupied_containers'),
            style:
                (isDarkMode
                        ? AppTypography.dmSubTitleText
                        : AppTypography.subTitleText)
                    .copyWith(color: Colors.red, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          ...occupiedContainers.map((container) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.red.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.inventory_2,
                        color: Colors.red,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            container.displayName,
                            style:
                                (isDarkMode
                                        ? AppTypography.dmSubTitleText
                                        : AppTypography.subTitleText)
                                    .copyWith(
                                      color: Colors.red,
                                      fontWeight: FontWeight.w600,
                                    ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${tr('booking.occupied_by')}: ${container.occupiedBy ?? tr('booking.unknown')}',
                            style:
                                (isDarkMode
                                        ? AppTypography.dmBodyText
                                        : AppTypography.bodyText)
                                    .copyWith(
                                      color: Colors.red.withOpacity(0.8),
                                    ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ],
      ],
    );
  }
}

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
import 'package:zippy/services/mqtt/mqtt_manager.dart';
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
  final TextEditingController _receiverIdentifierController =
      TextEditingController();
  String _selectedStartPoint = ''; // Selected start point
  String _selectedRoom = ''; // Selected delivery room

  // Generate room list from DE-101 to DE-120 (Delta Building)
  final List<String> _roomOptions = [
    ...List.generate(
      20, // 120 - 101 + 1 = 20 rooms
      (index) => 'DE-${101 + index}',
    ),
    'DE105', // manual
    'cuuhoa',
    'WC',
  ];

  // Start point options - same as room options since they're all in Delta building
  final List<String> _startPointOptions = [
    ...List.generate(
      20, // 120 - 101 + 1 = 20 rooms
      (index) => 'DE-${101 + index}',
    ),
    'DE105', // manual
    'cuuhoa',
    'WC',
  ];

  String? _selectedRobotId;

  // Form progress tracking
  int _currentStep = 0;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _selectedStartPoint =
        _startPointOptions[0]; // Initialize with first start point
    _selectedRoom =
        _getFirstAvailableRoom(); // Initialize with first available room

    // Initialize MQTT connection for real-time robot status updates
    WidgetsBinding.instance.addPostFrameCallback((_) {
      MqttManager.initialize();
    });

    // Set up callback for when robots become available
    RobotNotifier.onRobotsAvailable = _onRobotsAvailable;
  }

  @override
  void dispose() {
    _productNameController.dispose();
    _receiverIdentifierController.dispose();
    // Clear the callbacks to prevent memory leaks
    RobotNotifier.onRobotsAvailable = null;
    super.dispose();
  }

  /// Called when robots become available via MQTT
  void _onRobotsAvailable() {
    // Only auto-refresh if we're currently on the final step (robot selection)
    if (_currentStep == 3) {
      print(
        'BookingScreen: 🔄 Auto-refreshing robot selection due to MQTT update',
      );

      // Show a snackbar to inform user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('booking.robots_updated')),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );

        // Trigger a rebuild to show updated robot list
        setState(() {
          // Force UI rebuild - the provider state has already been updated
        });
      }
    }
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
      // Step 2: Validate start point selection
      if (_selectedStartPoint.isNotEmpty) {
        setState(() {
          _currentStep++;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('booking.start_point_selection_required')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else if (_currentStep == 2) {
      // Step 3: Validate endpoint/room selection
      if (_selectedRoom.isNotEmpty) {
        setState(() {
          _currentStep++;
        });
        // Load robots when entering step 4
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
    } else if (_currentStep == 3) {
      // Step 4: Validate robot selection and load robots if not already loaded
      final robotState = ref.read(robotProvider);
      if (!robotState.isLoaded && !robotState.isLoading) {
        // Load robots first
        ref.read(robotProvider.notifier).loadRobots();
        return;
      }

      if (_selectedRobotId != null && _selectedRobotId!.isNotEmpty) {
        _submitOrder();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('booking.robot_selection_required')),
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

  /// Get the first available room that's not the same as the selected start point
  String _getFirstAvailableRoom() {
    for (String room in _roomOptions) {
      if (room != _selectedStartPoint) {
        return room;
      }
    }
    // Fallback: if all rooms are somehow the same as start point, return the first room
    return _roomOptions.isNotEmpty ? _roomOptions[0] : '';
  }

  // Submit the order directly without reservation
  Future<void> _submitOrder() async {
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
      // Create the order request object
      final orderRequest = OrderRequest(
        senderIdentifier:
            authState.user!.username, // Use username as sender identifier
        receiverIdentifier: _receiverIdentifierController.text.trim(),
        productName: _productNameController.text.trim(),
        robotCode: _selectedRobotId!,
        startPoint: _selectedStartPoint,
        endPoint: _selectedRoom, // Updated to match API field name
      );

      // Create the order directly
      final orderResponse = await OrderService.createOrder(orderRequest);

      // Close loading dialog
      if (context.mounted) {
        Navigator.pop(context);
      }

      if (orderResponse != null && orderResponse.success) {
        // Order created successfully
        final robotState = ref.read(robotProvider);
        final allRobots = [...robotState.freeRobots, ...robotState.busyRobots];
        final selectedRobot = allRobots.firstWhere(
          (robot) => robot.robotCode == _selectedRobotId,
          orElse: () => throw Exception('Selected robot not found'),
        );

        _showOrderSuccessDialog(orderResponse, selectedRobot);
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

  void _showOrderSuccessDialog(orderResponse, selectedRobot) {
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

              // Order Code
              if (orderResponse.data?.orderCode != null) ...[
                Row(
                  children: [
                    Text(
                      '${tr('booking.order_code')}: ',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Expanded(child: Text(orderResponse.data!.orderCode!)),
                  ],
                ),
                const SizedBox(height: 8),
              ],

              // Price
              if (orderResponse.data?.price != null) ...[
                Row(
                  children: [
                    Text(
                      '${tr('booking.order_price')}: ',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Expanded(child: Text('${orderResponse.data!.price} VND')),
                  ],
                ),
                const SizedBox(height: 8),
              ],

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
              if (orderResponse.data?.status != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      '${tr('booking.order_status')}: ',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusColor(orderResponse.data!.status),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getStatusIcon(orderResponse.data!.status),
                            size: 16,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _translateStatus(orderResponse.data!.status),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Status explanation
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _getStatusColor(
                      orderResponse.data!.status,
                    ).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _getStatusColor(
                        orderResponse.data!.status,
                      ).withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    _getStatusExplanation(orderResponse.data!.status),
                    style: TextStyle(
                      color: _getStatusColor(orderResponse.data!.status),
                      fontSize: 12,
                    ),
                  ),
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
      case 'queued':
        return tr('booking.status_queued');
      default:
        return status; // Return original if no translation found
    }
  }

  // Helper function to get status color
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'active':
        return Colors.green;
      case 'completed':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      case 'queued':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  // Helper function to get status icon
  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Icons.schedule;
      case 'active':
        return Icons.local_shipping;
      case 'completed':
        return Icons.check_circle;
      case 'cancelled':
        return Icons.cancel;
      case 'queued':
        return Icons.queue;
      default:
        return Icons.info;
    }
  }

  // Helper function to get status explanation
  String _getStatusExplanation(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return tr('booking.status_explanation_pending');
      case 'active':
        return tr('booking.status_explanation_active');
      case 'completed':
        return tr('booking.status_explanation_completed');
      case 'cancelled':
        return tr('booking.status_explanation_cancelled');
      case 'queued':
        return tr('booking.status_explanation_queued');
      default:
        return 'Order status information';
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
              ? AppTypography.dmHeading(
                  context,
                ).copyWith(fontWeight: FontWeight.w500)
              : AppTypography.heading(
                  context,
                ).copyWith(fontWeight: FontWeight.w500),
        ),
        leading: Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios),
            onPressed: _previousStep,
          ),
        ),
        actions: [
          // Temporary debug button to test MQTT subscription
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: () async {
              print('Debug button pressed - checking MQTT status');

              // Also show current robot state
              final robotState = ref.read(robotProvider);
              print('=== CURRENT ROBOT STATE ===');
              print('State type: ${robotState.runtimeType}');
              print('Is loaded: ${robotState.isLoaded}');
              if (robotState.isLoaded) {
                print('Free robots: ${robotState.freeRobots.length}');
                print('Busy robots: ${robotState.busyRobots.length}');
                print(
                  'Free robot IDs: ${robotState.freeRobots.map((r) => r.robotCode).join(", ")}',
                );
                print(
                  'Busy robot IDs: ${robotState.busyRobots.map((r) => r.robotCode).join(", ")}',
                );
              }
              print(
                'Message: ${robotState.isLoaded ? 'Loaded successfully' : 'Not loaded'}',
              );
              print('==========================');

              // Show a snackbar with the current state
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Debug info printed to console. Robot count: ${robotState.isLoaded ? robotState.freeRobots.length + robotState.busyRobots.length : 0}',
                  ),
                  duration: Duration(seconds: 3),
                ),
              );

              // Wait a bit then test publishing
              await Future.delayed(Duration(seconds: 2));
            },
          ),
        ],
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
                              ); // First step: Red (Product Info)
                            } else if (index == 1) {
                              indicatorColor = Color(
                                0xffFA812F,
                              ); // Second step: Orange (Start Point)
                            } else if (index == 2) {
                              indicatorColor = Color(
                                0xffFAB12F,
                              ); // Third step: Yellow (Endpoint)
                            } else {
                              indicatorColor = Color(
                                0xff2ECC71,
                              ); // Fourth step: Green (Robot)
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
                              ? AppTypography.dmSubTitleText(context)
                              : AppTypography.subTitleText(context),
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
                                  ? tr('booking.create_order')
                                  : tr('booking.next'),
                              style: AppTypography.buttonText(context),
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
        return _buildStartPointSelectionStep(isDarkMode);
      case 2:
        return _buildRoomSelectionStep(isDarkMode);
      case 3:
        return _buildRobotSelectionStep(isDarkMode);
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
        CustomInput(
          labelKey: 'booking.receiver_identifier',
          hintKey: 'booking.receiver_identifier_hint',
          controller: _receiverIdentifierController,
          keyboardType: TextInputType.emailAddress,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return tr('booking.receiver_identifier_required');
            }
            // Check if it's a valid email or phone number
            final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
            final phoneRegex = RegExp(r'^[0-9]{10,11}$');
            final cleanValue = value.replaceAll(RegExp(r'[\s\-\(\)]'), '');

            if (!emailRegex.hasMatch(value) &&
                !phoneRegex.hasMatch(cleanValue)) {
              return tr('booking.invalid_identifier_format');
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        Text(
          tr('booking.product_info_desc'),
          textAlign: TextAlign.center,
          style: isDarkMode
              ? AppTypography.dmBodyText(
                  context,
                ).copyWith(color: Colors.grey[400])
              : AppTypography.bodyText(
                  context,
                ).copyWith(color: Colors.grey[600]),
        ),
      ],
    );
  }

  // Step 2: Start Point Selection
  Widget _buildStartPointSelectionStep(bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          tr('booking.select_start_point'),
          style: isDarkMode
              ? AppTypography.dmSubTitleText(context)
              : AppTypography.subTitleText(context),
        ),
        const SizedBox(height: 8),
        // Description text for start point selection
        Text(
          tr('booking.start_point_selection_desc'),
          style: isDarkMode
              ? AppTypography.dmBodyText(
                  context,
                ).copyWith(color: Colors.grey[400])
              : AppTypography.bodyText(
                  context,
                ).copyWith(color: Colors.grey[600]),
        ),
        const SizedBox(height: 16),

        // Start point grid layout (same as room selection)
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5, // 5 rooms per row
            childAspectRatio: 1.5,
            crossAxisSpacing: 8.0,
            mainAxisSpacing: 8.0,
          ),
          itemCount: _startPointOptions.length,
          itemBuilder: (context, index) {
            final startPoint = _startPointOptions[index];
            final isSelected = startPoint == _selectedStartPoint;

            return InkWell(
              onTap: () {
                setState(() {
                  _selectedStartPoint = startPoint;
                  // Clear selected room if it's the same as the new start point
                  if (_selectedRoom == startPoint) {
                    _selectedRoom =
                        _getFirstAvailableRoom(); // Select next available room
                  }
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
                    startPoint,
                    style:
                        (isDarkMode
                                ? AppTypography.dmBodyText(context)
                                : AppTypography.bodyText(context))
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

  // Step 3: Room Selection
  Widget _buildRoomSelectionStep(bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          tr('booking.select_room'),
          style: isDarkMode
              ? AppTypography.dmSubTitleText(context)
              : AppTypography.subTitleText(context),
        ),
        const SizedBox(height: 8),
        // Description text for room selection
        Text(
          tr('booking.room_selection_desc'),
          style: isDarkMode
              ? AppTypography.dmBodyText(
                  context,
                ).copyWith(color: Colors.grey[400])
              : AppTypography.bodyText(
                  context,
                ).copyWith(color: Colors.grey[600]),
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
            final isStartPoint =
                room ==
                _selectedStartPoint; // Check if this room is the selected start point
            final isDisabled = isStartPoint; // Disable if it's the start point

            return InkWell(
              onTap: isDisabled
                  ? null
                  : () {
                      setState(() {
                        _selectedRoom = room;
                      });
                    },
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.buttonColor
                      : isDisabled
                      ? (isDarkMode ? Colors.grey[800] : Colors.grey[300])
                      : (isDarkMode
                            ? AppColors.dmCardColor
                            : AppColors.cardColor.withOpacity(0.2)),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.buttonColor
                        : isDisabled
                        ? (isDarkMode ? Colors.grey[600]! : Colors.grey[400]!)
                        : (isDarkMode ? Colors.white24 : Colors.black12),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        room,
                        style:
                            (isDarkMode
                                    ? AppTypography.dmBodyText(context)
                                    : AppTypography.bodyText(context))
                                .copyWith(
                                  color: isSelected
                                      ? Colors.white
                                      : isDisabled
                                      ? (isDarkMode
                                            ? Colors.grey[400]
                                            : Colors.grey[600])
                                      : (isDarkMode
                                            ? Colors.white
                                            : Colors.black87),
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  fontSize: 12,
                                ),
                      ),
                      if (isDisabled)
                        Text(
                          '(Start)',
                          style: TextStyle(
                            color: isDarkMode
                                ? Colors.grey[400]
                                : Colors.grey[600],
                            fontSize: 8,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // Step 4: Robot Selection
  Widget _buildRobotSelectionStep(bool isDarkMode) {
    final robotState = ref.watch(robotProvider);

    // Debug logging for UI state changes
    print('BookingScreen: Building robot selection step');
    print('BookingScreen: Robot state type: ${robotState.runtimeType}');
    print('BookingScreen: Is loaded: ${robotState.isLoaded}');
    if (robotState.isLoaded) {
      print(
        'BookingScreen: Free robots count: ${robotState.freeRobots.length}',
      );
      print(
        'BookingScreen: Free robot IDs: ${robotState.freeRobots.map((r) => r.robotCode).join(", ")}',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          tr('booking.select_robot'),
          style: isDarkMode
              ? AppTypography.dmSubTitleText(context)
              : AppTypography.subTitleText(context),
        ),
        const SizedBox(height: 8),
        Text(
          tr('booking.robot_selection_desc'),
          style: isDarkMode
              ? AppTypography.dmBodyText(
                  context,
                ).copyWith(color: Colors.grey[400])
              : AppTypography.bodyText(
                  context,
                ).copyWith(color: Colors.grey[600]),
        ),
        const SizedBox(height: 8),

        // MQTT Connection Status
        Consumer(
          builder: (context, ref, child) {
            final isConnected = MqttManager.isConnected;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isConnected
                    ? Colors.green.withOpacity(0.1)
                    : Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isConnected
                      ? Colors.green.withOpacity(0.3)
                      : Colors.orange.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isConnected ? Icons.wifi : Icons.wifi_off,
                    size: 16,
                    color: isConnected ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isConnected
                        ? tr('booking.mqtt_connected')
                        : tr('booking.mqtt_disconnected'),
                    style:
                        (isDarkMode
                                ? AppTypography.dmBodyText(context)
                                : AppTypography.bodyText(context))
                            .copyWith(
                              color: isConnected ? Colors.green : Colors.orange,
                              fontSize: 12,
                            ),
                  ),
                ],
              ),
            );
          },
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
                                    ? AppTypography.dmBodyText(context)
                                    : AppTypography.bodyText(context))
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
                          ? AppTypography.dmSubTitleText(context)
                          : AppTypography.subTitleText(context))
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
                                            ? AppTypography.dmSubTitleText(
                                                context,
                                              )
                                            : AppTypography.subTitleText(
                                                context,
                                              ))
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
                                        ? AppTypography.dmBodyText(context)
                                        : AppTypography.bodyText(context),
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
                                          ? AppTypography.dmBodyText(context)
                                          : AppTypography.bodyText(context),
                                      overflow: TextOverflow.ellipsis,
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
                                          ? AppTypography.dmSubTitleText(
                                              context,
                                            )
                                          : AppTypography.subTitleText(context))
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
                                          ? AppTypography.dmBodyText(context)
                                          : AppTypography.bodyText(context))
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
                          ? AppTypography.dmSubTitleText(context)
                          : AppTypography.subTitleText(context))
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
                                          ? AppTypography.dmSubTitleText(
                                              context,
                                            )
                                          : AppTypography.subTitleText(context))
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
                                          ? AppTypography.dmBodyText(context)
                                          : AppTypography.bodyText(context))
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
}

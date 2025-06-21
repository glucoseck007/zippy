import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:zippy/components/custom_input.dart';
import 'package:zippy/components/map_component.dart';
import 'package:zippy/constants/screen_size.dart';
import 'package:zippy/design/app_colors.dart';
import 'package:zippy/design/app_typography.dart';
import 'package:zippy/providers/theme_provider.dart';
import 'package:zippy/screens/home.dart';
import 'package:zippy/utils/navigation_manager.dart';
import 'package:zippy/widgets/gif_view.dart';
import 'package:zippy/services/map/osm_service.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final TextEditingController _productNameController = TextEditingController();
  String _selectedBox = ''; // Default selected cargo space
  final List<String> _boxOptions = [
    tr('booking.cargo_space.space_1'),
    tr('booking.cargo_space.space_2'),
    // tr('booking.cargo_space.space_3'),
    // tr('booking.cargo_space.space_4'),
  ];

  // Map related variables
  LatLng _selectedLocation = const LatLng(
    21.0285,
    105.8542,
  ); // Default to Hanoi City
  String _currentAddress = '';

  // Form progress tracking
  int _currentStep = 0;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _selectedBox = _boxOptions[0]; // Initialize with first cargo space option
    _requestLocationPermission();
  }

  @override
  void dispose() {
    _productNameController.dispose();
    super.dispose();
  }

  // Request location permissions and get current location with address
  Future<void> _requestLocationPermission() async {
    try {
      final osmService = OpenStreetMapService();
      final result = await osmService.getCurrentLocationWithAddress();

      if (result != null) {
        setState(() {
          _selectedLocation = result['position'];
          _currentAddress = result['address'];
        });
      } else {
        // If location service fails, ensure we have default values
        if (mounted) {
          setState(() {
            // Keep the default _selectedLocation (Hanoi)
            _currentAddress = 'Default location: Hanoi City, Vietnam';
          });
        }
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
      if (mounted) {
        setState(() {
          // Keep the default _selectedLocation (Hanoi)
          _currentAddress =
              'Unable to get location. Using default location: Hanoi.';
        });
      }
    }
  }

  // Move to next step
  void _nextStep() {
    if (_currentStep == 0) {
      if (_formKey.currentState!.validate()) {
        setState(() {
          _currentStep++;
        });
      }
    } else if (_currentStep < 2) {
      setState(() {
        _currentStep++;
      });
    } else {
      _submitBooking();
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
  void _submitBooking() {
    // Here you would typically send the data to your backend
    // For this example, we'll just show a success dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('booking.success_title')),
        content: Text(tr('booking.success_message')),
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

  @override
  Widget build(BuildContext context) {
    bool isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

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
                          children: List.generate(3, (index) {
                            // Different color for each step
                            Color indicatorColor;
                            if (index == 0) {
                              indicatorColor = Color(
                                0xffFA4032,
                              ); // First step: Orange
                            } else if (index == 1) {
                              indicatorColor = Color(
                                0xffFA812F,
                              ); // Second step: Green
                            } else {
                              indicatorColor = Color(
                                0xffFAB12F,
                              ); // Third step: Yellow
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
                          '${tr('booking.step')} ${_currentStep + 1} ${tr('booking.of')} 3',
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
                              _currentStep == 2
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
        return _buildBoxSelectionStep(isDarkMode);
      case 2:
        return _buildLocationSelectionStep(isDarkMode);
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
  } // Step 2: Box Selection

  Widget _buildBoxSelectionStep(bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          tr('booking.select_box'),
          style: isDarkMode
              ? AppTypography.dmSubTitleText
              : AppTypography.subTitleText,
        ),
        const SizedBox(height: 8),
        // Description text for cargo spaces
        Text(
          tr('booking.cargo_spaces_desc'),
          style: isDarkMode
              ? AppTypography.dmBodyText.copyWith(color: Colors.grey[400])
              : AppTypography.bodyText.copyWith(color: Colors.grey[600]),
        ),
        const SizedBox(height: 16),
        ...List.generate(_boxOptions.length, (index) {
          final box = _boxOptions[index];
          final isSelected = box == _selectedBox;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedBox = box;
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
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.buttonColor
                            : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? AppColors.buttonColor
                              : (isDarkMode ? Colors.white54 : Colors.black54),
                          width: 2,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 18,
                            )
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          box,
                          style:
                              (isDarkMode
                                      ? AppTypography.dmSubTitleText
                                      : AppTypography.subTitleText)
                                  .copyWith(
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  // Step 3: Location Selection
  Widget _buildLocationSelectionStep(bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MapComponent(
          initialLocation: _selectedLocation,
          onLocationSelected: (location, address) {
            setState(() {
              _selectedLocation = location;
              _currentAddress = address;
            });
          },
        ),
        const SizedBox(height: 16),
        // Display selected location address
        if (_currentAddress.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Row(
              children: [
                const Icon(Icons.location_on, color: AppColors.buttonColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _currentAddress,
                    style: isDarkMode
                        ? AppTypography.dmBodyText
                        : AppTypography.bodyText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        Text(
          tr('booking.location_description'),
          textAlign: TextAlign.center,
          style: isDarkMode
              ? AppTypography.dmBodyText.copyWith(color: Colors.grey[400])
              : AppTypography.bodyText.copyWith(color: Colors.grey[600]),
        ),
      ],
    );
  }
}

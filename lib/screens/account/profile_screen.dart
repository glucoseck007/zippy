import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zippy/design/app_typography.dart';
import 'package:zippy/design/app_colors.dart';
import 'package:zippy/models/response/api_response.dart';
import '../../services/api_client.dart';
import '../../models/entity/location/address.dart';
import '../../components/custom_input.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isLoading = false;
  Map<String, dynamic>? _profileData;
  String? _errorMessage;

  // Controllers for editable fields
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _streetController = TextEditingController();
  final TextEditingController _wardController = TextEditingController();
  final TextEditingController _districtController = TextEditingController();
  final TextEditingController _provinceController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();

  // Local state for address
  Address _address = Address();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _streetController.dispose();
    _wardController.dispose();
    _districtController.dispose();
    _provinceController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  void _initializeControllers() {
    final address = _profileData?['address'];
    if (address != null) {
      _address = Address.fromJson(address);
      _streetController.text = _address.street ?? '';
      _wardController.text = _address.ward ?? '';
      _districtController.text = _address.district ?? '';
      _provinceController.text = _address.province ?? '';
      _cityController.text = _address.city ?? '';
    } else {
      // Set default values from translations
      _streetController.text = tr('profile.default.address');
      _wardController.text = tr('profile.default.ward');
      _districtController.text = tr('profile.default.district');
      _provinceController.text = tr('profile.default.province');
      _cityController.text = tr('profile.default.city');
    }

    // Set phone from user data or profile data
    final phone = _profileData?['phone'];
    _phoneController.text = phone ?? tr('profile.default.phone');
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Example authenticated API call to get user profile
      final response = await ApiClient.get('/account/profile');

      final apiResponse = ApiResponse.fromJson(response.body);
      if (apiResponse.success) {
        setState(() {
          _profileData = apiResponse.data;
        });

        // Initialize controllers with loaded data
        _initializeControllers();
      } else {
        setState(() {
          _errorMessage = apiResponse.message;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Create the update body with phone and address
      final Map<String, dynamic> updates = {
        'phone': _phoneController.text,
        'address': {
          'street': _streetController.text,
          'ward': _wardController.text,
          'district': _districtController.text,
          'province': _provinceController.text,
          'city': _cityController.text,
        },
      };

      final response = await ApiClient.put(
        '/account/edit-profile',
        body: updates,
      );

      final apiResponse = ApiResponse.fromJson(response.body);
      if (apiResponse.success) {
        setState(() {
          _profileData = apiResponse.data;
        });

        // TODO: Update user in AuthProvider when user state is available
        // This would require extending AuthState to include user data

        final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr('profile.address_updated'),
              style: AppTypography.bodyText.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
            backgroundColor: isDarkMode
                ? AppColors.dmSuccessColor
                : AppColors.successColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        setState(() {
          _errorMessage = apiResponse.message;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });

      final bool isDarkErrorMode =
          Theme.of(context).brightness == Brightness.dark;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to update profile: $e',
            style: AppTypography.bodyText.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
          backgroundColor: isDarkErrorMode
              ? AppColors.dmRejectColor
              : AppColors.rejectColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // TODO: User data is not yet available in AuthState
    // When AuthState is extended to include user data, uncomment and use:
    // final authState = ref.watch(authProvider);
    // final user = authState.user;
    final user = null;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Initialize controllers if not already done
    if (_phoneController.text.isEmpty && user != null) {
      _initializeControllers();
    }

    return Scaffold(
      backgroundColor: isDarkMode
          ? AppColors.dmBackgroundColor
          : AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: isDarkMode
            ? AppColors.dmBackgroundColor
            : AppColors.backgroundColor,
        title: Text(
          tr('profile.personal_info'),
          style: isDarkMode
              ? AppTypography.dmTitleText
              : AppTypography.titleText,
        ),
        iconTheme: IconThemeData(
          color: isDarkMode ? AppColors.dmDefaultColor : AppColors.defaultColor,
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            color: isDarkMode ? AppColors.buttonColor : AppColors.buttonColor,
            onPressed: _isLoading ? null : _loadProfile,
          ),
        ],
      ),
      body: Container(
        color: isDarkMode
            ? AppColors.dmBackgroundColor
            : AppColors.backgroundColor,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isLoading)
                  Center(
                    child: CircularProgressIndicator(
                      color: isDarkMode
                          ? AppColors.dmButtonColor
                          : AppColors.buttonColor,
                    ),
                  )
                else if (_errorMessage != null)
                  Card(
                    color: isDarkMode
                        ? AppColors.dmRejectColor.withOpacity(0.2)
                        : AppColors.rejectColor.withOpacity(0.1),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr('auth.error'),
                            style:
                                (isDarkMode
                                        ? AppTypography.dmSubTitleText
                                        : AppTypography.subTitleText)
                                    .copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: isDarkMode
                                          ? AppColors.dmRejectColor
                                          : AppColors.rejectColor,
                                    ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _errorMessage!,
                            style:
                                (isDarkMode
                                        ? AppTypography.dmBodyText
                                        : AppTypography.bodyText)
                                    .copyWith(
                                      color: isDarkMode
                                          ? AppColors.dmRejectColor.withOpacity(
                                              0.9,
                                            )
                                          : AppColors.rejectColor,
                                    ),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: _loadProfile,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDarkMode
                                  ? AppColors.dmRejectColor
                                  : AppColors.rejectColor,
                              foregroundColor: Colors.white,
                            ),
                            child: Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                else ...[
                  // Personal Information
                  Card(
                    color: isDarkMode ? AppColors.dmCardColor : Colors.white,
                    elevation: isDarkMode ? 2 : 1,
                    shadowColor: isDarkMode
                        ? AppColors.dmButtonColor.withOpacity(0.2)
                        : AppColors.buttonColor.withOpacity(0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: isDarkMode
                          ? BorderSide(
                              color: AppColors.dmCardColor.withOpacity(0.6),
                              width: 1,
                            )
                          : BorderSide.none,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr('profile.personal_info'),
                            style: isDarkMode
                                ? AppTypography.dmTitleText
                                : AppTypography.titleText,
                          ),
                          const SizedBox(height: 16),
                          if (user != null) ...[
                            _buildInfoRow(
                              tr('profile.full_name'),
                              "${user.firstName} ${user.lastName}",
                            ),
                            _buildInfoRow(
                              tr('profile.username'),
                              user.username,
                            ),
                            _buildInfoRow(tr('profile.email'), user.email),
                          ] else
                            Text(
                              'No user data available',
                              style:
                                  (isDarkMode
                                          ? AppTypography.dmBodyText
                                          : AppTypography.bodyText)
                                      .copyWith(
                                        fontStyle: FontStyle.italic,
                                        color: isDarkMode
                                            ? AppColors.dmDefaultColor
                                                  .withOpacity(0.7)
                                            : AppColors.defaultColor
                                                  .withOpacity(0.7),
                                      ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Contact Information (Editable Phone)
                  Card(
                    color: isDarkMode ? AppColors.dmCardColor : Colors.white,
                    elevation: isDarkMode ? 2 : 1,
                    shadowColor: isDarkMode
                        ? AppColors.dmButtonColor.withOpacity(0.2)
                        : AppColors.buttonColor.withOpacity(0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: isDarkMode
                          ? BorderSide(
                              color: AppColors.dmCardColor.withOpacity(0.6),
                              width: 1,
                            )
                          : BorderSide.none,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr('profile.contact_info'),
                            style: isDarkMode
                                ? AppTypography.dmTitleText
                                : AppTypography.titleText,
                          ),
                          const SizedBox(height: 16),
                          // Phone Number (editable)
                          CustomInput(
                            labelKey: 'profile.phone',
                            hintKey: 'auth.input.phone_hint',
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Address Information (Editable)
                  Card(
                    color: isDarkMode ? AppColors.dmCardColor : Colors.white,
                    elevation: isDarkMode ? 2 : 1,
                    shadowColor: isDarkMode
                        ? AppColors.dmButtonColor.withOpacity(0.2)
                        : AppColors.buttonColor.withOpacity(0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: isDarkMode
                          ? BorderSide(
                              color: AppColors.dmCardColor.withOpacity(0.6),
                              width: 1,
                            )
                          : BorderSide.none,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr('profile.address_info'),
                            style: isDarkMode
                                ? AppTypography.dmTitleText
                                : AppTypography.titleText,
                          ),
                          const SizedBox(height: 16),

                          // Street Address
                          CustomInput(
                            labelKey: 'profile.address',
                            hintKey: 'profile.address_required',
                            controller: _streetController,
                            keyboardType: TextInputType.streetAddress,
                          ),
                          const SizedBox(height: 16),

                          // Ward & District (2 in a row)
                          Row(
                            children: [
                              // Ward
                              Expanded(
                                child: CustomInput(
                                  labelKey: 'profile.ward',
                                  hintKey: 'profile.ward_required',
                                  controller: _wardController,
                                ),
                              ),
                              const SizedBox(width: 16),
                              // District
                              Expanded(
                                child: CustomInput(
                                  labelKey: 'profile.district',
                                  hintKey: 'profile.district_required',
                                  controller: _districtController,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Province & City (2 in a row)
                          Row(
                            children: [
                              // Province
                              Expanded(
                                child: CustomInput(
                                  labelKey: 'profile.province',
                                  hintKey: 'profile.province_required',
                                  controller: _provinceController,
                                ),
                              ),
                              const SizedBox(width: 16),
                              // City
                              Expanded(
                                child: CustomInput(
                                  labelKey: 'profile.city',
                                  hintKey: 'profile.city_required',
                                  controller: _cityController,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _updateProfile,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: isDarkMode
                            ? AppColors.dmButtonColor
                            : AppColors.buttonColor,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: isDarkMode
                            ? AppColors.dmCardColor
                            : AppColors.cardColor.withOpacity(0.3),
                        disabledForegroundColor: isDarkMode
                            ? AppColors.dmDefaultColor.withOpacity(0.6)
                            : AppColors.defaultColor.withOpacity(0.6),
                        elevation: isDarkMode ? 4 : 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        tr('profile.save_address'),
                        style: AppTypography.buttonText,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 125,
            child: Text(
              '$label:',
              style:
                  (isDarkMode
                          ? AppTypography.dmSubTitleText
                          : AppTypography.subTitleText)
                      .copyWith(
                        color: isDarkMode
                            ? AppColors.dmDefaultColor.withOpacity(0.8)
                            : AppColors.defaultColor.withOpacity(0.8),
                        fontWeight: FontWeight.w600,
                      ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: isDarkMode
                  ? AppTypography.dmSubTitleText
                  : AppTypography.subTitleText,
            ),
          ),
        ],
      ),
    );
  }
}

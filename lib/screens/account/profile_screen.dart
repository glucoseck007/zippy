import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zippy/design/app_typography.dart';
import 'package:zippy/design/app_colors.dart';
import 'package:zippy/models/entity/account/profile.dart';
import 'package:zippy/providers/account/profile_provider.dart';
import 'package:zippy/providers/core/theme_provider.dart';
import '../../components/custom_input.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  // Controllers for editable fields
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _streetController = TextEditingController();
  final TextEditingController _wardController = TextEditingController();
  final TextEditingController _districtController = TextEditingController();
  final TextEditingController _provinceController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();

  bool _controllersInitialized = false;

  @override
  void initState() {
    super.initState();
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

  void _initializeControllers(Profile profile) {
    if (!_controllersInitialized) {
      // Set phone from profile
      _phoneController.text = profile.phone.isNotEmpty
          ? profile.phone
          : tr('profile.default.phone');

      // Handle address - if it's a structured address, parse it
      // For now, treat it as a simple string and put it in street field
      _streetController.text = profile.address.isNotEmpty
          ? profile.address
          : tr('profile.default.address');
      _wardController.text = tr('profile.default.ward');
      _districtController.text = tr('profile.default.district');
      _provinceController.text = tr('profile.default.province');
      _cityController.text = tr('profile.default.city');

      _controllersInitialized = true;
    }
  }

  Future<void> _updateProfile() async {
    try {
      // Create updated profile with new data
      final currentProfile = ref.read(profileProvider).valueOrNull;
      if (currentProfile == null) return;

      final updatedProfile = Profile(
        firstName: currentProfile.firstName,
        lastName: currentProfile.lastName,
        email: currentProfile.email,
        phone: _phoneController.text,
        address: _streetController.text, // For now, just use street as address
      );

      // Update through the provider
      await ref.read(profileProvider.notifier).updateProfile(updatedProfile);

      if (mounted) {
        final themeState = ref.watch(themeProvider);
        final bool isDarkMode = themeState.isDarkMode;
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
      }
    } catch (e) {
      if (mounted) {
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
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);
    final themeState = ref.watch(themeProvider);
    final bool isDarkMode = themeState.isDarkMode;

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
            onPressed: () => ref.refresh(profileProvider),
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
            child: profileAsync.when(
              data: (profile) {
                // Initialize controllers with profile data
                _initializeControllers(profile);

                return _buildProfileContent(profile, isDarkMode);
              },
              loading: () => Center(
                child: CircularProgressIndicator(
                  color: isDarkMode
                      ? AppColors.dmButtonColor
                      : AppColors.buttonColor,
                ),
              ),
              error: (error, stack) => _buildErrorContent(error, isDarkMode),
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

  Widget _buildErrorContent(Object error, bool isDarkMode) {
    return Card(
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
              error.toString(),
              style:
                  (isDarkMode
                          ? AppTypography.dmBodyText
                          : AppTypography.bodyText)
                      .copyWith(
                        color: isDarkMode
                            ? AppColors.dmRejectColor.withOpacity(0.9)
                            : AppColors.rejectColor,
                      ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => ref.refresh(profileProvider),
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
    );
  }

  Widget _buildProfileContent(Profile profile, bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                _buildInfoRow(
                  tr('profile.full_name'),
                  "${profile.firstName} ${profile.lastName}".trim().isNotEmpty
                      ? "${profile.firstName} ${profile.lastName}".trim()
                      : 'Not provided',
                ),
                _buildInfoRow(
                  tr('profile.email'),
                  profile.email.isNotEmpty ? profile.email : 'Not provided',
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
            onPressed: _updateProfile,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: isDarkMode
                  ? AppColors.dmButtonColor
                  : AppColors.buttonColor,
              foregroundColor: Colors.white,
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
    );
  }
}

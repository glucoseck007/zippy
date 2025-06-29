import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_client.dart';
import '../../models/entity/address.dart';
import '../../models/entity/auth/user.dart';
import '../../components/custom_input.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
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
    final phone =
        _profileData?['phone'] ??
        Provider.of<AuthProvider>(context, listen: false).currentUser?.phone;
    _phoneController.text = phone ?? tr('profile.default.phone');
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Example authenticated API call to get user profile
      final response = await ApiClient.get('/user/profile');

      if (ApiClient.isSuccessResponse(response)) {
        final data = ApiClient.handleResponse(response);
        setState(() {
          _profileData = data;
        });

        // Initialize controllers with loaded data
        _initializeControllers();
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

      if (ApiClient.isSuccessResponse(response)) {
        final data = ApiClient.handleResponse(response);
        setState(() {
          _profileData = data;
        });

        // Update the user in AuthProvider
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        if (authProvider.currentUser != null) {
          // Create an updated user with the new phone number
          final updatedUser = User(
            id: authProvider.currentUser!.id,
            username: authProvider.currentUser!.username,
            email: authProvider.currentUser!.email,
            firstName: authProvider.currentUser!.firstName,
            lastName: authProvider.currentUser!.lastName,
            phone: _phoneController.text,
            profileImage: authProvider.currentUser!.profileImage,
            isVerified: authProvider.currentUser!.isVerified,
            createdAt: authProvider.currentUser!.createdAt,
            updatedAt: DateTime.now(),
          );
          authProvider.updateUser(updatedUser);
        }

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(tr('profile.address_updated'))));
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update profile: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;

    // Initialize controllers if not already done
    if (_phoneController.text.isEmpty && user != null) {
      _initializeControllers();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('profile.personal_info')),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadProfile,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else if (_errorMessage != null)
                Card(
                  color: Colors.red.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr('auth.error'),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: _loadProfile,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                // Personal Information
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr('profile.personal_info'),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (user != null) ...[
                          _buildInfoRow(tr('profile.full_name'), user.fullName),
                          _buildInfoRow(tr('profile.username'), user.username),
                          _buildInfoRow(tr('profile.email'), user.email),
                        ] else
                          const Text('No user data available'),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Contact Information (Editable Phone)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr('profile.contact_info'),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
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
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr('profile.address_info'),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
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
                    ),
                    child: Text(tr('profile.save_address')),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

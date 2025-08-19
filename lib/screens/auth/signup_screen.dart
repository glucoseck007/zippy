import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zippy/components/custom_input.dart';
import 'package:zippy/providers/core/theme_provider.dart';
import 'package:zippy/constants/screen_size.dart';
import 'package:zippy/design/app_colors.dart';
import 'package:zippy/design/app_typography.dart';
import 'package:zippy/screens/auth/verify_screen.dart';
import 'package:zippy/utils/navigation_manager.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  // Split full name into first and last name controllers
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _agreeToTerms = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Additional validation for terms acceptance
    if (!_agreeToTerms) {
      _showErrorDialog(tr('auth.validation.terms_required'));
      return;
    }

    setState(() {
      _isLoading = true;
    });
    final uri = Uri.parse(
      '${dotenv.env['BACKEND_API_ENDPOINT']}/auth/register',
    ); // Use your API base URL
    final body = jsonEncode({
      'username': _usernameController.text.trim(),
      'firstName': _firstNameController.text.trim(),
      'lastName': _lastNameController.text.trim(),
      'email': _emailController.text.trim(),
      'phone': _phoneController.text.trim(),
      'password': _passwordController.text,
      'confirmPassword': _confirmPasswordController.text,
      'termsAccepted': _agreeToTerms,
    });
    try {
      final resp = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );
      if (resp.statusCode == 201) {
        // Navigate to verify screen with user's email
        if (mounted) {
          NavigationManager.navigateToWithSlideTransition(
            context,
            VerifyScreen(
              email: _emailController.text.trim(),
              password: _passwordController.text.trim(),
              autoSendOtp:
                  false, // Don't auto-send since registration sends OTP
            ),
          );
        }
      } else if (resp.statusCode == 500) {
        // Handle server errors
        final msg = jsonDecode(resp.body)['message'] ?? tr('auth.error_server');
        if (mounted) {
          _showErrorDialog(msg);
        }
      } else if (resp.statusCode == 403) {
        // Handle forbidden errors - account created but needs verification
        final msg =
            jsonDecode(resp.body)['message'] ?? tr('auth.error_not_verified');
        if (mounted) {
          // Show dialog and navigate after user clicks OK
          _showVerificationDialog(msg);
        }
      } else if (resp.statusCode == 401) {
        // Handle unauthorized errors
        final msg =
            jsonDecode(resp.body)['message'] ??
            tr('auth.error_email_already_exists');
        if (mounted) {
          _showErrorDialog(msg);
        }
      } else {
        final msg =
            jsonDecode(resp.body)['message'] ?? tr('auth.signup_failed');
        if (mounted) {
          _showErrorDialog(msg);
        }
      }
    } on SocketException {
      if (mounted) {
        _showErrorDialog(tr('auth.error_connection'));
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog(e.toString());
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String? _validateEmail(String? v) {
    if (v == null || v.trim().isEmpty) {
      return tr('auth.validation.email_required');
    }
    final re = RegExp(r"^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}");
    return re.hasMatch(v.trim()) ? null : tr('auth.validation.email_invalid');
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return tr('auth.validation.password_required');
    return v.length < 6 ? tr('auth.validation.password_short') : null;
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('auth.error')),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(tr('auth.ok')),
          ),
        ],
      ),
    );
  }

  void _showVerificationDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('auth.error')),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop(); // Close dialog first

              // Send resend OTP request before navigating
              final email = _emailController.text.trim();
              try {
                final resendUri = Uri.parse(
                  '${dotenv.env['BACKEND_API_ENDPOINT']}/auth/resend-otp',
                );
                await http.get(
                  resendUri.replace(queryParameters: {'credential': email}),
                  headers: {'Content-Type': 'application/json'},
                );
              } catch (e) {
                print('Resend OTP error: $e');
              }

              // Navigate to verify screen
              if (mounted) {
                NavigationManager.navigateToWithSlideTransition(
                  context,
                  VerifyScreen(
                    email: email,
                    password: _passwordController.text.trim(),
                    autoSendOtp: false, // Don't auto-send since we just sent it
                  ),
                );
              }
            },
            child: Text(tr('auth.ok')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProviderState = ref.watch(themeProvider);
    final isDarkMode = themeProviderState.isDarkMode;

    return SafeArea(
      child: Scaffold(
        backgroundColor: isDarkMode
            ? AppColors.backgroundColor
            : AppColors.dmBackgroundColor,
        body: Form(
          key: _formKey,
          child: Column(
            children: [
              // Header Section
              Container(
                width: double.infinity,
                padding: EdgeInsets.only(
                  top: (ScreenSize.height(context) * 0.05),
                  bottom: (ScreenSize.width(context) * 0.1),
                ),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? AppColors.backgroundColor
                      : AppColors.dmBackgroundColor,
                ),
                child: Column(
                  children: [
                    // Back Arrow
                    Row(
                      children: [
                        Container(
                          margin: const EdgeInsets.only(left: 16),
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDarkMode
                                ? AppColors.dmInputColor
                                : AppColors.inputColor,
                            boxShadow: [
                              BoxShadow(
                                // ignore: deprecated_member_use
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(22),
                              onTap: () {
                                NavigationManager.popWithTransition(context);
                              },
                              child: Padding(
                                padding: const EdgeInsets.only(left: 6),
                                child: Center(
                                  child: Icon(
                                    Icons.arrow_back_ios,
                                    color: isDarkMode
                                        ? AppColors.dmHeadingColor
                                        : AppColors.headingColor,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(child: Container()),
                      ],
                    ),
                    Text(
                      tr('auth.signup'),
                      style: isDarkMode
                          ? AppTypography.heading(context)
                          : AppTypography.dmHeading(context),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      tr('auth.signup_subtitle'),
                      style: isDarkMode
                          ? AppTypography.subTitleText(context)
                          : AppTypography.dmSubTitleText(context),
                    ),
                  ],
                ),
              ),
              // Form Section
              Expanded(
                child: Card(
                  margin: EdgeInsets.zero,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Full Name Input (split into first and last)
                          Row(
                            children: [
                              Expanded(
                                child: CustomInput(
                                  controller: _lastNameController,
                                  validator: (v) => v!.isEmpty
                                      ? tr('auth.validation.last_name_required')
                                      : null,
                                  labelKey: 'auth.input.last_name',
                                  hintKey: 'auth.input.last_name_hint',
                                  keyboardType: TextInputType.name,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: CustomInput(
                                  controller: _firstNameController,
                                  validator: (v) => v!.isEmpty
                                      ? tr(
                                          'auth.validation.first_name_required',
                                        )
                                      : null,
                                  labelKey: 'auth.input.first_name',
                                  hintKey: 'auth.input.first_name_hint',
                                  keyboardType: TextInputType.name,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Username Input
                          CustomInput(
                            controller: _usernameController,
                            validator: (v) => v!.isEmpty
                                ? tr('auth.validation.username_required')
                                : null,
                            labelKey: 'auth.input.username',
                            hintKey: 'auth.input.username_hint',
                            keyboardType: TextInputType.text,
                          ),
                          const SizedBox(height: 16),
                          CustomInput(
                            controller: _emailController,
                            validator: _validateEmail,
                            labelKey: 'auth.input.email',
                            hintKey: 'auth.input.email_hint',
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 16),
                          CustomInput(
                            controller: _phoneController,
                            validator: (v) => v!.isEmpty
                                ? tr('auth.validation.phone_required')
                                : null,
                            labelKey: 'auth.input.phone',
                            hintKey: 'auth.input.phone_hint',
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 16),
                          CustomInput(
                            controller: _passwordController,
                            validator: _validatePassword,
                            labelKey: 'auth.input.password',
                            hintKey: 'auth.input.password_hint',
                            obscureText: !_isPasswordVisible,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _isPasswordVisible
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                              onPressed: () => setState(
                                () => _isPasswordVisible = !_isPasswordVisible,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          CustomInput(
                            controller: _confirmPasswordController,
                            validator: (v) => v != _passwordController.text
                                ? tr('auth.validation.password_mismatch')
                                : null,
                            labelKey: 'auth.input.confirm_password',
                            hintKey: 'auth.input.confirm_password_hint',
                            obscureText: !_isConfirmPasswordVisible,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _isConfirmPasswordVisible
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                              onPressed: () => setState(
                                () => _isConfirmPasswordVisible =
                                    !_isConfirmPasswordVisible,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Terms & Conditions Checkbox
                          Row(
                            children: [
                              Checkbox(
                                value: _agreeToTerms,
                                onChanged: (value) {
                                  setState(() {
                                    _agreeToTerms = value!;
                                  });
                                },
                              ),
                              Expanded(
                                child: Text(
                                  tr('auth.checkbox.agree_terms'),
                                  style: isDarkMode
                                      ? AppTypography.dmBodyText(context)
                                      : AppTypography.bodyText(context),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          // Sign Up Button
                          Center(
                            child: SizedBox(
                              width: ScreenSize.width(context) * 0.8,
                              child: ElevatedButton(
                                onPressed: _agreeToTerms && !_isLoading
                                    ? _handleSignup
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                ),
                                child: _isLoading
                                    ? SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          color: isDarkMode
                                              ? AppColors.dmButtonColor
                                              : AppColors.buttonColor,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(tr('auth.button.create_account')),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Login Option
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                tr('auth.haveAccount'),
                                style: isDarkMode
                                    ? AppTypography.dmBodyText(context)
                                    : AppTypography.bodyText(context),
                              ),
                              TextButton(
                                onPressed: () {
                                  NavigationManager.popWithTransition(context);
                                },
                                child: Text(
                                  tr('auth.button.login'),
                                  style: TextStyle(
                                    color: AppColors.buttonColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

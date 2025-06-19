import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:zippy/components/custom_input.dart';
import 'package:zippy/constants/screen_size.dart';
import 'package:zippy/design/app_colors.dart';
import 'package:zippy/design/app_typography.dart';
import 'package:zippy/providers/theme_provider.dart';
import 'package:zippy/providers/auth_provider.dart';
import 'package:zippy/screens/auth/signup_screen.dart';
import 'package:zippy/screens/auth/forgot_password_screen.dart';
import 'package:zippy/screens/auth/verify_screen.dart';
import 'package:zippy/utils/navigation_manager.dart';
import 'dart:io';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailOrUsernameController =
      TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _rememberMe = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailOrUsernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validateEmailOrUsername(String? v) {
    if (v == null || v.trim().isEmpty) {
      return tr('auth.validation.email_or_username_required');
    }
    // Accept both email and username (no specific format validation)
    return null;
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) {
      return tr('auth.validation.password_required');
    }
    return null;
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

              // Send resend OTP request using AuthProvider
              final loginValue = _emailOrUsernameController.text.trim();
              try {
                final authProvider = Provider.of<AuthProvider>(
                  context,
                  listen: false,
                );
                final result = await authProvider.resendOTP(
                  credential: loginValue,
                );

                if (result.isSuccess) {
                  // Show success message if needed
                  if (mounted && result.message != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(result.message!),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } else {
                  // Show error message if resend failed
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          result.errorMessage ?? 'Failed to resend OTP',
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Resend OTP error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }

              // Navigate to verify screen
              if (mounted) {
                NavigationManager.navigateToWithSlideTransition(
                  context,
                  VerifyScreen(email: loginValue),
                );
              }
            },
            child: Text(tr('auth.ok')),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final loginValue = _emailOrUsernameController.text.trim();

    try {
      final result = await authProvider.login(
        credential: loginValue,
        password: _passwordController.text,
      );

      if (!mounted) return;

      if (result.isSuccess) {
        // Navigate to home on success
        Navigator.of(context).pushReplacementNamed('/home');
      } else if (result.isVerificationError) {
        // Handle account not verified
        _showVerificationDialog(
          result.errorMessage ?? tr('auth.error_not_verified'),
        );
      } else {
        // Handle other errors
        _showErrorDialog(result.errorMessage ?? tr('auth.login_failed'));
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
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    // determine if login can be attempted
    final canLogin =
        _emailOrUsernameController.text.trim().isNotEmpty &&
        _passwordController.text.isNotEmpty;
    // rebuild when controllers change
    _emailOrUsernameController.addListener(() => setState(() {}));
    _passwordController.addListener(() => setState(() {}));

    return SafeArea(
      child: Scaffold(
        backgroundColor: isDarkMode
            ? AppColors.dmBackgroundColor
            : AppColors.dmBackgroundColor,
        body: Form(
          key: _formKey,
          child: Column(
            children: [
              // Header Section
              Container(
                width: double.infinity,
                padding: EdgeInsets.only(
                  top: (ScreenSize.height(context) * 0.15),
                  bottom: (ScreenSize.width(context) * 0.1),
                ),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? AppColors.backgroundColor
                      : AppColors.dmBackgroundColor,
                ),
                child: Column(
                  children: [
                    Text(
                      tr('auth.login'),
                      style: isDarkMode
                          ? AppTypography.heading
                          : AppTypography.dmHeading,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      tr('auth.login_subtitle'),
                      style: isDarkMode
                          ? AppTypography.subTitleText
                          : AppTypography.dmSubTitleText,
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
                          CustomInput(
                            labelKey: 'auth.input.email_or_username',
                            hintKey: 'auth.input.email_or_username_hint',
                            controller: _emailOrUsernameController,
                            validator: _validateEmailOrUsername,
                            keyboardType: TextInputType.text,
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 16),
                          CustomInput(
                            labelKey: 'auth.input.password',
                            hintKey: 'auth.input.password_hint',
                            controller: _passwordController,
                            validator: _validatePassword,
                            obscureText: !_isPasswordVisible,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _isPasswordVisible
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                color: Colors.grey,
                              ),
                              onPressed: () {
                                setState(() {
                                  _isPasswordVisible = !_isPasswordVisible;
                                });
                              },
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 16),
                          // Remember Me and Forgot Password
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Checkbox(
                                    value: _rememberMe,
                                    onChanged: (value) {
                                      setState(() {
                                        _rememberMe = value!;
                                      });
                                    },
                                  ),
                                  Text(tr('auth.checkbox.remember_me')),
                                ],
                              ),
                              TextButton(
                                onPressed: () {
                                  NavigationManager.navigateToWithSlideTransition(
                                    context,
                                    const ForgotPasswordScreen(),
                                  );
                                },
                                child: Text(
                                  tr('auth.button.forgot_password'),
                                  style: TextStyle(
                                    color: AppColors.buttonColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Login Button
                          Center(
                            child: SizedBox(
                              width: ScreenSize.width(context) * 0.8,
                              child: ElevatedButton(
                                onPressed: canLogin ? _handleLogin : null,
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
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(tr('auth.button.login')),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Sign-Up Option
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                tr('auth.createAccount'),
                                style: isDarkMode
                                    ? AppTypography.dmBodyText
                                    : AppTypography.bodyText,
                              ),
                              TextButton(
                                onPressed: () {
                                  NavigationManager.navigateToWithSlideTransition(
                                    context,
                                    const SignupScreen(),
                                  );
                                },
                                child: Text(
                                  tr('auth.button.signup'),
                                  style: TextStyle(
                                    color: AppColors.buttonColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Social Login Separator
                          Center(
                            child: Text(
                              tr('auth.or'),
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Social Login Buttons
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: const BoxDecoration(
                                  color: Colors.blue,
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.facebook,
                                    color: Colors.white,
                                  ),
                                  onPressed: () {
                                    // Handle Facebook login
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              Container(
                                width: 50,
                                height: 50,
                                decoration: const BoxDecoration(
                                  color: Colors.lightBlue,
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.alarm, // Placeholder for Twitter
                                    color: Colors.white,
                                  ),
                                  onPressed: () {
                                    // Handle Twitter login
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              Container(
                                width: 50,
                                height: 50,
                                decoration: const BoxDecoration(
                                  color: Colors.black,
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.apple,
                                    color: Colors.white,
                                  ),
                                  onPressed: () {
                                    // Handle Apple login
                                  },
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

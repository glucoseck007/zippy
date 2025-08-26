import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zippy/components/custom_input.dart';
import 'package:zippy/constants/screen_size.dart';
import 'package:zippy/design/app_colors.dart';
import 'package:zippy/design/app_typography.dart';
import 'package:zippy/providers/core/theme_provider.dart';
import 'package:zippy/utils/navigation_manager.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Listen to email changes to update button state
    _emailController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleResetPassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _isLoading = true;
    });
    final uri = Uri.parse(
      '${dotenv.env['BACKEND_API_ENDPOINT']}/auth/forgot-password',
    );
    final body = jsonEncode({'email': _emailController.text.trim()});
    try {
      final resp = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );
      if (resp.statusCode == 200) {
        if (mounted) {
          _showSuccessDialog();
        }
      } else {
        final msg = jsonDecode(resp.body)['message'] ?? tr('auth.reset_failed');
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

  bool _isEmailValid() {
    final email = _emailController.text.trim();
    return email.isNotEmpty &&
        RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(tr('auth.error')),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(tr('auth.button.ok')),
            ),
          ],
        );
      },
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(tr('auth.reset_password_sent')),
          content: Text(tr('auth.reset_password_instruction')),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                NavigationManager.popWithTransition(context);
              },
              child: Text(tr('auth.button.ok')),
            ),
          ],
        );
      },
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
                                color: isDarkMode
                                    ? Colors.black.withValues(alpha: 0.3)
                                    : Colors.black.withValues(alpha: 0.1),
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
                      tr('auth.forgot_password'),
                      style: isDarkMode
                          ? AppTypography.heading(context)
                          : AppTypography.dmHeading(context),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      tr('auth.forgot_password_subtitle'),
                      style: isDarkMode
                          ? AppTypography.subTitleText(context)
                          : AppTypography.dmSubTitleText(context),
                      textAlign: TextAlign.center,
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),
                        // Email Input
                        CustomInput(
                          labelKey: 'auth.input.email',
                          hintKey: 'auth.input.email_hint',
                          keyboardType: TextInputType.emailAddress,
                          controller: _emailController,
                          validator: _validateEmail,
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 32),
                        // Reset Password Button
                        Center(
                          child: SizedBox(
                            width: ScreenSize.width(context) * 0.8,
                            child: ElevatedButton(
                              onPressed: _isEmailValid() && !_isLoading
                                  ? _handleResetPassword
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
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(tr('auth.button.reset_password')),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Back to Login
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              tr('auth.remember_password'),
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
                                style: TextStyle(color: AppColors.buttonColor),
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        // Info Text
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDarkMode
                                ? AppColors.dmInputColor.withValues(alpha: 0.5)
                                : AppColors.inputColor.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: isDarkMode
                                    ? Colors.lightBlueAccent
                                    : Colors.blue,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  tr('auth.reset_password_info'),
                                  style: isDarkMode
                                      ? AppTypography.dmBodyText(
                                          context,
                                        ).copyWith(fontSize: 12)
                                      : AppTypography.bodyText(
                                          context,
                                        ).copyWith(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
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

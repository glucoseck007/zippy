import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:zippy/constants/screen_size.dart';
import 'package:zippy/design/app_colors.dart';
import 'package:zippy/design/app_typography.dart';
import 'package:zippy/providers/theme_provider.dart';

class VerifyScreen extends StatefulWidget {
  final String email;

  const VerifyScreen({super.key, required this.email});

  @override
  State<VerifyScreen> createState() => _VerifyScreenState();
}

class _VerifyScreenState extends State<VerifyScreen> {
  // Verification code digits
  final List<TextEditingController> _controllers = List.generate(
    6, // 6-digit code
    (_) => TextEditingController(),
  );

  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  // Timer related
  Timer? _timer;
  int _secondsRemaining = 120; // 2 minutes
  bool _isLoading = false; // Loading state for verification

  @override
  void initState() {
    super.initState();
    startTimer();

    // Set up focus changes
    for (int i = 0; i < 6; i++) {
      _controllers[i].addListener(() {
        if (_controllers[i].text.length == 1 && i < 5) {
          // Move to next field
          FocusScope.of(context).requestFocus(_focusNodes[i + 1]);
        }
      });
    }
  }

  void startTimer() {
    _timer?.cancel(); // Cancel any existing timer
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_secondsRemaining > 0) {
            _secondsRemaining--;
            print('Timer: $_secondsRemaining seconds remaining'); // Debug print
          } else {
            _timer?.cancel();
            print('Timer: finished'); // Debug print
          }
        });
      }
    });
  }

  Future<void> resendCode() async {
    try {
      // Reset timer
      setState(() {
        _secondsRemaining = 120;
      });
      startTimer(); // Restart the timer

      // Call API to resend OTP
      final uri = Uri.parse(
        '${dotenv.env['BACKEND_API_ENDPOINT']}/auth/resend-otp',
      );
      final response = await http.get(
        uri.replace(queryParameters: {'email': widget.email}),
        headers: {'Content-Type': 'application/json'},
      );

      if (mounted) {
        if (response.statusCode == 200) {
          // Show success feedback
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(tr('auth.resend_code_sent')),
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          // Show error message
          final errorMsg =
              jsonDecode(response.body)['message'] ?? 'Failed to resend code';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMsg), duration: Duration(seconds: 3)),
          );
        }
      }
    } on SocketException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('auth.error_connection')),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> verifyCode() async {
    // Get full code
    final code = _controllers.map((controller) => controller.text).join();
    if (code.length != 6) {
      // Show error if code is incomplete
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('auth.validation.complete_code'))),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Call API to verify code
      final uri = Uri.parse(
        '${dotenv.env['BACKEND_API_ENDPOINT']}/auth/verify-otp',
      );
      final body = jsonEncode({'credential': widget.email, 'otp': code});

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (mounted) {
        if (response.statusCode == 200) {
          // Verification successful, navigate to home
          Navigator.of(context).pushReplacementNamed('/home');
        } else {
          // Show error message
          final errorData = jsonDecode(response.body);
          final errorMsg =
              errorData['message'] ?? tr('auth.verification_failed');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMsg), duration: Duration(seconds: 3)),
          );
        }
      }
    } on SocketException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('auth.error_connection')),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            duration: Duration(seconds: 3),
          ),
        );
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
  void dispose() {
    _timer?.cancel();
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  Widget _buildKeyboardButton(String number, String letters) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return InkWell(
      onTap: () {
        // Find first empty controller
        for (int i = 0; i < 6; i++) {
          if (_controllers[i].text.isEmpty) {
            _controllers[i].text = number;
            break;
          }
        }
      },
      child: Container(
        width: 80,
        height: 55,
        decoration: BoxDecoration(
          color: isDarkMode
              ? AppColors.dmInputColor.withOpacity(0.8)
              : AppColors.inputColor.withOpacity(0.8),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              number,
              style: isDarkMode
                  ? AppTypography.dmTitleText
                  : AppTypography.titleText,
            ),
            if (letters.isNotEmpty)
              Text(
                letters,
                style: TextStyle(
                  fontSize: 10,
                  color: isDarkMode
                      ? AppColors.dmDefaultColor.withOpacity(0.6)
                      : AppColors.defaultColor.withOpacity(0.6),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: isDarkMode
          ? AppColors.dmBackgroundColor
          : AppColors.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header section with dark background
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              // Limit header height
              constraints: BoxConstraints(maxHeight: screenHeight * 0.25),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? AppColors.dmBackgroundColor
                    : AppColors.backgroundColor,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back button
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.arrow_back_ios_new,
                        color: isDarkMode
                            ? AppColors.dmDefaultColor
                            : AppColors.defaultColor,
                        size: 16,
                      ),
                    ),
                  ),
                  Spacer(),

                  // Verification text - centered content
                  Center(
                    child: Column(
                      children: [
                        Text(
                          tr('auth.verification'),
                          style: isDarkMode
                              ? AppTypography.dmHeading
                              : AppTypography.heading,
                        ),
                        SizedBox(height: 8),
                        Text(
                          tr('auth.verification_subtitle'),
                          style: isDarkMode
                              ? AppTypography.dmBodyText
                              : AppTypography.bodyText,
                        ),
                        SizedBox(height: 8),
                      ],
                    ),
                  ),
                  Spacer(),
                ],
              ),
            ),

            // Main content area
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
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 20,
                  ),
                  children: [
                    // Code label and resend
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          tr('auth.verification_code'),
                          style: isDarkMode
                              ? AppTypography.dmBodyText.copyWith(
                                  fontWeight: FontWeight.bold,
                                )
                              : AppTypography.bodyText.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                        ),
                        TextButton(
                          onPressed: _secondsRemaining == 0 ? resendCode : null,
                          child: Text(
                            _secondsRemaining == 0
                                ? tr('auth.resend_code')
                                : tr('auth.resend_in').replaceAll(
                                    '{0}',
                                    _secondsRemaining.toString(),
                                  ),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: _secondsRemaining == 0
                                  ? AppColors.buttonColor
                                  : isDarkMode
                                  ? AppColors.dmDefaultColor.withOpacity(0.5)
                                  : AppColors.defaultColor.withOpacity(0.5),
                            ),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: ScreenSize.height(context) * 0.02),

                    // Code input boxes
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(
                        6,
                        (index) => Container(
                          width: 45,
                          height: 45,
                          decoration: BoxDecoration(
                            color: isDarkMode
                                ? AppColors.dmInputColor
                                : AppColors.inputColor,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isDarkMode
                                  ? AppColors.dmInputColor
                                  : AppColors.inputColor,
                              width: 1,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: TextField(
                            controller: _controllers[index],
                            focusNode: _focusNodes[index],
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            maxLength: 1,
                            style: isDarkMode
                                ? AppTypography.dmTitleText
                                : AppTypography.titleText,
                            decoration: InputDecoration(
                              counterText: '',
                              border: InputBorder.none,
                            ),
                            onChanged: (value) {
                              if (value.isEmpty && index > 0) {
                                // Move to previous field on backspace
                                FocusScope.of(
                                  context,
                                ).requestFocus(_focusNodes[index - 1]);
                              }
                            },
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: ScreenSize.height(context) * 0.05),

                    // Verify button
                    Center(
                      child: SizedBox(
                        width: MediaQuery.of(context).size.width * 0.8,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : verifyCode,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.buttonColor,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
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
                              : Text(
                                  tr('auth.button.verify'),
                                  style: AppTypography.buttonText,
                                ),
                        ),
                      ),
                    ),

                    SizedBox(height: ScreenSize.height(context) * 0.08),

                    // Numeric keyboard - optimized for space
                    // Row 1: 1-2-3
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildKeyboardButton('1', ''),
                        _buildKeyboardButton('2', 'ABC'),
                        _buildKeyboardButton('3', 'DEF'),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Row 2: 4-5-6
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildKeyboardButton('4', 'GHI'),
                        _buildKeyboardButton('5', 'JKL'),
                        _buildKeyboardButton('6', 'MNO'),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Row 3: 7-8-9
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildKeyboardButton('7', 'PQRS'),
                        _buildKeyboardButton('8', 'TUV'),
                        _buildKeyboardButton('9', 'WXYZ'),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Row 4: Empty-0-Backspace
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Container(width: 70), // Empty space
                        _buildKeyboardButton('0', ''),
                        InkWell(
                          onTap: () {
                            // Handle backspace
                            for (int i = 5; i >= 0; i--) {
                              if (_controllers[i].text.isNotEmpty) {
                                _controllers[i].clear();
                                if (i > 0) {
                                  FocusScope.of(
                                    context,
                                  ).requestFocus(_focusNodes[i]);
                                }
                                break;
                              }
                            }
                          },
                          child: Container(
                            width: 70,
                            height: 45,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                            ),
                            child: Icon(
                              Icons.backspace_outlined,
                              color: isDarkMode
                                  ? AppColors.dmDefaultColor.withOpacity(0.6)
                                  : AppColors.defaultColor.withOpacity(0.6),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

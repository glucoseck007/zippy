import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:zippy/design/app_colors.dart';
import 'package:zippy/design/app_typography.dart';
import 'package:zippy/providers/core/theme_provider.dart';
import 'package:zippy/services/pickup/pickup_service.dart';

class OTPVerificationDialog extends ConsumerStatefulWidget {
  final String orderCode;
  final String tripCode;
  final VoidCallback onSuccess;

  const OTPVerificationDialog({
    super.key,
    required this.orderCode,
    required this.tripCode,
    required this.onSuccess,
  });

  @override
  ConsumerState<OTPVerificationDialog> createState() =>
      _OTPVerificationDialogState();
}

class _OTPVerificationDialogState extends ConsumerState<OTPVerificationDialog> {
  String _otpValue = '';
  bool _isVerifying = false;
  bool _isResending = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    // Automatically send OTP when dialog is first displayed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sendInitialOTP();
    });
  }

  Future<void> _sendInitialOTP() async {
    try {
      await PickupService.sendOtp(widget.orderCode, widget.tripCode);
    } catch (e) {
      // If initial OTP sending fails, user can still use resend button
      // We don't show an error here to avoid interrupting the dialog display
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeProvider);
    final isDarkMode = themeState.isDarkMode;

    return AlertDialog(
      backgroundColor: isDarkMode ? AppColors.dmCardColor : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        tr('pickup.otp_verification.title'),
        style: isDarkMode
            ? AppTypography.dmHeading(context)
            : AppTypography.heading(context),
        textAlign: TextAlign.center,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tr('pickup.otp_verification.message'),
              style: isDarkMode
                  ? AppTypography.dmBodyText(context)
                  : AppTypography.bodyText(context),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // OTP Input Field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: PinCodeTextField(
                appContext: context,
                length: 6,
                keyboardType: TextInputType.number,
                animationType: AnimationType.fade,
                pinTheme: PinTheme(
                  shape: PinCodeFieldShape.box,
                  borderRadius: BorderRadius.circular(8),
                  fieldHeight:
                      MediaQuery.of(context).size.height *
                      0.06, // Dynamic height
                  fieldWidth:
                      MediaQuery.of(context).size.width *
                      0.08, // Even smaller width to prevent overflow
                  activeFillColor: isDarkMode
                      ? AppColors.dmInputColor
                      : Colors.white,
                  inactiveFillColor: isDarkMode
                      ? AppColors.dmInputColor.withOpacity(0.5)
                      : Colors.grey[100],
                  selectedFillColor: isDarkMode
                      ? AppColors.dmInputColor.withOpacity(0.8)
                      : Colors.grey[200],
                  activeColor: isDarkMode
                      ? AppColors.dmButtonColor
                      : AppColors.buttonColor,
                  inactiveColor: isDarkMode
                      ? Colors.grey[600]
                      : Colors.grey[300],
                  selectedColor: isDarkMode
                      ? AppColors.dmButtonColor
                      : AppColors.buttonColor,
                ),
                enableActiveFill: true,
                cursorColor: isDarkMode
                    ? AppColors.dmDefaultColor
                    : AppColors.defaultColor,
                textStyle: isDarkMode
                    ? AppTypography.dmBodyText(context).copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize:
                            MediaQuery.of(context).size.width *
                            0.035, // Smaller font size for better fit
                      )
                    : AppTypography.bodyText(context).copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize:
                            MediaQuery.of(context).size.width *
                            0.035, // Smaller font size for better fit
                      ),
                onChanged: (value) {
                  setState(() {
                    _otpValue = value;
                    _errorMessage = '';
                  });
                },
                onCompleted: (value) {
                  setState(() {
                    _otpValue = value;
                  });
                  _verifyOTP();
                },
              ),
            ),

            if (_errorMessage.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage,
                style:
                    (isDarkMode
                            ? AppTypography.dmBodyText(context)
                            : AppTypography.bodyText(context))
                        .copyWith(
                          color: isDarkMode
                              ? AppColors.dmRejectColor
                              : AppColors.rejectColor,
                        ),
                textAlign: TextAlign.center,
              ),
            ],

            const SizedBox(height: 24),

            // Resend Code Button
            TextButton(
              onPressed: _isResending ? null : _resendOTP,
              child: Text(
                _isResending
                    ? tr('pickup.otp_verification.resending')
                    : tr('pickup.otp_verification.resend'),
                style:
                    (isDarkMode
                            ? AppTypography.dmBodyText(context)
                            : AppTypography.bodyText(context))
                        .copyWith(
                          color: _isResending
                              ? (isDarkMode ? Colors.grey[600] : Colors.grey)
                              : (isDarkMode
                                    ? AppColors.dmButtonColor
                                    : AppColors.buttonColor),
                        ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isVerifying ? null : () => Navigator.pop(context),
          child: Text(
            tr('pickup.confirm_pickup.cancel'),
            style:
                (isDarkMode
                        ? AppTypography.dmBodyText(context)
                        : AppTypography.bodyText(context))
                    .copyWith(
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    ),
          ),
        ),
        ElevatedButton(
          onPressed: _isVerifying || _otpValue.length != 6 ? null : _verifyOTP,
          style: ElevatedButton.styleFrom(
            backgroundColor: isDarkMode
                ? AppColors.dmButtonColor
                : AppColors.buttonColor,
            foregroundColor: Colors.white,
            disabledBackgroundColor: isDarkMode
                ? Colors.grey[700]
                : Colors.grey[300],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: _isVerifying
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(tr('pickup.otp_verification.verify')),
        ),
      ],
    );
  }

  Future<void> _verifyOTP() async {
    if (_otpValue.length != 6) {
      setState(() {
        _errorMessage = tr('pickup.otp_verification.verification_failed');
      });
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = '';
    });

    try {
      final response = await PickupService.verifyOtpAndComplete(
        widget.orderCode,
        _otpValue,
        widget.tripCode,
      );

      if (mounted) {
        if (response != null && response.success) {
          Navigator.pop(context);
          _showSuccessDialog();
        } else {
          setState(() {
            _errorMessage =
                response?.message ??
                tr('pickup.otp_verification.verification_failed');
            _isVerifying = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = tr('pickup.otp_verification.network_error');
          _isVerifying = false;
        });
      }
    }
  }

  Future<void> _resendOTP() async {
    setState(() {
      _isResending = true;
    });

    final themeState = ref.watch(themeProvider);
    final isDarkMode = themeState.isDarkMode;

    try {
      final response = await PickupService.sendOtp(
        widget.orderCode,
        widget.tripCode,
      );

      if (mounted) {
        if (response != null && response.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                tr('pickup.otp_verification.resend_success'),
                style:
                    (isDarkMode
                            ? AppTypography.dmBodyText(context)
                            : AppTypography.bodyText(context))
                        .copyWith(color: Colors.white),
              ),
              backgroundColor: isDarkMode
                  ? AppColors.dmSuccessColor
                  : AppColors.successColor,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                tr('pickup.otp_verification.resend_failed'),
                style:
                    (isDarkMode
                            ? AppTypography.dmBodyText(context)
                            : AppTypography.bodyText(context))
                        .copyWith(color: Colors.white),
              ),
              backgroundColor: isDarkMode
                  ? AppColors.dmRejectColor
                  : AppColors.rejectColor,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        setState(() {
          _isResending = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr('pickup.otp_verification.resend_failed'),
              style:
                  (isDarkMode
                          ? AppTypography.dmBodyText(context)
                          : AppTypography.bodyText(context))
                      .copyWith(color: Colors.white),
            ),
            backgroundColor: isDarkMode
                ? AppColors.dmRejectColor
                : AppColors.rejectColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() {
          _isResending = false;
        });
      }
    }
  }

  void _showSuccessDialog() {
    final themeState = ref.read(themeProvider);
    final isDarkMode = themeState.isDarkMode;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: isDarkMode ? AppColors.dmCardColor : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle,
                color: isDarkMode
                    ? AppColors.dmSuccessColor
                    : AppColors.successColor,
                size: 64,
              ),
              const SizedBox(height: 16),
              Text(
                tr('pickup.otp_verification.verification_success'),
                style: isDarkMode
                    ? AppTypography.dmHeading(context)
                    : AppTypography.heading(context),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Close success dialog
                widget.onSuccess(); // Refresh the pickup screen
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isDarkMode
                    ? AppColors.dmButtonColor
                    : AppColors.buttonColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(tr('pickup.common.ok')),
            ),
          ],
        );
      },
    );
  }
}

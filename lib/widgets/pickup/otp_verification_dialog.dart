import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:zippy/design/app_colors.dart';
import 'package:zippy/design/app_typography.dart';
import 'package:zippy/services/pickup/pickup_service.dart';

class OTPVerificationDialog extends StatefulWidget {
  final String orderCode;
  final VoidCallback onSuccess;

  const OTPVerificationDialog({
    super.key,
    required this.orderCode,
    required this.onSuccess,
  });

  @override
  State<OTPVerificationDialog> createState() => _OTPVerificationDialogState();
}

class _OTPVerificationDialogState extends State<OTPVerificationDialog> {
  final TextEditingController _otpController = TextEditingController();
  bool _isVerifying = false;
  bool _isResending = false;
  String _errorMessage = '';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        tr('pickup.otp_verification.title'),
        style: AppTypography.heading,
        textAlign: TextAlign.center,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tr('pickup.otp_verification.message'),
              style: AppTypography.bodyText,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // OTP Input Field
            PinCodeTextField(
              appContext: context,
              length: 6,
              controller: _otpController,
              keyboardType: TextInputType.number,
              animationType: AnimationType.fade,
              pinTheme: PinTheme(
                shape: PinCodeFieldShape.box,
                borderRadius: BorderRadius.circular(8),
                fieldHeight: 50,
                fieldWidth: 45,
                activeFillColor: Colors.white,
                inactiveFillColor: Colors.grey[100],
                selectedFillColor: Colors.grey[200],
                activeColor: AppColors.buttonColor,
                inactiveColor: Colors.grey[300],
                selectedColor: AppColors.buttonColor,
              ),
              enableActiveFill: true,
              onChanged: (value) {
                setState(() {
                  _errorMessage = '';
                });
              },
              onCompleted: (value) {
                _verifyOTP();
              },
            ),

            if (_errorMessage.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage,
                style: AppTypography.bodyText.copyWith(color: Colors.red),
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
                style: AppTypography.bodyText.copyWith(
                  color: _isResending ? Colors.grey : AppColors.buttonColor,
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
            style: AppTypography.bodyText.copyWith(color: Colors.grey[600]),
          ),
        ),
        ElevatedButton(
          onPressed: _isVerifying || _otpController.text.length != 6
              ? null
              : _verifyOTP,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.buttonColor,
            foregroundColor: Colors.white,
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
    if (_otpController.text.length != 6) {
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
        _otpController.text,
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

    try {
      final response = await PickupService.sendOtp(widget.orderCode);

      if (mounted) {
        if (response != null && response.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(tr('pickup.otp_verification.resend_success')),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(tr('pickup.otp_verification.resend_failed')),
              backgroundColor: Colors.red,
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
            content: Text(tr('pickup.otp_verification.resend_failed')),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isResending = false;
        });
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 64),
              const SizedBox(height: 16),
              Text(
                tr('pickup.otp_verification.verification_success'),
                style: AppTypography.heading,
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
                backgroundColor: AppColors.buttonColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(tr('order.common.ok')),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }
}

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:zippy/design/app_colors.dart';
import 'package:zippy/design/app_typography.dart';
import 'package:zippy/widgets/pickup/otp_verification_dialog.dart';

class ConfirmPickupDialog extends StatefulWidget {
  final String orderCode;
  final String tripCode;
  final String robotCode;
  final VoidCallback onSuccess;

  const ConfirmPickupDialog({
    super.key,
    required this.orderCode,
    required this.tripCode,
    required this.robotCode,
    required this.onSuccess,
  });

  @override
  State<ConfirmPickupDialog> createState() => _ConfirmPickupDialogState();
}

class _ConfirmPickupDialogState extends State<ConfirmPickupDialog> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        tr('pickup.confirm_pickup.title'),
        style: AppTypography.heading(context),
        textAlign: TextAlign.center,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.inventory_2, size: 64, color: AppColors.buttonColor),
          const SizedBox(height: 16),
          Text(
            tr('pickup.confirm_pickup.message'),
            style: AppTypography.bodyText(context),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            tr('pickup.confirm_pickup.order_code', args: [widget.orderCode]),
            style: AppTypography.bodyText(
              context,
            ).copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: Text(
            tr('pickup.confirm_pickup.cancel'),
            style: AppTypography.bodyText(
              context,
            ).copyWith(color: Colors.grey[600]),
          ),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _confirmPickup,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.buttonColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(tr('pickup.confirm_pickup.confirm')),
        ),
      ],
    );
  }

  Future<void> _confirmPickup() async {
    setState(() {
      _isLoading = true;
    });

    // Close confirm dialog and show OTP verification dialog
    Navigator.pop(context);

    // Show OTP verification dialog (which will handle sending the OTP)
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return OTPVerificationDialog(
          orderCode: widget.orderCode,
          tripCode: widget.tripCode,
          robotCode: widget.robotCode,
          onSuccess: widget.onSuccess,
        );
      },
    );
  }
}

import 'package:flutter/material.dart';

import '../../screens/payment/payment_screen.dart';

class PaymentHelper {
  /// Launch payment screen for an order
  static Future<bool?> launchPayment({
    required BuildContext context,
    required String orderId,
    double? amount,
    String? orderDescription,
  }) async {
    return await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => PaymentScreen(
          orderId: orderId,
          amount: amount,
          orderDescription: orderDescription,
        ),
        fullscreenDialog: true,
      ),
    );
  }

  /// Show payment result dialog
  static void showPaymentResult({
    required BuildContext context,
    required bool success,
    String? message,
    VoidCallback? onSuccess,
    VoidCallback? onFailure,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              success ? Icons.check_circle : Icons.error_outline,
              color: success ? Colors.green : Colors.red,
            ),
            const SizedBox(width: 8),
            Text(success ? 'Payment Successful' : 'Payment Failed'),
          ],
        ),
        content: Text(
          message ??
              (success
                  ? 'Your payment has been processed successfully.'
                  : 'Payment failed. Please try again.'),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              if (success) {
                onSuccess?.call();
              } else {
                onFailure?.call();
              }
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

/// Example usage in your order/pickup screens:
/// 
/// ```dart
/// // In your order screen or wherever you want to initiate payment
/// void _handlePayment() async {
///   final result = await PaymentHelper.launchPayment(
///     context: context,
///     orderId: widget.orderCode,
///     amount: order.price,
///     orderDescription: order.productName,
///   );
///   
///   if (result == true) {
///     // Payment successful
///     _onPaymentSuccess();
///   } else if (result == false) {
///     // Payment failed
///     _onPaymentFailure();
///   }
///   // result == null means user cancelled without completing payment
/// }
/// ```

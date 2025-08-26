import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/payment/payment_service.dart';
import '../../state/payment/payment_state.dart';

class PaymentNotifier extends StateNotifier<PaymentState> {
  PaymentNotifier() : super(const PaymentInitial());

  /// Create payment for an order
  Future<void> createPayment(String orderId) async {
    state = const PaymentLoading();

    try {
      print('PaymentProvider: Creating payment for order: $orderId');

      final paymentData = await PaymentService.createPayment(orderId);

      if (paymentData != null) {
        print('PaymentProvider: Payment created successfully');
        state = PaymentCreated(paymentData: paymentData);
      } else {
        print('PaymentProvider: Failed to create payment - no data received');
        state = const PaymentError(errorMessage: 'Failed to create payment');
      }
    } catch (e) {
      print('PaymentProvider: Error creating payment: $e');
      state = PaymentError(errorMessage: e.toString());
    }
  }

  /// Set webview loading state
  void setWebViewLoading(bool isLoading) {
    if (state is PaymentCreated) {
      final currentState = state as PaymentCreated;
      if (isLoading) {
        state = PaymentWebViewLoading(paymentData: currentState.paymentData);
      } else {
        state = PaymentCreated(paymentData: currentState.paymentData);
      }
    }
  }

  /// Handle payment result from deep link
  Future<void> handlePaymentResult(String orderId, String status) async {
    print(
      'PaymentProvider: Handling payment result - Order: $orderId, Status: $status',
    );

    state = PaymentProcessing(orderId: orderId);

    try {
      // Wait a bit for the backend to process the webhook
      await Future.delayed(const Duration(seconds: 2));

      final paymentStatus = await PaymentService.getPaymentStatus(orderId);

      if (paymentStatus != null) {
        if (paymentStatus.isPaid) {
          print('PaymentProvider: Payment successful');
          state = PaymentSuccess(paymentStatus: paymentStatus);
        } else if (paymentStatus.isPending) {
          print('PaymentProvider: Payment still pending');
          state = PaymentFailed(
            errorMessage: 'Payment is still pending. Please try again later.',
            paymentStatus: paymentStatus,
          );
        } else {
          print('PaymentProvider: Payment failed');
          state = PaymentFailed(
            errorMessage: 'Payment failed. Please try again.',
            paymentStatus: paymentStatus,
          );
        }
      } else {
        print('PaymentProvider: Failed to get payment status');
        state = const PaymentError(
          errorMessage: 'Failed to verify payment status',
        );
      }
    } catch (e) {
      print('PaymentProvider: Error handling payment result: $e');
      state = PaymentError(errorMessage: e.toString());
    }
  }

  /// Reset payment state
  void reset() {
    state = const PaymentInitial();
  }

  /// Retry payment creation
  Future<void> retryPayment(String orderId) async {
    await createPayment(orderId);
  }
}

final paymentProvider = StateNotifierProvider<PaymentNotifier, PaymentState>((
  ref,
) {
  return PaymentNotifier();
});

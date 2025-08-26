import '../../models/response/payment/payment_create_response.dart';
import '../../models/response/payment/payment_status_response.dart';

abstract class PaymentState {
  const PaymentState();
}

class PaymentInitial extends PaymentState {
  const PaymentInitial();
}

class PaymentLoading extends PaymentState {
  const PaymentLoading();
}

class PaymentCreated extends PaymentState {
  final PaymentCreateResponse paymentData;

  const PaymentCreated({required this.paymentData});
}

class PaymentProcessing extends PaymentState {
  final String orderId;

  const PaymentProcessing({required this.orderId});
}

class PaymentSuccess extends PaymentState {
  final PaymentStatusResponse paymentStatus;

  const PaymentSuccess({required this.paymentStatus});
}

class PaymentFailed extends PaymentState {
  final String errorMessage;
  final PaymentStatusResponse? paymentStatus;

  const PaymentFailed({required this.errorMessage, this.paymentStatus});
}

class PaymentError extends PaymentState {
  final String errorMessage;

  const PaymentError({required this.errorMessage});
}

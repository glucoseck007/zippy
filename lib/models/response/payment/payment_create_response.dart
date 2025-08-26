class PaymentCreateResponse {
  final String paymentId;
  final String paymentLinkId;
  final String checkoutUrl;
  final String orderCode;
  final double amount;

  const PaymentCreateResponse({
    required this.paymentId,
    required this.paymentLinkId,
    required this.checkoutUrl,
    required this.orderCode,
    required this.amount,
  });

  factory PaymentCreateResponse.fromJson(Map<String, dynamic> json) {
    return PaymentCreateResponse(
      paymentId: json['paymentId'] as String,
      paymentLinkId: json['paymentLinkId'] as String,
      checkoutUrl: json['checkoutUrl'] as String,
      orderCode: json['orderCode'] as String,
      amount: json['amount'] is num ? (json['amount'] as num).toDouble() : 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'paymentId': paymentId,
      'paymentLinkId': paymentLinkId,
      'checkoutUrl': checkoutUrl,
      'orderCode': orderCode,
      'amount': amount,
    };
  }

  @override
  String toString() {
    return 'PaymentCreateResponse(paymentId: $paymentId, paymentLinkId: $paymentLinkId, checkoutUrl: $checkoutUrl, orderCode: $orderCode, amount: $amount)';
  }
}

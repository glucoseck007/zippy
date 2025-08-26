class PaymentStatusResponse {
  final String paymentId;
  final String paymentStatus; // PAID, PENDING, FAILED, etc.
  final String orderStatus;
  final double amount;
  final DateTime createdAt;
  final DateTime? paidAt;

  const PaymentStatusResponse({
    required this.paymentId,
    required this.paymentStatus,
    required this.orderStatus,
    required this.amount,
    required this.createdAt,
    this.paidAt,
  });

  factory PaymentStatusResponse.fromJson(Map<String, dynamic> json) {
    return PaymentStatusResponse(
      paymentId: json['paymentId'] as String,
      paymentStatus: json['paymentStatus'] as String,
      orderStatus: json['orderStatus'] as String,
      amount: json['amount'] is num ? (json['amount'] as num).toDouble() : 0.0,
      createdAt: DateTime.parse(json['createdAt'] as String),
      paidAt: json['paidAt'] != null
          ? DateTime.parse(json['paidAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'paymentId': paymentId,
      'paymentStatus': paymentStatus,
      'orderStatus': orderStatus,
      'amount': amount,
      'createdAt': createdAt.toIso8601String(),
      if (paidAt != null) 'paidAt': paidAt!.toIso8601String(),
    };
  }

  bool get isPaid => paymentStatus.toUpperCase() == 'PAID';
  bool get isPending => paymentStatus.toUpperCase() == 'PENDING';
  bool get isFailed => !isPaid && !isPending;

  @override
  String toString() {
    return 'PaymentStatusResponse(paymentId: $paymentId, paymentStatus: $paymentStatus, orderStatus: $orderStatus, amount: $amount, createdAt: $createdAt, paidAt: $paidAt)';
  }
}

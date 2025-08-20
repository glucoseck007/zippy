class StaffOrder {
  final String orderId;
  final String orderCode;
  final String productName;
  final String? robotCode;
  final String? robotContainerCode;
  final String endpoint;
  final double price;
  final String status;
  final String createdAt;
  final String? completedAt;

  StaffOrder({
    required this.orderId,
    required this.orderCode,
    required this.productName,
    this.robotCode,
    this.robotContainerCode,
    required this.endpoint,
    required this.price,
    required this.status,
    required this.createdAt,
    this.completedAt,
  });

  factory StaffOrder.fromJson(Map<String, dynamic> json) {
    return StaffOrder(
      orderId: json['orderId'] ?? '',
      orderCode: json['orderCode'] ?? '',
      productName: json['productName'] ?? '',
      robotCode: json['robotCode'],
      robotContainerCode: json['robotContainerCode'],
      endpoint: json['endpoint'] ?? '',
      price: (json['price'] ?? 0.0).toDouble(),
      status: json['status'] ?? '',
      createdAt: json['createdAt'] ?? '',
      completedAt: json['completedAt'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'orderId': orderId,
      'orderCode': orderCode,
      'productName': productName,
      'robotCode': robotCode,
      'robotContainerCode': robotContainerCode,
      'endpoint': endpoint,
      'price': price,
      'status': status,
      'createdAt': createdAt,
      'completedAt': completedAt,
    };
  }
}

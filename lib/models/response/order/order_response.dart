class OrderResponse {
  final bool success;
  final String message;
  final OrderData? data;

  const OrderResponse({
    required this.success,
    required this.message,
    this.data,
  });

  factory OrderResponse.fromJson(Map<String, dynamic> json) {
    return OrderResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      data: json['data'] != null ? OrderData.fromJson(json['data']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message': message,
      if (data != null) 'data': data!.toJson(),
    };
  }

  @override
  String toString() {
    return 'OrderResponse(success: $success, message: $message, data: $data)';
  }
}

class OrderData {
  final String orderId;
  final String status;
  final String? estimatedDeliveryTime;
  final String robotCode;
  final String containerCode;
  final String productName;
  final String endpoint;
  final DateTime? createdAt;

  const OrderData({
    required this.orderId,
    required this.status,
    this.estimatedDeliveryTime,
    required this.robotCode,
    required this.containerCode,
    required this.productName,
    required this.endpoint,
    this.createdAt,
  });

  factory OrderData.fromJson(Map<String, dynamic> json) {
    return OrderData(
      orderId: json['orderId'] as String? ?? '',
      status: json['status'] as String? ?? '',
      estimatedDeliveryTime: json['estimatedDeliveryTime'] as String?,
      robotCode: json['robotCode'] as String? ?? '',
      containerCode: json['containerCode'] as String? ?? '',
      productName: json['productName'] as String? ?? '',
      endpoint: json['endpoint'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'orderId': orderId,
      'status': status,
      if (estimatedDeliveryTime != null)
        'estimatedDeliveryTime': estimatedDeliveryTime,
      'robotCode': robotCode,
      'containerCode': containerCode,
      'productName': productName,
      'endpoint': endpoint,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'OrderData(orderId: $orderId, status: $status, estimatedDeliveryTime: $estimatedDeliveryTime, robotCode: $robotCode, containerCode: $containerCode, productName: $productName, endpoint: $endpoint, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OrderData &&
        other.orderId == orderId &&
        other.status == status &&
        other.estimatedDeliveryTime == estimatedDeliveryTime &&
        other.robotCode == robotCode &&
        other.containerCode == containerCode &&
        other.productName == productName &&
        other.endpoint == endpoint &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      orderId,
      status,
      estimatedDeliveryTime,
      robotCode,
      containerCode,
      productName,
      endpoint,
      createdAt,
    );
  }
}

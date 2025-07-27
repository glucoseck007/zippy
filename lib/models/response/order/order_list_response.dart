class OrderListResponse {
  final bool success;
  final String message;
  final List<OrderListItem> data;

  const OrderListResponse({
    required this.success,
    required this.message,
    required this.data,
  });

  factory OrderListResponse.fromJson(Map<String, dynamic> json) {
    return OrderListResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      data:
          (json['data'] as List<dynamic>?)
              ?.map(
                (item) => OrderListItem.fromJson(item as Map<String, dynamic>),
              )
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message': message,
      'data': data.map((item) => item.toJson()).toList(),
    };
  }
}

class OrderListItem {
  final String orderId;
  final String orderCode;
  final String productName;
  final String robotCode;
  final String robotContainerCode;
  final String endpoint;
  final String status;
  final DateTime? createdAt;
  final DateTime? completedAt;
  final String? estimatedDeliveryTime;

  const OrderListItem({
    required this.orderId,
    required this.orderCode,
    required this.productName,
    required this.robotCode,
    required this.robotContainerCode,
    required this.endpoint,
    required this.status,
    this.createdAt,
    this.completedAt,
    this.estimatedDeliveryTime,
  });

  factory OrderListItem.fromJson(Map<String, dynamic> json) {
    return OrderListItem(
      orderId: json['orderId'] as String? ?? '',
      orderCode: json['orderCode'] as String? ?? '',
      productName: json['productName'] as String? ?? '',
      robotCode: json['robotCode'] as String? ?? '',
      robotContainerCode: json['robotContainerCode'] as String? ?? '',
      endpoint: json['endpoint'] as String? ?? '',
      status: json['status'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'] as String)
          : null,
      estimatedDeliveryTime: json['estimatedDeliveryTime'] as String?,
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
      'status': status,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
      if (estimatedDeliveryTime != null)
        'estimatedDeliveryTime': estimatedDeliveryTime,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OrderListItem &&
        other.orderId == orderId &&
        other.orderCode == orderCode &&
        other.productName == productName &&
        other.robotCode == robotCode &&
        other.robotContainerCode == robotContainerCode &&
        other.endpoint == endpoint &&
        other.status == status;
  }

  @override
  int get hashCode {
    return Object.hash(
      orderId,
      orderCode,
      productName,
      robotCode,
      robotContainerCode,
      endpoint,
      status,
    );
  }

  @override
  String toString() {
    return 'OrderListItem(orderId: $orderId, orderCode: $orderCode, productName: $productName, robotCode: $robotCode, endpoint: $endpoint, status: $status)';
  }
}

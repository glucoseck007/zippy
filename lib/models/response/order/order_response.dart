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
  final String?
  orderCode; // Changed from orderId to orderCode and made nullable
  final String status;
  final String? estimatedDeliveryTime;
  final String?
  robotCode; // Made nullable since it might not be in the response
  final String?
  containerCode; // Made nullable since it might not be in the response
  final String?
  productName; // Made nullable since it might not be in the response
  final String? endpoint; // Made nullable since it might not be in the response
  final double? price;
  final String?
  createdAt; // Changed from DateTime to String to match API response

  const OrderData({
    this.orderCode, // Made nullable
    required this.status,
    this.estimatedDeliveryTime,
    this.robotCode, // Made nullable
    this.containerCode, // Made nullable
    this.productName, // Made nullable
    this.endpoint, // Made nullable
    this.price,
    this.createdAt, // Made nullable
  });

  factory OrderData.fromJson(Map<String, dynamic> json) {
    return OrderData(
      orderCode:
          json['orderCode'] as String?, // Changed from orderId to orderCode
      status: json['status'] as String? ?? '',
      estimatedDeliveryTime: json['estimatedDeliveryTime'] as String?,
      robotCode: json['robotCode'] as String?,
      containerCode: json['containerCode'] as String?,
      productName: json['productName'] as String?,
      endpoint: json['endpoint'] as String?,
      price: json['price'] is num ? (json['price'] as num).toDouble() : null,
      createdAt:
          json['createdAt'] as String?, // Keep as string to match API response
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (orderCode != null)
        'orderCode': orderCode, // Changed from orderId to orderCode
      'status': status,
      if (estimatedDeliveryTime != null)
        'estimatedDeliveryTime': estimatedDeliveryTime,
      if (robotCode != null) 'robotCode': robotCode,
      if (containerCode != null) 'containerCode': containerCode,
      if (productName != null) 'productName': productName,
      if (endpoint != null) 'endpoint': endpoint,
      if (price != null) 'price': price,
      if (createdAt != null) 'createdAt': createdAt, // Keep as string
    };
  }

  @override
  String toString() {
    return 'OrderData(orderCode: $orderCode, status: $status, estimatedDeliveryTime: $estimatedDeliveryTime, robotCode: $robotCode, containerCode: $containerCode, productName: $productName, endpoint: $endpoint, price: $price, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OrderData &&
        other.orderCode == orderCode && // Changed from orderId to orderCode
        other.status == status &&
        other.estimatedDeliveryTime == estimatedDeliveryTime &&
        other.robotCode == robotCode &&
        other.containerCode == containerCode &&
        other.productName == productName &&
        other.endpoint == endpoint &&
        other.price == price &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      orderCode, // Changed from orderId to orderCode
      status,
      estimatedDeliveryTime,
      robotCode,
      containerCode,
      productName,
      endpoint,
      price,
      createdAt,
    );
  }
}

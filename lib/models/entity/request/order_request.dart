class OrderRequest {
  final String username;
  final String productName;
  final String robotCode;
  final String robotContainerCode;
  final String endpoint;

  const OrderRequest({
    required this.username,
    required this.productName,
    required this.robotCode,
    required this.robotContainerCode,
    required this.endpoint,
  });

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'productName': productName,
      'robotCode': robotCode,
      'robotContainerCode': robotContainerCode,
      'endpoint': endpoint,
    };
  }

  factory OrderRequest.fromJson(Map<String, dynamic> json) {
    return OrderRequest(
      username: json['username'] as String,
      productName: json['productName'] as String,
      robotCode: json['robotCode'] as String,
      robotContainerCode: json['robotContainerCode'] as String,
      endpoint: json['endpoint'] as String,
    );
  }

  @override
  String toString() {
    return 'OrderRequest(username: $username, productName: $productName, robotCode: $robotCode, robotContainerCode: $robotContainerCode, endpoint: $endpoint)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OrderRequest &&
        other.username == username &&
        other.productName == productName &&
        other.robotCode == robotCode &&
        other.robotContainerCode == robotContainerCode &&
        other.endpoint == endpoint;
  }

  @override
  int get hashCode {
    return Object.hash(
      username,
      productName,
      robotCode,
      robotContainerCode,
      endpoint,
    );
  }
}

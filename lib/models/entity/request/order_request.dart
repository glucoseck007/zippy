class OrderRequest {
  final String senderIdentifier; // Can be email or phone
  final String receiverIdentifier; // Can be email or phone
  final String productName;
  final String robotCode;
  final String robotContainerCode;
  final String startPoint;
  final String endpoint;
  final bool approved;

  const OrderRequest({
    required this.senderIdentifier,
    required this.receiverIdentifier,
    required this.productName,
    required this.robotCode,
    required this.robotContainerCode,
    required this.startPoint,
    required this.endpoint,
    this.approved = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'senderIdentifier': senderIdentifier,
      'receiverIdentifier': receiverIdentifier,
      'productName': productName,
      'robotCode': robotCode,
      'robotContainerCode': robotContainerCode,
      'startPoint': startPoint,
      'endpoint': endpoint,
      'approved': approved,
    };
  }

  factory OrderRequest.fromJson(Map<String, dynamic> json) {
    return OrderRequest(
      senderIdentifier: json['senderIdentifier'] as String,
      receiverIdentifier: json['receiverIdentifier'] as String,
      productName: json['productName'] as String,
      robotCode: json['robotCode'] as String,
      robotContainerCode: json['robotContainerCode'] as String,
      startPoint: json['startPoint'] as String,
      endpoint: json['endpoint'] as String,
      approved: json['approved'] as bool? ?? false,
    );
  }

  @override
  String toString() {
    return 'OrderRequest(senderIdentifier: $senderIdentifier, receiverIdentifier: $receiverIdentifier, productName: $productName, robotCode: $robotCode, robotContainerCode: $robotContainerCode, startPoint: $startPoint, endpoint: $endpoint, approved: $approved)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OrderRequest &&
        other.senderIdentifier == senderIdentifier &&
        other.receiverIdentifier == receiverIdentifier &&
        other.productName == productName &&
        other.robotCode == robotCode &&
        other.robotContainerCode == robotContainerCode &&
        other.startPoint == startPoint &&
        other.endpoint == endpoint &&
        other.approved == approved;
  }

  @override
  int get hashCode {
    return Object.hash(
      senderIdentifier,
      receiverIdentifier,
      productName,
      robotCode,
      robotContainerCode,
      startPoint,
      endpoint,
      approved,
    );
  }
}

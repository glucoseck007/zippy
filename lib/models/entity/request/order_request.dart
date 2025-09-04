class OrderRequest {
  final String senderIdentifier; // Can be email or phone
  final String receiverIdentifier; // Can be email or phone
  final String productName;
  final String robotCode;
  final String startPoint;
  final String endPoint;

  const OrderRequest({
    required this.senderIdentifier,
    required this.receiverIdentifier,
    required this.productName,
    required this.robotCode,
    required this.startPoint,
    required this.endPoint,
  });

  Map<String, dynamic> toJson() {
    return {
      'senderIdentifier': senderIdentifier,
      'receiverIdentifier': receiverIdentifier,
      'productName': productName,
      'robotCode': robotCode,
      'startPoint': startPoint,
      'endPoint': endPoint,
    };
  }

  factory OrderRequest.fromJson(Map<String, dynamic> json) {
    return OrderRequest(
      senderIdentifier: json['senderIdentifier'] as String,
      receiverIdentifier: json['receiverIdentifier'] as String,
      productName: json['productName'] as String,
      robotCode: json['robotCode'] as String,
      startPoint: json['startPoint'] as String,
      endPoint: json['endPoint'] as String,
    );
  }

  @override
  String toString() {
    return 'OrderRequest(senderIdentifier: $senderIdentifier, receiverIdentifier: $receiverIdentifier, productName: $productName, robotCode: $robotCode, startPoint: $startPoint, endPoint: $endPoint)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OrderRequest &&
        other.senderIdentifier == senderIdentifier &&
        other.receiverIdentifier == receiverIdentifier &&
        other.productName == productName &&
        other.robotCode == robotCode &&
        other.startPoint == startPoint &&
        other.endPoint == endPoint;
  }

  @override
  int get hashCode {
    return Object.hash(
      senderIdentifier,
      receiverIdentifier,
      productName,
      robotCode,
      startPoint,
      endPoint,
    );
  }
}

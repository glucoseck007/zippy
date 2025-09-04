/// Container model for robot containers
class Container {
  final String containerId;
  final bool isClosed;
  final String status;
  final double weight;
  final String? occupiedBy;

  const Container({
    required this.containerId,
    required this.isClosed,
    required this.status,
    required this.weight,
    this.occupiedBy,
  });

  factory Container.fromJson(Map<String, dynamic> json) {
    return Container(
      containerId: json['containerId'] ?? '',
      isClosed: json['isClosed'] ?? false,
      status: json['status'] ?? 'free',
      weight: (json['weight'] ?? 0.0).toDouble(),
      occupiedBy: json['occupiedBy'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'containerId': containerId,
      'isClosed': isClosed,
      'status': status,
      'weight': weight,
      if (occupiedBy != null) 'occupiedBy': occupiedBy,
    };
  }

  Container copyWith({
    String? containerId,
    bool? isClosed,
    String? status,
    double? weight,
    String? occupiedBy,
  }) {
    return Container(
      containerId: containerId ?? this.containerId,
      isClosed: isClosed ?? this.isClosed,
      status: status ?? this.status,
      weight: weight ?? this.weight,
      occupiedBy: occupiedBy ?? this.occupiedBy,
    );
  }

  /// Check if container is available for use
  bool get isAvailable => status == 'free' && !isClosed;

  /// Check if container is occupied
  bool get isOccupied => status != 'free' || (isClosed && weight > 0);

  /// Get user-friendly display name
  String get displayName => 'Container $containerId';

  /// For backward compatibility with old Container class
  String get containerCode => containerId;

  @override
  String toString() {
    return 'Container(id: $containerId, closed: $isClosed, status: $status, weight: $weight)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Container &&
        other.containerId == containerId &&
        other.isClosed == isClosed &&
        other.status == status &&
        other.weight == weight &&
        other.occupiedBy == occupiedBy;
  }

  @override
  int get hashCode {
    return containerId.hashCode ^
        isClosed.hashCode ^
        status.hashCode ^
        weight.hashCode ^
        occupiedBy.hashCode;
  }
}

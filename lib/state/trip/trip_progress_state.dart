abstract class TripProgressState {
  const TripProgressState();
}

class TripProgressInitial extends TripProgressState {
  const TripProgressInitial();
}

class TripProgressLoading extends TripProgressState {
  const TripProgressLoading();
}

class TripProgressLoaded extends TripProgressState {
  final double progress;
  final String? tripStartPoint;
  final String? tripEndPoint;
  final bool hasPickupPhase;
  final bool hasDeliveryPhase;
  final bool phase1QRScanned;
  final bool phase2QRScanned;
  final bool phase1NotificationSent;
  final bool phase2NotificationSent;
  final bool awaitingPhase1QR;
  final bool awaitingPhase2QR;

  const TripProgressLoaded({
    required this.progress,
    required this.tripStartPoint,
    required this.tripEndPoint,
    required this.hasPickupPhase,
    required this.hasDeliveryPhase,
    required this.phase1QRScanned,
    required this.phase2QRScanned,
    required this.phase1NotificationSent,
    required this.phase2NotificationSent,
    required this.awaitingPhase1QR,
    required this.awaitingPhase2QR,
  });

  TripProgressLoaded copyWith({
    double? progress,
    String? tripStartPoint,
    String? tripEndPoint,
    bool? hasPickupPhase,
    bool? hasDeliveryPhase,
    bool? phase1QRScanned,
    bool? phase2QRScanned,
    bool? phase1NotificationSent,
    bool? phase2NotificationSent,
    bool? awaitingPhase1QR,
    bool? awaitingPhase2QR,
  }) {
    return TripProgressLoaded(
      progress: progress ?? this.progress,
      tripStartPoint: tripStartPoint ?? this.tripStartPoint,
      tripEndPoint: tripEndPoint ?? this.tripEndPoint,
      hasPickupPhase: hasPickupPhase ?? this.hasPickupPhase,
      hasDeliveryPhase: hasDeliveryPhase ?? this.hasDeliveryPhase,
      phase1QRScanned: phase1QRScanned ?? this.phase1QRScanned,
      phase2QRScanned: phase2QRScanned ?? this.phase2QRScanned,
      phase1NotificationSent:
          phase1NotificationSent ?? this.phase1NotificationSent,
      phase2NotificationSent:
          phase2NotificationSent ?? this.phase2NotificationSent,
      awaitingPhase1QR: awaitingPhase1QR ?? this.awaitingPhase1QR,
      awaitingPhase2QR: awaitingPhase2QR ?? this.awaitingPhase2QR,
    );
  }
}

class TripProgressError extends TripProgressState {
  final String errorMessage;

  const TripProgressError({required this.errorMessage});
}

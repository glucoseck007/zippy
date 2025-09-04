import 'package:freezed_annotation/freezed_annotation.dart';

part 'pickup_response.freezed.dart';
part 'pickup_response.g.dart';

@freezed
class PickupResponse with _$PickupResponse {
  const factory PickupResponse({
    required bool success,
    required String message,
    required PickupData? data,
  }) = _PickupResponse;

  factory PickupResponse.fromJson(Map<String, dynamic> json) =>
      _$PickupResponseFromJson(json);
}

@freezed
class PickupData with _$PickupData {
  const factory PickupData({
    required String orderCode,
    String? tripCode,
    required String status,
    String? otpSentTo,
    String? completedAt,
  }) = _PickupData;

  factory PickupData.fromJson(Map<String, dynamic> json) =>
      _$PickupDataFromJson(json);
}

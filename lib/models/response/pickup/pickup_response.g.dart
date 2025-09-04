// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pickup_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$PickupResponseImpl _$$PickupResponseImplFromJson(Map<String, dynamic> json) =>
    _$PickupResponseImpl(
      success: json['success'] as bool,
      message: json['message'] as String,
      data: json['data'] == null
          ? null
          : PickupData.fromJson(json['data'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$$PickupResponseImplToJson(
  _$PickupResponseImpl instance,
) => <String, dynamic>{
  'success': instance.success,
  'message': instance.message,
  'data': instance.data,
};

_$PickupDataImpl _$$PickupDataImplFromJson(Map<String, dynamic> json) =>
    _$PickupDataImpl(
      orderCode: json['orderCode'] as String,
      tripCode: json['tripCode'] as String?,
      status: json['status'] as String,
      otpSentTo: json['otpSentTo'] as String?,
      completedAt: json['completedAt'] as String?,
    );

Map<String, dynamic> _$$PickupDataImplToJson(_$PickupDataImpl instance) =>
    <String, dynamic>{
      'orderCode': instance.orderCode,
      'tripCode': instance.tripCode,
      'status': instance.status,
      'otpSentTo': instance.otpSentTo,
      'completedAt': instance.completedAt,
    };

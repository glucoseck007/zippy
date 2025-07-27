// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'pickup_response.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

PickupResponse _$PickupResponseFromJson(Map<String, dynamic> json) {
  return _PickupResponse.fromJson(json);
}

/// @nodoc
mixin _$PickupResponse {
  bool get success => throw _privateConstructorUsedError;
  String get message => throw _privateConstructorUsedError;
  PickupData? get data => throw _privateConstructorUsedError;

  /// Serializes this PickupResponse to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of PickupResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PickupResponseCopyWith<PickupResponse> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PickupResponseCopyWith<$Res> {
  factory $PickupResponseCopyWith(
    PickupResponse value,
    $Res Function(PickupResponse) then,
  ) = _$PickupResponseCopyWithImpl<$Res, PickupResponse>;
  @useResult
  $Res call({bool success, String message, PickupData? data});

  $PickupDataCopyWith<$Res>? get data;
}

/// @nodoc
class _$PickupResponseCopyWithImpl<$Res, $Val extends PickupResponse>
    implements $PickupResponseCopyWith<$Res> {
  _$PickupResponseCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PickupResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? success = null,
    Object? message = null,
    Object? data = freezed,
  }) {
    return _then(
      _value.copyWith(
            success: null == success
                ? _value.success
                : success // ignore: cast_nullable_to_non_nullable
                      as bool,
            message: null == message
                ? _value.message
                : message // ignore: cast_nullable_to_non_nullable
                      as String,
            data: freezed == data
                ? _value.data
                : data // ignore: cast_nullable_to_non_nullable
                      as PickupData?,
          )
          as $Val,
    );
  }

  /// Create a copy of PickupResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $PickupDataCopyWith<$Res>? get data {
    if (_value.data == null) {
      return null;
    }

    return $PickupDataCopyWith<$Res>(_value.data!, (value) {
      return _then(_value.copyWith(data: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$PickupResponseImplCopyWith<$Res>
    implements $PickupResponseCopyWith<$Res> {
  factory _$$PickupResponseImplCopyWith(
    _$PickupResponseImpl value,
    $Res Function(_$PickupResponseImpl) then,
  ) = __$$PickupResponseImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({bool success, String message, PickupData? data});

  @override
  $PickupDataCopyWith<$Res>? get data;
}

/// @nodoc
class __$$PickupResponseImplCopyWithImpl<$Res>
    extends _$PickupResponseCopyWithImpl<$Res, _$PickupResponseImpl>
    implements _$$PickupResponseImplCopyWith<$Res> {
  __$$PickupResponseImplCopyWithImpl(
    _$PickupResponseImpl _value,
    $Res Function(_$PickupResponseImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of PickupResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? success = null,
    Object? message = null,
    Object? data = freezed,
  }) {
    return _then(
      _$PickupResponseImpl(
        success: null == success
            ? _value.success
            : success // ignore: cast_nullable_to_non_nullable
                  as bool,
        message: null == message
            ? _value.message
            : message // ignore: cast_nullable_to_non_nullable
                  as String,
        data: freezed == data
            ? _value.data
            : data // ignore: cast_nullable_to_non_nullable
                  as PickupData?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$PickupResponseImpl implements _PickupResponse {
  const _$PickupResponseImpl({
    required this.success,
    required this.message,
    required this.data,
  });

  factory _$PickupResponseImpl.fromJson(Map<String, dynamic> json) =>
      _$$PickupResponseImplFromJson(json);

  @override
  final bool success;
  @override
  final String message;
  @override
  final PickupData? data;

  @override
  String toString() {
    return 'PickupResponse(success: $success, message: $message, data: $data)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PickupResponseImpl &&
            (identical(other.success, success) || other.success == success) &&
            (identical(other.message, message) || other.message == message) &&
            (identical(other.data, data) || other.data == data));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, success, message, data);

  /// Create a copy of PickupResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PickupResponseImplCopyWith<_$PickupResponseImpl> get copyWith =>
      __$$PickupResponseImplCopyWithImpl<_$PickupResponseImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$PickupResponseImplToJson(this);
  }
}

abstract class _PickupResponse implements PickupResponse {
  const factory _PickupResponse({
    required final bool success,
    required final String message,
    required final PickupData? data,
  }) = _$PickupResponseImpl;

  factory _PickupResponse.fromJson(Map<String, dynamic> json) =
      _$PickupResponseImpl.fromJson;

  @override
  bool get success;
  @override
  String get message;
  @override
  PickupData? get data;

  /// Create a copy of PickupResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PickupResponseImplCopyWith<_$PickupResponseImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

PickupData _$PickupDataFromJson(Map<String, dynamic> json) {
  return _PickupData.fromJson(json);
}

/// @nodoc
mixin _$PickupData {
  String get orderCode => throw _privateConstructorUsedError;
  String get status => throw _privateConstructorUsedError;
  String? get otpSentTo => throw _privateConstructorUsedError;
  String? get completedAt => throw _privateConstructorUsedError;

  /// Serializes this PickupData to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of PickupData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PickupDataCopyWith<PickupData> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PickupDataCopyWith<$Res> {
  factory $PickupDataCopyWith(
    PickupData value,
    $Res Function(PickupData) then,
  ) = _$PickupDataCopyWithImpl<$Res, PickupData>;
  @useResult
  $Res call({
    String orderCode,
    String status,
    String? otpSentTo,
    String? completedAt,
  });
}

/// @nodoc
class _$PickupDataCopyWithImpl<$Res, $Val extends PickupData>
    implements $PickupDataCopyWith<$Res> {
  _$PickupDataCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PickupData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? orderCode = null,
    Object? status = null,
    Object? otpSentTo = freezed,
    Object? completedAt = freezed,
  }) {
    return _then(
      _value.copyWith(
            orderCode: null == orderCode
                ? _value.orderCode
                : orderCode // ignore: cast_nullable_to_non_nullable
                      as String,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as String,
            otpSentTo: freezed == otpSentTo
                ? _value.otpSentTo
                : otpSentTo // ignore: cast_nullable_to_non_nullable
                      as String?,
            completedAt: freezed == completedAt
                ? _value.completedAt
                : completedAt // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$PickupDataImplCopyWith<$Res>
    implements $PickupDataCopyWith<$Res> {
  factory _$$PickupDataImplCopyWith(
    _$PickupDataImpl value,
    $Res Function(_$PickupDataImpl) then,
  ) = __$$PickupDataImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String orderCode,
    String status,
    String? otpSentTo,
    String? completedAt,
  });
}

/// @nodoc
class __$$PickupDataImplCopyWithImpl<$Res>
    extends _$PickupDataCopyWithImpl<$Res, _$PickupDataImpl>
    implements _$$PickupDataImplCopyWith<$Res> {
  __$$PickupDataImplCopyWithImpl(
    _$PickupDataImpl _value,
    $Res Function(_$PickupDataImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of PickupData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? orderCode = null,
    Object? status = null,
    Object? otpSentTo = freezed,
    Object? completedAt = freezed,
  }) {
    return _then(
      _$PickupDataImpl(
        orderCode: null == orderCode
            ? _value.orderCode
            : orderCode // ignore: cast_nullable_to_non_nullable
                  as String,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as String,
        otpSentTo: freezed == otpSentTo
            ? _value.otpSentTo
            : otpSentTo // ignore: cast_nullable_to_non_nullable
                  as String?,
        completedAt: freezed == completedAt
            ? _value.completedAt
            : completedAt // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$PickupDataImpl implements _PickupData {
  const _$PickupDataImpl({
    required this.orderCode,
    required this.status,
    this.otpSentTo,
    this.completedAt,
  });

  factory _$PickupDataImpl.fromJson(Map<String, dynamic> json) =>
      _$$PickupDataImplFromJson(json);

  @override
  final String orderCode;
  @override
  final String status;
  @override
  final String? otpSentTo;
  @override
  final String? completedAt;

  @override
  String toString() {
    return 'PickupData(orderCode: $orderCode, status: $status, otpSentTo: $otpSentTo, completedAt: $completedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PickupDataImpl &&
            (identical(other.orderCode, orderCode) ||
                other.orderCode == orderCode) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.otpSentTo, otpSentTo) ||
                other.otpSentTo == otpSentTo) &&
            (identical(other.completedAt, completedAt) ||
                other.completedAt == completedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, orderCode, status, otpSentTo, completedAt);

  /// Create a copy of PickupData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PickupDataImplCopyWith<_$PickupDataImpl> get copyWith =>
      __$$PickupDataImplCopyWithImpl<_$PickupDataImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PickupDataImplToJson(this);
  }
}

abstract class _PickupData implements PickupData {
  const factory _PickupData({
    required final String orderCode,
    required final String status,
    final String? otpSentTo,
    final String? completedAt,
  }) = _$PickupDataImpl;

  factory _PickupData.fromJson(Map<String, dynamic> json) =
      _$PickupDataImpl.fromJson;

  @override
  String get orderCode;
  @override
  String get status;
  @override
  String? get otpSentTo;
  @override
  String? get completedAt;

  /// Create a copy of PickupData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PickupDataImplCopyWith<_$PickupDataImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

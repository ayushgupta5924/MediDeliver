// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'prescription_order.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PrescriptionOrder {

 String get id; String get patientName; String get prescriptionImageUrl; OrderStatus get status; DateTime get uploadedAt; String? get rejectionReason;
/// Create a copy of PrescriptionOrder
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PrescriptionOrderCopyWith<PrescriptionOrder> get copyWith => _$PrescriptionOrderCopyWithImpl<PrescriptionOrder>(this as PrescriptionOrder, _$identity);

  /// Serializes this PrescriptionOrder to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PrescriptionOrder&&(identical(other.id, id) || other.id == id)&&(identical(other.patientName, patientName) || other.patientName == patientName)&&(identical(other.prescriptionImageUrl, prescriptionImageUrl) || other.prescriptionImageUrl == prescriptionImageUrl)&&(identical(other.status, status) || other.status == status)&&(identical(other.uploadedAt, uploadedAt) || other.uploadedAt == uploadedAt)&&(identical(other.rejectionReason, rejectionReason) || other.rejectionReason == rejectionReason));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,patientName,prescriptionImageUrl,status,uploadedAt,rejectionReason);

@override
String toString() {
  return 'PrescriptionOrder(id: $id, patientName: $patientName, prescriptionImageUrl: $prescriptionImageUrl, status: $status, uploadedAt: $uploadedAt, rejectionReason: $rejectionReason)';
}


}

/// @nodoc
abstract mixin class $PrescriptionOrderCopyWith<$Res>  {
  factory $PrescriptionOrderCopyWith(PrescriptionOrder value, $Res Function(PrescriptionOrder) _then) = _$PrescriptionOrderCopyWithImpl;
@useResult
$Res call({
 String id, String patientName, String prescriptionImageUrl, OrderStatus status, DateTime uploadedAt, String? rejectionReason
});




}
/// @nodoc
class _$PrescriptionOrderCopyWithImpl<$Res>
    implements $PrescriptionOrderCopyWith<$Res> {
  _$PrescriptionOrderCopyWithImpl(this._self, this._then);

  final PrescriptionOrder _self;
  final $Res Function(PrescriptionOrder) _then;

/// Create a copy of PrescriptionOrder
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? patientName = null,Object? prescriptionImageUrl = null,Object? status = null,Object? uploadedAt = null,Object? rejectionReason = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,patientName: null == patientName ? _self.patientName : patientName // ignore: cast_nullable_to_non_nullable
as String,prescriptionImageUrl: null == prescriptionImageUrl ? _self.prescriptionImageUrl : prescriptionImageUrl // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as OrderStatus,uploadedAt: null == uploadedAt ? _self.uploadedAt : uploadedAt // ignore: cast_nullable_to_non_nullable
as DateTime,rejectionReason: freezed == rejectionReason ? _self.rejectionReason : rejectionReason // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [PrescriptionOrder].
extension PrescriptionOrderPatterns on PrescriptionOrder {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PrescriptionOrder value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PrescriptionOrder() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PrescriptionOrder value)  $default,){
final _that = this;
switch (_that) {
case _PrescriptionOrder():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PrescriptionOrder value)?  $default,){
final _that = this;
switch (_that) {
case _PrescriptionOrder() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String patientName,  String prescriptionImageUrl,  OrderStatus status,  DateTime uploadedAt,  String? rejectionReason)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PrescriptionOrder() when $default != null:
return $default(_that.id,_that.patientName,_that.prescriptionImageUrl,_that.status,_that.uploadedAt,_that.rejectionReason);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String patientName,  String prescriptionImageUrl,  OrderStatus status,  DateTime uploadedAt,  String? rejectionReason)  $default,) {final _that = this;
switch (_that) {
case _PrescriptionOrder():
return $default(_that.id,_that.patientName,_that.prescriptionImageUrl,_that.status,_that.uploadedAt,_that.rejectionReason);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String patientName,  String prescriptionImageUrl,  OrderStatus status,  DateTime uploadedAt,  String? rejectionReason)?  $default,) {final _that = this;
switch (_that) {
case _PrescriptionOrder() when $default != null:
return $default(_that.id,_that.patientName,_that.prescriptionImageUrl,_that.status,_that.uploadedAt,_that.rejectionReason);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PrescriptionOrder implements PrescriptionOrder {
  const _PrescriptionOrder({required this.id, required this.patientName, required this.prescriptionImageUrl, this.status = OrderStatus.pending, required this.uploadedAt, this.rejectionReason});
  factory _PrescriptionOrder.fromJson(Map<String, dynamic> json) => _$PrescriptionOrderFromJson(json);

@override final  String id;
@override final  String patientName;
@override final  String prescriptionImageUrl;
@override@JsonKey() final  OrderStatus status;
@override final  DateTime uploadedAt;
@override final  String? rejectionReason;

/// Create a copy of PrescriptionOrder
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PrescriptionOrderCopyWith<_PrescriptionOrder> get copyWith => __$PrescriptionOrderCopyWithImpl<_PrescriptionOrder>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PrescriptionOrderToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PrescriptionOrder&&(identical(other.id, id) || other.id == id)&&(identical(other.patientName, patientName) || other.patientName == patientName)&&(identical(other.prescriptionImageUrl, prescriptionImageUrl) || other.prescriptionImageUrl == prescriptionImageUrl)&&(identical(other.status, status) || other.status == status)&&(identical(other.uploadedAt, uploadedAt) || other.uploadedAt == uploadedAt)&&(identical(other.rejectionReason, rejectionReason) || other.rejectionReason == rejectionReason));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,patientName,prescriptionImageUrl,status,uploadedAt,rejectionReason);

@override
String toString() {
  return 'PrescriptionOrder(id: $id, patientName: $patientName, prescriptionImageUrl: $prescriptionImageUrl, status: $status, uploadedAt: $uploadedAt, rejectionReason: $rejectionReason)';
}


}

/// @nodoc
abstract mixin class _$PrescriptionOrderCopyWith<$Res> implements $PrescriptionOrderCopyWith<$Res> {
  factory _$PrescriptionOrderCopyWith(_PrescriptionOrder value, $Res Function(_PrescriptionOrder) _then) = __$PrescriptionOrderCopyWithImpl;
@override @useResult
$Res call({
 String id, String patientName, String prescriptionImageUrl, OrderStatus status, DateTime uploadedAt, String? rejectionReason
});




}
/// @nodoc
class __$PrescriptionOrderCopyWithImpl<$Res>
    implements _$PrescriptionOrderCopyWith<$Res> {
  __$PrescriptionOrderCopyWithImpl(this._self, this._then);

  final _PrescriptionOrder _self;
  final $Res Function(_PrescriptionOrder) _then;

/// Create a copy of PrescriptionOrder
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? patientName = null,Object? prescriptionImageUrl = null,Object? status = null,Object? uploadedAt = null,Object? rejectionReason = freezed,}) {
  return _then(_PrescriptionOrder(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,patientName: null == patientName ? _self.patientName : patientName // ignore: cast_nullable_to_non_nullable
as String,prescriptionImageUrl: null == prescriptionImageUrl ? _self.prescriptionImageUrl : prescriptionImageUrl // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as OrderStatus,uploadedAt: null == uploadedAt ? _self.uploadedAt : uploadedAt // ignore: cast_nullable_to_non_nullable
as DateTime,rejectionReason: freezed == rejectionReason ? _self.rejectionReason : rejectionReason // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on

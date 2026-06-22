// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'delivery_order.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$DeliveryOrder {

 String get id; String get patientName; String get deliveryAddress; double get distanceKm; double get earningAmount; DeliveryStatus get status;
/// Create a copy of DeliveryOrder
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DeliveryOrderCopyWith<DeliveryOrder> get copyWith => _$DeliveryOrderCopyWithImpl<DeliveryOrder>(this as DeliveryOrder, _$identity);

  /// Serializes this DeliveryOrder to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DeliveryOrder&&(identical(other.id, id) || other.id == id)&&(identical(other.patientName, patientName) || other.patientName == patientName)&&(identical(other.deliveryAddress, deliveryAddress) || other.deliveryAddress == deliveryAddress)&&(identical(other.distanceKm, distanceKm) || other.distanceKm == distanceKm)&&(identical(other.earningAmount, earningAmount) || other.earningAmount == earningAmount)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,patientName,deliveryAddress,distanceKm,earningAmount,status);

@override
String toString() {
  return 'DeliveryOrder(id: $id, patientName: $patientName, deliveryAddress: $deliveryAddress, distanceKm: $distanceKm, earningAmount: $earningAmount, status: $status)';
}


}

/// @nodoc
abstract mixin class $DeliveryOrderCopyWith<$Res>  {
  factory $DeliveryOrderCopyWith(DeliveryOrder value, $Res Function(DeliveryOrder) _then) = _$DeliveryOrderCopyWithImpl;
@useResult
$Res call({
 String id, String patientName, String deliveryAddress, double distanceKm, double earningAmount, DeliveryStatus status
});




}
/// @nodoc
class _$DeliveryOrderCopyWithImpl<$Res>
    implements $DeliveryOrderCopyWith<$Res> {
  _$DeliveryOrderCopyWithImpl(this._self, this._then);

  final DeliveryOrder _self;
  final $Res Function(DeliveryOrder) _then;

/// Create a copy of DeliveryOrder
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? patientName = null,Object? deliveryAddress = null,Object? distanceKm = null,Object? earningAmount = null,Object? status = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,patientName: null == patientName ? _self.patientName : patientName // ignore: cast_nullable_to_non_nullable
as String,deliveryAddress: null == deliveryAddress ? _self.deliveryAddress : deliveryAddress // ignore: cast_nullable_to_non_nullable
as String,distanceKm: null == distanceKm ? _self.distanceKm : distanceKm // ignore: cast_nullable_to_non_nullable
as double,earningAmount: null == earningAmount ? _self.earningAmount : earningAmount // ignore: cast_nullable_to_non_nullable
as double,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as DeliveryStatus,
  ));
}

}


/// Adds pattern-matching-related methods to [DeliveryOrder].
extension DeliveryOrderPatterns on DeliveryOrder {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DeliveryOrder value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DeliveryOrder() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DeliveryOrder value)  $default,){
final _that = this;
switch (_that) {
case _DeliveryOrder():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DeliveryOrder value)?  $default,){
final _that = this;
switch (_that) {
case _DeliveryOrder() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String patientName,  String deliveryAddress,  double distanceKm,  double earningAmount,  DeliveryStatus status)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DeliveryOrder() when $default != null:
return $default(_that.id,_that.patientName,_that.deliveryAddress,_that.distanceKm,_that.earningAmount,_that.status);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String patientName,  String deliveryAddress,  double distanceKm,  double earningAmount,  DeliveryStatus status)  $default,) {final _that = this;
switch (_that) {
case _DeliveryOrder():
return $default(_that.id,_that.patientName,_that.deliveryAddress,_that.distanceKm,_that.earningAmount,_that.status);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String patientName,  String deliveryAddress,  double distanceKm,  double earningAmount,  DeliveryStatus status)?  $default,) {final _that = this;
switch (_that) {
case _DeliveryOrder() when $default != null:
return $default(_that.id,_that.patientName,_that.deliveryAddress,_that.distanceKm,_that.earningAmount,_that.status);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DeliveryOrder implements DeliveryOrder {
  const _DeliveryOrder({required this.id, required this.patientName, required this.deliveryAddress, required this.distanceKm, required this.earningAmount, this.status = DeliveryStatus.available});
  factory _DeliveryOrder.fromJson(Map<String, dynamic> json) => _$DeliveryOrderFromJson(json);

@override final  String id;
@override final  String patientName;
@override final  String deliveryAddress;
@override final  double distanceKm;
@override final  double earningAmount;
@override@JsonKey() final  DeliveryStatus status;

/// Create a copy of DeliveryOrder
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DeliveryOrderCopyWith<_DeliveryOrder> get copyWith => __$DeliveryOrderCopyWithImpl<_DeliveryOrder>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DeliveryOrderToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DeliveryOrder&&(identical(other.id, id) || other.id == id)&&(identical(other.patientName, patientName) || other.patientName == patientName)&&(identical(other.deliveryAddress, deliveryAddress) || other.deliveryAddress == deliveryAddress)&&(identical(other.distanceKm, distanceKm) || other.distanceKm == distanceKm)&&(identical(other.earningAmount, earningAmount) || other.earningAmount == earningAmount)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,patientName,deliveryAddress,distanceKm,earningAmount,status);

@override
String toString() {
  return 'DeliveryOrder(id: $id, patientName: $patientName, deliveryAddress: $deliveryAddress, distanceKm: $distanceKm, earningAmount: $earningAmount, status: $status)';
}


}

/// @nodoc
abstract mixin class _$DeliveryOrderCopyWith<$Res> implements $DeliveryOrderCopyWith<$Res> {
  factory _$DeliveryOrderCopyWith(_DeliveryOrder value, $Res Function(_DeliveryOrder) _then) = __$DeliveryOrderCopyWithImpl;
@override @useResult
$Res call({
 String id, String patientName, String deliveryAddress, double distanceKm, double earningAmount, DeliveryStatus status
});




}
/// @nodoc
class __$DeliveryOrderCopyWithImpl<$Res>
    implements _$DeliveryOrderCopyWith<$Res> {
  __$DeliveryOrderCopyWithImpl(this._self, this._then);

  final _DeliveryOrder _self;
  final $Res Function(_DeliveryOrder) _then;

/// Create a copy of DeliveryOrder
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? patientName = null,Object? deliveryAddress = null,Object? distanceKm = null,Object? earningAmount = null,Object? status = null,}) {
  return _then(_DeliveryOrder(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,patientName: null == patientName ? _self.patientName : patientName // ignore: cast_nullable_to_non_nullable
as String,deliveryAddress: null == deliveryAddress ? _self.deliveryAddress : deliveryAddress // ignore: cast_nullable_to_non_nullable
as String,distanceKm: null == distanceKm ? _self.distanceKm : distanceKm // ignore: cast_nullable_to_non_nullable
as double,earningAmount: null == earningAmount ? _self.earningAmount : earningAmount // ignore: cast_nullable_to_non_nullable
as double,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as DeliveryStatus,
  ));
}


}

// dart format on

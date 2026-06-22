// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'delivery_order.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_DeliveryOrder _$DeliveryOrderFromJson(Map<String, dynamic> json) =>
    _DeliveryOrder(
      id: json['id'] as String,
      patientName: json['patientName'] as String,
      deliveryAddress: json['deliveryAddress'] as String,
      distanceKm: (json['distanceKm'] as num).toDouble(),
      earningAmount: (json['earningAmount'] as num).toDouble(),
      status:
          $enumDecodeNullable(_$DeliveryStatusEnumMap, json['status']) ??
          DeliveryStatus.available,
    );

Map<String, dynamic> _$DeliveryOrderToJson(_DeliveryOrder instance) =>
    <String, dynamic>{
      'id': instance.id,
      'patientName': instance.patientName,
      'deliveryAddress': instance.deliveryAddress,
      'distanceKm': instance.distanceKm,
      'earningAmount': instance.earningAmount,
      'status': _$DeliveryStatusEnumMap[instance.status]!,
    };

const _$DeliveryStatusEnumMap = {
  DeliveryStatus.available: 'available',
  DeliveryStatus.accepted: 'accepted',
  DeliveryStatus.pickedUp: 'pickedUp',
  DeliveryStatus.delivered: 'delivered',
};

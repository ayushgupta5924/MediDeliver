// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'prescription_order.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PrescriptionOrder _$PrescriptionOrderFromJson(Map<String, dynamic> json) =>
    _PrescriptionOrder(
      id: json['id'] as String,
      patientName: json['patientName'] as String,
      prescriptionImageUrl: json['prescriptionImageUrl'] as String,
      status:
          $enumDecodeNullable(_$OrderStatusEnumMap, json['status']) ??
          OrderStatus.pending,
      uploadedAt: DateTime.parse(json['uploadedAt'] as String),
      rejectionReason: json['rejectionReason'] as String?,
    );

Map<String, dynamic> _$PrescriptionOrderToJson(_PrescriptionOrder instance) =>
    <String, dynamic>{
      'id': instance.id,
      'patientName': instance.patientName,
      'prescriptionImageUrl': instance.prescriptionImageUrl,
      'status': _$OrderStatusEnumMap[instance.status]!,
      'uploadedAt': instance.uploadedAt.toIso8601String(),
      'rejectionReason': instance.rejectionReason,
    };

const _$OrderStatusEnumMap = {
  OrderStatus.pending: 'pending',
  OrderStatus.approved: 'approved',
  OrderStatus.rejected: 'rejected',
};

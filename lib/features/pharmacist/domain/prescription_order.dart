import 'package:freezed_annotation/freezed_annotation.dart';

part 'prescription_order.freezed.dart';
part 'prescription_order.g.dart';

// Tell json_serializable how to serialize this enum
@JsonEnum(valueField: 'value')
enum OrderStatus {
  pending('pending'),
  approved('approved'),
  rejected('rejected');

  const OrderStatus(this.value);
  final String value;
}

@freezed
class PrescriptionOrder with _$PrescriptionOrder {
  const factory PrescriptionOrder({
    required String id,
    required String patientName,
    required String prescriptionImageUrl,
    @Default(OrderStatus.pending) OrderStatus status,
    required DateTime uploadedAt,
    String? rejectionReason,
  }) = _PrescriptionOrder;

  factory PrescriptionOrder.fromJson(Map<String, dynamic> json) =>
      _$PrescriptionOrderFromJson(json);
}

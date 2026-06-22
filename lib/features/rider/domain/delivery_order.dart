import 'package:freezed_annotation/freezed_annotation.dart';

part 'delivery_order.freezed.dart';
part 'delivery_order.g.dart';

enum DeliveryStatus { available, accepted, pickedUp, delivered }

@freezed
class DeliveryOrder with _$DeliveryOrder {
  const factory DeliveryOrder({
    required String id,
    required String patientName,
    required String deliveryAddress,
    required double distanceKm,
    required double earningAmount,
    @Default(DeliveryStatus.available) DeliveryStatus status,
  }) = _DeliveryOrder;

  factory DeliveryOrder.fromJson(Map<String, dynamic> json) =>
      _$DeliveryOrderFromJson(json);
}

extension DeliveryOrderExt on DeliveryOrder {
  String get statusText {
    switch (status) {
      case DeliveryStatus.available:
        return 'Available';
      case DeliveryStatus.accepted:
        return 'Accepted';
      case DeliveryStatus.pickedUp:
        return 'Picked Up';
      case DeliveryStatus.delivered:
        return 'Delivered';
      default:
        throw StateError('Unknown status: $status');
    }
  }
}

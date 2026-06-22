import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/delivery_order.dart';

part 'rider_controller.g.dart';

@riverpod
class RiderController extends _$RiderController {
  @override
  FutureOr<List<DeliveryOrder>> build() async {
    // Simulated network delay
    await Future.delayed(const Duration(seconds: 1));

    // Mock Data for available deliveries
    return const [
      DeliveryOrder(
        id: 'DEL-1001',
        patientName: 'Rahul Desai',
        deliveryAddress: '123 Health Ave, Sector 14, Gandhinagar',
        distanceKm: 2.5,
        earningAmount: 45.0,
      ),
      DeliveryOrder(
        id: 'DEL-1002',
        patientName: 'Anjali Sharma',
        deliveryAddress: '45 Wellness Blvd, Sector 21, Gandhinagar',
        distanceKm: 4.2,
        earningAmount: 65.0,
      ),
    ];
  }

  /// Rider accepts an available order
  Future<void> acceptOrder(String orderId) async {
    final currentOrders = state.value ?? [];

    state = AsyncData(
      currentOrders.map((order) {
        if (order.id == orderId) {
          return order.copyWith(status: DeliveryStatus.accepted);
        }
        return order;
      }).toList(),
    );

    print('🛵 Rider accepted order $orderId!');
  }
}

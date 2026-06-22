import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/prescription_order.dart';

part 'pharmacist_controller.g.dart';

@riverpod
class PharmacistController extends _$PharmacistController {
  @override
  FutureOr<List<PrescriptionOrder>> build() async {
    // Simulated network delay
    await Future.delayed(const Duration(seconds: 1));
    // Mock Data to build the UI
    return [
      PrescriptionOrder(
        id: 'ORD-9938-A',
        patientName: 'Rahul Desai',
        prescriptionImageUrl:
            'https://images.unsplash.com/photo-1585435557343-3b092031a831?auto=format&fit=crop&q=80&w=400',
        uploadedAt: DateTime.now().subtract(const Duration(minutes: 5)),
      ),
      PrescriptionOrder(
        id: 'ORD-1124-B',
        patientName: 'Anjali Sharma',
        prescriptionImageUrl:
            'https://images.unsplash.com/photo-1631549916768-4119b2e5f926?auto=format&fit=crop&q=80&w=400',
        uploadedAt: DateTime.now().subtract(const Duration(minutes: 12)),
      ),
    ];
  }

  Future<void> approveOrder(String orderId) async {
    final currentOrders = state.value ?? [];

    state = AsyncData(
      currentOrders.where((order) => order.id != orderId).toList(),
    );
    print('✅ Order $orderId approved! Pushed to fulfillment.');
  }

  Future<void> rejectOrder(String orderId, String reason) async {
    final currentOrders = state.value ?? [];

    state = AsyncData(
      currentOrders.where((order) => order.id != orderId).toList(),
    );

    print('❌ Order $orderId rejected. Reason: $reason');
  }
}

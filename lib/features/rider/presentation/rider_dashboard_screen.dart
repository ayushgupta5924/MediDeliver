import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../domain/delivery_order.dart';
import 'rider_controller.dart';

class RiderDashboardScreen extends HookConsumerWidget {
  const RiderDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersState = ref.watch(riderControllerProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        title: const Text('Available Deliveries'),
        backgroundColor: Colors.black87, // Darker theme for rider app
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.grey[100],
      body: ordersState.when(
        loading:
            () => const Center(
              child: CircularProgressIndicator(color: Colors.black87),
            ),
        error: (error, stack) => Center(child: Text('Error: $error')),
        data: (orders) {
          // Only show orders that haven't been accepted yet
          final availableOrders =
              orders
                  .where((o) => o.status == DeliveryStatus.available)
                  .toList();

          if (availableOrders.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: availableOrders.length,
            itemBuilder: (context, index) {
              return _DeliveryCard(order: availableOrders[index]);
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.radar, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text(
            'Scanning for orders...',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Stay online to receive new delivery requests.',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class _DeliveryCard extends HookConsumerWidget {
  final DeliveryOrder order;

  const _DeliveryCard({required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'EARN ₹${order.earningAmount}',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  '${order.distanceKm} km away',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.red),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Drop-off Location',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      Text(
                        order.deliveryAddress,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black87,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  ref
                      .read(riderControllerProvider.notifier)
                      .acceptOrder(order.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Order Accepted! Route started.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                child: const Text(
                  'Swipe to Accept',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

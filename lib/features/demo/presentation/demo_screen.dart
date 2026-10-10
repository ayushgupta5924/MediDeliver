import 'package:flutter/material.dart';
import '../../../core/services/auth_service.dart';
import '../../orders/presentation/orders_screen.dart';

/// A browser-local walkthrough. Never creates users, orders, or payments.
class DemoScreen extends StatefulWidget {
  const DemoScreen({super.key});
  @override
  State<DemoScreen> createState() => _DemoScreenState();
}

class _DemoScreenState extends State<DemoScreen> {
  UserRole role = UserRole.customer;
  String status = 'submitted';
  int stock = 100;
  int reserved = 0;
  final List<String> events = ['Customer submitted a sample request'];
  static const roles = {
    UserRole.customer: 'Customer',
    UserRole.pharmacyOwner: 'Pharmacy',
    UserRole.deliveryPartner: 'Rider',
    UserRole.admin: 'Operations',
  };
  void act(String action) {
    if (!orderActions(role, status).containsKey(action)) return;
    setState(() {
      switch (action) {
        case 'quote':
          status = 'quoted';
          reserved = 2;
        case 'confirm':
          status = 'confirmed';
        case 'prepare':
          status = 'preparing';
        case 'ready':
          status = 'ready';
        case 'accept':
          status = 'assigned';
        case 'pickup':
          status = 'picked_up';
        case 'deliver':
          status = 'delivered';
          stock -= 2;
          reserved = 0;
        case 'fail':
          status = 'delivery_failed';
        case 'redispatch':
          status = 'ready';
        case 'return_cancel':
          status = 'cancelled';
          reserved = 0;
        case 'cancel':
          status = 'cancelled';
          reserved = 0;
        case 'reject':
          status = 'rejected';
          reserved = 0;
        default:
          return;
      }
      events.add('${roles[role]}: ${status.replaceAll('_', ' ')}');
    });
  }

  @override
  Widget build(BuildContext context) {
    final rider = role == UserRole.deliveryPartner;
    final assigned = [
      'assigned',
      'picked_up',
      'delivery_failed',
    ].contains(status);
    final nextRole = switch (status) {
      'submitted' || 'confirmed' || 'preparing' => 'Pharmacy',
      'quoted' => 'Customer',
      'ready' || 'assigned' || 'picked_up' => 'Rider',
      'delivery_failed' => 'Operations',
      _ => 'Finished. Start another sample request to try a different path.',
    };
    return Scaffold(
      appBar: AppBar(title: const Text('COD workflow demo')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 840),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Try every side of a delivery',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text(
                'This walkthrough uses fictional data in this browser only. It resets when you leave. No account, prescription, payment, or real delivery is created.',
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final entry in roles.entries)
                    ChoiceChip(
                      label: Text(entry.value),
                      selected: role == entry.key,
                      onSelected: (_) => setState(() => role = entry.key),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Next: $nextRole',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MD-DEMO-1001',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text('Status: ${status.replaceAll('_', ' ')}'),
                      const Text('Demo Community Pharmacy • 382010'),
                      const Text('Pickup: 123 Fictional Pharmacy Road'),
                      if (!rider || assigned)
                        const Text(
                          'Delivery: 12 Fictional Garden, Demo District',
                        ),
                      if (!rider) ...[
                        const Divider(),
                        const Text('Sample item A (fictional), pack of 10 × 2'),
                        const Text('Batch DEMO-A • Pharmacy review required'),
                        if (status != 'submitted') ...[
                          const Text('2 × ₹92.25 = ₹184.50'),
                          const Text('Delivery: ₹25.00 • Total: ₹209.50'),
                          const Text(
                            'Prices include applicable taxes. Cash on delivery only.',
                          ),
                        ],
                      ],
                      if (rider && assigned)
                        const Text('Collect ₹209.50 on delivery'),
                      if (status == 'delivered')
                        const Text('Cash collected: ₹209.50'),
                      if (status == 'delivery_failed')
                        const Text(
                          'Mock failure: customer unavailable. Return the parcel to the pharmacy before resolving it.',
                        ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final action in orderActions(
                            role,
                            status,
                          ).entries.where((entry) => entry.key != 'prepay'))
                            FilledButton(
                              onPressed: () => act(action.key),
                              child: Text(action.value),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (role == UserRole.pharmacyOwner || role == UserRole.admin)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Inventory',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          'On hand: $stock • Reserved: $reserved • Available: ${stock - reserved}',
                        ),
                        const Text(
                          'A quote reserves stock. Delivery deducts it; cancellation or rejection releases it.',
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Text(
                'Order history',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              for (final event in events)
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.check_circle_outline),
                  title: Text(event),
                ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => setState(() {
                  role = UserRole.customer;
                  status = 'submitted';
                  stock = 100;
                  reserved = 0;
                  events
                    ..clear()
                    ..add('Customer submitted a sample request');
                }),
                child: const Text('Reset demo'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

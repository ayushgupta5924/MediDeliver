import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/auth_service.dart';
import '../../patient/data/order_repository.dart';
import '../../patient/domain/order_model.dart';

class OrdersNotifier extends AsyncNotifier<List<OrderModel>> {
  @override
  Future<List<OrderModel>> build() {
    ref.watch(authProvider.select((s) => s.user?.id));
    return ref.watch(orderRepositoryProvider).orders();
  }

  Future<void> more() async {
    final actorId = ref.read(authProvider).user?.id;
    final current = state.value ?? [];
    final next = await ref
        .read(orderRepositoryProvider)
        .orders(offset: current.length);
    if (ref.mounted && ref.read(authProvider).user?.id == actorId) {
      state = AsyncData(
        {
          ...{for (final o in current) o.id: o},
          ...{for (final o in next) o.id: o},
        }.values.toList(),
      );
    }
  }
}

final ordersProvider = AsyncNotifierProvider<OrdersNotifier, List<OrderModel>>(
  OrdersNotifier.new,
);

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});
  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  bool busy = false;
  Future<void> perform(Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Action not confirmed. Refresh to check the latest status, then retry.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<String?> prompt(String title, {bool numeric = false}) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => HookBuilder(
        builder: (ctx) {
          final controller = useTextEditingController();
          return AlertDialog(
            title: Text(title),
            content: TextField(
              controller: controller,
              autofocus: true,
              maxLength: numeric ? 10 : 500,
              keyboardType: numeric
                  ? const TextInputType.numberWithOptions(decimal: true)
                  : TextInputType.text,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  if (controller.text.trim().isNotEmpty) {
                    Navigator.pop(ctx, controller.text.trim());
                  }
                },
                child: const Text('Confirm'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> update(OrderModel order, String action) async {
    int? quote;
    String? reason;
    if (action == 'quote') {
      final value = await prompt(
        'Verified total including delivery (₹)',
        numeric: true,
      );
      if (value == null) return;
      quote = parseRupees(value);
      if (quote == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Enter a positive amount with up to two decimal places (maximum ₹100,000).',
              ),
            ),
          );
        }
        return;
      }
    }
    if (action == 'reject' || action == 'fail') {
      reason = await prompt(
        action == 'reject' ? 'Reason for rejection' : 'Reason delivery failed',
      );
      if (reason == null) return;
    }
    if (!mounted) return;
    await perform(() async {
      await ref
          .read(orderRepositoryProvider)
          .transition(order.id, action, quotePaise: quote, reason: reason);
      ref.invalidate(ordersProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(authProvider).user?.role;
    final orders = ref.watch(ordersProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(role == UserRole.admin ? 'Operations' : 'Orders'),
        actions: [
          if (role == UserRole.customer)
            IconButton(
              tooltip: 'New order',
              icon: const Icon(Icons.add),
              onPressed: () => context.go('/patient'),
            ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: busy ? null : () => ref.invalidate(ordersProvider),
          ),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: busy
                ? null
                : () => perform(() => ref.read(authProvider.notifier).logout()),
          ),
        ],
      ),
      body: orders.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(ordersProvider),
            child: const Text('Could not load orders. Retry'),
          ),
        ),
        data: (rows) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(ordersProvider);
            await ref.read(ordersProvider.future);
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              if (busy) const LinearProgressIndicator(),
              if (rows.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: Text('No orders yet. Pull down to refresh.'),
                ),
              for (final order in rows)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.orderNumber,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          '${order.pharmacyName} • ${order.status.replaceAll("_", " ")}',
                        ),
                        if (order.deliveryAddress.isNotEmpty)
                          Text(order.deliveryAddress),
                        Text('Postal code: ${order.postalCode}'),
                        for (final item in order.items)
                          Text('${item["name"]} × ${item["quantity"]}'),
                        if (order.customerNotes.isNotEmpty)
                          Text('Notes: ${order.customerNotes}'),
                        if (order.quotePaise != null)
                          Text(
                            'Total: ₹${(order.quotePaise! / 100).toStringAsFixed(2)} • ${order.paymentStatus.replaceAll("_", " ")}',
                          ),
                        if (order.rejectionReason != null)
                          Text(order.rejectionReason!),
                        if (order.prescriptionPath != null &&
                            role != UserRole.deliveryPartner)
                          TextButton.icon(
                            icon: const Icon(Icons.description),
                            label: const Text('View prescription'),
                            onPressed: busy
                                ? null
                                : () => perform(() async {
                                    final url = await ref
                                        .read(orderRepositoryProvider)
                                        .prescriptionUrl(
                                          order.prescriptionPath!,
                                        );
                                    if (!context.mounted) return;
                                    await showDialog<void>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('Prescription'),
                                        content: SizedBox(
                                          width: 600,
                                          height: 500,
                                          child: InteractiveViewer(
                                            child: Image.network(
                                              url,
                                              errorBuilder: (_, _, _) => const Text(
                                                'Image unavailable. Close and reopen to refresh access.',
                                              ),
                                            ),
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(ctx),
                                            child: const Text('Close'),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                          ),
                        Wrap(
                          spacing: 8,
                          children: [
                            for (final entry in orderActions(
                              role,
                              order.status,
                            ).entries)
                              OutlinedButton(
                                onPressed: busy
                                    ? null
                                    : () => update(order, entry.key),
                                child: Text(entry.value),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              if (rows.length >= 25)
                TextButton(
                  onPressed: busy
                      ? null
                      : () => perform(
                          () => ref.read(ordersProvider.notifier).more(),
                        ),
                  child: const Text('Load more'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

int? parseRupees(String value) {
  if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(value)) return null;
  final parts = value.split('.');
  final amount = int.tryParse(parts[0]);
  if (amount == null || amount > 100000) return null;
  final paise =
      amount * 100 +
      (parts.length == 2 ? int.parse(parts[1].padRight(2, '0')) : 0);
  return paise > 0 && paise <= 10000000 ? paise : null;
}

Map<String, String> orderActions(UserRole? role, String status) {
  if (role == UserRole.customer) {
    return {
      if (status == 'quoted') 'confirm': 'Accept total • Cash on delivery',
      if (['submitted', 'quoted', 'confirmed'].contains(status))
        'cancel': 'Cancel request',
    };
  }
  if (role == UserRole.pharmacyOwner) {
    return {
      if (status == 'submitted')
        'quote': 'Verified prescription / eligible medicine: quote',
      if (['submitted', 'quoted', 'confirmed'].contains(status))
        'reject': 'Reject',
      if (status == 'confirmed') 'prepare': 'Start preparing',
      if (status == 'preparing') 'ready': 'Ready for pickup',
    };
  }
  if (role == UserRole.deliveryPartner) {
    return {
      if (status == 'ready') 'accept': 'Accept delivery',
      if (status == 'assigned') 'pickup': 'Confirm pickup',
      if (status == 'picked_up') 'deliver': 'Cash collected • Confirm delivery',
      if (status == 'picked_up') 'fail': 'Report failed delivery',
    };
  }
  if (role == UserRole.admin) {
    return {
      if (status == 'delivery_failed')
        'redispatch': 'Confirm pharmacy return • Redispatch',
    };
  }
  return {};
}

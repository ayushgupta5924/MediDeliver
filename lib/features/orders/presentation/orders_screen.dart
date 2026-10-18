import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/supabase_provider.dart';
import '../../../core/services/payment_service.dart';
import '../../../core/constants/supabase_constants.dart';
import 'inventory_screen.dart';
import '../../patient/data/order_repository.dart';
import '../../patient/domain/order_model.dart';

class OrdersNotifier extends AsyncNotifier<List<OrderModel>> {
  int _generation = 0;
  bool _paging = false;
  @override
  Future<List<OrderModel>> build() {
    _generation++;
    _paging = false;
    ref.watch(authProvider.select((s) => s.user?.id));
    return ref.watch(orderRepositoryProvider).orders();
  }

  Future<void> more() async {
    if (_paging || state.isLoading) return;
    _paging = true;
    final generation = _generation;
    final actorId = ref.read(authProvider).user?.id;
    final current = state.value ?? [];
    try {
      final next = await ref
          .read(orderRepositoryProvider)
          .orders(offset: current.length);
      if (ref.mounted &&
          generation == _generation &&
          ref.read(authProvider).user?.id == actorId) {
        state = AsyncData(
          {
            ...{for (final o in current) o.id: o},
            ...{for (final o in next) o.id: o},
          }.values.toList(),
        );
      }
    } finally {
      if (generation == _generation) _paging = false;
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
  Timer? _refreshTimer;
  AppLifecycleListener? _lifecycle;
  bool _resumed = true;
  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onStateChange: (state) {
        _resumed = state == AppLifecycleState.resumed;
        if (_resumed && mounted && !busy) ref.invalidate(ordersProvider);
      },
    );
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted &&
          _resumed &&
          !busy &&
          (ref.read(ordersProvider).value?.length ?? 0) <= 25) {
        ref.invalidate(ordersProvider);
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _lifecycle?.dispose();
    super.dispose();
  }

  Future<bool> confirmAction(String message) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Confirm action'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Back'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirm'),
            ),
          ],
        ),
      ) ??
      false;
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
    String? reason;
    if (action == 'quote') {
      final values = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (_) => QuoteDialog(pharmacyId: order.pharmacyId),
      );
      if (values == null || !mounted) return;
      await perform(() async {
        await ref
            .read(supabaseProvider)
            .rpc('quote_order', params: {'p_id': order.id, ...values});
        ref.invalidate(ordersProvider);
        ref.invalidate(inventoryProvider(order.pharmacyId));
      });
      return;
    }
    if (action == 'upi') {
      await perform(
        () => ref.read(paymentServiceProvider).pay(order.id, upi: true),
      );
      return;
    }
    if (action == 'upi_review' || action == 'upi_refund') {
      final refund = action == 'upi_refund';
      Map<String, dynamic>? payment;
      await perform(() async {
        payment = await ref
            .read(supabaseProvider)
            .from('upi_payments')
            .select('mode,vpa,payee_name,claimed_utr,verified_utr,created_at')
            .eq('order_id', order.id)
            .single();
      });
      if (payment == null || !mounted) return;
      final summary =
          'Mode: ${payment!['mode']} • Merchant: ${payment!['payee_name']} • UPI ID: ${payment!['vpa'] ?? 'none (simulation)'}\n'
          'Checkout created: ${payment!['created_at']}\n'
          'Customer claim (unverified): ${payment!['claimed_utr'] ?? 'none'}\n'
          'Verified credit: ${payment!['verified_utr'] ?? 'none'}\n\n';
      if (!await confirmAction(
        summary +
            (refund
                ? 'Confirm a full refund has already reached the payer. This records the refund; it does not send money.'
                : 'Verify the credit in the merchant bank ledger: receiving account, payer, date, unique UTR and exact order total. A screenshot, SMS or matching amount alone is insufficient. For mock orders, record a simulated credit only.'),
      )) {
        return;
      }
      final utr = await prompt(
        refund
            ? '12-digit bank refund reference'
            : '12-digit bank credit reference',
      );
      if (utr == null || !mounted) return;
      final amount = await prompt('Exact bank amount in rupees', numeric: true);
      if (amount == null || !mounted) return;
      final note = await prompt(
        'Verification evidence (20–500 characters; no bank credentials)',
      );
      if (note == null || !mounted) return;
      await perform(() async {
        await ref
            .read(supabaseProvider)
            .rpc(
              'upi_review',
              params: {
                'p_order': order.id,
                'p_utr': utr,
                'p_amount': parseRupees(amount),
                'p_note': note,
                'p_refund': refund,
              },
            );
        ref.invalidate(ordersProvider);
      });
      return;
    }
    if (action == 'prepay') {
      await perform(() => ref.read(paymentServiceProvider).pay(order.id));
      return;
    }
    if (['confirm', 'cancel', 'deliver', 'redispatch'].contains(action)) {
      final message = switch (action) {
        'confirm' =>
          'Accept the itemized quote and pay ₹${((order.quotePaise ?? 0) / 100).toStringAsFixed(2)} in cash on delivery?',
        'deliver' =>
          order.paymentStatus == 'paid'
              ? 'Confirm this prepaid order was delivered. Do not collect cash.'
              : 'Confirm delivery and collection of ₹${((order.quotePaise ?? 0) / 100).toStringAsFixed(2)} in cash.',
        'redispatch' =>
          'Confirm all items were returned to the pharmacy and can be dispatched again.',
        _ =>
          'Cancel this request? Captured online payments will be queued for a full refund.',
      };
      if (!await confirmAction(message) || !mounted) return;
    }
    if (action == 'reject' || action == 'fail' || action == 'return_cancel') {
      reason = await prompt(
        action == 'reject'
            ? 'Reason for rejection'
            : action == 'return_cancel'
            ? 'Confirm pharmacy return and cancellation reason'
            : 'Reason delivery failed',
      );
      if (reason == null) return;
    }
    if (!mounted) return;
    await perform(() async {
      await ref
          .read(orderRepositoryProvider)
          .transition(order.id, action, reason: reason);
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
          if (role == UserRole.pharmacyOwner)
            IconButton(
              tooltip: 'Inventory',
              icon: const Icon(Icons.inventory_2),
              onPressed: busy
                  ? null
                  : () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const InventoryScreen(),
                      ),
                    ),
            ),
          IconButton(
            tooltip: 'Support',
            icon: const Icon(Icons.help_outline),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('MediDeliver support'),
                content: const SelectableText(
                  'ayushgupta.5924@gmail.com\nInclude your order number. Do not email prescriptions or payment details. For urgent medical help, contact local emergency services.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ),
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
                        if (order.paymentMethod == 'upi' &&
                            SupabaseConstants.demoMode)
                          const Text('Simulated UPI payment • No real money'),
                        if (order.deliveryAddress.isNotEmpty)
                          Text(order.deliveryAddress),
                        Text('Postal code: ${order.postalCode}'),
                        if (order.recipientPhone.isNotEmpty)
                          SelectableText(
                            'Delivery contact: ${order.recipientPhone}',
                          ),
                        if (order.pickupAddress.isNotEmpty)
                          Text('Pharmacy pickup: ${order.pickupAddress}'),
                        if (order.pharmacyPhone.isNotEmpty)
                          SelectableText(
                            'Pharmacy contact: ${order.pharmacyPhone}',
                          ),
                        for (final item in order.quoteItems)
                          Text(
                            '${item['name']} × ${item['quantity']} • ₹${((item['unit_price_paise'] as num) / 100).toStringAsFixed(2)} each • Batch ${item['batch_number']} • Expiry ${item['expires_on']}',
                          ),
                        if (order.quoteItems.isNotEmpty)
                          Text(
                            'Delivery: ₹${(order.deliveryFeePaise / 100).toStringAsFixed(2)} • All prices include applicable taxes',
                          ),
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
                              paymentStatus: order.paymentStatus,
                              paymentMethod: order.paymentMethod,
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

Map<String, String> orderActions(
  UserRole? role,
  String status, {
  String paymentStatus = 'unpaid',
  String? paymentMethod,
}) {
  if (role == UserRole.customer) {
    return {
      if (status == 'quoted' && !['razorpay', 'upi'].contains(paymentMethod))
        'confirm': 'Accept total • Cash on delivery',
      if (status == 'quoted' &&
          paymentMethod != 'razorpay' &&
          SupabaseConstants.upiMode != 'disabled')
        'upi': paymentMethod == 'upi'
            ? 'View UPI checkout'
            : SupabaseConstants.upiMode == 'mock'
            ? 'Try UPI • No real payment'
            : 'Pay by UPI • Bank review required',
      if (status == 'quoted' &&
          paymentMethod != 'upi' &&
          SupabaseConstants.paymentsEnabled)
        'prepay': paymentMethod == 'razorpay'
            ? 'Resume online checkout'
            : 'Accept total • Pay online',
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
      if (status == 'picked_up')
        'deliver': paymentStatus == 'paid'
            ? 'Prepaid • Confirm delivery'
            : 'Cash collected • Confirm delivery',
      if (status == 'picked_up') 'fail': 'Report failed delivery',
    };
  }
  if (role == UserRole.admin) {
    return {
      if (paymentMethod == 'upi' && paymentStatus == 'pending')
        'upi_review': 'Review UPI bank credit',
      if (paymentMethod == 'upi' && paymentStatus == 'refund_pending')
        'upi_refund': 'Record completed UPI refund',
      if (status == 'delivery_failed')
        'redispatch': 'Confirm pharmacy return • Redispatch',
      if (status == 'delivery_failed')
        'return_cancel': 'Confirm pharmacy return • Cancel and refund',
    };
  }
  return {};
}

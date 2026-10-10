import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import '../../../core/services/supabase_provider.dart';
import 'orders_screen.dart';

final inventoryProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, id) async {
      return await ref
          .watch(supabaseProvider)
          .from('inventory_lots')
          .select()
          .eq('pharmacy_id', id)
          .order('expires_on')
          .limit(500);
    });

class InventoryScreen extends ConsumerWidget {
  const InventoryScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pharmacy inventory')),
      body: FutureBuilder(
        future: ref
            .read(supabaseProvider)
            .from('pharmacy_members')
            .select('pharmacy_id'),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('Inventory unavailable. Reopen to retry.'),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final ids = snapshot.data!
              .map((m) => m['pharmacy_id'] as String)
              .toList();
          if (ids.isEmpty) {
            return const Center(
              child: Text('Ask your operator to assign a pharmacy.'),
            );
          }
          return ListView(
            children: [for (final id in ids) InventoryPanel(pharmacyId: id)],
          );
        },
      ),
    );
  }
}

class InventoryPanel extends ConsumerWidget {
  final String pharmacyId;
  const InventoryPanel({super.key, required this.pharmacyId});
  Future<void> save(
    BuildContext context,
    WidgetRef ref, [
    Map<String, dynamic>? lot,
  ]) async {
    final values = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => LotDialog(lot: lot),
    );
    if (values == null || !context.mounted) return;
    try {
      await ref
          .read(supabaseProvider)
          .rpc(
            'save_inventory',
            params: {'p_pharmacy_id': pharmacyId, ...values},
          );
      if (context.mounted) ref.invalidate(inventoryProvider(pharmacyId));
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not save. Check expiry, duplicate batches and reserved stock.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Pharmacy $pharmacyId'),
        FilledButton.icon(
          onPressed: () => save(context, ref),
          icon: const Icon(Icons.add),
          label: const Text('Add stock batch'),
        ),
        const Text(
          'Stock is counted in the pack/unit shown in the medicine name. Include strength and pack size. Prices include applicable taxes.',
        ),
        ref
            .watch(inventoryProvider(pharmacyId))
            .when(
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => TextButton(
                onPressed: () => ref.invalidate(inventoryProvider(pharmacyId)),
                child: const Text('Retry inventory'),
              ),
              data: (lots) => Column(
                children: [
                  if (lots.isEmpty) const Text('No stock batches yet.'),
                  for (final lot in lots)
                    ListTile(
                      title: Text(
                        '${lot['medicine_name']} • ${lot['batch_number']}',
                      ),
                      subtitle: Text(
                        'Expiry ${lot['expires_on']} • Stock ${lot['on_hand']} • Reserved ${lot['reserved']} • ₹${((lot['unit_price_paise'] as num) / 100).toStringAsFixed(2)}',
                      ),
                      trailing: IconButton(
                        tooltip: 'Update stock and price',
                        icon: const Icon(Icons.edit),
                        onPressed: () => save(context, ref, lot),
                      ),
                    ),
                  if (lots.length == 500)
                    const Text(
                      'Showing the first 500 batches. Use database administration for larger inventories.',
                    ),
                ],
              ),
            ),
      ],
    ),
  );
}

class LotDialog extends HookWidget {
  final Map<String, dynamic>? lot;
  const LotDialog({super.key, this.lot});
  @override
  Widget build(BuildContext context) {
    final name = useTextEditingController(
      text: lot?['medicine_name'] as String?,
    );
    final batch = useTextEditingController(
      text: lot?['batch_number'] as String?,
    );
    final expiry = useTextEditingController(
      text: lot?['expires_on'] as String?,
    );
    final price = useTextEditingController(
      text: lot == null
          ? ''
          : ((lot!['unit_price_paise'] as num) / 100).toStringAsFixed(2),
    );
    final stock = useTextEditingController(text: lot?['on_hand'].toString());
    final error = useState<String?>(null);
    return AlertDialog(
      title: Text(lot == null ? 'Add batch' : 'Update batch'),
      content: SizedBox(
        width: 450,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                enabled: lot == null,
                maxLength: 200,
                decoration: const InputDecoration(
                  labelText: 'Medicine, strength and pack size',
                ),
              ),
              TextField(
                controller: batch,
                enabled: lot == null,
                maxLength: 100,
                decoration: const InputDecoration(labelText: 'Batch number'),
              ),
              TextField(
                controller: expiry,
                enabled: lot == null,
                decoration: const InputDecoration(
                  labelText: 'Expiry YYYY-MM-DD',
                ),
              ),
              TextField(
                controller: price,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Price per unit/pack (₹, including tax)',
                ),
              ),
              TextField(
                controller: stock,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Total on hand (including reserved)',
                ),
              ),
              if (error.value != null) Text(error.value!),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final amount = parseRupees(price.text.trim());
            final qty = int.tryParse(stock.text.trim());
            final date = DateTime.tryParse(expiry.text.trim());
            if (name.text.trim().isEmpty ||
                batch.text.trim().isEmpty ||
                amount == null ||
                qty == null ||
                qty < 0 ||
                qty > 1000000 ||
                date == null ||
                date.toIso8601String().substring(0, 10) != expiry.text.trim()) {
              error.value = 'Check all fields and use YYYY-MM-DD for expiry.';
              return;
            }
            Navigator.pop(context, {
              'p_id': lot?['id'],
              'p_name': name.text.trim(),
              'p_batch': batch.text.trim(),
              'p_expiry': expiry.text.trim(),
              'p_price': amount,
              'p_stock': qty,
            });
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class QuoteDialog extends HookConsumerWidget {
  final String pharmacyId;
  const QuoteDialog({super.key, required this.pharmacyId});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quantities = useState(<String, int>{});
    final fee = useTextEditingController(text: '0');
    final note = useTextEditingController();
    final reviewed = useState(false);
    final error = useState<String?>(null);
    final inventory = ref.watch(inventoryProvider(pharmacyId));
    return AlertDialog(
      title: const Text('Review and itemize quote'),
      content: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Review the request and any prescription before quoting. Select exact stock batches; no automatic substitution is performed.',
              ),
              inventory.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, _) =>
                    const Text('Could not load inventory. Close and retry.'),
                data: (lots) => Column(
                  children: [
                    if (lots.isEmpty)
                      const Text('Add inventory before quoting.'),
                    for (final lot in lots)
                      if ((lot['on_hand'] as int) > (lot['reserved'] as int))
                        TextField(
                          key: ValueKey(lot['id']),
                          keyboardType: TextInputType.number,
                          maxLength: 3,
                          decoration: InputDecoration(
                            labelText:
                                '${lot['medicine_name']} • ${lot['batch_number']}',
                            helperText:
                                'Expires ${lot['expires_on']} • Available ${(lot['on_hand'] as int) - (lot['reserved'] as int)} • ₹${((lot['unit_price_paise'] as num) / 100).toStringAsFixed(2)}',
                          ),
                          onChanged: (v) => quantities.value = {
                            ...quantities.value,
                            lot['id'] as String: int.tryParse(v) ?? 0,
                          },
                        ),
                  ],
                ),
              ),
              TextField(
                controller: fee,
                decoration: const InputDecoration(
                  labelText: 'Delivery fee (₹, including tax)',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              TextField(
                controller: note,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'Review decision / dispensing notes',
                ),
              ),
              CheckboxListTile(
                value: reviewed.value,
                onChanged: (v) => reviewed.value = v ?? false,
                title: const Text(
                  'I reviewed the prescription/eligibility, exact medicines and quantities.',
                ),
              ),
              if (error.value != null) Text(error.value!),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final delivery = RegExp(r'^0(\.0{1,2})?$').hasMatch(fee.text.trim())
                ? 0
                : parseRupees(fee.text.trim());
            final lines = quantities.value.entries
                .where((e) => e.value != 0)
                .map((e) => {'lot_id': e.key, 'quantity': e.value})
                .toList();
            if (!reviewed.value ||
                delivery == null ||
                delivery > 1000000 ||
                note.text.trim().length < 3 ||
                lines.isEmpty ||
                quantities.value.values.any((v) => v < 0 || v > 100)) {
              error.value =
                  'Select quantities, a valid fee and a review decision.';
              return;
            }
            Navigator.pop(context, {
              'p_lines': lines,
              'p_delivery_fee': delivery,
              'p_review_note': note.text.trim(),
            });
          },
          child: const Text('Reserve stock and quote'),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/services/auth_service.dart';
import 'patient_controller.dart';

class PatientUploadScreen extends HookConsumerWidget {
  const PatientUploadScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(patientProvider);
    final notifier = ref.read(patientProvider.notifier);
    final medicine = useTextEditingController();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order medicine'),
        actions: [
          IconButton(
            tooltip: 'My orders',
            icon: const Icon(Icons.receipt_long),
            onPressed: () => context.go('/orders'),
          ),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              try {
                await ref.read(authProvider.notifier).logout();
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Could not sign out. Try again.'),
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 650),
          child: state.submittedOrder != null
              ? ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    Text(
                      'Request received',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    Text(state.submittedOrder!.orderNumber),
                    const Text(
                      'The pharmacy will review your request and quote a total. Delivery availability is confirmed by the pharmacy.',
                    ),
                    FilledButton(
                      onPressed: () => context.go('/orders'),
                      child: const Text('View order status'),
                    ),
                    TextButton(
                      onPressed: notifier.resetAfterSubmit,
                      child: const Text('New request'),
                    ),
                  ],
                )
              : AbsorbPointer(
                  absorbing: state.isUploading,
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      ref
                          .watch(pharmaciesProvider)
                          .when(
                            loading: () => const LinearProgressIndicator(),
                            error: (_, _) => TextButton(
                              onPressed: () =>
                                  ref.invalidate(pharmaciesProvider),
                              child: const Text(
                                'Could not load pharmacies. Retry',
                              ),
                            ),
                            data: (pharmacies) => pharmacies.isEmpty
                                ? const Text(
                                    'No pharmacies are accepting requests yet.',
                                  )
                                : DropdownButtonFormField<String>(
                                    initialValue: state.pharmacyId,
                                    decoration: const InputDecoration(
                                      labelText: 'Pharmacy',
                                    ),
                                    isExpanded: true,
                                    items: pharmacies
                                        .map(
                                          (p) => DropdownMenuItem(
                                            value: p.id,
                                            child: Text(
                                              '${p.name} (${p.postalCodes.join(", ")})',
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (id) =>
                                        notifier.edit(pharmacyId: id),
                                  ),
                          ),
                      TextFormField(
                        initialValue: state.address,
                        maxLength: 500,
                        decoration: const InputDecoration(
                          labelText: 'Full delivery address',
                        ),
                        onChanged: (v) => notifier.edit(address: v),
                      ),
                      TextFormField(
                        initialValue: state.postalCode,
                        maxLength: 6,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Postal code',
                        ),
                        onChanged: (v) => notifier.edit(postalCode: v.trim()),
                      ),
                      const SizedBox(height: 16),
                      SegmentedButton<OrderInputMode>(
                        segments: const [
                          ButtonSegment(
                            value: OrderInputMode.prescription,
                            label: Text('Prescription'),
                          ),
                          ButtonSegment(
                            value: OrderInputMode.typed,
                            label: Text('Medicine names'),
                          ),
                        ],
                        selected: {state.inputMode},
                        onSelectionChanged: (v) =>
                            notifier.setInputMode(v.first),
                      ),
                      const SizedBox(height: 16),
                      if (state.inputMode == OrderInputMode.prescription) ...[
                        const Text('Upload a clear JPEG or PNG, up to 5 MB.'),
                        if (state.selectedImage != null)
                          Text('Selected: ${state.selectedImage!.name}'),
                        Wrap(
                          spacing: 12,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () =>
                                  notifier.pick(ImageSource.camera),
                              icon: const Icon(Icons.camera_alt),
                              label: const Text('Camera'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () =>
                                  notifier.pick(ImageSource.gallery),
                              icon: const Icon(Icons.photo),
                              label: const Text('Gallery'),
                            ),
                          ],
                        ),
                      ] else ...[
                        const Text(
                          'Include strength and pack size. The pharmacist must verify the request before fulfillment.',
                        ),
                        TextField(
                          controller: medicine,
                          maxLength: 200,
                          decoration: InputDecoration(
                            labelText: 'Medicine, strength and pack size',
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.add),
                              onPressed: () {
                                notifier.addMedicine(medicine.text);
                                medicine.clear();
                              },
                            ),
                          ),
                        ),
                        for (final item in state.typedMedicines)
                          ListTile(
                            title: Text(item.name),
                            subtitle: Text('Quantity: ${item.quantity}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove),
                                  onPressed: () => notifier.changeQuantity(
                                    item.id,
                                    item.quantity - 1,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add),
                                  onPressed: () => notifier.changeQuantity(
                                    item.id,
                                    item.quantity + 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                      TextFormField(
                        initialValue: state.notes,
                        maxLength: 1000,
                        decoration: const InputDecoration(
                          labelText: 'Notes (optional)',
                        ),
                        onChanged: (v) => notifier.edit(notes: v),
                      ),
                      if (state.errorMessage != null)
                        Text(
                          state.errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: state.canSubmit
                            ? notifier.submitOrder
                            : null,
                        child: Text(
                          state.isUploading
                              ? 'Submitting…'
                              : 'Request pharmacy review',
                        ),
                      ),
                      const Text(
                        'Prices and delivery availability are confirmed after review. This pilot supports cash on delivery only.',
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

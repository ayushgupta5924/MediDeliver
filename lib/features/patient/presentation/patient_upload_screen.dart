import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'patient_controller.dart';

class PatientUploadScreen extends HookConsumerWidget {
  const PatientUploadScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(patientProvider);
    final notifier = ref.read(patientProvider.notifier);

    if (state.orderSubmitted && state.submittedOrder != null) {
      return _OrderConfirmationScreen(
        orderNumber: state.submittedOrder!.orderNumber,
        onPlaceAnother: notifier.resetAfterSubmit,
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF00897B),
        foregroundColor: Colors.white,
        title: const Text('Order Medicine'),
        elevation: 0,
      ),
      backgroundColor: Colors.grey[50],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Mode toggle ───────────────────────
            _ModeToggle(
              selected: state.inputMode,
              onChanged: notifier.setInputMode,
            ),

            const SizedBox(height: 20),

            // ── Content based on mode ─────────────
            if (state.inputMode == OrderInputMode.typed)
              _TypeMedicineSection(state: state, notifier: notifier)
            else
              _PrescriptionSection(state: state, notifier: notifier),

            // ── Customer notes ────────────────────
            const SizedBox(height: 16),
            _NotesField(
              initialValue: state.customerNotes ?? '',
              onChanged: notifier.updateNotes,
            ),

            // ── Error ─────────────────────────────
            if (state.errorMessage != null) ...[
              const SizedBox(height: 12),
              _ErrorBanner(message: state.errorMessage!),
            ],

            const SizedBox(height: 24),

            // ── Submit button ─────────────────────
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: state.canSubmit ? notifier.submitOrder : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00897B),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey[200],
                  disabledForegroundColor: Colors.grey[400],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: state.isUploading
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Placing Order...',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      )
                    : const Text(
                        'Submit Order',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 12),

            Center(
              child: Text(
                '🛵  ₹25 delivery fee  •  60 min delivery',
                style: TextStyle(fontSize: 13, color: Colors.grey[500]),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ── Mode Toggle ────────────────────────────────────

class _ModeToggle extends StatelessWidget {
  final OrderInputMode selected;
  final ValueChanged<OrderInputMode> onChanged;

  const _ModeToggle({
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _Tab(
            label: 'Type Medicines',
            icon: Icons.edit_outlined,
            selected: selected == OrderInputMode.typed,
            onTap: () => onChanged(OrderInputMode.typed),
          ),
          _Tab(
            label: 'Upload Prescription',
            icon: Icons.document_scanner_outlined,
            selected: selected == OrderInputMode.prescription,
            onTap: () => onChanged(OrderInputMode.prescription),
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _Tab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected
                    ? const Color(0xFF00897B)
                    : Colors.grey[500],
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected
                        ? FontWeight.w600
                        : FontWeight.normal,
                    color: selected
                        ? const Color(0xFF00897B)
                        : Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Type Medicine Section ──────────────────────────

class _TypeMedicineSection extends StatefulWidget {
  final PatientState state;
  final PatientNotifier notifier;

  const _TypeMedicineSection({
    required this.state,
    required this.notifier,
  });

  @override
  State<_TypeMedicineSection> createState() => _TypeMedicineSectionState();
}

class _TypeMedicineSectionState extends State<_TypeMedicineSection> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  // Common medicine suggestions shown below search
  // EXTEND: fetch these from Supabase products table later
  static const List<String> _suggestions = [
    'Paracetamol 500mg',
    'Amoxicillin 500mg',
    'Azithromycin 500mg',
    'Pantoprazole 40mg',
    'Metformin 500mg',
    'Atorvastatin 10mg',
    'Amlodipine 5mg',
    'Cetirizine 10mg',
    'Ibuprofen 400mg',
    'Vitamin D3',
    'Vitamin B12',
    'Calcium + D3',
  ];

  List<String> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = _suggestions;
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearch(String value) {
    setState(() {
      if (value.trim().isEmpty) {
        _filtered = _suggestions;
      } else {
        _filtered = _suggestions
            .where((s) =>
                s.toLowerCase().contains(value.toLowerCase()))
            .toList();
      }
    });
  }

  void _addFromField() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.notifier.addMedicine(text);
    _controller.clear();
    _focusNode.unfocus();
    setState(() => _filtered = _suggestions);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Search/type field ──────────────────
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            onChanged: _onSearch,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: 'Search or type medicine name...',
              hintStyle:
                  TextStyle(color: Colors.grey[400], fontSize: 14),
              prefixIcon: const Icon(
                Icons.search,
                color: Color(0xFF00897B),
              ),
              suffixIcon: _controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.add_circle,
                          color: Color(0xFF00897B)),
                      onPressed: _addFromField,
                      tooltip: 'Add medicine',
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            onSubmitted: (_) => _addFromField(),
          ),
        ),

        // ── Added medicines list ───────────────
        if (widget.state.typedMedicines.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            'Added Medicines',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          ...widget.state.typedMedicines.map(
            (medicine) => _MedicineListItem(
              medicine: medicine,
              onRemove: () =>
                  widget.notifier.removeMedicine(medicine.id),
              onQuantityChanged: (qty) => widget.notifier
                  .updateMedicineQuantity(medicine.id, qty),
            ),
          ),
        ],

        // ── Suggestions ────────────────────────
        const SizedBox(height: 16),
        Text(
          _controller.text.isEmpty
              ? 'Common Medicines'
              : 'Search Results',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 8),

        if (_filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.add_circle_outline,
                    color: Color(0xFF00897B), size: 18),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _addFromField,
                  child: Text(
                    'Add "${_controller.text}" as custom medicine',
                    style: const TextStyle(
                      color: Color(0xFF00897B),
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _filtered.map((suggestion) {
              final alreadyAdded = widget.state.typedMedicines
                  .any((m) =>
                      m.name.toLowerCase() ==
                      suggestion.toLowerCase());
              return GestureDetector(
                onTap: alreadyAdded
                    ? null
                    : () {
                        widget.notifier.addMedicine(suggestion);
                        _controller.clear();
                        _focusNode.unfocus();
                        setState(
                            () => _filtered = _suggestions);
                      },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: alreadyAdded
                        ? const Color(0xFF00897B).withOpacity(0.1)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: alreadyAdded
                          ? const Color(0xFF00897B)
                          : Colors.grey[300]!,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (alreadyAdded)
                        const Icon(
                          Icons.check,
                          size: 14,
                          color: Color(0xFF00897B),
                        )
                      else
                        const Icon(
                          Icons.add,
                          size: 14,
                          color: Colors.grey,
                        ),
                      const SizedBox(width: 4),
                      Text(
                        suggestion,
                        style: TextStyle(
                          fontSize: 13,
                          color: alreadyAdded
                              ? const Color(0xFF00897B)
                              : Colors.grey[700],
                          fontWeight: alreadyAdded
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}

// ── Medicine List Item ─────────────────────────────

class _MedicineListItem extends StatelessWidget {
  final MedicineItem medicine;
  final VoidCallback onRemove;
  final ValueChanged<int> onQuantityChanged;

  const _MedicineListItem({
    required this.medicine,
    required this.onRemove,
    required this.onQuantityChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF00897B).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.medication_outlined,
            color: Color(0xFF00897B),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              medicine.name,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          // Quantity control
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () => onQuantityChanged(medicine.quantity - 1),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.remove, size: 14),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '${medicine.quantity}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => onQuantityChanged(medicine.quantity + 1),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: Color(0xFF00897B),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add,
                      size: 14, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(
              Icons.close,
              size: 18,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Prescription Section ───────────────────────────

class _PrescriptionSection extends StatelessWidget {
  final PatientState state;
  final PatientNotifier notifier;

  const _PrescriptionSection({
    required this.state,
    required this.notifier,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Info banner
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF00897B).withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF00897B).withOpacity(0.2),
            ),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline,
                  color: Color(0xFF00897B), size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Upload a clear photo of your doctor\'s prescription.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF00897B),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Image picker
        GestureDetector(
          onTap: state.isUploading
              ? null
              : () => _showPickerSheet(context, notifier),
          child: Container(
            width: double.infinity,
            height: 220,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: state.selectedImage != null
                    ? const Color(0xFF00897B)
                    : Colors.grey[300]!,
                width: state.selectedImage != null ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: state.selectedImage != null
                ? _SelectedImageView(
                    imageFile: state.selectedImage!,
                    onClear:
                        state.isUploading ? null : notifier.clearImage,
                  )
                : _EmptyPickerView(),
          ),
        ),

        const SizedBox(height: 12),

        // Camera / Gallery buttons
        Row(
          children: [
            Expanded(
              child: _PickerButton(
                icon: Icons.camera_alt_outlined,
                label: 'Camera',
                onTap: state.isUploading ? null : notifier.pickFromCamera,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _PickerButton(
                icon: Icons.photo_library_outlined,
                label: 'Gallery',
                outlined: true,
                onTap: state.isUploading ? null : notifier.pickFromGallery,
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showPickerSheet(BuildContext context, PatientNotifier notifier) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Select Prescription Image',
                style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFF00897B),
                  child: Icon(Icons.camera_alt,
                      color: Colors.white, size: 20),
                ),
                title: const Text('Take a photo'),
                onTap: () {
                  Navigator.pop(context);
                  notifier.pickFromCamera();
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFF1565C0),
                  child: Icon(Icons.photo_library,
                      color: Colors.white, size: 20),
                ),
                title: const Text('Choose from gallery'),
                onTap: () {
                  Navigator.pop(context);
                  notifier.pickFromGallery();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Notes Field ────────────────────────────────────

class _NotesField extends StatelessWidget {
  final String initialValue;
  final ValueChanged<String> onChanged;

  const _NotesField({
    required this.initialValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      maxLines: 2,
      decoration: InputDecoration(
        hintText: 'Add notes for pharmacy (optional)...',
        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
        prefixIcon: const Icon(Icons.note_outlined, color: Colors.grey),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
              color: Color(0xFF00897B), width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }
}

// ── Shared sub-widgets ─────────────────────────────

class _EmptyPickerView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.document_scanner_outlined,
            size: 56, color: Colors.grey[400]),
        const SizedBox(height: 10),
        Text(
          'Tap to upload prescription',
          style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
              fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        Text('JPG or PNG',
            style: TextStyle(fontSize: 12, color: Colors.grey[400])),
      ],
    );
  }
}

class _SelectedImageView extends StatelessWidget {
  final File imageFile;
  final VoidCallback? onClear;

  const _SelectedImageView({required this.imageFile, this.onClear});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.file(imageFile, fit: BoxFit.cover),
        ),
        if (onClear != null)
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: onClear,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close,
                    color: Colors.white, size: 18),
              ),
            ),
          ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFF00897B),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(14),
                bottomRight: Radius.circular(14),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 16),
                SizedBox(width: 6),
                Text(
                  'Prescription selected — tap to change',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PickerButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool outlined;

  const _PickerButton({
    required this.icon,
    required this.label,
    this.onTap,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor:
            outlined ? Colors.white : const Color(0xFF00897B),
        foregroundColor:
            outlined ? const Color(0xFF00897B) : Colors.white,
        side: outlined
            ? const BorderSide(color: Color(0xFF00897B))
            : BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.red, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Order Confirmation ─────────────────────────────

class _OrderConfirmationScreen extends StatelessWidget {
  final String orderNumber;
  final VoidCallback onPlaceAnother;

  const _OrderConfirmationScreen({
    required this.orderNumber,
    required this.onPlaceAnother,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: const Color(0xFF00897B).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF00897B),
                  size: 60,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Order Placed!',
                style: TextStyle(
                    fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                orderNumber,
                style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                    fontFamily: 'monospace'),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: const Column(
                  children: [
                    _StatusStep(
                      icon: Icons.receipt_long_outlined,
                      label: 'Order received',
                      done: true,
                    ),
                    _StatusStep(
                      icon: Icons.local_pharmacy_outlined,
                      label: 'Pharmacy reviewing',
                      done: false,
                    ),
                    _StatusStep(
                      icon: Icons.delivery_dining_outlined,
                      label: 'Rider on the way',
                      done: false,
                      isLast: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Expected delivery within 60 minutes',
                style:
                    TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: onPlaceAnother,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00897B),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Place Another Order',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusStep extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool done;
  final bool isLast;

  const _StatusStep({
    required this.icon,
    required this.label,
    required this.done,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Column(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: done
                    ? const Color(0xFF00897B)
                    : Colors.grey[200],
                shape: BoxShape.circle,
              ),
              child: Icon(icon,
                  size: 18,
                  color: done ? Colors.white : Colors.grey[400]),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 24,
                color: done
                    ? const Color(0xFF00897B).withOpacity(0.3)
                    : Colors.grey[200],
              ),
          ],
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: done ? const Color(0xFF00897B) : Colors.grey[500],
            fontWeight:
                done ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
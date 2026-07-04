import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../data/order_repository.dart';
import '../domain/order_model.dart';

// ── Medicine Item ──────────────────────────────────
// Represents one medicine typed by the customer

class MedicineItem {
  final String id;
  final String name;
  final int quantity;

  const MedicineItem({
    required this.id,
    required this.name,
    this.quantity = 1,
  });

  MedicineItem copyWith({String? name, int? quantity}) {
    return MedicineItem(
      id: id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
    );
  }
}

// ── Order Input Mode ───────────────────────────────

enum OrderInputMode {
  prescription, // Upload image
  typed,        // Type medicine names
}

// ── State ──────────────────────────────────────────

class PatientState {
  final OrderInputMode inputMode;
  final File? selectedImage;
  final List<MedicineItem> typedMedicines;
  final bool isUploading;
  final String? errorMessage;
  final OrderModel? submittedOrder;
  final bool orderSubmitted;
  final String? customerNotes;

  const PatientState({
    this.inputMode = OrderInputMode.prescription,
    this.selectedImage,
    this.typedMedicines = const [],
    this.isUploading = false,
    this.errorMessage,
    this.submittedOrder,
    this.orderSubmitted = false,
    this.customerNotes,
  });

  // Can submit if:
  // - Prescription mode: image selected
  // - Typed mode: at least one medicine added
  bool get canSubmit {
    if (isUploading) return false;
    if (inputMode == OrderInputMode.prescription) {
      return selectedImage != null;
    }
    return typedMedicines.isNotEmpty;
  }

  PatientState copyWith({
    OrderInputMode? inputMode,
    File? selectedImage,
    List<MedicineItem>? typedMedicines,
    bool? isUploading,
    String? errorMessage,
    OrderModel? submittedOrder,
    bool? orderSubmitted,
    String? customerNotes,
    bool clearImage = false,
    bool clearError = false,
    bool clearOrder = false,
  }) {
    return PatientState(
      inputMode: inputMode ?? this.inputMode,
      selectedImage:
          clearImage ? null : selectedImage ?? this.selectedImage,
      typedMedicines: typedMedicines ?? this.typedMedicines,
      isUploading: isUploading ?? this.isUploading,
      errorMessage:
          clearError ? null : errorMessage ?? this.errorMessage,
      submittedOrder:
          clearOrder ? null : submittedOrder ?? this.submittedOrder,
      orderSubmitted: orderSubmitted ?? this.orderSubmitted,
      customerNotes: customerNotes ?? this.customerNotes,
    );
  }
}

// ── Notifier ───────────────────────────────────────

class PatientNotifier extends Notifier<PatientState> {
  final _picker = ImagePicker();

  @override
  PatientState build() => const PatientState();

  // ── Switch input mode ──────────────────────────

  void setInputMode(OrderInputMode mode) {
    state = state.copyWith(
      inputMode: mode,
      clearImage: true,
      clearError: true,
    );
  }

  // ── Typed medicines ────────────────────────────

  void addMedicine(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    // Prevent exact duplicates
    final exists = state.typedMedicines
        .any((m) => m.name.toLowerCase() == trimmed.toLowerCase());
    if (exists) return;

    final newItem = MedicineItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: trimmed,
    );

    state = state.copyWith(
      typedMedicines: [...state.typedMedicines, newItem],
      clearError: true,
    );
  }

  void removeMedicine(String id) {
    state = state.copyWith(
      typedMedicines:
          state.typedMedicines.where((m) => m.id != id).toList(),
    );
  }

  void updateMedicineQuantity(String id, int quantity) {
    if (quantity < 1) return;
    state = state.copyWith(
      typedMedicines: state.typedMedicines
          .map((m) => m.id == id ? m.copyWith(quantity: quantity) : m)
          .toList(),
    );
  }

  // ── Image picking ──────────────────────────────

  Future<void> pickFromCamera() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1200,
      );
      if (picked != null) {
        state = state.copyWith(
          selectedImage: File(picked.path),
          clearError: true,
        );
      }
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Could not open camera. Please try gallery.',
      );
    }
  }

  Future<void> pickFromGallery() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1200,
      );
      if (picked != null) {
        state = state.copyWith(
          selectedImage: File(picked.path),
          clearError: true,
        );
      }
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Could not open gallery.',
      );
    }
  }

  void clearImage() {
    state = state.copyWith(clearImage: true, clearError: true);
  }

  void updateNotes(String notes) {
    state = state.copyWith(customerNotes: notes);
  }

  // ── Submit order ───────────────────────────────

  Future<void> submitOrder() async {
    if (!state.canSubmit) return;
    state = state.copyWith(isUploading: true, clearError: true);

    final repository = ref.read(orderRepositoryProvider);

    String? prescriptionUrl;
    String? typedMedicinesText;

    if (state.inputMode == OrderInputMode.prescription) {
      // Upload image
      final uploadResult = await repository.uploadPrescriptionImage(
        state.selectedImage!,
      );
      if (uploadResult.isFailure) {
        state = state.copyWith(
          isUploading: false,
          errorMessage: uploadResult.error,
        );
        return;
      }
      prescriptionUrl = uploadResult.data;
    } else {
      // Convert typed medicines to a readable string
      // stored in customer_notes field
      typedMedicinesText = state.typedMedicines
          .map((m) => '${m.name} x${m.quantity}')
          .join(', ');
    }

    final orderResult = await repository.createOrder(
      prescriptionImageUrl: prescriptionUrl,
      customerNotes: state.inputMode == OrderInputMode.typed
          ? 'Medicines: $typedMedicinesText'
          : state.customerNotes,
    );

    if (orderResult.isFailure) {
      state = state.copyWith(
        isUploading: false,
        errorMessage: orderResult.error,
      );
      return;
    }

    state = state.copyWith(
      isUploading: false,
      orderSubmitted: true,
      submittedOrder: orderResult.data,
      clearImage: true,
      clearError: true,
    );
  }

  void resetAfterSubmit() {
    state = const PatientState();
  }
}

final patientProvider = NotifierProvider<PatientNotifier, PatientState>(
  PatientNotifier.new,
);
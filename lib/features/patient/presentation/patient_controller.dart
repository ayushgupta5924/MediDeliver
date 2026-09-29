import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../../core/services/auth_service.dart';
import '../data/order_repository.dart';
import '../domain/order_model.dart';

enum OrderInputMode { prescription, typed }

class MedicineItem {
  final String id, name;
  final int quantity;
  const MedicineItem({required this.id, required this.name, this.quantity = 1});
  Map<String, dynamic> toMap() => {'name': name, 'quantity': quantity};
}

class PatientState {
  final OrderInputMode inputMode;
  final XFile? selectedImage;
  final List<MedicineItem> typedMedicines;
  final bool isUploading;
  final String? errorMessage;
  final OrderModel? submittedOrder;
  final String address, postalCode, notes;
  final String? pharmacyId;
  const PatientState({
    this.inputMode = OrderInputMode.prescription,
    this.selectedImage,
    this.typedMedicines = const [],
    this.isUploading = false,
    this.errorMessage,
    this.submittedOrder,
    this.address = '',
    this.postalCode = '',
    this.notes = '',
    this.pharmacyId,
  });
  bool get canSubmit =>
      !isUploading &&
      pharmacyId != null &&
      address.trim().length >= 10 &&
      RegExp(r'^\d{6}$').hasMatch(postalCode) &&
      (inputMode == OrderInputMode.prescription
          ? selectedImage != null
          : typedMedicines.isNotEmpty);
  PatientState copyWith({
    OrderInputMode? inputMode,
    XFile? selectedImage,
    List<MedicineItem>? typedMedicines,
    bool? isUploading,
    String? errorMessage,
    OrderModel? submittedOrder,
    String? address,
    String? postalCode,
    String? notes,
    String? pharmacyId,
    bool clearImage = false,
  }) => PatientState(
    inputMode: inputMode ?? this.inputMode,
    selectedImage: clearImage ? null : selectedImage ?? this.selectedImage,
    typedMedicines: typedMedicines ?? this.typedMedicines,
    isUploading: isUploading ?? this.isUploading,
    errorMessage: errorMessage,
    submittedOrder: submittedOrder ?? this.submittedOrder,
    address: address ?? this.address,
    postalCode: postalCode ?? this.postalCode,
    notes: notes ?? this.notes,
    pharmacyId: pharmacyId ?? this.pharmacyId,
  );
}

class PatientNotifier extends Notifier<PatientState> {
  String? _requestId;
  @override
  PatientState build() {
    ref.watch(authProvider.select((s) => s.user?.id));
    _requestId = null;
    return const PatientState();
  }

  void edit({
    String? address,
    String? postalCode,
    String? notes,
    String? pharmacyId,
  }) {
    if (state.isUploading) return;
    _requestId = null;
    state = state.copyWith(
      address: address,
      postalCode: postalCode,
      notes: notes,
      pharmacyId: pharmacyId,
    );
  }

  void setInputMode(OrderInputMode mode) {
    if (state.isUploading) return;
    _requestId = null;
    state = state.copyWith(inputMode: mode, clearImage: true);
  }

  void addMedicine(String name) {
    if (state.isUploading ||
        name.trim().isEmpty ||
        name.trim().length > 200 ||
        state.typedMedicines.length >= 50) {
      return;
    }
    if (state.typedMedicines.any(
      (m) => m.name.toLowerCase() == name.trim().toLowerCase(),
    )) {
      return;
    }
    _requestId = null;
    state = state.copyWith(
      typedMedicines: [
        ...state.typedMedicines,
        MedicineItem(id: const Uuid().v4(), name: name.trim()),
      ],
    );
  }

  void changeQuantity(String id, int quantity) {
    if (state.isUploading || quantity < 0 || quantity > 100) return;
    _requestId = null;
    state = state.copyWith(
      typedMedicines: [
        for (final item in state.typedMedicines)
          if (item.id != id)
            item
          else if (quantity > 0)
            MedicineItem(id: id, name: item.name, quantity: quantity),
      ],
    );
  }

  Future<void> pick(ImageSource source) async {
    if (state.isUploading) return;
    try {
      final image = await ImagePicker().pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (image != null && ref.mounted) {
        _requestId = null;
        state = state.copyWith(selectedImage: image);
      }
    } catch (_) {
      if (ref.mounted) {
        state = state.copyWith(
          errorMessage:
              'Could not open images. Check camera/photo permissions.',
        );
      }
    }
  }

  Future<void> submitOrder() async {
    if (!state.canSubmit) return;
    final actorId = ref.read(authProvider).user?.id;
    final input = state;
    final requestId = _requestId ??= const Uuid().v4();
    state = state.copyWith(isUploading: true);
    try {
      final repo = ref.read(orderRepositoryProvider);
      final path = input.inputMode == OrderInputMode.prescription
          ? await repo.uploadPrescription(input.selectedImage!, requestId)
          : null;
      if (!ref.mounted || ref.read(authProvider).user?.id != actorId) return;
      final order = await repo.createOrder(
        requestId: requestId,
        pharmacyId: input.pharmacyId!,
        address: input.address.trim(),
        postalCode: input.postalCode,
        notes: input.notes,
        prescriptionPath: path,
        items: input.inputMode == OrderInputMode.typed
            ? input.typedMedicines.map((m) => m.toMap()).toList()
            : [],
      );
      if (ref.mounted && ref.read(authProvider).user?.id == actorId) {
        state = state.copyWith(isUploading: false, submittedOrder: order);
      }
    } catch (_) {
      if (ref.mounted && ref.read(authProvider).user?.id == actorId) {
        state = state.copyWith(
          isUploading: false,
          errorMessage:
              'Order not confirmed. Check your connection and pharmacy service area, then retry. Check order history before starting a new request.',
        );
      }
    }
  }

  void resetAfterSubmit() {
    _requestId = null;
    state = const PatientState();
  }
}

final patientProvider = NotifierProvider<PatientNotifier, PatientState>(
  PatientNotifier.new,
);
final pharmaciesProvider = FutureProvider<List<Pharmacy>>(
  (ref) => ref.watch(orderRepositoryProvider).pharmacies(),
);

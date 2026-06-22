import 'package:image_picker/image_picker.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'patient_controller.g.dart';

@riverpod
class PatientUploadController extends _$PatientUploadController {
  @override
  XFile? build() {
    // The state is simply the selected image file (or null if none selected)
    return null;
  }

  /// Opens the camera or gallery to pick a prescription image
  Future<void> pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: source,
      imageQuality: 80, // Compress slightly for faster uploads
    );

    if (pickedFile != null) {
      state = pickedFile; // Update the UI with the selected image
    }
  }

  /// Clears the current selection
  void clearImage() {
    state = null;
  }

  /// Submits the prescription to the backend
  Future<bool> submitPrescription() async {
    if (state == null) return false;

    // TODO: Upload image to Firebase Storage and create a new PrescriptionOrder in Firestore.
    // For now, simulate a network delay.
    await Future.delayed(const Duration(seconds: 2));

    return true; // Indicates success
  }
}

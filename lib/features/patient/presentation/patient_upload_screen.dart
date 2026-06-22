import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'patient_controller.dart';

class PatientUploadScreen extends HookConsumerWidget {
  const PatientUploadScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the selected image state
    final selectedImage = ref.watch(patientUploadControllerProvider);
    final controller = ref.read(patientUploadControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        title: const Text('Upload Prescription'),
        backgroundColor: const Color(0xFF00897B),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Please upload a clear image of your doctor\'s prescription.',
                style: TextStyle(fontSize: 16, color: Colors.black87),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Image Preview Area
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    border: Border.all(color: Colors.grey[300]!, width: 2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child:
                      selectedImage == null
                          ? _buildEmptyPlaceholder(controller)
                          : _buildImagePreview(selectedImage, controller),
                ),
              ),
              const SizedBox(height: 24),

              // Submit Button
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00897B),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  // Disable button if no image is selected
                  disabledBackgroundColor: Colors.grey[300],
                ),
                onPressed:
                    selectedImage == null
                        ? null
                        : () async {
                          // Show loading indicator
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder:
                                (context) => const Center(
                                  child: CircularProgressIndicator(),
                                ),
                          );

                          final success = await controller.submitPrescription();

                          // Hide loading indicator
                          if (context.mounted) Navigator.pop(context);

                          if (success && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Prescription submitted for pharmacist review!',
                                ),
                              ),
                            );
                            context.go('/'); // Go back to home
                          }
                        },
                child: const Text(
                  'Submit Order',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyPlaceholder(PatientUploadController controller) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.document_scanner_outlined,
          size: 80,
          color: Colors.grey[400],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: () => controller.pickImage(ImageSource.camera),
              icon: const Icon(Icons.camera_alt),
              label: const Text('Camera'),
            ),
            const SizedBox(width: 16),
            OutlinedButton.icon(
              onPressed: () => controller.pickImage(ImageSource.gallery),
              icon: const Icon(Icons.photo_library),
              label: const Text('Gallery'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildImagePreview(XFile image, PatientUploadController controller) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child:
              kIsWeb
                  // Web uses NetworkImage for local paths
                  ? Image.network(image.path, fit: BoxFit.cover)
                  // Mobile/Desktop uses File
                  : Image.file(File(image.path), fit: BoxFit.cover),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: IconButton(
            icon: const Icon(Icons.cancel, color: Colors.red, size: 32),
            onPressed: controller.clearImage,
          ),
        ),
      ],
    );
  }
}

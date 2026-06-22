// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'patient_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(PatientUploadController)
final patientUploadControllerProvider = PatientUploadControllerProvider._();

final class PatientUploadControllerProvider
    extends $NotifierProvider<PatientUploadController, XFile?> {
  PatientUploadControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'patientUploadControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$patientUploadControllerHash();

  @$internal
  @override
  PatientUploadController create() => PatientUploadController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(XFile? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<XFile?>(value),
    );
  }
}

String _$patientUploadControllerHash() =>
    r'dfda8d095c304662536cc6c0accf127a35b97692';

abstract class _$PatientUploadController extends $Notifier<XFile?> {
  XFile? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<XFile?, XFile?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<XFile?, XFile?>,
              XFile?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pharmacist_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(PharmacistController)
final pharmacistControllerProvider = PharmacistControllerProvider._();

final class PharmacistControllerProvider
    extends
        $AsyncNotifierProvider<PharmacistController, List<PrescriptionOrder>> {
  PharmacistControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pharmacistControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pharmacistControllerHash();

  @$internal
  @override
  PharmacistController create() => PharmacistController();
}

String _$pharmacistControllerHash() =>
    r'16b3ac74bc939c985450c12a26996c4ad17d9db6';

abstract class _$PharmacistController
    extends $AsyncNotifier<List<PrescriptionOrder>> {
  FutureOr<List<PrescriptionOrder>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<List<PrescriptionOrder>>,
              List<PrescriptionOrder>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<PrescriptionOrder>>,
                List<PrescriptionOrder>
              >,
              AsyncValue<List<PrescriptionOrder>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

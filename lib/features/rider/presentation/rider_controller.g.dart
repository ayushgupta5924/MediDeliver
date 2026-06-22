// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rider_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(RiderController)
final riderControllerProvider = RiderControllerProvider._();

final class RiderControllerProvider
    extends $AsyncNotifierProvider<RiderController, List<DeliveryOrder>> {
  RiderControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'riderControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$riderControllerHash();

  @$internal
  @override
  RiderController create() => RiderController();
}

String _$riderControllerHash() => r'412bd1cfe61bcd5c5d4dece2959b9ea03837c750';

abstract class _$RiderController extends $AsyncNotifier<List<DeliveryOrder>> {
  FutureOr<List<DeliveryOrder>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<List<DeliveryOrder>>, List<DeliveryOrder>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<DeliveryOrder>>, List<DeliveryOrder>>,
              AsyncValue<List<DeliveryOrder>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

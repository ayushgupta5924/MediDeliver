import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:medideliver/core/router/app_router.dart';
import 'package:medideliver/core/services/auth_service.dart';
import 'package:medideliver/features/orders/presentation/orders_screen.dart';
import 'package:medideliver/features/patient/data/order_repository.dart';
import 'package:medideliver/features/patient/domain/order_model.dart';
import 'package:medideliver/features/patient/presentation/patient_controller.dart';

class MockRepository extends Mock implements OrderRepository {}

class CustomerAuth extends AuthNotifier {
  void switchUser(String id) {
    state = AuthState(
      user: AppUser(
        id: id,
        email: 'other@example.invalid',
        role: UserRole.customer,
      ),
    );
  }

  @override
  AuthState build() => const AuthState(
    user: AppUser(
      id: 'customer',
      email: 'demo@example.invalid',
      role: UserRole.customer,
    ),
  );
}

void main() {
  test('in-flight results cannot populate another customer account', () async {
    final repo = MockRepository();
    final auth = CustomerAuth();
    final response = Completer<OrderModel>();
    when(
      () => repo.createOrder(
        requestId: any(named: 'requestId'),
        pharmacyId: any(named: 'pharmacyId'),
        address: any(named: 'address'),
        postalCode: any(named: 'postalCode'),
        items: any(named: 'items'),
        prescriptionPath: any(named: 'prescriptionPath'),
        notes: any(named: 'notes'),
      ),
    ).thenAnswer((_) => response.future);
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(() => auth),
        orderRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(patientProvider.notifier);
    notifier.setInputMode(OrderInputMode.typed);
    notifier.edit(
      address: '123 Fictional Road',
      postalCode: '382010',
      pharmacyId: 'pharmacy',
    );
    notifier.addMedicine('Fictional item');
    final submission = notifier.submitOrder();
    auth.switchUser('another-customer');
    container.read(patientProvider);
    response.complete(
      const OrderModel(
        id: 'old-order',
        orderNumber: 'MD-OLD',
        status: 'submitted',
        pharmacyId: 'pharmacy',
        pharmacyName: '',
        deliveryAddress: '123 Fictional Road',
        postalCode: '382010',
        customerNotes: '',
        items: [],
      ),
    );
    await submission;
    expect(container.read(patientProvider).submittedOrder, isNull);
    expect(container.read(patientProvider).typedMedicines, isEmpty);
  });
  test('roles cannot navigate into another role dashboard', () {
    for (final role in UserRole.values) {
      final auth = AuthState(
        user: AppUser(id: 'id', email: '', role: role),
      );
      for (final path in ['/patient', '/pharmacist', '/rider', '/admin']) {
        expect(
          authRedirect(auth, path),
          path == homeForRole(role) ? null : homeForRole(role),
        );
      }
    }
    expect(authRedirect(const AuthState(), '/orders'), '/login');
    expect(
      authRedirect(const AuthState(isLoading: true), '/pharmacist'),
      '/loading',
    );
    expect(authRedirect(const AuthState(), '/otp'), '/login');
  });
  test('quote parsing uses integer paise and rejects malformed totals', () {
    expect(parseRupees('123.45'), 12345);
    expect(parseRupees('0.01'), 1);
    for (final invalid in ['0', '-1', '1.001', 'NaN', '1e5', '100000.01']) {
      expect(parseRupees(invalid), isNull);
    }
  });
  test(
    'submission sends structured items and retries the same request identifier',
    () async {
      final repo = MockRepository();
      final ids = <String>[];
      var attempts = 0;
      when(
        () => repo.createOrder(
          requestId: any(named: 'requestId'),
          pharmacyId: any(named: 'pharmacyId'),
          address: any(named: 'address'),
          postalCode: any(named: 'postalCode'),
          items: any(named: 'items'),
          prescriptionPath: any(named: 'prescriptionPath'),
          notes: any(named: 'notes'),
        ),
      ).thenAnswer((invocation) async {
        ids.add(invocation.namedArguments[#requestId] as String);
        expect(invocation.namedArguments[#items], [
          {'name': 'Sample medicine 10 mg', 'quantity': 2},
        ]);
        expect(invocation.namedArguments[#notes], 'Call at gate');
        if (attempts++ == 0) {
          throw TimeoutException('Response lost after commit');
        }
        return const OrderModel(
          id: 'order',
          orderNumber: 'MD-1',
          status: 'submitted',
          pharmacyId: 'pharmacy',
          pharmacyName: 'Demo',
          deliveryAddress: '123 Fictional Road',
          postalCode: '382010',
          customerNotes: '',
          items: [],
        );
      });
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(CustomerAuth.new),
          orderRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(patientProvider.notifier);
      notifier.setInputMode(OrderInputMode.typed);
      notifier.edit(
        address: '123 Fictional Road',
        postalCode: '382010',
        pharmacyId: 'pharmacy',
        notes: 'Call at gate',
      );
      notifier.addMedicine('Sample medicine 10 mg');
      notifier.changeQuantity(
        container.read(patientProvider).typedMedicines.single.id,
        2,
      );
      await notifier.submitOrder();
      expect(container.read(patientProvider).isUploading, isFalse);
      expect(container.read(patientProvider).errorMessage, isNotNull);
      await notifier.submitOrder();
      expect(ids[0], ids[1]);
      expect(container.read(patientProvider).submittedOrder?.id, 'order');
    },
  );
}

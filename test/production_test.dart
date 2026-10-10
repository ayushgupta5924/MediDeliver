import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:medideliver/core/constants/supabase_constants.dart';
import 'package:medideliver/core/services/auth_service.dart';
import 'package:medideliver/features/orders/presentation/orders_screen.dart';
import 'package:medideliver/features/patient/domain/order_model.dart';

void main() {
  test('release rejects insecure URLs and privileged client keys', () {
    const key = 'sb_publishable_test_key_for_configuration';
    expect(
      validClientConfig('https://example.supabase.co', key, release: true),
      isTrue,
    );
    for (final url in [
      'http://example.supabase.co',
      'http://127.0.0.1:54321',
      'https://user:password@example.supabase.co',
      'https://example.supabase.co/path',
    ]) {
      expect(validClientConfig(url, key, release: true), isFalse);
    }
    expect(
      validClientConfig('http://127.0.0.1:54321', key, release: false),
      isTrue,
    );
    final secret =
        'header.${base64Url.encode(utf8.encode(jsonEncode({'role': 'service_role'})))}.signature';
    expect(
      validClientConfig('https://example.supabase.co', secret, release: true),
      isFalse,
    );
    expect(
      validClientConfig(
        'https://example.supabase.co',
        'sb_secret_never_ship_this',
        release: true,
      ),
      isFalse,
    );
  });
  test('riders are told not to collect cash for prepaid deliveries', () {
    expect(
      orderActions(
        UserRole.deliveryPartner,
        'picked_up',
        paymentStatus: 'paid',
      )['deliver'],
      contains('Prepaid'),
    );
    expect(
      orderActions(
        UserRole.deliveryPartner,
        'picked_up',
        paymentStatus: 'cash_due',
      )['deliver'],
      contains('Cash collected'),
    );
    expect(
      orderActions(
        UserRole.customer,
        'quoted',
        paymentMethod: 'razorpay',
      ).containsKey('confirm'),
      isFalse,
    );
  });
  test('order projection tolerates redacted rider fields', () {
    final order = OrderModel.fromMap({
      'id': 'id',
      'order_number': 'MD-1',
      'status': 'ready',
      'pharmacy_id': 'pharmacy',
      'pickup_address': 'Test pickup',
    });
    expect(order.recipientPhone, isEmpty);
    expect(order.quoteItems, isEmpty);
    expect(order.items, isEmpty);
    expect(order.pickupAddress, 'Test pickup');
  });
}

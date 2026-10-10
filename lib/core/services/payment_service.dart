import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/supabase_constants.dart';
import 'supabase_provider.dart';
import 'timeout_client.dart';

final paymentServiceProvider = Provider((ref) => PaymentService(ref));

class PaymentService {
  final Ref ref;
  PaymentService(this.ref);
  Future<void> pay(String orderId) async {
    final token = ref.read(supabaseProvider).auth.currentSession?.accessToken;
    if (token == null || !SupabaseConstants.paymentsEnabled) {
      throw StateError('Online payment unavailable');
    }
    final client = TimeoutClient();
    try {
      final response = await client.post(
        Uri.parse('${SupabaseConstants.appUrl}/api/payments/create'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'order_id': orderId}),
      );
      if (response.statusCode != 200) {
        throw StateError('Checkout could not start');
      }
      final url = Uri.parse(
        (jsonDecode(response.body) as Map)['url'] as String,
      );
      if (url.origin != Uri.parse(SupabaseConstants.appUrl).origin ||
          url.path != '/checkout.html') {
        throw StateError('Invalid checkout URL');
      }
      if (!await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: '_self',
      )) {
        throw StateError('Could not open checkout');
      }
    } finally {
      client.close();
    }
  }
}

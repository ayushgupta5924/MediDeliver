import 'dart:convert';
import 'package:flutter/foundation.dart';

class SupabaseConstants {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const appUrl = String.fromEnvironment('APP_URL');
  static const paymentsEnabled = bool.fromEnvironment('PAYMENTS_ENABLED');
  static const upiMode = String.fromEnvironment(
    'UPI_MODE',
    defaultValue: 'disabled',
  );
  static const demoMode = bool.fromEnvironment('DEMO_MODE', defaultValue: true);
  static bool get isConfigured =>
      validClientConfig(supabaseUrl, supabaseAnonKey, release: kReleaseMode);
}

bool validClientConfig(String url, String key, {required bool release}) {
  final uri = Uri.tryParse(url);
  if (uri == null ||
      !uri.hasAuthority ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment ||
      (uri.path.isNotEmpty && uri.path != '/')) {
    return false;
  }
  if (uri.scheme != 'https' &&
      !(uri.scheme == 'http' &&
          !release &&
          ['localhost', '127.0.0.1', '10.0.2.2'].contains(uri.host))) {
    return false;
  }
  if (key.startsWith('sb_publishable_')) return key.length > 25;
  try {
    final parts = key.split('.');
    if (parts.length != 3) return false;
    final payload = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    );
    return payload is Map && payload['role'] == 'anon';
  } catch (_) {
    return false;
  }
}

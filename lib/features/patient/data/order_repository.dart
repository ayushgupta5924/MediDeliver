import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_provider.dart';
import '../domain/order_model.dart';

abstract class OrderRepository {
  Future<List<Pharmacy>> pharmacies();
  Future<String> uploadPrescription(XFile file, String requestId);
  Future<OrderModel> createOrder({
    required String requestId,
    required String pharmacyId,
    required String address,
    required String postalCode,
    required List<Map<String, dynamic>> items,
    String? prescriptionPath,
    String? notes,
  });
  Future<List<OrderModel>> orders({int offset = 0});
  Future<void> transition(
    String id,
    String action, {
    int? quotePaise,
    String? reason,
  });
  Future<String> prescriptionUrl(String path);
}

final orderRepositoryProvider = Provider<OrderRepository>(
  (ref) => SupabaseOrderRepository(ref.watch(supabaseProvider)),
);

class SupabaseOrderRepository implements OrderRepository {
  final SupabaseClient client;
  SupabaseOrderRepository(this.client);
  @override
  Future<List<Pharmacy>> pharmacies() async {
    final rows = await client
        .from('pharmacies')
        .select('id,name,postal_codes')
        .eq('active', true)
        .order('name')
        .limit(100);
    return rows.map(Pharmacy.fromMap).toList();
  }

  @override
  Future<String> uploadPrescription(XFile file, String requestId) async {
    final user = client.auth.currentUser;
    if (user == null) throw StateError('Please sign in again.');
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty || bytes.length > 5 * 1024 * 1024) {
      throw StateError('Prescription must be smaller than 5 MB.');
    }
    final jpeg =
        bytes.length >= 3 &&
        bytes[0] == 255 &&
        bytes[1] == 216 &&
        bytes[2] == 255;
    final png =
        bytes.length >= 8 &&
        bytes.take(8).join(',') == '137,80,78,71,13,10,26,10';
    if (!jpeg && !png) {
      throw StateError('Choose a JPEG or PNG prescription image.');
    }
    final path = '${user.id}/$requestId.${jpeg ? "jpg" : "png"}';
    try {
      await client.storage
          .from('prescriptions')
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              contentType: jpeg ? 'image/jpeg' : 'image/png',
              upsert: false,
            ),
          );
    } on StorageException catch (e) {
      // A retry can encounter an already completed upload. Never overwrite prescriptions.
      if (e.statusCode != '409' && e.error != 'Duplicate') rethrow;
    }
    return path;
  }

  @override
  Future<OrderModel> createOrder({
    required String requestId,
    required String pharmacyId,
    required String address,
    required String postalCode,
    required List<Map<String, dynamic>> items,
    String? prescriptionPath,
    String? notes,
  }) async {
    final data = await client.rpc(
      'create_order',
      params: {
        'p_request_id': requestId,
        'p_pharmacy_id': pharmacyId,
        'p_address': address,
        'p_postal_code': postalCode,
        'p_items': items,
        'p_prescription_path': prescriptionPath,
        'p_notes': notes ?? '',
      },
    );
    return OrderModel.fromMap(Map<String, dynamic>.from(data as Map));
  }

  @override
  Future<List<OrderModel>> orders({int offset = 0}) async {
    final data = await client.rpc('list_orders', params: {'p_offset': offset});
    return (data as List)
        .map((e) => OrderModel.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  @override
  Future<void> transition(
    String id,
    String action, {
    int? quotePaise,
    String? reason,
  }) async {
    await client.rpc(
      'transition_order',
      params: {
        'p_id': id,
        'p_action': action,
        'p_quote_paise': quotePaise,
        'p_reason': reason,
      },
    );
  }

  @override
  Future<String> prescriptionUrl(String path) =>
      client.storage.from('prescriptions').createSignedUrl(path, 60);
}

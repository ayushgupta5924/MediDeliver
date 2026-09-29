class OrderModel {
  final String id, orderNumber, status, pharmacyId, pharmacyName;
  final String deliveryAddress, postalCode, customerNotes;
  final String? prescriptionPath, rejectionReason, riderId;
  final List<Map<String, dynamic>> items;
  final int? quotePaise;
  final String paymentStatus;
  const OrderModel({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.pharmacyId,
    required this.pharmacyName,
    required this.deliveryAddress,
    required this.postalCode,
    required this.customerNotes,
    required this.items,
    this.prescriptionPath,
    this.rejectionReason,
    this.riderId,
    this.quotePaise,
    this.paymentStatus = 'unpaid',
  });
  factory OrderModel.fromMap(Map<String, dynamic> m) => OrderModel(
    id: m['id'] as String,
    orderNumber: m['order_number'] as String,
    status: m['status'] as String,
    pharmacyId: m['pharmacy_id'] as String,
    pharmacyName: m['pharmacy_name'] as String? ?? '',
    deliveryAddress: m['delivery_address'] as String? ?? '',
    postalCode: m['postal_code'] as String? ?? '',
    customerNotes: m['customer_notes'] as String? ?? '',
    items: (m['items'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList(),
    prescriptionPath: m['prescription_path'] as String?,
    rejectionReason: m['rejection_reason'] as String?,
    riderId: m['rider_id'] as String?,
    quotePaise: (m['quote_paise'] as num?)?.toInt(),
    paymentStatus: m['payment_status'] as String? ?? 'unpaid',
  );
}

class Pharmacy {
  final String id, name;
  final List<String> postalCodes;
  const Pharmacy(this.id, this.name, this.postalCodes);
  factory Pharmacy.fromMap(Map<String, dynamic> m) => Pharmacy(
    m['id'] as String,
    m['name'] as String,
    List<String>.from(m['postal_codes'] as List),
  );
}

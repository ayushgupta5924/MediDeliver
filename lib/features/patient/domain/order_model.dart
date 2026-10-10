class OrderModel {
  final String id, orderNumber, status, pharmacyId, pharmacyName;
  final String deliveryAddress, postalCode, customerNotes;
  final String? prescriptionPath, rejectionReason, riderId;
  final List<Map<String, dynamic>> items;
  final int? quotePaise;
  final String paymentStatus;
  final String? paymentMethod;
  final String recipientPhone, pickupAddress, pharmacyPhone;
  final List<Map<String, dynamic>> quoteItems;
  final int deliveryFeePaise;
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
    this.paymentMethod,
    this.recipientPhone = '',
    this.pickupAddress = '',
    this.pharmacyPhone = '',
    this.quoteItems = const [],
    this.deliveryFeePaise = 0,
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
    paymentMethod: m['payment_method'] as String?,
    recipientPhone: m['recipient_phone'] as String? ?? '',
    pickupAddress: m['pickup_address'] as String? ?? '',
    pharmacyPhone: m['pharmacy_phone'] as String? ?? '',
    quoteItems: (m['quote_items'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList(),
    deliveryFeePaise: (m['delivery_fee_paise'] as num?)?.toInt() ?? 0,
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

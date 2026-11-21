import 'package:cloud_firestore/cloud_firestore.dart';

/// Store configuration.
///
/// Firestore layout:
///  - settings/store          -> profile + support fields
///  - settings/service_config -> radius (km)
class StoreSettings {
  const StoreSettings({
    this.name = '',
    this.taxNumber = '',
    this.address = '',
    this.phone = '',
    this.openingHours = '',
    this.radius = defaultRadius,
    this.deliveryCharges = 0,
    this.serviceCharges = 0,
    this.freeDeliveryThreshold = 0,
    this.minimumOrder = 0,
    this.supportPhone = '',
    this.supportWhatsapp = '',
    this.supportEmail = '',
    this.supportHours = '',
    this.updatedAt,
  });

  static const double defaultRadius = 20;
  static const double minRadius = 1;
  static const double maxRadius = 100;

  // Store profile
  final String name;
  final String taxNumber;
  final String address;
  final String phone;
  final String openingHours;

  // Delivery area
  final double radius;

  // Charges & orders (collection: charges, single document)
  final double deliveryCharges;
  final double serviceCharges;

  /// Delivery is free when the order total reaches this amount (0 = off).
  final double freeDeliveryThreshold;

  /// Orders below this amount cannot be placed (0 = no minimum).
  final double minimumOrder;

  // Support info
  final String supportPhone;
  final String supportWhatsapp;
  final String supportEmail;
  final String supportHours;

  final DateTime? updatedAt;

  /// Builds the model from the two Firestore documents.
  /// Missing fields fall back to safe defaults.
  factory StoreSettings.fromMaps({
    Map<String, dynamic>? store,
    Map<String, dynamic>? service,
    Map<String, dynamic>? charges,
  }) {
    final c = charges ?? const <String, dynamic>{};
    final s = store ?? const <String, dynamic>{};
    final v = service ?? const <String, dynamic>{};
    return StoreSettings(
      name: _text(s['name']),
      taxNumber: _text(s['taxNumber']),
      address: _text(s['address']),
      phone: _text(s['phone']),
      openingHours: _text(s['openingHours']),
      supportPhone: _text(s['supportPhone']),
      supportWhatsapp: _text(s['supportWhatsapp']),
      supportEmail: _text(s['supportEmail']),
      supportHours: _text(s['supportHours']),
      radius: _radius(v['radius']),
      deliveryCharges: _money(c['deliveryCharges']),
      serviceCharges: _money(c['serviceCharges']),
      freeDeliveryThreshold: _money(c['freeDeliveryThreshold']),
      minimumOrder: _money(c['minimumOrder']),
      updatedAt: _date(s['updatedAt']),
    );
  }

  /// Fields written to settings/store from the Store profile tab.
  Map<String, dynamic> toProfileMap() => {
    'name': name.trim(),
    'taxNumber': taxNumber.trim(),
    'address': address.trim(),
    'phone': phone.trim(),
    'openingHours': openingHours.trim(),
    'updatedAt': FieldValue.serverTimestamp(),
  };

  /// Fields written to settings/store from the Support info tab.
  Map<String, dynamic> toSupportMap() => {
    'supportPhone': supportPhone.trim(),
    'supportWhatsapp': supportWhatsapp.trim(),
    'supportEmail': supportEmail.trim(),
    'supportHours': supportHours.trim(),
    'updatedAt': FieldValue.serverTimestamp(),
  };

  /// Fields written to settings/service_config from the Delivery area tab.
  Map<String, dynamic> toServiceMap() => {
    'radius': radius,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  /// Fields written to the charges document from the Charges & orders tab.
  Map<String, dynamic> toChargesMap() => {
    'deliveryCharges': deliveryCharges,
    'serviceCharges': serviceCharges,
    'freeDeliveryThreshold': freeDeliveryThreshold,
    'minimumOrder': minimumOrder,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  StoreSettings copyWith({
    String? name,
    String? taxNumber,
    String? address,
    String? phone,
    String? openingHours,
    double? radius,
    double? deliveryCharges,
    double? serviceCharges,
    double? freeDeliveryThreshold,
    double? minimumOrder,
    String? supportPhone,
    String? supportWhatsapp,
    String? supportEmail,
    String? supportHours,
  }) => StoreSettings(
    name: name ?? this.name,
    taxNumber: taxNumber ?? this.taxNumber,
    address: address ?? this.address,
    phone: phone ?? this.phone,
    openingHours: openingHours ?? this.openingHours,
    radius: radius ?? this.radius,
    deliveryCharges: deliveryCharges ?? this.deliveryCharges,
    serviceCharges: serviceCharges ?? this.serviceCharges,
    freeDeliveryThreshold: freeDeliveryThreshold ?? this.freeDeliveryThreshold,
    minimumOrder: minimumOrder ?? this.minimumOrder,
    supportPhone: supportPhone ?? this.supportPhone,
    supportWhatsapp: supportWhatsapp ?? this.supportWhatsapp,
    supportEmail: supportEmail ?? this.supportEmail,
    supportHours: supportHours ?? this.supportHours,
    updatedAt: updatedAt,
  );

  /// True when the value is a usable email (or empty, since it is optional).
  bool get hasValidSupportEmail =>
      supportEmail.trim().isEmpty ||
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(supportEmail.trim());

  bool get hasValidRadius => radius >= minRadius && radius <= maxRadius;

  @override
  bool operator ==(Object other) =>
      other is StoreSettings &&
      other.name == name &&
      other.taxNumber == taxNumber &&
      other.address == address &&
      other.phone == phone &&
      other.openingHours == openingHours &&
      other.radius == radius &&
      other.deliveryCharges == deliveryCharges &&
      other.serviceCharges == serviceCharges &&
      other.freeDeliveryThreshold == freeDeliveryThreshold &&
      other.minimumOrder == minimumOrder &&
      other.supportPhone == supportPhone &&
      other.supportWhatsapp == supportWhatsapp &&
      other.supportEmail == supportEmail &&
      other.supportHours == supportHours;

  @override
  int get hashCode => Object.hash(
    name,
    taxNumber,
    address,
    phone,
    openingHours,
    radius,
    deliveryCharges,
    serviceCharges,
    freeDeliveryThreshold,
    minimumOrder,
    supportPhone,
    supportWhatsapp,
    supportEmail,
    supportHours,
  );
}

double _money(dynamic value) {
  final number = value is num ? value.toDouble() : double.tryParse('$value');
  return number == null || number < 0 ? 0 : number;
}

String _text(dynamic value) => value == null ? '' : '$value'.trim();

double _radius(dynamic value) {
  final number = value is num ? value.toDouble() : double.tryParse('$value');
  if (number == null) return StoreSettings.defaultRadius;
  return number
      .clamp(StoreSettings.minRadius, StoreSettings.maxRadius)
      .toDouble();
}

DateTime? _date(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}

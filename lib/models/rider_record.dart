class RiderRecord {
  const RiderRecord({
    this.id,
    required this.name,
    this.phone = '',
    this.email = '',
    this.uid,
    this.status = 'available',
    this.active = true,
    this.cnic = '',
    this.address = '',
    this.vehicleType = 'Motorcycle',
    this.vehicleNumber = '',
    this.emergencyName = '',
    this.emergencyPhone = '',
    this.baseSalary = 0,
    this.perDeliveryBonus = 0,
    this.fuelAllowance = 0,
    this.advance = 0,
    this.joinedAt,
  });

  /// Firestore document id. For riders created from the panel this is the
  /// same value as [uid] (the Firebase Auth user id).
  final String? id;
  final String name;
  final String phone;

  /// Login email used in the rider app.
  final String email;
  final String? uid;

  /// available | on_delivery | off_duty
  final String status;

  /// When false the rider cannot use the rider app (checked by the app and
  /// by Firestore rules).
  final bool active;
  final String cnic;
  final String address;
  final String vehicleType;
  final String vehicleNumber;
  final String emergencyName;
  final String emergencyPhone;
  final double baseSalary;
  final double perDeliveryBonus;
  final double fuelAllowance;
  final double advance;
  final DateTime? joinedAt;

  factory RiderRecord.fromMap(Map<String, dynamic> data, {String? id}) =>
      RiderRecord(
        id: id,
        name: data['name'] as String? ?? '',
        phone: data['phone'] as String? ?? '',
        email: data['email'] as String? ?? '',
        uid: data['uid'] as String?,
        status: data['status'] as String? ?? 'available',
        active: data['active'] as bool? ?? true,
        cnic: data['cnic'] as String? ?? '',
        address: data['address'] as String? ?? '',
        vehicleType: data['vehicleType'] as String? ?? 'Motorcycle',
        vehicleNumber: data['vehicleNumber'] as String? ?? '',
        emergencyName: data['emergencyName'] as String? ?? '',
        emergencyPhone: data['emergencyPhone'] as String? ?? '',
        baseSalary: _double(data['baseSalary']),
        perDeliveryBonus: _double(data['perDeliveryBonus']),
        fuelAllowance: _double(data['fuelAllowance']),
        advance: _double(data['advance']),
        joinedAt: _date(data['joinedAt']),
      );

  Map<String, dynamic> toMap() => {
    'name': name,
    'phone': phone,
    'email': email,
    'uid': uid,
    'status': status,
    'active': active,
    'cnic': cnic,
    'address': address,
    'vehicleType': vehicleType,
    'vehicleNumber': vehicleNumber,
    'emergencyName': emergencyName,
    'emergencyPhone': emergencyPhone,
    'baseSalary': baseSalary,
    'perDeliveryBonus': perDeliveryBonus,
    'fuelAllowance': fuelAllowance,
    'advance': advance,
    'joinedAt': joinedAt,
  };

  RiderRecord copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    String? uid,
    String? status,
    bool? active,
    String? cnic,
    String? address,
    String? vehicleType,
    String? vehicleNumber,
    String? emergencyName,
    String? emergencyPhone,
    double? baseSalary,
    double? perDeliveryBonus,
    double? fuelAllowance,
    double? advance,
    DateTime? joinedAt,
  }) => RiderRecord(
    id: id ?? this.id,
    name: name ?? this.name,
    phone: phone ?? this.phone,
    email: email ?? this.email,
    uid: uid ?? this.uid,
    status: status ?? this.status,
    active: active ?? this.active,
    cnic: cnic ?? this.cnic,
    address: address ?? this.address,
    vehicleType: vehicleType ?? this.vehicleType,
    vehicleNumber: vehicleNumber ?? this.vehicleNumber,
    emergencyName: emergencyName ?? this.emergencyName,
    emergencyPhone: emergencyPhone ?? this.emergencyPhone,
    baseSalary: baseSalary ?? this.baseSalary,
    perDeliveryBonus: perDeliveryBonus ?? this.perDeliveryBonus,
    fuelAllowance: fuelAllowance ?? this.fuelAllowance,
    advance: advance ?? this.advance,
    joinedAt: joinedAt ?? this.joinedAt,
  );
}

double _double(dynamic value) => value is num ? value.toDouble() : 0;
DateTime? _date(dynamic value) {
  if (value is DateTime) return value;
  try {
    return value?.toDate() as DateTime?;
  } on NoSuchMethodError {
    return null;
  }
}
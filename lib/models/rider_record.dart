class RiderRecord {
  const RiderRecord({
    this.id,
    required this.name,
    this.phone = '',
    this.uid,
    this.status = 'available',
    this.baseSalary = 0,
    this.perDeliveryBonus = 0,
    this.fuelAllowance = 0,
    this.advance = 0,
    this.joinedAt,
  });

  final String? id;
  final String name;
  final String phone;
  final String? uid;
  final String status;
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
        uid: data['uid'] as String?,
        status: data['status'] as String? ?? 'available',
        baseSalary: _double(data['baseSalary']),
        perDeliveryBonus: _double(data['perDeliveryBonus']),
        fuelAllowance: _double(data['fuelAllowance']),
        advance: _double(data['advance']),
        joinedAt: _date(data['joinedAt']),
      );

  Map<String, dynamic> toMap() => {
    'name': name,
    'phone': phone,
    'uid': uid,
    'status': status,
    'baseSalary': baseSalary,
    'perDeliveryBonus': perDeliveryBonus,
    'fuelAllowance': fuelAllowance,
    'advance': advance,
    'joinedAt': joinedAt,
  };

  RiderRecord copyWith({
    String? name,
    String? phone,
    String? uid,
    String? status,
    double? baseSalary,
    double? perDeliveryBonus,
    double? fuelAllowance,
    double? advance,
    DateTime? joinedAt,
  }) => RiderRecord(
    id: id,
    name: name ?? this.name,
    phone: phone ?? this.phone,
    uid: uid ?? this.uid,
    status: status ?? this.status,
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

class RiderInviteRecord {
  const RiderInviteRecord({
    this.id,
    required this.name,
    required this.phone,
    this.baseSalary = 0,
    this.perDeliveryBonus = 0,
    this.status = 'pending',
    required this.code,
    this.sentAt,
  });

  final String? id;
  final String name;
  final String phone;
  final double baseSalary;
  final double perDeliveryBonus;
  final String status;
  final String code;
  final DateTime? sentAt;

  factory RiderInviteRecord.fromMap(Map<String, dynamic> data, {String? id}) =>
      RiderInviteRecord(
        id: id,
        name: data['name'] as String? ?? '',
        phone: data['phone'] as String? ?? '',
        baseSalary: _number(data['baseSalary']),
        perDeliveryBonus: _number(data['perDeliveryBonus']),
        status: data['status'] as String? ?? 'pending',
        code: data['code'] as String? ?? '',
        sentAt: _date(data['sentAt']),
      );

  Map<String, dynamic> toMap() => {
    'name': name,
    'phone': phone,
    'baseSalary': baseSalary,
    'perDeliveryBonus': perDeliveryBonus,
    'status': status,
    'code': code,
    'sentAt': sentAt,
  };

  RiderInviteRecord copyWith({
    String? name,
    String? phone,
    double? baseSalary,
    double? perDeliveryBonus,
    String? status,
    String? code,
    DateTime? sentAt,
  }) => RiderInviteRecord(
    id: id,
    name: name ?? this.name,
    phone: phone ?? this.phone,
    baseSalary: baseSalary ?? this.baseSalary,
    perDeliveryBonus: perDeliveryBonus ?? this.perDeliveryBonus,
    status: status ?? this.status,
    code: code ?? this.code,
    sentAt: sentAt ?? this.sentAt,
  );
}

double _number(dynamic value) => value is num ? value.toDouble() : 0;
DateTime? _date(dynamic value) {
  if (value is DateTime) return value;
  try {
    return value?.toDate() as DateTime?;
  } on NoSuchMethodError {
    return null;
  }
}

class OfferRecord {
  const OfferRecord({
    this.id,
    required this.name,
    this.type = 'pct',
    this.value = 0,
    this.productIds = const [],
    this.audience = 'both',
    this.endsAt,
    this.pinned = false,
    this.live = false,
    this.imageUrl,
  });

  final String? id;
  final String name;
  final String type;
  final double value;
  final List<String> productIds;
  final String audience;
  final DateTime? endsAt;
  final bool pinned;
  final bool live;
  final String? imageUrl;

  factory OfferRecord.fromMap(Map<String, dynamic> data, {String? id}) =>
      OfferRecord(
        id: id,
        name: data['name'] as String? ?? '',
        type: data['type'] as String? ?? 'pct',
        value: (data['value'] as num?)?.toDouble() ?? 0,
        productIds: (data['productIds'] as List? ?? const [])
            .map((e) => e.toString())
            .toList(),
        audience: data['audience'] as String? ?? 'both',
        endsAt: _asDate(data['endsAt']),
        pinned: data['pinned'] as bool? ?? false,
        live: data['live'] as bool? ?? false,
        imageUrl: data['imageUrl'] as String?,
      );

  Map<String, dynamic> toMap() => {
    'name': name,
    'type': type,
    'value': value,
    'productIds': productIds,
    'audience': audience,
    'endsAt': endsAt,
    'pinned': pinned,
    'live': live,
    'imageUrl': imageUrl,
  };

  OfferRecord copyWith({
    String? name,
    String? type,
    double? value,
    List<String>? productIds,
    String? audience,
    DateTime? endsAt,
    bool? pinned,
    bool? live,
    String? imageUrl,
  }) => OfferRecord(
    id: id,
    name: name ?? this.name,
    type: type ?? this.type,
    value: value ?? this.value,
    productIds: productIds ?? this.productIds,
    audience: audience ?? this.audience,
    endsAt: endsAt ?? this.endsAt,
    pinned: pinned ?? this.pinned,
    live: live ?? this.live,
    imageUrl: imageUrl ?? this.imageUrl,
  );
}

DateTime? _asDate(dynamic value) {
  if (value is DateTime) return value;
  try {
    return value?.toDate() as DateTime?;
  } on NoSuchMethodError {
    return null;
  }
}

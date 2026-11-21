class Product {
  Product({
    this.id,
    required this.name,
    this.category = '',
    String? categoryId,
    this.subcategory = '',
    double? price,
    double? homePrice,
    double? shopPrice,
    this.mrp = 0,
    double? cost,
    double? rating,
    double? ratingAvg,
    this.ratingCount = 0,
    this.description = '',
    bool? isFeatured,
    bool? featured,
    bool? isHide,
    bool? active,
    this.showForHomeUsers = true,
    this.showForShopOwners = true,
    this.isOutOfStock = false,
    String? imageUrl,
    List<String> images = const [],
    this.videoUrl,
    Map<String, double> bulkPricing = const {},
    List<Map<String, dynamic>> tiers = const [],
    int? totalQuantity,
    int? stock,
    this.reorderLevel = 0,
    this.sku = '',
    bool? bulkEnabled,
    DateTime? createdAt,
  }) : categoryId = categoryId ?? category,
       price = price ?? homePrice ?? 0,
       homePrice = homePrice ?? price ?? 0,
       shopPrice = shopPrice ?? homePrice ?? price ?? 0,
       cost = cost ?? 0,
       rating = rating ?? ratingAvg ?? 0,
       ratingAvg = ratingAvg ?? rating ?? 0,
       isFeatured = featured ?? isFeatured ?? false,
       featured = featured ?? isFeatured ?? false,
       active = active ?? !(isHide ?? false),
       isHide = isHide ?? !(active ?? true),
       imageUrl = imageUrl ?? (images.isEmpty ? null : images.first),
       images = List.unmodifiable(
         images.isEmpty && imageUrl != null ? [imageUrl] : images,
       ),
       bulkPricing = _resolveBulkPricing(bulkPricing, tiers),
       tiers = List.unmodifiable(_resolveTiers(tiers, bulkPricing)),
       totalQuantity = totalQuantity ?? stock ?? 0,
       stock = stock ?? totalQuantity ?? 0,
       bulkEnabled =
           bulkEnabled ?? (bulkPricing.isNotEmpty || tiers.isNotEmpty),
       createdAt = createdAt ?? DateTime.now();

  final String? id;
  final String name;
  final String category;
  final String categoryId;
  final String subcategory;
  final String sku;
  final String description;
  final double price;
  final double homePrice;
  final double shopPrice;
  final double mrp;
  final double cost;
  final double rating;
  final double ratingAvg;
  final int ratingCount;
  final bool isFeatured;
  final bool featured;
  final bool isHide;
  final bool active;
  final bool showForHomeUsers;
  final bool showForShopOwners;
  final bool isOutOfStock;
  final String? imageUrl;
  final List<String> images;
  final String? videoUrl;
  final Map<String, double> bulkPricing;
  final List<Map<String, dynamic>> tiers;
  final int totalQuantity;
  final int stock;
  final int reorderLevel;
  final bool bulkEnabled;
  final DateTime createdAt;

  factory Product.fromMap(Map<String, dynamic> data, {String? id}) {
    final oldPrice = _number(data['price']);
    final oldImage = data['imageUrl'] as String?;
    final images = data['images'] is List
        ? (data['images'] as List)
              .whereType<String>()
              .where((value) => value.isNotEmpty)
              .toList()
        : <String>[];
    if (images.isEmpty && oldImage?.isNotEmpty == true) {
      images.add(oldImage!);
    }
    final tiers = _parseTiers(data['tiers'] ?? data['bulkPricing']);
    return Product(
      id: id,
      name: data['name'] as String? ?? '',
      category: (data['categoryName'] ?? data['category'] ?? '').toString(),
      categoryId: (data['categoryId'] ?? data['category'] ?? '').toString(),
      subcategory: (data['subcategory'] ?? '').toString(),
      sku: (data['sku'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
      price: _number(data['price'], fallback: oldPrice),
      homePrice: _number(data['homePrice'], fallback: oldPrice),
      shopPrice: _number(
        data['shopPrice'],
        fallback: _number(data['homePrice'], fallback: oldPrice),
      ),
      mrp: _number(data['mrp']),
      cost: _number(data['cost']),
      rating: _number(data['rating']),
      ratingAvg: _number(data['ratingAvg'], fallback: _number(data['rating'])),
      ratingCount: _integer(data['ratingCount']),
      isFeatured: data['isFeatured'] as bool? ?? false,
      featured:
          data['featured'] as bool? ?? data['isFeatured'] as bool? ?? false,
      isHide: data['isHide'] as bool? ?? false,
      active: data['active'] as bool? ?? !(data['isHide'] as bool? ?? false),
      showForHomeUsers: data['showForHomeUsers'] as bool? ?? true,
      showForShopOwners: data['showForShopOwners'] as bool? ?? true,
      isOutOfStock: data['isOutOfStock'] as bool? ?? false,
      imageUrl: oldImage,
      images: images,
      videoUrl: data['videoUrl'] as String?,
      bulkPricing: _parseBulkPricing(data['bulkPricing']),
      tiers: tiers,
      totalQuantity: _integer(data['totalQuantity']),
      stock: _integer(data['stock'], fallback: _integer(data['totalQuantity'])),
      reorderLevel: _integer(data['reorderLevel']),
      bulkEnabled:
          data['bulkEnabled'] as bool? ??
          (data['bulkPricing'] is Map || tiers.isNotEmpty),
      createdAt: _asDate(data['createdAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'category': category,
    'categoryName': category,
    'categoryId': categoryId,
    'subcategory': subcategory,
    'sku': sku,
    'description': description,
    'price': homePrice,
    'homePrice': homePrice,
    'shopPrice': shopPrice,
    'mrp': mrp,
    'cost': cost,
    'rating': ratingAvg,
    'ratingAvg': ratingAvg,
    'ratingCount': ratingCount,
    'isFeatured': featured,
    'featured': featured,
    'isHide': !active,
    'active': active,
    'showForHomeUsers': showForHomeUsers,
    'showForShopOwners': showForShopOwners,
    'isOutOfStock': isOutOfStock,
    'imageUrl': images.isEmpty ? imageUrl : images.first,
    'images': images,
    'videoUrl': videoUrl,
    'bulkPricing': bulkPricing,
    'bulkEnabled': bulkEnabled,
    'tiers': tiers,
    'totalQuantity': stock,
    'stock': stock,
    'reorderLevel': reorderLevel,
    'createdAt': createdAt,
  };

  bool get inStock => stock > 0 && !isOutOfStock;
  int get availableQuantity => inStock ? stock : 0;
  double get inventoryCost => cost > 0 ? cost : price;
  bool isAvailableForCustomerType(String customerType) =>
      customerType.toLowerCase() == 'shop'
      ? showForShopOwners
      : showForHomeUsers;

  double? getBulkPriceForQuantity(int quantity) {
    final eligible =
        tiers.where((tier) {
            final threshold = _integer(tier['qty']);
            return threshold > 0 && quantity >= threshold;
          }).toList()
          ..sort((a, b) => _integer(b['qty']).compareTo(_integer(a['qty'])));
    if (eligible.isNotEmpty) {
      return _number(eligible.first['homePrice']);
    }
    final thresholds =
        bulkPricing.keys
            .map((key) => int.tryParse(key) ?? 0)
            .where((threshold) => threshold > 0 && threshold <= quantity)
            .toList()
          ..sort((a, b) => b.compareTo(a));
    return thresholds.isEmpty ? null : bulkPricing['${thresholds.first}'];
  }

  Product copyWith({
    String? name,
    String? category,
    String? categoryId,
    String? subcategory,
    String? sku,
    String? description,
    double? price,
    double? homePrice,
    double? shopPrice,
    double? mrp,
    double? cost,
    double? rating,
    double? ratingAvg,
    int? ratingCount,
    bool? isFeatured,
    bool? featured,
    bool? isHide,
    bool? active,
    bool? showForHomeUsers,
    bool? showForShopOwners,
    bool? isOutOfStock,
    String? imageUrl,
    List<String>? images,
    String? videoUrl,
    Map<String, double>? bulkPricing,
    List<Map<String, dynamic>>? tiers,
    int? totalQuantity,
    int? stock,
    int? reorderLevel,
    bool? bulkEnabled,
  }) => Product(
    id: id,
    name: name ?? this.name,
    category: category ?? this.category,
    categoryId: categoryId ?? this.categoryId,
    subcategory: subcategory ?? this.subcategory,
    sku: sku ?? this.sku,
    description: description ?? this.description,
    price: price ?? this.price,
    homePrice: homePrice ?? this.homePrice,
    shopPrice: shopPrice ?? this.shopPrice,
    mrp: mrp ?? this.mrp,
    cost: cost ?? this.cost,
    rating: rating ?? this.rating,
    ratingAvg: ratingAvg ?? this.ratingAvg,
    ratingCount: ratingCount ?? this.ratingCount,
    isFeatured: isFeatured ?? this.isFeatured,
    featured: featured ?? this.featured,
    isHide: isHide ?? this.isHide,
    active: active ?? this.active,
    showForHomeUsers: showForHomeUsers ?? this.showForHomeUsers,
    showForShopOwners: showForShopOwners ?? this.showForShopOwners,
    isOutOfStock: isOutOfStock ?? this.isOutOfStock,
    imageUrl: imageUrl ?? this.imageUrl,
    images: images ?? this.images,
    videoUrl: videoUrl ?? this.videoUrl,
    bulkPricing: bulkPricing ?? this.bulkPricing,
    tiers: tiers ?? this.tiers,
    totalQuantity: totalQuantity ?? this.totalQuantity,
    stock: stock ?? this.stock,
    reorderLevel: reorderLevel ?? this.reorderLevel,
    bulkEnabled: bulkEnabled ?? this.bulkEnabled,
    createdAt: createdAt,
  );
}

typedef ProductRecord = Product;

double _number(dynamic value, {double fallback = 0}) =>
    value is num ? value.toDouble() : fallback;

int _integer(dynamic value, {int fallback = 0}) =>
    value is num ? value.toInt() : fallback;

DateTime? _asDate(dynamic value) {
  if (value is DateTime) return value;
  try {
    return value?.toDate() as DateTime?;
  } on NoSuchMethodError {
    return null;
  }
}

Map<String, double> _parseBulkPricing(dynamic value) {
  if (value is! Map) return const {};
  return {
    for (final entry in value.entries)
      entry.key.toString(): _number(entry.value),
  };
}

List<Map<String, dynamic>> _parseTiers(dynamic value) {
  if (value is List) {
    return value.whereType<Map>().map((entry) {
        final tier = Map<String, dynamic>.from(entry);
        return {
          'qty': _integer(tier['qty']),
          'homePrice': _number(
            tier['homePrice'],
            fallback: _number(tier['price'], fallback: _number(tier['p'])),
          ),
          'shopPrice': _number(
            tier['shopPrice'],
            fallback: _number(
              tier['s'],
              fallback: _number(tier['price'], fallback: _number(tier['p'])),
            ),
          ),
        };
      }).toList()
      ..sort((a, b) => _integer(a['qty']).compareTo(_integer(b['qty'])));
  }
  if (value is Map) {
    return value.entries
        .map(
          (entry) => {
            'qty': int.tryParse(entry.key.toString()) ?? 0,
            'homePrice': _number(entry.value),
            'shopPrice': _number(entry.value),
          },
        )
        .where((tier) => _integer(tier['qty']) > 0)
        .toList()
      ..sort((a, b) => _integer(a['qty']).compareTo(_integer(b['qty'])));
  }
  return const [];
}

Map<String, double> _resolveBulkPricing(
  Map<String, double> bulkPricing,
  List<Map<String, dynamic>> tiers,
) {
  if (bulkPricing.isNotEmpty) return Map.unmodifiable(bulkPricing);
  return Map.unmodifiable({
    for (final tier in tiers)
      if (_integer(tier['qty']) > 0)
        '${_integer(tier['qty'])}': _number(tier['homePrice']),
  });
}

List<Map<String, dynamic>> _resolveTiers(
  List<Map<String, dynamic>> tiers,
  Map<String, double> bulkPricing,
) {
  if (tiers.isNotEmpty) return tiers;
  return _parseTiers(bulkPricing);
}

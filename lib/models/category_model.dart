class Category {
  const Category({
    this.id,
    required this.name,
    this.imageUrl,
    this.subcategories = const [],
    this.isVisible = true,
    this.sortOrder = 0,
  });

  final String? id;
  final String name;
  final String? imageUrl;
  final List<String> subcategories;
  final bool isVisible;
  final int sortOrder;

  factory Category.fromMap(Map<String, dynamic> map, {String? id}) => Category(
    id: id ?? map['id'] as String?,
    name: map['name'] as String? ?? '',
    imageUrl: (map['imageUrl'] ?? map['image']) as String?,
    subcategories: (map['subcategories'] as List? ?? const [])
        .map((value) => value.toString())
        .toList(),
    isVisible: map['isVisible'] as bool? ?? true,
    sortOrder: (map['sortOrder'] as num?)?.toInt() ?? 0,
  );

  Map<String, dynamic> toMap() => {
    'name': name,
    'imageUrl': imageUrl,
    'subcategories': subcategories,
    'isVisible': isVisible,
    'sortOrder': sortOrder,
  };

  Category copyWith({
    String? name,
    String? imageUrl,
    List<String>? subcategories,
    bool? isVisible,
    String? color,
    int? sortOrder,
  }) => Category(
    id: id,
    name: name ?? this.name,
    imageUrl: imageUrl ?? this.imageUrl,
    subcategories: subcategories ?? this.subcategories,
    isVisible: isVisible ?? this.isVisible,
    sortOrder: sortOrder ?? this.sortOrder,
  );
}

typedef CategoryRecord = Category;

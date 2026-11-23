import 'package:cloud_firestore/cloud_firestore.dart';

class OrderModel {
  OrderModel({
    String? orderId,
    String? number,
    this.id = '',
    String? userId,
    String? customerId,
    this.userName = '',
    this.userPhone = '',
    this.items = const [],
    this.subtotal = 0,
    double? deliveryFee,
    double? delivery,
    this.serviceFee = 0,
    this.tax = 0,
    this.total = 0,
    this.deliveryAddress = '',
    GeoPoint? location,
    DateTime? orderDate,
    DateTime? createdAt,
    this.status = 'Pending',
    this.paymentMethod = '',
    this.paymentStatus = 'unpaid',
    this.notes,
    this.isFirstOrder = false,
    this.billImageUrl,
    this.riderId,
    this.customerType = 'home',
    this.channel = 'online',
    this.discount = 0,
    this.statusReason,
  }) : orderId = orderId ?? number,
       userId = customerId ?? userId ?? '',
       deliveryFee = deliveryFee ?? delivery ?? 0,
       location = location ?? const GeoPoint(0, 0),
       orderDate = createdAt ?? orderDate ?? DateTime.now();

  final String id;
  String? orderId;
  final String userId;
  final String userName;
  final String userPhone;
  final List<OrderItem> items;
  final double subtotal;
  final double deliveryFee;
  final double serviceFee;
  final double tax;
  final double total;
  final String deliveryAddress;
  final GeoPoint location;
  final DateTime orderDate;
  final String status;
  final String paymentMethod;
  final String paymentStatus;
  final String? notes;
  final bool isFirstOrder;
  String? billImageUrl;
  final String? riderId;
  final String customerType;
  final String channel;
  final double discount;

  /// Why the order was cancelled or returned.
  final String? statusReason;

  String get number => orderId ?? id;
  String get customerId => userId;
  DateTime? get createdAt => orderDate;
  double get delivery => deliveryFee;

  factory OrderModel.fromMap(Map<String, dynamic> data, [String? legacyId]) {
    final rawItems = data['items'] as List? ?? const [];
    final id = legacyId ?? (data['id'] ?? data['orderId'] ?? '').toString();
    return OrderModel(
      id: id,
      orderId: (data['orderId'] ?? data['number'] ?? id).toString(),
      userId: (data['userId'] ?? data['customerId'] ?? '').toString(),
      userName: (data['userName'] ?? data['customerName'] ?? '').toString(),
      userPhone: (data['userPhone'] ?? data['customerPhone'] ?? '').toString(),
      items: rawItems.whereType<Map>().map((item) {
        return OrderItem.fromMap(Map<String, dynamic>.from(item));
      }).toList(),
      subtotal: _number(data['subtotal']),
      deliveryFee: _number(
        data['deliveryFee'],
        fallback: _number(data['delivery']),
      ),
      serviceFee: _number(data['serviceFee']),
      tax: _number(data['tax']),
      total: _number(data['total']),
      deliveryAddress: (data['deliveryAddress'] ?? '').toString(),
      location: data['location'] is GeoPoint
          ? data['location'] as GeoPoint
          : const GeoPoint(0, 0),
      orderDate:
          _date(data['orderDate'] ?? data['createdAt']) ?? DateTime.now(),
      status: _normalizeOrderStatus(data['status']),
      paymentMethod: (data['paymentMethod'] ?? '').toString(),
      paymentStatus: (data['paymentStatus'] ?? 'unpaid').toString(),
      notes: data['notes'] as String?,
      isFirstOrder: data['isFirstOrder'] as bool? ?? false,
      billImageUrl: data['billImageUrl'] as String?,
      riderId: data['riderId'] as String?,
      customerType: (data['customerType'] ?? 'home').toString(),
      channel: (data['channel'] ?? 'online').toString(),
      discount: _number(data['discount']),
      statusReason: data['statusReason'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'orderId': number,
    'number': number,
    'userId': userId,
    'customerId': userId,
    'userName': userName,
    'userPhone': userPhone,
    'items': items.map((item) => item.toMap()).toList(),
    'subtotal': subtotal,
    'deliveryFee': deliveryFee,
    'delivery': deliveryFee,
    'serviceFee': serviceFee,
    'tax': tax,
    'total': total,
    'discount': discount,
    'deliveryAddress': deliveryAddress,
    'location': location,
    'orderDate': orderDate,
    'createdAt': orderDate,
    'status': status,
    'paymentMethod': paymentMethod,
    'paymentStatus': paymentStatus,
    'notes': notes,
    'isFirstOrder': isFirstOrder,
    'billImageUrl': billImageUrl,
    'riderId': riderId,
    'customerType': customerType,
    'channel': channel,
    'statusReason': statusReason,
  };

  OrderModel copyWith({
    String? status,
    String? paymentStatus,
    String? riderId,
    double? subtotal,
    double? deliveryFee,
    double? discount,
    double? total,
    List<OrderItem>? items,
    String? notes,
    String? statusReason,
  }) => OrderModel(
    id: id,
    orderId: orderId,
    userId: userId,
    userName: userName,
    userPhone: userPhone,
    items: items ?? this.items,
    subtotal: subtotal ?? this.subtotal,
    deliveryFee: deliveryFee ?? this.deliveryFee,
    serviceFee: serviceFee,
    tax: tax,
    total: total ?? this.total,
    deliveryAddress: deliveryAddress,
    location: location,
    orderDate: orderDate,
    status: status ?? this.status,
    paymentMethod: paymentMethod,
    paymentStatus: paymentStatus ?? this.paymentStatus,
    notes: notes ?? this.notes,
    isFirstOrder: isFirstOrder,
    billImageUrl: billImageUrl,
    riderId: riderId ?? this.riderId,
    customerType: customerType,
    channel: channel,
    discount: discount ?? this.discount,
    statusReason: statusReason ?? this.statusReason,
  );
}

class OrderItem {
  const OrderItem({
    required this.productId,
    String? productName,
    String? name,
    double? price,
    double? unitPrice,
    int? quantity,
    int? qty,
    this.imageUrl,
    this.costAtSale = 0,
  }) : productName = productName ?? name ?? '',
       price = price ?? unitPrice ?? 0,
       quantity = quantity ?? qty ?? 0;

  final String productId;
  final String productName;
  final double price;
  final int quantity;
  final String? imageUrl;
  final double costAtSale;

  String get name => productName;
  double get unitPrice => price;
  int get qty => quantity;

  factory OrderItem.fromMap(Map<String, dynamic> data) => OrderItem(
    productId: (data['productId'] ?? '').toString(),
    productName: (data['productName'] ?? data['name'] ?? '').toString(),
    price: _number(data['price'], fallback: _number(data['unitPrice'])),
    quantity: _integer(data['quantity'], fallback: _integer(data['qty'])),
    imageUrl: data['imageUrl'] as String?,
    costAtSale: _number(data['costAtSale']),
  );

  Map<String, dynamic> toMap() => {
    'productId': productId,
    'productName': productName,
    'name': productName,
    'price': price,
    'unitPrice': price,
    'quantity': quantity,
    'qty': quantity,
    'imageUrl': imageUrl,
    'costAtSale': costAtSale,
  };

  OrderItem copyWith({
    String? productId,
    String? productName,
    double? price,
    int? quantity,
    String? imageUrl,
    double? costAtSale,
  }) => OrderItem(
    productId: productId ?? this.productId,
    productName: productName ?? this.productName,
    price: price ?? this.price,
    quantity: quantity ?? this.quantity,
    imageUrl: imageUrl ?? this.imageUrl,
    costAtSale: costAtSale ?? this.costAtSale,
  );
}

typedef OrderRecord = OrderModel;
typedef OrderLineRecord = OrderItem;

double _number(dynamic value, {double fallback = 0}) =>
    value is num ? value.toDouble() : fallback;

int _integer(dynamic value, {int fallback = 0}) =>
    value is num ? value.toInt() : fallback;

String _normalizeOrderStatus(dynamic value) {
  final status = (value ?? 'Pending').toString().trim();
  if (status.toLowerCase() == 'rejected') return 'Cancelled';
  return status.isEmpty ? 'Pending' : status;
}

DateTime? _date(dynamic value) {
  if (value is DateTime) return value;
  try {
    return value?.toDate() as DateTime?;
  } on NoSuchMethodError {
    return null;
  }
}

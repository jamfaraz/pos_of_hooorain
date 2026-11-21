import 'package:cloud_firestore/cloud_firestore.dart';

const kExpenseCategories = <String>[
  'Rent',
  'Salaries',
  'Riders & fuel',
  'Electricity & utilities',
  'Packaging',
  'Other',
];

const kPaymentMethods = <String>[
  'Cash',
  'Bank transfer',
  'Easypaisa',
  'JazzCash',
];

/// Usual monthly spend, used until the admin saves their own budgets.
const kDefaultExpenseBudgets = <String, double>{
  'Rent': 120000,
  'Salaries': 180000,
  'Riders & fuel': 52000,
  'Electricity & utilities': 34000,
  'Packaging': 17000,
  'Other': 17000,
};

class ExpenseRecord {
  const ExpenseRecord({
    this.id,
    required this.category,
    this.note = '',
    required this.amount,
    this.paidBy = 'Cash',
    required this.createdAt,
    this.source = '',
  });

  final String? id;
  final String category;
  final String note;
  final double amount;
  final String paidBy;
  final DateTime createdAt;

  /// '' for manual entries. 'rider_salary' for rows created when a rider's
  /// salary is marked paid.
  final String source;

  /// Rows created by the system (rider salary payments). They are managed from
  /// the Riders screen and are read-only here, so profit reports stay correct.
  bool get isAuto =>
      source == 'rider_salary' ||
      (category == 'Salaries' &&
          paidBy == 'Admin' &&
          note.startsWith('Salary payment for'));

  /// Accepts both new and old field names so existing documents keep working.
  factory ExpenseRecord.fromMap(Map<String, dynamic> map, {String? id}) {
    DateTime date(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
      if (v is num) return DateTime.fromMillisecondsSinceEpoch(v.toInt());
      return DateTime.now();
    }

    double number(dynamic v) =>
        v is num ? v.toDouble() : double.tryParse('$v') ?? 0;

    return ExpenseRecord(
      id: id,
      category: '${map['category'] ?? map['type'] ?? 'Other'}',
      note: '${map['note'] ?? map['title'] ?? map['description'] ?? ''}',
      amount: number(map['amount'] ?? map['a']),
      paidBy: '${map['paidBy'] ?? map['method'] ?? map['by'] ?? 'Cash'}',
      createdAt: date(map['createdAt'] ?? map['date'] ?? map['d']),
      source: '${map['source'] ?? ''}',
    );
  }

  Map<String, dynamic> toMap() => {
    'category': category,
    'note': note,
    'amount': amount,
    'paidBy': paidBy,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': FieldValue.serverTimestamp(),
    if (source.isNotEmpty) 'source': source,
  };

  ExpenseRecord copyWith({
    String? category,
    String? note,
    double? amount,
    String? paidBy,
    DateTime? createdAt,
    String? source,
  }) => ExpenseRecord(
    id: id,
    category: category ?? this.category,
    note: note ?? this.note,
    amount: amount ?? this.amount,
    paidBy: paidBy ?? this.paidBy,
    createdAt: createdAt ?? this.createdAt,
    source: source ?? this.source,
  );
}

class TransactionModel {
  final int id;
  final int userId;
  final String type; // SALE, PURCHASE, EXPENSE
  final double amount;
  final String? description;
  final int? productId;
  final double? quantity;
  final int? clientId;
  final DateTime? createdAt;

  TransactionModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.amount,
    this.description,
    this.productId,
    this.quantity,
    this.clientId,
    this.createdAt,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      type: json['type'] as String,
      amount: (json['amount'] as num).toDouble(),
      description: json['description'] as String?,
      productId: json['product_id'] as int?,
      quantity: (json['quantity'] as num?)?.toDouble(),
      clientId: json['client_id'] as int?,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
    );
  }
}

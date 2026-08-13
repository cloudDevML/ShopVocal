class AiActionModel {
  final String type; // SALE, PURCHASE, EXPENSE
  final double amount;
  final String description;
  final int? productId;
  final String? productName;
  final double? quantity;
  final int? clientId;
  final String? clientName;

  AiActionModel({
    required this.type,
    required this.amount,
    required this.description,
    this.productId,
    this.productName,
    this.quantity,
    this.clientId,
    this.clientName,
  });

  factory AiActionModel.fromJson(Map<String, dynamic> json) {
    return AiActionModel(
      type: json['type'] ?? 'SALE',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      description: json['description'] ?? '',
      productId: json['product_id'],
      productName: json['_guessed_product_name'] ?? json['product_name'],
      quantity: (json['quantity'] as num?)?.toDouble(),
      clientId: json['client_id'],
      clientName: json['_guessed_client_name'] ?? json['client_name'],
    );
  }
}

class ProductModel {
  final int id;
  final int userId;
  final String name;
  final double quantity;
  final double unitPrice;
  final double costPrice;
  final double minStockAlert;

  ProductModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.costPrice,
    required this.minStockAlert,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'],
      userId: json['user_id'],
      name: json['name'],
      quantity: (json['quantity'] as num).toDouble(),
      unitPrice: (json['unit_price'] as num).toDouble(),
      costPrice: (json['cost_price'] as num?)?.toDouble() ?? 0.0,
      minStockAlert: (json['min_stock_alert'] as num?)?.toDouble() ?? 5.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'quantity': quantity,
      'unit_price': unitPrice,
      'cost_price': costPrice,
      'min_stock_alert': minStockAlert,
    };
  }
}

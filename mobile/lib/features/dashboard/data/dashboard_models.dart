class FinancialSummaryModel {
  final double turnover;
  final double stockPurchases;
  final double ancillaryExpenses;
  final double costOfGoodsSold;
  final double grossProfit;
  final double netProfit;

  FinancialSummaryModel({
    required this.turnover,
    required this.stockPurchases,
    required this.ancillaryExpenses,
    required this.costOfGoodsSold,
    required this.grossProfit,
    required this.netProfit,
  });

  factory FinancialSummaryModel.fromJson(Map<String, dynamic> json) {
    return FinancialSummaryModel(
      turnover: (json['chiffre_d_affaires'] as num?)?.toDouble() ?? 0.0,
      stockPurchases: (json['achats_stock'] as num?)?.toDouble() ?? 0.0,
      ancillaryExpenses: (json['depenses_ancillaires'] as num?)?.toDouble() ?? 0.0,
      costOfGoodsSold: (json['cout_des_marchandises_vendues'] as num?)?.toDouble() ?? 0.0,
      grossProfit: (json['benefice_brut'] as num?)?.toDouble() ?? 0.0,
      netProfit: (json['benefice_net'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class TransactionModel {
  final int id;
  final int userId;
  final String type; // SALE, PURCHASE, EXPENSE
  final String? description;
  final double amount;
  final int? productId;
  final double? quantity;
  final int? clientId;
  final DateTime createdAt;

  TransactionModel({
    required this.id,
    required this.userId,
    required this.type,
    this.description,
    required this.amount,
    this.productId,
    this.quantity,
    this.clientId,
    required this.createdAt,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'],
      userId: json['user_id'],
      type: json['type'],
      description: json['description'],
      amount: (json['amount'] as num).toDouble(),
      productId: json['product_id'],
      quantity: (json['quantity'] as num?)?.toDouble(),
      clientId: json['client_id'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

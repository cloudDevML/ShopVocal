class ClientModel {
  final int id;
  final int userId;
  final String name;
  final String? phone;
  final double debtAmount;

  ClientModel({
    required this.id,
    required this.userId,
    required this.name,
    this.phone,
    required this.debtAmount,
  });

  factory ClientModel.fromJson(Map<String, dynamic> json) {
    return ClientModel(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      name: json['name'] as String,
      phone: json['phone'] as String?,
      debtAmount: (json['debt_amount'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

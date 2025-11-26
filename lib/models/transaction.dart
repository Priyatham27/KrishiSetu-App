// lib/models/transaction.dart

class TransactionModel {
  final String id;
  final String offerId;
  final String listingId;
  final String buyerId;
  final String sellerId;
  final double finalPrice;
  final double quantity;
  final String status; // confirmed | completed | cancelled
  final DateTime createdAt;

  // ----------- STATUS CONSTANTS -----------
  static const String STATUS_CONFIRMED = 'confirmed';
  static const String STATUS_COMPLETED = 'completed';
  static const String STATUS_CANCELLED = 'cancelled';

  // -----------------------------------------

  TransactionModel({
    required this.id,
    required this.offerId,
    required this.listingId,
    required this.buyerId,
    required this.sellerId,
    required this.finalPrice,
    required this.quantity,
    required this.status,
    required this.createdAt, required double totalAmount,
  });

  // Convert object → Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'offerId': offerId,
      'listingId': listingId,
      'buyerId': buyerId,
      'sellerId': sellerId,
      'finalPrice': finalPrice,
      'quantity': quantity,
      'status': status,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  // Convert Firestore → Object
  factory TransactionModel.fromMap(String id, Map<String, dynamic> map) {
    return TransactionModel(
      id: id,
      offerId: map['offerId'] ?? '',
      listingId: map['listingId'] ?? '',
      buyerId: map['buyerId'] ?? '',
      sellerId: map['sellerId'] ?? '',
      finalPrice: (map['finalPrice'] is int)
          ? (map['finalPrice'] as int).toDouble()
          : map['finalPrice']?.toDouble() ?? 0.0,
      quantity: (map['quantity'] is int)
          ? (map['quantity'] as int).toDouble()
          : map['quantity']?.toDouble() ?? 0.0,
      status: map['status'] ?? STATUS_CONFIRMED,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        map['createdAt'] ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}

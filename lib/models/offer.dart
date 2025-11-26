// lib/models/offer.dart
//
// Offer model for KrishiSetu.
// Represents an offer made by a buyer on a listing.
// Fields:
//  - id: Firestore document id (empty for new objects)
//  - listingId: id of the listing this offer targets
//  - buyerId: uid of the buyer who made the offer
//  - offerPrice: offered price per unit (INR)
//  - quantity: quantity requested (in unit)
//  - status: one of STATUS_PENDING / STATUS_ACCEPTED / STATUS_REJECTED / STATUS_COUNTERED
//  - counterPrice: optional counter price set by farmer when countering
//  - message: optional message from buyer
//  - createdAt: DateTime of creation
//
// Utility: fromMap/from Firestore, toMap(for saving), copyWith, toString
//
import 'package:cloud_firestore/cloud_firestore.dart';

class Offer {
  final String id;
  final String listingId;
  final String buyerId;
  final double offerPrice;
  final double quantity;
  final String status;
  final double? counterPrice;
  final String? message;
  final DateTime createdAt;

  const Offer({
    required this.id,
    required this.listingId,
    required this.buyerId,
    required this.offerPrice,
    required this.quantity,
    this.status = STATUS_PENDING,
    this.counterPrice,
    this.message,
    required this.createdAt, required double offeredPrice, required DateTime timestamp,
  });

  // Status constants
  static const String STATUS_PENDING = 'pending';
  static const String STATUS_ACCEPTED = 'accepted';
  static const String STATUS_REJECTED = 'rejected';
  static const String STATUS_COUNTERED = 'countered';

  /// Parse double values safely from dynamic Firestore fields.
  static double _parseDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  /// Create Offer from Firestore document map.
  factory Offer.fromMap(String id, Map<String, dynamic> map) {
    final listingId = (map['listingId'] ?? '') as String;
    final buyerId = (map['buyerId'] ?? '') as String;
    final offerPrice = _parseDouble(map['offerPrice']);
    final quantity = _parseDouble(map['quantity']);
    final status = (map['status'] ?? STATUS_PENDING) as String;
    final counterPrice = map['counterPrice'] != null ? _parseDouble(map['counterPrice']) : null;
    final message = map['message'] != null ? (map['message'] as String) : null;

    // createdAt can be a Timestamp, int, or ISO string
    final rawCreated = map['createdAt'];
    DateTime createdAt;
    if (rawCreated == null) {
      createdAt = DateTime.now();
    } else if (rawCreated is Timestamp) {
      createdAt = rawCreated.toDate();
    } else if (rawCreated is int) {
      createdAt = DateTime.fromMillisecondsSinceEpoch(rawCreated);
    } else if (rawCreated is String) {
      createdAt = DateTime.tryParse(rawCreated) ?? DateTime.now();
    } else {
      createdAt = DateTime.now();
    }

    return Offer(
      id: id,
      listingId: listingId,
      buyerId: buyerId,
      offerPrice: offerPrice,
      quantity: quantity,
      status: status,
      counterPrice: counterPrice,
      message: message,
      createdAt: createdAt,
    );
  }

  /// Convert to map for Firestore.
  /// If you want server timestamp for createdAt, you can set useServerTimestampIfMissing = true.
  Map<String, dynamic> toMap({bool includeId = false, bool useServerTimestampIfMissing = true}) {
    final map = <String, dynamic>{
      'listingId': listingId,
      'buyerId': buyerId,
      'offerPrice': offerPrice,
      'quantity': quantity,
      'status': status,
    };

    if (counterPrice != null) map['counterPrice'] = counterPrice;
    if (message != null && message!.isNotEmpty) map['message'] = message;

    if (createdAt != null) {
      map['createdAt'] = Timestamp.fromDate(createdAt);
    } else if (useServerTimestampIfMissing) {
      map['createdAt'] = FieldValue.serverTimestamp();
    }

    if (includeId) map['id'] = id;
    return map;
  }

  Offer copyWith({
    String? id,
    String? listingId,
    String? buyerId,
    double? offerPrice,
    double? quantity,
    String? status,
    double? counterPrice,
    String? message,
    DateTime? createdAt,
  }) {
    return Offer(
      id: id ?? this.id,
      listingId: listingId ?? this.listingId,
      buyerId: buyerId ?? this.buyerId,
      offerPrice: offerPrice ?? this.offerPrice,
      quantity: quantity ?? this.quantity,
      status: status ?? this.status,
      counterPrice: counterPrice ?? this.counterPrice,
      message: message ?? this.message,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'Offer{id: $id, listingId: $listingId, buyerId: $buyerId, offerPrice: $offerPrice, quantity: $quantity, status: $status, counterPrice: $counterPrice, message: $message, createdAt: $createdAt}';
  }
}

// lib/models/listing.dart
//
// Listing model used by KrishiSetu app.
// Represents a farmer's produce listing stored in Firestore.
// Fields:
//  - id: document id (empty string for a not-yet-saved object)
//  - userId: uid of the farmer (owner)
//  - crop: name of crop (e.g., "Tomato")
//  - quantity: numeric amount (in unit, e.g., 100.0)
//  - unit: unit string (default 'kg')
//  - pricePerUnit: price per unit in INR
//  - imageUrl: public download URL stored in Firebase Storage
//  - location: place name or string (city/village)
//  - status: 'open'|'sold' (use constants ListinG.STATUS_*)
//  - createdAt: DateTime when created
//
// Includes helpers: fromMap, toMap, copyWith, toString
//
import 'package:cloud_firestore/cloud_firestore.dart';

class Listing {
  final String id;
  final String userId;
  final String crop;
  final double quantity;
  final String unit;
  final double pricePerUnit;
  final String imageUrl;
  final String location;
  final String status;
  final DateTime createdAt;

  const Listing({
    required this.id,
    required this.userId,
    required this.crop,
    required this.quantity,
    this.unit = 'kg',
    required this.pricePerUnit,
    this.imageUrl = '',
    this.location = '',
    this.status = STATUS_OPEN,
    required this.createdAt,
  });

  // Status constants
  static const String STATUS_OPEN = 'open';
  static const String STATUS_SOLD = 'sold';

  /// Create a Listing from Firestore map (doc.data()).
  /// Accepts both Timestamp and ISO string or milliseconds for createdAt.
  factory Listing.fromMap(String id, Map<String, dynamic> map) {
    // Defensive parsing
    final userId = (map['userId'] ?? '') as String;
    final crop = (map['crop'] ?? '') as String;
    final unit = (map['unit'] ?? 'kg') as String;
    final imageUrl = (map['imageUrl'] ?? '') as String;
    final location = (map['location'] ?? '') as String;
    final status = (map['status'] ?? STATUS_OPEN) as String;

    double parseDouble(dynamic v) {
      if (v == null) return 0.0;
      if (v is double) return v;
      if (v is int) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0.0;
      return 0.0;
    }

    final quantity = parseDouble(map['quantity']);
    final pricePerUnit = parseDouble(map['pricePerUnit']);

    DateTime createdAt;
    final raw = map['createdAt'];
    if (raw == null) {
      createdAt = DateTime.now();
    } else if (raw is Timestamp) {
      createdAt = raw.toDate();
    } else if (raw is int) {
      // milliseconds since epoch
      createdAt = DateTime.fromMillisecondsSinceEpoch(raw);
    } else if (raw is String) {
      createdAt = DateTime.tryParse(raw) ?? DateTime.now();
    } else {
      createdAt = DateTime.now();
    }

    return Listing(
      id: id,
      userId: userId,
      crop: crop,
      quantity: quantity,
      unit: unit,
      pricePerUnit: pricePerUnit,
      imageUrl: imageUrl,
      location: location,
      status: status,
      createdAt: createdAt,
    );
  }

  /// Convert to map suitable for writing to Firestore.
  /// If createdAt should be server-generated, pass createdAt as null and Firestore will store serverTimestamp.
  Map<String, dynamic> toMap({bool useServerTimestampIfMissing = true}) {
    final map = <String, dynamic>{
      'userId': userId,
      'crop': crop,
      'quantity': quantity,
      'unit': unit,
      'pricePerUnit': pricePerUnit,
      'imageUrl': imageUrl,
      'location': location,
      'status': status,
    };

    // If createdAt exists, store as Timestamp; otherwise use serverTimestamp optionally
    if (createdAt != null) {
      map['createdAt'] = Timestamp.fromDate(createdAt);
    } else if (useServerTimestampIfMissing) {
      map['createdAt'] = FieldValue.serverTimestamp();
    }

    return map;
  }

  /// Create a copy with overrides
  Listing copyWith({
    String? id,
    String? userId,
    String? crop,
    double? quantity,
    String? unit,
    double? pricePerUnit,
    String? imageUrl,
    String? location,
    String? status,
    DateTime? createdAt,
  }) {
    return Listing(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      crop: crop ?? this.crop,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      pricePerUnit: pricePerUnit ?? this.pricePerUnit,
      imageUrl: imageUrl ?? this.imageUrl,
      location: location ?? this.location,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'Listing{id: $id, userId: $userId, crop: $crop, quantity: $quantity $unit, pricePerUnit: $pricePerUnit, status: $status, createdAt: $createdAt}';
  }
}

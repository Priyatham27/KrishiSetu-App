// lib/models/user.dart
import 'package:flutter/foundation.dart';

/// AppUser model used across the app.
///
/// Fields:
/// - id: Firestore doc id (uid)
/// - name: display name
/// - phone: phone number (E.164 recommended, but not required)
/// - email: optional email
/// - role: 'farmer' or 'buyer'
/// - avatarUrl: optional profile image URL
/// - location: optional map { 'place': 'Village name', 'lat': double?, 'lng': double? }
/// - createdAt: when profile was created
class AppUser {
  final String id;
  final String name;
  final String phone;
  final String? email;
  final String role;
  final String? avatarUrl;
  final Map<String, dynamic>? location;
  final DateTime createdAt;

  // Role constants used across the app
  static const String ROLE_FARMER = 'farmer';
  static const String ROLE_BUYER = 'buyer';

  AppUser({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    required this.role,
    this.avatarUrl,
    this.location,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Create a copy with modifications
  AppUser copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    String? role,
    String? avatarUrl,
    Map<String, dynamic>? location,
    DateTime? createdAt,
  }) {
    return AppUser(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      role: role ?? this.role,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      location: location ?? this.location,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Convert model -> Firestore map
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      if (email != null) 'email': email,
      'role': role,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
      if (location != null) 'location': location,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  /// Construct model from Firestore map
  factory AppUser.fromMap(String id, Map<String, dynamic> map) {
    return AppUser(
      id: id,
      name: (map['name'] as String?) ?? '',
      phone: (map['phone'] as String?) ?? '',
      email: (map['email'] as String?) ?? null,
      role: (map['role'] as String?) ?? ROLE_BUYER,
      avatarUrl: (map['avatarUrl'] as String?) ?? null,
      location: (map['location'] as Map<String, dynamic>?) != null
          ? Map<String, dynamic>.from(map['location'] as Map)
          : null,
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
          (map['createdAt'] is int) ? map['createdAt'] as int : int.tryParse(map['createdAt'].toString()) ?? DateTime.now().millisecondsSinceEpoch)
          : DateTime.now(),
    );
  }

  /// Returns true if user is a farmer
  bool get isFarmer => role == ROLE_FARMER;

  /// Returns true if user is a buyer
  bool get isBuyer => role == ROLE_BUYER;

  @override
  String toString() {
    return 'AppUser(id: $id, name: $name, phone: $phone, role: $role, email: $email, avatarUrl: $avatarUrl, location: $location, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppUser && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

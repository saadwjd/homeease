import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { user, provider }

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final UserRole role;
  final String? avatarUrl;
  final String? address;
  final bool isVerified;
  final DateTime createdAt;

  const UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    this.avatarUrl,
    this.address,
    this.isVerified = false,
    required this.createdAt,
  });

  // Convert Firestore document → UserModel
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      role: data['role'] == 'provider' ? UserRole.provider : UserRole.user,
      avatarUrl: data['avatarUrl'],
      address: data['address'],
      isVerified: data['isVerified'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // Convert UserModel → Map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'role': role == UserRole.provider ? 'provider' : 'user',
      'avatarUrl': avatarUrl,
      'address': address,
      'isVerified': isVerified,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  // copyWith allows updating individual fields
  UserModel copyWith({
    String? name,
    String? phone,
    String? avatarUrl,
    String? address,
  }) {
    return UserModel(
      uid: uid,
      name: name ?? this.name,
      email: email,
      phone: phone ?? this.phone,
      role: role,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      address: address ?? this.address,
      isVerified: isVerified,
      createdAt: createdAt,
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

class ProviderModel {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final String? avatarUrl;
  final List<String> skills; // e.g. ['Plumber', 'Electrician']
  final String bio;
  final double rating;
  final int reviewCount;
  final bool isAvailable;
  final bool isVerified;
  final String? address;
  final double? latitude;
  final double? longitude;
  final double hourlyRate;
  final DateTime createdAt;

  const ProviderModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    this.avatarUrl,
    required this.skills,
    required this.bio,
    this.rating = 0.0,
    this.reviewCount = 0,
    this.isAvailable = true,
    this.isVerified = false,
    this.address,
    this.latitude,
    this.longitude,
    required this.hourlyRate,
    required this.createdAt,
  });

  factory ProviderModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ProviderModel(
      uid: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      avatarUrl: data['avatarUrl'],
      skills: List<String>.from(data['skills'] ?? []),
      bio: data['bio'] ?? '',
      rating: (data['rating'] ?? 0.0).toDouble(),
      reviewCount: data['reviewCount'] ?? 0,
      isAvailable: data['isAvailable'] ?? true,
      isVerified: data['isVerified'] ?? false,
      address: data['address'],
      latitude: data['latitude']?.toDouble(),
      longitude: data['longitude']?.toDouble(),
      hourlyRate: (data['hourlyRate'] ?? 0.0).toDouble(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'avatarUrl': avatarUrl,
      'skills': skills,
      'bio': bio,
      'rating': rating,
      'reviewCount': reviewCount,
      'isAvailable': isAvailable,
      'isVerified': isVerified,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'hourlyRate': hourlyRate,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  ProviderModel copyWith({
    String? bio,
    List<String>? skills,
    bool? isAvailable,
    String? address,
    double? latitude,
    double? longitude,
    double? hourlyRate,
    String? avatarUrl,
  }) {
    return ProviderModel(
      uid: uid,
      name: name,
      email: email,
      phone: phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      skills: skills ?? this.skills,
      bio: bio ?? this.bio,
      rating: rating,
      reviewCount: reviewCount,
      isAvailable: isAvailable ?? this.isAvailable,
      isVerified: isVerified,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      hourlyRate: hourlyRate ?? this.hourlyRate,
      createdAt: createdAt,
    );
  }
}

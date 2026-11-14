// user_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String? id;
  final String? userId;
  final String fullName;
  final String email;
  final String? phoneNumber;
  final String? image;
  final String? locationImage;
  final String? uniqueId;
  final String? fcmToken;
  final String profileStatus;
  final bool isVerified;
  final bool isBanned;
  final bool emailVerified;
  final DateTime? createdAt;
  final int? totalOrders;
  final double? totalSpent;

  UserModel({
    this.id,
    this.userId,
    required this.fullName,
    required this.email,
    this.phoneNumber,
    this.image,
    this.locationImage,
    this.uniqueId,
    this.fcmToken,
    this.profileStatus = 'notVerified',
    this.isVerified = false,
    this.isBanned = false,
    this.emailVerified = true,
    this.createdAt,
    this.totalOrders,
    this.totalSpent,
  });

  // Factory method to create UserModel from Firestore document
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      id: doc.id,
      userId: data['userId'] as String?,
      fullName: data['fullName'] as String? ?? 'Unknown User',
      email: data['email'] as String? ?? '',
      phoneNumber: data['phoneNumber'] as String?,
      image: data['image'] as String? ?? '',
      locationImage: data['locationImage'] as String?,
      uniqueId: data['uniqueId'] as String?,
      fcmToken: data['fcmToken'] as String?,
      profileStatus: data['profileStatus'] as String? ?? 'notVerified',
      isVerified: data['isVerified'] as bool? ?? false,
      isBanned: data['isBanned'] as bool? ?? false,
      emailVerified: data['emailVerified'] as bool? ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      totalOrders: data['totalOrders'] as int? ?? 0,
      totalSpent: (data['totalSpent'] as num?)?.toDouble() ?? 0.0,
    );
  }

  // Convert UserModel to Map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'fullName': fullName,
      'email': email,
      'userId': userId,
      'uniqueId': uniqueId,
      'locationImage': locationImage,
      'image': image ?? '',
      'fcmToken': fcmToken ?? '',
      'phoneNumber': phoneNumber,
      'profileStatus': profileStatus,
      'isVerified': isVerified,
      'isBanned': isBanned,
      'emailVerified': emailVerified,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'totalOrders': totalOrders ?? 0,
      'totalSpent': totalSpent ?? 0.0,
    };
  }

  // Helper method to create a copy with updated fields
  UserModel copyWith({
    String? id,
    String? userId,
    String? fullName,
    String? email,
    String? phoneNumber,
    String? image,
    String? locationImage,
    String? uniqueId,
    String? fcmToken,
    String? profileStatus,
    bool? isVerified,
    bool? isBanned,
    bool? emailVerified,
    DateTime? createdAt,
    int? totalOrders,
    double? totalSpent,
  }) {
    return UserModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      image: image ?? this.image,
      locationImage: locationImage ?? this.locationImage,
      uniqueId: uniqueId ?? this.uniqueId,
      fcmToken: fcmToken ?? this.fcmToken,
      profileStatus: profileStatus ?? this.profileStatus,
      isVerified: isVerified ?? this.isVerified,
      isBanned: isBanned ?? this.isBanned,
      emailVerified: emailVerified ?? this.emailVerified,
      createdAt: createdAt ?? this.createdAt,
      totalOrders: totalOrders ?? this.totalOrders,
      totalSpent: totalSpent ?? this.totalSpent,
    );
  }

  // Getter for profile image (for backward compatibility)
  String? get profileImage => image;

  // Getter for name (for backward compatibility)
  String get name => fullName;

  // Getter for phone (for backward compatibility)
  String? get phone => phoneNumber;

  // Getter for isActive (for backward compatibility)
  bool get isActive => !isBanned;

  // Helper method to check if user is verified
  bool get isProfileVerified => profileStatus.toLowerCase() == 'verified';

  // Helper method to check if user is banned
  bool get isUserBanned => isBanned;

  // Helper method to get user display name
  String get displayName => fullName.isEmpty ? 'User' : fullName;
}
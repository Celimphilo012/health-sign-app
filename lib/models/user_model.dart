import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { patient, nurse, superAdmin }

class UserModel {
  final String uid;
  final String name;
  final String email;
  final UserRole role;
  final DateTime createdAt;
  final String? profileImageUrl;
  final bool isDisabled;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.createdAt,
    this.profileImageUrl,
    this.isDisabled = false,
  });

  String get roleString {
    switch (role) {
      case UserRole.nurse:
        return 'nurse';
      case UserRole.superAdmin:
        return 'superAdmin';
      case UserRole.patient:
        return 'patient';
    }
  }

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    UserRole role;
    switch (data['role']) {
      case 'nurse':
        role = UserRole.nurse;
        break;
      case 'superAdmin':
        role = UserRole.superAdmin;
        break;
      default:
        role = UserRole.patient;
    }
    return UserModel(
      uid: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      role: role,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      profileImageUrl: data['profileImageUrl'],
      isDisabled: data['isDisabled'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'role': roleString,
      'createdAt': Timestamp.fromDate(createdAt),
      'profileImageUrl': profileImageUrl,
    };
  }
}

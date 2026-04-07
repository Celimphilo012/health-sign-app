import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { patient, nurse }

class UserModel {
  final String uid;
  final String name;
  final String email;
  final UserRole role;
  final DateTime createdAt;
  final String? profileImageUrl;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.createdAt,
    this.profileImageUrl,
  });

  String get roleString => role == UserRole.patient ? 'patient' : 'nurse';

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      role: data['role'] == 'nurse' ? UserRole.nurse : UserRole.patient,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      profileImageUrl: data['profileImageUrl'],
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

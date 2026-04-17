import 'package:cloud_firestore/cloud_firestore.dart';

enum RequestStatus { pending, accepted, declined, ended }

class ChatRequestModel {
  final String id;
  final String? nurseId;
  final String nurseName;
  final String patientId;
  final String patientName;
  final RequestStatus status;
  final DateTime createdAt;
  final DateTime? endedAt;
  final String? conversationId;
  final String urgency; // ← NEW
  final String initiatedBy;
  final String? declineReason;
  final DateTime? declinedAt;

  ChatRequestModel({
    required this.id,
    required this.nurseId,
    required this.nurseName,
    required this.patientId,
    required this.patientName,
    required this.status,
    required this.createdAt,
    this.endedAt,
    this.conversationId,
    this.urgency = 'normal',
    this.initiatedBy = 'nurse',
    this.declineReason,
    this.declinedAt,
  });

  factory ChatRequestModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatRequestModel(
      id: doc.id,
      nurseId: data['nurseId'] ?? '',
      nurseName: data['nurseName'] ?? '',
      patientId: data['patientId'] ?? '',
      patientName: data['patientName'] ?? '',
      status: _parseStatus(data['status']),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      endedAt: data['endedAt'] != null
          ? (data['endedAt'] as Timestamp).toDate()
          : null,
      conversationId: data['conversationId'],
      urgency: data['urgency'] ?? 'normal',
      initiatedBy: data['initiatedBy'] ?? 'nurse',
      declineReason: data['declineReason'],
      declinedAt: data['declinedAt'] != null
          ? (data['declinedAt'] as Timestamp).toDate()
          : null,
    );
  }

  static RequestStatus _parseStatus(String? s) {
    switch (s) {
      case 'accepted':
        return RequestStatus.accepted;
      case 'declined':
        return RequestStatus.declined;
      case 'ended':
        return RequestStatus.ended;
      default:
        return RequestStatus.pending;
    }
  }

  Map<String, dynamic> toFirestore() {
    return {
      'nurseId': nurseId,
      'nurseName': nurseName,
      'patientId': patientId,
      'patientName': patientName,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      if (endedAt != null) 'endedAt': Timestamp.fromDate(endedAt!),
      'conversationId': conversationId,
      'urgency': urgency,
      'initiatedBy': initiatedBy,
    };
  }
}

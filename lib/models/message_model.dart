import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageType { text, gesture, speech, shortcut }

enum MessageSender { patient, nurse }

class MessageModel {
  final String id;
  final String conversationId;
  final String senderId;
  final MessageSender senderRole;
  final String text;
  final MessageType type;
  final DateTime timestamp;
  final bool isRead;

  MessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderRole,
    required this.text,
    required this.type,
    required this.timestamp,
    this.isRead = false,
  });

  String get typeLabel {
    switch (type) {
      case MessageType.gesture:
        return 'Sign Language';
      case MessageType.speech:
        return 'Voice';
      case MessageType.shortcut:
        return 'Quick';
      default:
        return 'Text';
    }
  }

  factory MessageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MessageModel(
      id: doc.id,
      conversationId: data['conversationId'] ?? '',
      senderId: data['senderId'] ?? '',
      senderRole: data['senderRole'] == 'nurse'
          ? MessageSender.nurse
          : MessageSender.patient,
      text: data['text'] ?? '',
      type: _parseType(data['type']),
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      isRead: data['isRead'] ?? false,
    );
  }

  static MessageType _parseType(String? type) {
    switch (type) {
      case 'gesture':
        return MessageType.gesture;
      case 'speech':
        return MessageType.speech;
      case 'shortcut':
        return MessageType.shortcut;
      default:
        return MessageType.text;
    }
  }

  Map<String, dynamic> toFirestore() {
    return {
      'conversationId': conversationId,
      'senderId': senderId,
      'senderRole': senderRole == MessageSender.nurse ? 'nurse' : 'patient',
      'text': text,
      'type': type.name,
      'timestamp': Timestamp.fromDate(timestamp),
      'isRead': isRead,
    };
  }
}

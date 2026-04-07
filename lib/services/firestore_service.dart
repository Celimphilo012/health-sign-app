import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/message_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Save a message ────────────────────────────────────
  Future<void> saveMessage(MessageModel message) async {
    await _db
        .collection('conversations')
        .doc(message.conversationId)
        .collection('messages')
        .add(message.toFirestore());
  }

  // ── Get messages stream (real-time) ───────────────────
  Stream<List<MessageModel>> getMessagesStream(String conversationId) {
    return _db
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => MessageModel.fromFirestore(doc)).toList());
  }

  // ── Get or create conversation ID ─────────────────────
  Future<String> getOrCreateConversation(String patientId) async {
    final existing = await _db
        .collection('conversations')
        .where('patientId', isEqualTo: patientId)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      return existing.docs.first.id;
    }

    final doc = await _db.collection('conversations').add({
      'patientId': patientId,
      'createdAt': Timestamp.now(),
      'lastMessage': '',
      'lastUpdated': Timestamp.now(),
    });

    return doc.id;
  }

  // ── Update last message ───────────────────────────────
  Future<void> updateLastMessage(String conversationId, String message) async {
    await _db.collection('conversations').doc(conversationId).update({
      'lastMessage': message,
      'lastUpdated': Timestamp.now(),
    });
  }
}

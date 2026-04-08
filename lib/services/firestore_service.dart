import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';
import '../models/chat_request_model.dart';

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
    if (conversationId.isEmpty) return Stream.value([]);
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
  Future<void> updateLastMessage(
      String conversationId, String message) async {
    if (conversationId.isEmpty) return;
    await _db.collection('conversations').doc(conversationId).update({
      'lastMessage': message,
      'lastUpdated': Timestamp.now(),
    });
  }

  // ── Get all nurses ────────────────────────────────────
  Future<List<UserModel>> getNurses() async {
    final snap = await _db
        .collection('users')
        .where('role', isEqualTo: 'nurse')
        .get();
    return snap.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
  }

  // ── Get all patients ──────────────────────────────────
  Future<List<UserModel>> getPatients() async {
    final snap = await _db
        .collection('users')
        .where('role', isEqualTo: 'patient')
        .get();
    return snap.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
  }

  // ── Get specific user ─────────────────────────────────
  Future<UserModel?> getUserById(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (!doc.exists) return null;
      return UserModel.fromFirestore(doc);
    } catch (e) {
      return null;
    }
  }

  // ── Send chat request ─────────────────────────────────
  Future<String> sendChatRequest({
    required String nurseId,
    required String nurseName,
    required String patientId,
    required String patientName,
  }) async {
    // Remove any existing pending request first
    final existing = await _db
        .collection('chat_requests')
        .where('nurseId', isEqualTo: nurseId)
        .where('patientId', isEqualTo: patientId)
        .where('status', isEqualTo: 'pending')
        .get();
    for (final doc in existing.docs) {
      await doc.reference.delete();
    }

    final ref = await _db.collection('chat_requests').add({
      'nurseId': nurseId,
      'nurseName': nurseName,
      'patientId': patientId,
      'patientName': patientName,
      'status': 'pending',
      'createdAt': Timestamp.now(),
      'conversationId': null,
    });

    return ref.id;
  }

  // ── REAL-TIME: incoming requests for patient ──────────
  Stream<List<ChatRequestModel>> getIncomingRequestsStream(
      String patientId) {
    return _db
        .collection('chat_requests')
        .where('patientId', isEqualTo: patientId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => ChatRequestModel.fromFirestore(doc))
            .toList());
  }

  // ── REAL-TIME: active chat for nurse ──────────────────
  Stream<ChatRequestModel?> getNurseActiveChatStream(String nurseId) {
    return _db
        .collection('chat_requests')
        .where('nurseId', isEqualTo: nurseId)
        .where('status', isEqualTo: 'accepted')
        .limit(1)
        .snapshots()
        .map((snap) {
      if (snap.docs.isEmpty) return null;
      return ChatRequestModel.fromFirestore(snap.docs.first);
    });
  }

  // ── Accept request ────────────────────────────────────
  Future<String> acceptChatRequest(
      String requestId, String patientId) async {
    final convId = await getOrCreateConversation(patientId);
    await _db.collection('chat_requests').doc(requestId).update({
      'status': 'accepted',
      'conversationId': convId,
    });
    return convId;
  }

  // ── Decline request ───────────────────────────────────
  Future<void> declineChatRequest(String requestId) async {
    await _db
        .collection('chat_requests')
        .doc(requestId)
        .update({'status': 'declined'});
  }

  // ── End conversation ──────────────────────────────────
  Future<void> endConversation(String requestId) async {
    await _db.collection('chat_requests').doc(requestId).update({
      'status': 'ended',
      'endedAt': Timestamp.now(),
    });
  }

  // ── Nurse chat history (ended convos) ─────────────────
  Stream<List<ChatRequestModel>> getNurseChatHistoryStream(
      String nurseId) {
    return _db
        .collection('chat_requests')
        .where('nurseId', isEqualTo: nurseId)
        .where('status', isEqualTo: 'ended')
        .orderBy('endedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => ChatRequestModel.fromFirestore(doc))
            .toList());
  }
}
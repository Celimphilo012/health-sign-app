import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/message_model.dart';
import '../services/firestore_service.dart';
import '../services/speech_service.dart';

class ConversationProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  final SpeechService _speechService = SpeechService();
  final _uuid = const Uuid();

  List<MessageModel> _messages = [];
  String _conversationId = '';
  bool _isListening = false;
  bool _isSpeaking = false;
  String _liveText = '';
  String _detectedGesture = '';

  List<MessageModel> get messages => _messages;
  String get conversationId => _conversationId;
  bool get isListening => _isListening;
  bool get isSpeaking => _isSpeaking;
  String get liveText => _liveText;
  String get detectedGesture => _detectedGesture;

  // ── Initialize ────────────────────────────────────────
  Future<void> initialize(String userId) async {
    await _speechService.initTts();
    await _speechService.initStt();
    _conversationId = await _firestoreService.getOrCreateConversation(userId);

    // Listen to real-time messages
    _firestoreService.getMessagesStream(_conversationId).listen((msgs) {
      _messages = msgs;
      notifyListeners();
    });

    notifyListeners();
  }

  // ── Send message ──────────────────────────────────────
  Future<void> sendMessage({
    required String text,
    required String senderId,
    required MessageSender senderRole,
    required MessageType type,
  }) async {
    if (text.trim().isEmpty) return;

    final message = MessageModel(
      id: _uuid.v4(),
      conversationId: _conversationId,
      senderId: senderId,
      senderRole: senderRole,
      text: text.trim(),
      type: type,
      timestamp: DateTime.now(),
    );

    await _firestoreService.saveMessage(message);
    await _firestoreService.updateLastMessage(_conversationId, text.trim());
  }

  // ── TTS: speak text ───────────────────────────────────
  Future<void> speakText(String text) async {
    _isSpeaking = true;
    notifyListeners();
    await _speechService.speak(text);
    _isSpeaking = false;
    notifyListeners();
  }

  Future<void> stopSpeaking() async {
    await _speechService.stopSpeaking();
    _isSpeaking = false;
    notifyListeners();
  }

  // ── STT: start listening ──────────────────────────────
  Future<void> startListening() async {
    await _speechService.startListening(
      onResult: (text) {
        _liveText = text;
        notifyListeners();
      },
      onListeningChanged: (listening) {
        _isListening = listening;
        notifyListeners();
      },
    );
    _isListening = true;
    notifyListeners();
  }

  Future<void> stopListening() async {
    await _speechService.stopListening(
      onListeningChanged: (listening) {
        _isListening = listening;
        notifyListeners();
      },
    );
  }

  // ── Gesture detection (mock logic) ───────────────────
  void setDetectedGesture(String gesture) {
    _detectedGesture = gesture;
    notifyListeners();
  }

  void clearLiveText() {
    _liveText = '';
    notifyListeners();
  }

  @override
  void dispose() {
    _speechService.dispose();
    super.dispose();
  }
}

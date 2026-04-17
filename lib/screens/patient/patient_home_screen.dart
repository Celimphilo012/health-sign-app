import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import '../../providers/auth_provider.dart';
import '../../providers/conversation_provider.dart';
import '../../providers/chat_request_provider.dart';
import '../../models/message_model.dart';
import '../../models/chat_request_model.dart';
import '../../widgets/message_bubble.dart';
import '../../widgets/camera_preview_widget.dart';
import '../../services/haptic_service.dart';
import '../../services/firestore_service.dart';
import '../../services/notification_service.dart';
import '../../services/location_service.dart';

class PatientHomeScreen extends StatefulWidget {
  const PatientHomeScreen({super.key});

  @override
  State<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends State<PatientHomeScreen> {
  int _lastMessageCount = 0;
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _initialized = false;
  bool _isShowingDialog = false;
  StreamSubscription<List<ChatRequestModel>>? _declinedCallsSub;

  final List<Map<String, String>> _gestures = [
    {'gesture': 'thumbs_up', 'label': '👍', 'text': 'Yes / I agree'},
    {'gesture': 'thumbs_down', 'label': '👎', 'text': 'No / I disagree'},
    {'gesture': 'open_hand', 'label': '✋', 'text': 'Stop / Wait'},
    {'gesture': 'pointing', 'label': '☝️', 'text': 'I need attention'},
    {'gesture': 'fist', 'label': '✊', 'text': 'I am in pain'},
    {'gesture': 'peace', 'label': '✌️', 'text': 'I am okay'},
    {'gesture': 'wave', 'label': '👋', 'text': 'Hello / Goodbye'},
  ];

  final List<Map<String, String>> _shortcuts = [
    {'label': '🤕 Pain', 'text': 'I am in pain'},
    {'label': '🆘 Help', 'text': 'I need help urgently'},
    {'label': '😵 Dizzy', 'text': 'I feel dizzy'},
    {'label': '🤢 Nausea', 'text': 'I feel nauseous'},
    {'label': '💧 Water', 'text': 'I need water'},
    {'label': '🚽 Bathroom', 'text': 'I need the bathroom'},
    {'label': '🌡️ Fever', 'text': 'I have a fever'},
    {'label': '😴 Tired', 'text': 'I am very tired'},
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final user = context.read<AuthProvider>().user;
      if (user != null) {
        // Init conversation
        context.read<ConversationProvider>().initialize(
              user.uid,
              role: 'patient',
            );
        // ✅ FIX #1: Start REAL-TIME stream for incoming requests
        context.read<ChatRequestProvider>().listenForRequests(user.uid);
        // Only show snackbars for declines that happen after this login.
        final loginTime = DateTime.now();
        _declinedCallsSub =
            FirestoreService().getDeclinedCallsStream(user.uid).listen((calls) {
          for (final call in calls) {
            final isNew = call.declinedAt != null &&
                call.declinedAt!.isAfter(loginTime);
            if (isNew && call.declineReason != null && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'A nurse declined: ${call.declineReason}',
                  ),
                  backgroundColor: const Color(0xFFCF6679),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 5),
                  margin: const EdgeInsets.all(12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              );
            }
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _declinedCallsSub?.cancel();
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // Add this method to _PatientHomeScreenState:
  Future<void> _ringCallBell(String urgency) async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    // Get patient location
    final position = await LocationService().getCurrentPosition();

    // Save call to Firestore
    final requestId = await FirestoreService().sendCallBell(
      patientId: user.uid,
      patientName: user.name,
      urgency: urgency,
    );

    // Broadcast to nearby nurses if location available
    if (position != null) {
      await NotificationService().broadcastToNearbyNurses(
        patientId: user.uid,
        patientName: user.name,
        urgency: urgency,
        patientLat: position.latitude,
        patientLng: position.longitude,
        callRequestId: requestId,
      );
    }

    if (mounted) {
      HapticService.incomingRequest();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.notifications_active,
                  color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Text(urgency == 'emergency'
                  ? '🚨 Emergency alert sent to all nearby nurses!'
                  : '🔔 Call sent — a nurse will respond shortly'),
            ],
          ),
          backgroundColor: urgency == 'emergency'
              ? const Color(0xFFCF6679)
              : const Color(0xFF3FB950),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _sendMessage(String text, MessageType type) async {
    if (text.trim().isEmpty) return;
    final user = context.read<AuthProvider>().user;
    final conv = context.read<ConversationProvider>();
    await conv.sendMessage(
      text: text,
      senderId: user!.uid,
      senderRole: MessageSender.patient,
      type: type,
    );
    await conv.speakText(text);
    _textCtrl.clear();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showCallOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161B22),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF30363D),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Call a Nurse',
              style: TextStyle(
                color: Color(0xFFE6EDF3),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'A nurse will respond and open a chat with you',
              style: TextStyle(color: Color(0xFF8B949E), fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Normal call
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _ringCallBell('normal');
                },
                icon: const Icon(Icons.notifications_outlined, size: 20),
                label: const Text('Request a Nurse',
                    style: TextStyle(fontSize: 15)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3FB950),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Emergency call
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _ringCallBell('emergency');
                },
                icon: const Icon(Icons.emergency_outlined, size: 20),
                label: const Text('Emergency — Urgent Help',
                    style: TextStyle(fontSize: 15)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFCF6679),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _simulateGesture(Map<String, String> gesture) {
    final conv = context.read<ConversationProvider>();
    conv.setDetectedGesture(gesture['label']!);
    _sendMessage(gesture['text']!, MessageType.gesture);
  }

  // ✅ FIX #1: Real-time popup shown when request arrives
  void _showIncomingRequest(ChatRequestModel request) {
    if (_isShowingDialog) return;
    _isShowingDialog = true;

    HapticService.incomingRequest();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          backgroundColor: const Color(0xFF161B22),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFF3FB950), width: 2),
          ),
          title: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFF3FB950).withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: const Color(0xFF3FB950).withOpacity(0.4),
                      width: 2),
                ),
                child: const Icon(
                  Icons.medical_services_outlined,
                  color: Color(0xFF3FB950),
                  size: 32,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Incoming Chat Request',
                style: TextStyle(
                  color: Color(0xFFE6EDF3),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF21262D),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF30363D)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF3FB950).withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          request.nurseName.isNotEmpty
                              ? request.nurseName[0].toUpperCase()
                              : 'N',
                          style: const TextStyle(
                            color: Color(0xFF3FB950),
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            request.nurseName,
                            style: const TextStyle(
                              color: Color(0xFFE6EDF3),
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          const Text(
                            'Healthcare Worker',
                            style: TextStyle(
                              color: Color(0xFF3FB950),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'wants to start a conversation with you',
                style: TextStyle(
                  color: Color(0xFF8B949E),
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.spaceEvenly,
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            OutlinedButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                _isShowingDialog = false;

                HapticService.requestDeclined();

                await context
                    .read<ChatRequestProvider>()
                    .declineRequest(request.id);
              },
              icon: const Icon(Icons.close, color: Color(0xFFCF6679), size: 16),
              label: const Text('Decline',
                  style: TextStyle(color: Color(0xFFCF6679))),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFCF6679)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                _isShowingDialog = false;
                HapticService.requestAccepted();
                final convId = await context
                    .read<ChatRequestProvider>()
                    .acceptRequest(request.id, request.patientId);
                if (convId != null && context.mounted) {
                  // Init conversation with the accepted convId
                  await context
                      .read<ConversationProvider>()
                      .initWithConversationId(convId);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('✓ Connected with ${request.nurseName}!'),
                      backgroundColor: const Color(0xFF3FB950),
                      behavior: SnackBarBehavior.floating,
                      margin: const EdgeInsets.all(12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.check, size: 16),
              label: const Text('Accept'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3FB950),
                foregroundColor: Colors.black,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    ).then((_) => _isShowingDialog = false);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final conv = context.watch<ConversationProvider>();
    // ✅ Vibrate when nurse sends a new message
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (conv.messages.length > _lastMessageCount) {
        final newMessages = conv.messages.skip(_lastMessageCount).toList();
        // Only vibrate if the new message is from nurse (not self)
        final hasNurseMessage = newMessages.any(
          (m) => m.senderRole == MessageSender.nurse,
        );
        if (hasNurseMessage && _lastMessageCount > 0) {
          HapticService.newMessage();
        }
        _lastMessageCount = conv.messages.length;
        _scrollToBottom();
      }
    });
    final requests = context.watch<ChatRequestProvider>().incomingRequests;

    // ✅ FIX #1: Show popup when request arrives in real-time
    if (requests.isNotEmpty && !_isShowingDialog) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (requests.isNotEmpty && !_isShowingDialog && mounted) {
          _showIncomingRequest(requests.first);
        }
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF58A6FF).withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.personal_injury_outlined,
                  color: Color(0xFF58A6FF), size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.name ?? 'Patient',
                  style: const TextStyle(
                      color: Color(0xFFE6EDF3),
                      fontSize: 15,
                      fontWeight: FontWeight.w600),
                ),
                const Text('Patient Mode',
                    style: TextStyle(color: Color(0xFF58A6FF), fontSize: 11)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.sign_language,
                color: Color(0xFF8B949E), size: 20),
            onPressed: () => Navigator.pushNamed(context, '/gesture-demo'),
          ),
          // In the AppBar actions list, ADD before the history icon:
          IconButton(
            icon: const Icon(Icons.add_ic_call,
                color: Color(0xFF3FB950), size: 22),
            tooltip: 'Call a nurse',
            onPressed: () => _showCallOptions(),
          ),
          IconButton(
            icon: const Icon(Icons.history, color: Color(0xFF8B949E), size: 20),
            onPressed: () => Navigator.pushNamed(context, '/history'),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFF8B949E), size: 20),
            onPressed: () async {
              await context.read<AuthProvider>().logout();
              if (mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _GestureCameraPanel(
            detectedGesture: conv.detectedGesture,
            gestures: _gestures,
            onGestureSelected: _simulateGesture,
          ),
          _ShortcutBar(
            shortcuts: _shortcuts,
            onSelected: (text) => _sendMessage(text, MessageType.shortcut),
          ),
          Expanded(
            child: conv.messages.isEmpty
                ? const _EmptyChat()
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: conv.messages.length,
                    itemBuilder: (_, i) {
                      final msg = conv.messages[i];
                      final isMe = msg.senderRole == MessageSender.patient;
                      return MessageBubble(
                        message: msg,
                        isMe: isMe,
                        onSpeak: () => conv.speakText(msg.text),
                      );
                    },
                  ),
          ),
          _TextInputBar(
            controller: _textCtrl,
            isSpeaking: conv.isSpeaking,
            onSend: () => _sendMessage(_textCtrl.text, MessageType.text),
            onSpeak: () => conv.speakText(_textCtrl.text),
            onStop: () => conv.stopSpeaking(),
          ),
        ],
      ),
    );
  }
}

// ── Gesture Camera Panel ──────────────────────────────────
class _GestureCameraPanel extends StatelessWidget {
  final String detectedGesture;
  final List<Map<String, String>> gestures;
  final Function(Map<String, String>) onGestureSelected;

  const _GestureCameraPanel({
    required this.detectedGesture,
    required this.gestures,
    required this.onGestureSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Column(
        children: [
          Container(
            height: 140,
            decoration: const BoxDecoration(
              color: Color(0xFF0D1117),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Container(
                    margin: const EdgeInsets.all(12),
                    height: double.infinity,
                    child: CameraPreviewWidget(
                      autoDetect: true,
                      onGestureDetected: (gesture, text) {
                        if (text.isNotEmpty) {
                          onGestureSelected({'label': gesture, 'text': text});
                        }
                      },
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        detectedGesture.isEmpty ? '🤚' : detectedGesture,
                        style: const TextStyle(fontSize: 40),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        detectedGesture.isEmpty ? 'Waiting...' : 'Detected!',
                        style: TextStyle(
                          color: detectedGesture.isEmpty
                              ? const Color(0xFF8B949E)
                              : const Color(0xFF00BFA5),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 8, top: 8),
                  child: Text(
                    'Tap a gesture to send:',
                    style: TextStyle(color: Color(0xFF8B949E), fontSize: 11),
                  ),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: gestures
                      .map((g) => GestureDetector(
                            onTap: () => onGestureSelected(g),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF21262D),
                                borderRadius: BorderRadius.circular(20),
                                border:
                                    Border.all(color: const Color(0xFF30363D)),
                              ),
                              child: Text(
                                '${g['label']} ${g['text']}',
                                style: const TextStyle(
                                  color: Color(0xFFE6EDF3),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ))
                      .toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shortcut Bar ──────────────────────────────────────────
class _ShortcutBar extends StatelessWidget {
  final List<Map<String, String>> shortcuts;
  final Function(String) onSelected;

  const _ShortcutBar({required this.shortcuts, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: shortcuts.length,
        itemBuilder: (_, i) {
          final s = shortcuts[i];
          return GestureDetector(
            onTap: () => onSelected(s['text']!),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFCF6679).withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border:
                    Border.all(color: const Color(0xFFCF6679).withOpacity(0.4)),
              ),
              child: Text(
                s['label']!,
                style: const TextStyle(color: Color(0xFFE6EDF3), fontSize: 13),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Text Input Bar ────────────────────────────────────────
class _TextInputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isSpeaking;
  final VoidCallback onSend;
  final VoidCallback onSpeak;
  final VoidCallback onStop;

  const _TextInputBar({
    required this.controller,
    required this.isSpeaking,
    required this.onSend,
    required this.onSpeak,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      decoration: const BoxDecoration(
        color: Color(0xFF161B22),
        border: Border(top: BorderSide(color: Color(0xFF30363D))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              style: const TextStyle(color: Color(0xFFE6EDF3)),
              decoration: InputDecoration(
                hintText: 'Type a message...',
                hintStyle: const TextStyle(color: Color(0xFF8B949E)),
                filled: true,
                fillColor: const Color(0xFF21262D),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: isSpeaking ? onStop : onSpeak,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: isSpeaking
                    ? const Color(0xFFCF6679).withOpacity(0.15)
                    : const Color(0xFF8B949E).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSpeaking
                      ? const Color(0xFFCF6679).withOpacity(0.4)
                      : const Color(0xFF30363D),
                ),
              ),
              child: Icon(
                isSpeaking
                    ? Icons.stop_circle_outlined
                    : Icons.volume_up_outlined,
                color: isSpeaking
                    ? const Color(0xFFCF6679)
                    : const Color(0xFF8B949E),
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onSend,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFF00BFA5).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: const Color(0xFF00BFA5).withOpacity(0.4)),
              ),
              child: const Icon(Icons.send_rounded,
                  color: Color(0xFF00BFA5), size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 48, color: Color(0xFF30363D)),
          SizedBox(height: 12),
          Text('No messages yet',
              style: TextStyle(color: Color(0xFF8B949E), fontSize: 15)),
          Text('Use gestures or shortcuts to communicate',
              style: TextStyle(color: Color(0xFF8B949E), fontSize: 12)),
        ],
      ),
    );
  }
}

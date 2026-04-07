import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../providers/conversation_provider.dart';
import '../../models/message_model.dart';
import '../../widgets/message_bubble.dart';
import '../../widgets/camera_preview_widget.dart';
import '../../services/permission_service.dart';

class PatientHomeScreen extends StatefulWidget {
  const PatientHomeScreen({super.key});

  @override
  State<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends State<PatientHomeScreen> {
  final _textCtrl = TextEditingController();
  bool _initialized = false;

  // Mock gesture list — replace with real ML later
  final List<Map<String, String>> _gestures = [
    {'gesture': 'thumbs_up', 'label': '👍', 'text': 'Yes / I agree'},
    {'gesture': 'thumbs_down', 'label': '👎', 'text': 'No / I disagree'},
    {'gesture': 'open_hand', 'label': '✋', 'text': 'Stop / Wait'},
    {'gesture': 'pointing', 'label': '☝️', 'text': 'I need attention'},
    {'gesture': 'fist', 'label': '✊', 'text': 'I am in pain'},
    {'gesture': 'peace', 'label': '✌️', 'text': 'I am okay'},
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
      final user = context.read<app_auth.AuthProvider>().user;
      if (user != null) {
        context.read<ConversationProvider>().initialize(user.uid);
      }
    }
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendMessage(String text, MessageType type) async {
    if (text.trim().isEmpty) return;
    final user = context.read<app_auth.AuthProvider>().user;
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

  void _simulateGesture(Map<String, String> gesture) {
    final conv = context.read<ConversationProvider>();
    conv.setDetectedGesture(gesture['label']!);
    _sendMessage(gesture['text']!, MessageType.gesture);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<app_auth.AuthProvider>().user;
    final conv = context.watch<ConversationProvider>();

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
                const Text(
                  'Patient Mode',
                  style: TextStyle(color: Color(0xFF58A6FF), fontSize: 11),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history, color: Color(0xFF8B949E)),
            onPressed: () => Navigator.pushNamed(context, '/history'),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFF8B949E)),
            onPressed: () async {
              await context.read<app_auth.AuthProvider>().logout();
              if (mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.sign_language, color: Color(0xFF8B949E)),
            tooltip: 'Gesture Reference',
            onPressed: () => Navigator.pushNamed(context, '/gesture-demo'),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Gesture Camera Panel ─────────────────────
          _GestureCameraPanel(
            detectedGesture: conv.detectedGesture,
            gestures: _gestures,
            onGestureSelected: _simulateGesture,
          ),

          // ── Quick Shortcuts ──────────────────────────
          _ShortcutBar(
            shortcuts: _shortcuts,
            onSelected: (text) => _sendMessage(text, MessageType.shortcut),
          ),

          // ── Message List ─────────────────────────────
          Expanded(
            child: conv.messages.isEmpty
                ? const _EmptyChat()
                : ListView.builder(
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

          // ── Text Input ───────────────────────────────
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
          // Camera placeholder + detected gesture
          Container(
            height: 140,
            decoration: BoxDecoration(
              color: const Color(0xFF0D1117),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                // Camera preview
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
                // Detected gesture display
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
          // Gesture buttons row
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
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
          // Speak button
          _IconBtn(
            icon: isSpeaking
                ? Icons.stop_circle_outlined
                : Icons.volume_up_outlined,
            color:
                isSpeaking ? const Color(0xFFCF6679) : const Color(0xFF8B949E),
            onTap: isSpeaking ? onStop : onSpeak,
          ),
          const SizedBox(width: 6),
          // Send button
          _IconBtn(
            icon: Icons.send_rounded,
            color: const Color(0xFF00BFA5),
            onTap: onSend,
          ),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _IconBtn(
      {required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}

// ── Empty chat placeholder ────────────────────────────────
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
          Text(
            'No messages yet',
            style: TextStyle(color: Color(0xFF8B949E), fontSize: 15),
          ),
          Text(
            'Use gestures or shortcuts to communicate',
            style: TextStyle(color: Color(0xFF8B949E), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

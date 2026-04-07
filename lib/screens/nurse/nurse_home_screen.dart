import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../providers/conversation_provider.dart';
import '../../models/message_model.dart';
import '../../widgets/message_bubble.dart';

class NurseHomeScreen extends StatefulWidget {
  const NurseHomeScreen({super.key});

  @override
  State<NurseHomeScreen> createState() => _NurseHomeScreenState();
}

class _NurseHomeScreenState extends State<NurseHomeScreen> {
  final _textCtrl = TextEditingController();
  bool _initialized = false;

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
      senderRole: MessageSender.nurse,
      type: type,
    );
    _textCtrl.clear();
    conv.clearLiveText();
  }

  Future<void> _toggleListening() async {
    final conv = context.read<ConversationProvider>();
    if (conv.isListening) {
      await conv.stopListening();
      // Auto-send what was heard
      if (conv.liveText.isNotEmpty) {
        await _sendMessage(conv.liveText, MessageType.speech);
      }
    } else {
      await conv.startListening();
    }
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
                color: const Color(0xFF3FB950).withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.medical_services_outlined,
                  color: Color(0xFF3FB950), size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.name ?? 'Nurse',
                  style: const TextStyle(
                      color: Color(0xFFE6EDF3),
                      fontSize: 15,
                      fontWeight: FontWeight.w600),
                ),
                const Text(
                  'Nurse Mode',
                  style: TextStyle(color: Color(0xFF3FB950), fontSize: 11),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFF8B949E)),
            onPressed: () async {
              await context.read<app_auth.AuthProvider>().logout();
              if (mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // ── STT Panel ───────────────────────────────
          _SttPanel(
            isListening: conv.isListening,
            liveText: conv.liveText,
            onToggle: _toggleListening,
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
                      final isMe = msg.senderRole == MessageSender.nurse;
                      return MessageBubble(
                        message: msg,
                        isMe: isMe,
                        onSpeak: () => conv.speakText(msg.text),
                      );
                    },
                  ),
          ),

          // ── Text Input Bar ───────────────────────────
          _NurseInputBar(
            controller: _textCtrl,
            isListening: conv.isListening,
            isSpeaking: conv.isSpeaking,
            liveText: conv.liveText,
            onSend: () => _sendMessage(_textCtrl.text, MessageType.text),
            onToggleMic: _toggleListening,
            onSpeakLive: () => conv.speakText(conv.liveText),
            onStop: () => conv.stopSpeaking(),
          ),
        ],
      ),
    );
  }
}

// ── STT Panel ─────────────────────────────────────────────
class _SttPanel extends StatelessWidget {
  final bool isListening;
  final String liveText;
  final VoidCallback onToggle;

  const _SttPanel({
    required this.isListening,
    required this.liveText,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isListening
              ? const Color(0xFF3FB950).withOpacity(0.5)
              : const Color(0xFF30363D),
          width: isListening ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Mic button
              GestureDetector(
                onTap: onToggle,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: isListening
                        ? const Color(0xFF3FB950).withOpacity(0.2)
                        : const Color(0xFF21262D),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isListening
                          ? const Color(0xFF3FB950)
                          : const Color(0xFF30363D),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    isListening ? Icons.mic : Icons.mic_none,
                    color: isListening
                        ? const Color(0xFF3FB950)
                        : const Color(0xFF8B949E),
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isListening ? 'Listening...' : 'Tap mic to speak',
                      style: TextStyle(
                        color: isListening
                            ? const Color(0xFF3FB950)
                            : const Color(0xFF8B949E),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isListening
                          ? 'Speak clearly — tap again to send'
                          : 'Voice will be converted to text',
                      style: const TextStyle(
                        color: Color(0xFF8B949E),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              // Pulse indicator
              if (isListening) _PulsingDot(),
            ],
          ),
          // Live transcript
          if (liveText.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1117),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF30363D)),
              ),
              child: Text(
                liveText,
                style: const TextStyle(
                  color: Color(0xFFE6EDF3),
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Pulsing dot for listening indicator ──────────────────
class _PulsingDot extends StatefulWidget {
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 12,
        height: 12,
        decoration: const BoxDecoration(
          color: Color(0xFF3FB950),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

// ── Nurse Input Bar ───────────────────────────────────────
class _NurseInputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isListening;
  final bool isSpeaking;
  final String liveText;
  final VoidCallback onSend;
  final VoidCallback onToggleMic;
  final VoidCallback onSpeakLive;
  final VoidCallback onStop;

  const _NurseInputBar({
    required this.controller,
    required this.isListening,
    required this.isSpeaking,
    required this.liveText,
    required this.onSend,
    required this.onToggleMic,
    required this.onSpeakLive,
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
          // Mic toggle
          GestureDetector(
            onTap: onToggleMic,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: isListening
                    ? const Color(0xFF3FB950).withOpacity(0.2)
                    : const Color(0xFF21262D),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isListening
                      ? const Color(0xFF3FB950)
                      : const Color(0xFF30363D),
                ),
              ),
              child: Icon(
                isListening ? Icons.mic : Icons.mic_none,
                color: isListening
                    ? const Color(0xFF3FB950)
                    : const Color(0xFF8B949E),
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Text field
          Expanded(
            child: TextField(
              controller: controller,
              style: const TextStyle(color: Color(0xFFE6EDF3)),
              decoration: InputDecoration(
                hintText: 'Type a reply...',
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
          // Speak live text button
          if (liveText.isNotEmpty)
            GestureDetector(
              onTap: isSpeaking ? onStop : onSpeakLive,
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6D00).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFFFF6D00).withOpacity(0.4)),
                ),
                child: Icon(
                  isSpeaking
                      ? Icons.stop_circle_outlined
                      : Icons.volume_up_outlined,
                  color: const Color(0xFFFF6D00),
                  size: 20,
                ),
              ),
            ),
          if (liveText.isNotEmpty) const SizedBox(width: 6),
          // Send button
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

// ── Empty chat ────────────────────────────────────────────
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
          Text('Patient messages will appear here',
              style: TextStyle(color: Color(0xFF8B949E), fontSize: 12)),
        ],
      ),
    );
  }
}

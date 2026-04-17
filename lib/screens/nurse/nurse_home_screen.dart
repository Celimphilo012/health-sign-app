import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import '../../providers/auth_provider.dart';
import '../../providers/conversation_provider.dart';
import '../../providers/chat_request_provider.dart';
import '../../models/message_model.dart';
import '../../models/user_model.dart';
import '../../widgets/message_bubble.dart';
import '../shared/nurse_chat_history_screen.dart';
import '../../services/haptic_service.dart';
import 'package:salomon_bottom_bar/salomon_bottom_bar.dart';
import '../../services/firestore_service.dart';
import '../../models/chat_request_model.dart';
import '../../services/notification_service.dart';
import '../../services/location_service.dart';

class NurseHomeScreen extends StatefulWidget {
  const NurseHomeScreen({super.key});

  @override
  State<NurseHomeScreen> createState() => _NurseHomeScreenState();
}

class _NurseHomeScreenState extends State<NurseHomeScreen> {
  int _currentIndex = 0;
  bool _initialized = false;
  int _lastCallCount = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final user = context.read<AuthProvider>().user;
      if (user != null) {
        final chatProvider = context.read<ChatRequestProvider>();
        chatProvider.loadPatients();
        chatProvider.listenForAcceptedRequest(user.uid);
        chatProvider.listenForPatientCalls();
        _saveNursePresence(user.uid);
      }
    }
  }

  @override
  void didUpdateWidget(NurseHomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  void _checkForNewCalls(List<ChatRequestModel> calls) {
    if (calls.length > _lastCallCount) {
      final newest = calls.first;
      final isEmergency = newest.urgency == 'emergency';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(
            children: [
              Icon(isEmergency ? Icons.emergency : Icons.notifications_active,
                  color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isEmergency
                      ? '🚨 EMERGENCY: ${newest.patientName} needs urgent help!'
                      : '🔔 ${newest.patientName} is calling for a nurse',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  setState(() => _currentIndex = 1);
                },
                child: const Text('View',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          backgroundColor:
              isEmergency ? const Color(0xFFCF6679) : const Color(0xFF00BFA5),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 8),
        ));
      });
    }
    _lastCallCount = calls.length;
  }

  Future<void> _saveNursePresence(String nurseId) async {
    final position = await LocationService().getCurrentPosition();
    if (position != null) {
      await NotificationService().saveNurseToken(
        nurseId: nurseId,
        latitude: position.latitude,
        longitude: position.longitude,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final chatProvider = context.watch<ChatRequestProvider>();
    final hasActiveChat = chatProvider.hasActiveChat;
    _checkForNewCalls(chatProvider.patientCalls);

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _NurseChatTab(user: user),
          _NursePatientsTab(user: user),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF161B22),
          border: Border(
            top: BorderSide(color: Color(0xFF30363D)),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SalomonBottomBar(
              currentIndex: _currentIndex,
              onTap: (i) => setState(() => _currentIndex = i),
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              items: [
                SalomonBottomBarItem(
                  icon: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.chat_bubble_outline),
                      // ✅ Notification dot when active chat
                      if (hasActiveChat && _currentIndex != 0)
                        Positioned(
                          top: -2,
                          right: -4,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFFCF6679),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                  activeIcon: const Icon(Icons.chat_bubble),
                  title: const Text('Chat'),
                  selectedColor: const Color(0xFF3FB950),
                  unselectedColor: const Color(0xFF8B949E),
                ),
                SalomonBottomBarItem(
                  icon: const Icon(Icons.people_outline),
                  activeIcon: const Icon(Icons.people),
                  title: const Text('Patients'),
                  selectedColor: const Color(0xFF3FB950),
                  unselectedColor: const Color(0xFF8B949E),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PatientCallCard extends StatelessWidget {
  final ChatRequestModel call;
  final UserModel nurse;
  final VoidCallback onAnswer;

  const _PatientCallCard({
    required this.call,
    required this.nurse,
    required this.onAnswer,
  });

  Future<void> _showDeclineDialog(BuildContext context) async {
    final reasons = [
      'Currently attending another patient',
      'Off duty — please call another nurse',
      'Outside my ward area',
      'Technical issue',
      'Other',
    ];

    String? selectedReason;
    final customCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: const Color(0xFF161B22),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF30363D)),
          ),
          title: const Text(
            'Decline Reason',
            style: TextStyle(
                color: Color(0xFFE6EDF3), fontWeight: FontWeight.w600),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Please select or type a reason:',
                  style: TextStyle(color: Color(0xFF8B949E), fontSize: 13),
                ),
                const SizedBox(height: 12),
                ...reasons.map((r) => RadioListTile<String>(
                      value: r,
                      groupValue: selectedReason,
                      onChanged: (v) => setState(() => selectedReason = v),
                      title: Text(r,
                          style: const TextStyle(
                              color: Color(0xFFE6EDF3), fontSize: 13)),
                      activeColor: const Color(0xFF00BFA5),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    )),
                if (selectedReason == 'Other') ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: customCtrl,
                    style: const TextStyle(color: Color(0xFFE6EDF3)),
                    decoration: InputDecoration(
                      hintText: 'Type your reason...',
                      hintStyle: const TextStyle(color: Color(0xFF8B949E)),
                      filled: true,
                      fillColor: const Color(0xFF21262D),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: Color(0xFF8B949E))),
            ),
            ElevatedButton(
              onPressed: selectedReason == null
                  ? null
                  : () async {
                      Navigator.pop(ctx);
                      final reason = selectedReason == 'Other'
                          ? customCtrl.text.trim()
                          : selectedReason!;
                      await FirestoreService().declineCallWithReason(
                        requestId: call.id,
                        reason: reason,
                      );
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFCF6679),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: const Text('Decline'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEmergency = call.urgency == 'emergency';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isEmergency
            ? const Color(0xFFCF6679).withOpacity(0.1)
            : const Color(0xFF3FB950).withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isEmergency
              ? const Color(0xFFCF6679).withOpacity(0.5)
              : const Color(0xFF3FB950).withOpacity(0.5),
          width: isEmergency ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _PulsingIcon(isEmergency: isEmergency),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      call.patientName,
                      style: const TextStyle(
                        color: Color(0xFFE6EDF3),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isEmergency
                          ? '🚨 Emergency — urgent help needed'
                          : '🔔 Requesting a nurse',
                      style: TextStyle(
                        color: isEmergency
                            ? const Color(0xFFCF6679)
                            : const Color(0xFF3FB950),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // ✅ Answer + Decline buttons
          Row(
            children: [
              // Decline with reason
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showDeclineDialog(context),
                  icon: const Icon(Icons.close,
                      size: 14, color: Color(0xFF8B949E)),
                  label: const Text('Decline',
                      style: TextStyle(color: Color(0xFF8B949E), fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF30363D)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Answer
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: onAnswer,
                  icon: const Icon(Icons.call, size: 14),
                  label: const Text('Answer',
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isEmergency
                        ? const Color(0xFFCF6679)
                        : const Color(0xFF3FB950),
                    foregroundColor: isEmergency ? Colors.white : Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PulsingIcon extends StatefulWidget {
  final bool isEmergency;
  const _PulsingIcon({required this.isEmergency});

  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.isEmergency ? 500 : 900),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color =
        widget.isEmergency ? const Color(0xFFCF6679) : const Color(0xFF3FB950);

    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(
          widget.isEmergency ? Icons.emergency : Icons.notifications_active,
          color: color,
          size: 22,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// ANIMATED BOTTOM NAV
// ══════════════════════════════════════════════════════════
class _AnimatedBottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const _AnimatedBottomNav({
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      {
        'icon': Icons.chat_bubble_outline,
        'activeIcon': Icons.chat_bubble,
        'label': 'Chat'
      },
      {
        'icon': Icons.people_outline,
        'activeIcon': Icons.people,
        'label': 'Patients'
      },
    ];

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF161B22),
        border: Border(top: BorderSide(color: Color(0xFF30363D))),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (i) {
              final isActive = currentIndex == i;
              final item = items[i];
              return GestureDetector(
                onTap: () => onTap(i),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutBack,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  decoration: BoxDecoration(
                    color: isActive
                        ? const Color(0xFF3FB950).withOpacity(0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          isActive
                              ? item['activeIcon'] as IconData
                              : item['icon'] as IconData,
                          key: ValueKey(isActive),
                          color: isActive
                              ? const Color(0xFF3FB950)
                              : const Color(0xFF8B949E),
                          size: 22,
                        ),
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutBack,
                        child: isActive
                            ? Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: Text(
                                  item['label'] as String,
                                  style: const TextStyle(
                                    color: Color(0xFF3FB950),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// TAB 1: CHAT
// ══════════════════════════════════════════════════════════
class _NurseChatTab extends StatefulWidget {
  final UserModel? user;
  const _NurseChatTab({this.user});

  @override
  State<_NurseChatTab> createState() => _NurseChatTabState();
}

class _NurseChatTabState extends State<_NurseChatTab> {
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  String? _lastConvId;
  int _lastMessageCount = 0;

  // ✅ ADD didChangeDependencies here (inside _NurseChatTabState)
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Auto-send when user stops talking
    context.read<ConversationProvider>().setOnSttStopped((text) {
      if (mounted && text.trim().isNotEmpty) {
        _sendMessage(text, MessageType.speech);
      }
    });
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
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

  // ✅ FIX #3: Auto-init conversation when nurse gets active chat
  void _maybeInitConversation(String? convId) {
    if (convId != null && convId.isNotEmpty && convId != _lastConvId) {
      _lastConvId = convId;

      HapticService.requestAccepted();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<ConversationProvider>().initWithConversationId(convId);
        }
      });
    }
  }

  Future<void> _sendMessage(String text, MessageType type) async {
    if (text.trim().isEmpty) return;
    final conv = context.read<ConversationProvider>();
    await conv.sendMessage(
      text: text,
      senderId: widget.user!.uid,
      senderRole: MessageSender.nurse,
      type: type,
    );
    _textCtrl.clear();
    conv.clearLiveText();
  }

  Future<void> _toggleListening() async {
    final conv = context.read<ConversationProvider>();

    if (conv.isListening) {
      // Stop listening first
      await conv.stopListening();

      // ✅ Small delay to let final words be captured
      await Future.delayed(const Duration(milliseconds: 500));

      // ✅ Read liveText AFTER stopping
      final text = context.read<ConversationProvider>().liveText;

      if (text.trim().isNotEmpty) {
        await _sendMessage(text, MessageType.speech);
      }
    } else {
      await conv.startListening();
    }
  }

  // ✅ FIX #4: End conversation properly clears state
  Future<void> _endConversation() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF30363D)),
        ),
        title: const Text(
          'End Conversation',
          style: TextStyle(color: Color(0xFFE6EDF3)),
        ),
        content: const Text(
          'Are you sure you want to end this conversation?',
          style: TextStyle(color: Color(0xFF8B949E)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF8B949E))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFCF6679),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('End'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      // ✅ Clear messages + end convo in Firestore
      context.read<ConversationProvider>().clearMessages();
      await context.read<ChatRequestProvider>().endConversation();
      _lastConvId = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatRequestProvider>();
    final activeRequest = chatProvider.activeRequest;
    final conv = context.watch<ConversationProvider>();

    // ✅ Auto-scroll on new message
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (conv.messages.length > _lastMessageCount) {
        _lastMessageCount = conv.messages.length;
        _scrollToBottom();
      }
    });

    // ✅ FIX #3: Auto-init conversation stream when active request arrives
    if (activeRequest != null) {
      _maybeInitConversation(activeRequest.conversationId);
    }

    // No active chat — show empty state
    if (activeRequest == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0D1117),
        appBar: _buildAppBar(context, null),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFF3FB950).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.chat_bubble_outline,
                    color: Color(0xFF3FB950), size: 36),
              ),
              const SizedBox(height: 16),
              const Text(
                'No active conversation',
                style: TextStyle(
                  color: Color(0xFFE6EDF3),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Go to Patients tab to start a conversation',
                style: TextStyle(color: Color(0xFF8B949E), fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF3FB950).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: const Color(0xFF3FB950).withOpacity(0.3)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.arrow_downward,
                        color: Color(0xFF3FB950), size: 16),
                    SizedBox(width: 6),
                    Text(
                      'Tap Patients below',
                      style: TextStyle(color: Color(0xFF3FB950), fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Active chat
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: _buildAppBar(context, activeRequest.patientName),
      body: Column(
        children: [
          _SttPanel(
            isListening: conv.isListening,
            liveText: conv.liveText,
            onToggle: _toggleListening,
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
                      final isMe = msg.senderRole == MessageSender.nurse;
                      return MessageBubble(
                        message: msg,
                        isMe: isMe,
                        onSpeak: () => conv.speakText(msg.text),
                      );
                    },
                  ),
          ),
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

  AppBar _buildAppBar(BuildContext context, String? patientName) {
    return AppBar(
      backgroundColor: const Color(0xFF161B22),
      automaticallyImplyLeading: false,
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
                widget.user?.name ?? 'Nurse',
                style: const TextStyle(
                    color: Color(0xFFE6EDF3),
                    fontSize: 15,
                    fontWeight: FontWeight.w600),
              ),
              if (patientName != null)
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF58A6FF),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Patient: $patientName',
                      style: const TextStyle(
                          color: Color(0xFF58A6FF), fontSize: 11),
                    ),
                  ],
                )
              else
                const Text('Nurse Mode',
                    style: TextStyle(color: Color(0xFF3FB950), fontSize: 11)),
            ],
          ),
        ],
      ),
      actions: [
        // ✅ FIX #5: History button
        IconButton(
          icon: const Icon(Icons.history, color: Color(0xFF8B949E), size: 20),
          tooltip: 'Chat History',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const NurseChatHistoryScreen(),
            ),
          ),
        ),
        // End conversation button (only when active)
        if (patientName != null)
          TextButton.icon(
            onPressed: _endConversation,
            icon:
                const Icon(Icons.call_end, color: Color(0xFFCF6679), size: 16),
            label: const Text('End',
                style: TextStyle(color: Color(0xFFCF6679), fontSize: 12)),
          ),
        IconButton(
          icon: const Icon(Icons.logout, color: Color(0xFF8B949E), size: 20),
          onPressed: () async {
            context.read<ConversationProvider>().clearMessages();
            await context.read<AuthProvider>().logout();
            if (context.mounted) {
              Navigator.pushReplacementNamed(context, '/login');
            }
          },
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════
// TAB 2: PATIENTS
// ══════════════════════════════════════════════════════════
class _NursePatientsTab extends StatefulWidget {
  final UserModel? user;
  const _NursePatientsTab({this.user});

  @override
  State<_NursePatientsTab> createState() => _NursePatientsTabState();
}

class _NursePatientsTabState extends State<_NursePatientsTab> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatRequestProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF3FB950).withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child:
                  const Icon(Icons.people, color: Color(0xFF3FB950), size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'Patients',
              style: TextStyle(
                  color: Color(0xFFE6EDF3),
                  fontSize: 16,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF8B949E), size: 20),
            onPressed: () {
              provider.loadPatients();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          StreamBuilder<List<ChatRequestModel>>(
            stream: FirestoreService().getPatientCallsStream(),
            builder: (context, snapshot) {
              final calls = snapshot.data ?? [];
              if (calls.isEmpty) return const SizedBox.shrink();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFFCF6679),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${calls.length} patient call(s) waiting',
                          style: const TextStyle(
                            color: Color(0xFFCF6679),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...calls.map((call) => _PatientCallCard(
                        call: call,
                        nurse: widget.user!,
                        onAnswer: () async {
                          final convId = await FirestoreService().answerCall(
                            requestId: call.id,
                            nurseId: widget.user!.uid,
                            nurseName: widget.user!.name,
                            patientId: call.patientId,
                          );
                          if (context.mounted) {
                            context
                                .read<ConversationProvider>()
                                .initWithConversationId(convId);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content:
                                    Text('Connected with ${call.patientName}'),
                                backgroundColor: const Color(0xFF3FB950),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            );
                          }
                        },
                      )),
                  const Divider(color: Color(0xFF30363D), height: 1),
                ],
              );
            },
          ),
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(color: Color(0xFFE6EDF3)),
              onChanged: (q) {
                setState(() {});
                provider.searchPatients(q);
              },
              decoration: InputDecoration(
                hintText: 'Search patients by name...',
                hintStyle: const TextStyle(color: Color(0xFF8B949E)),
                prefixIcon: const Icon(Icons.search,
                    color: Color(0xFF8B949E), size: 20),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear,
                            color: Color(0xFF8B949E), size: 18),
                        onPressed: () {
                          setState(() => _searchCtrl.clear());
                          provider.clearSearch();
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFF21262D),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.people_outline,
                    size: 14, color: Color(0xFF8B949E)),
                const SizedBox(width: 6),
                Text(
                  '${provider.filteredPatients.length} patient(s) registered',
                  style:
                      const TextStyle(color: Color(0xFF8B949E), fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          Expanded(
            child: provider.isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF3FB950),
                      strokeWidth: 2,
                    ),
                  )
                : provider.filteredPatients.isEmpty
                    ? const _EmptyPatients()
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: provider.filteredPatients.length,
                        itemBuilder: (_, i) {
                          final patient = provider.filteredPatients[i];
                          return _PatientCard(
                            patient: patient,
                            onRequest: () async {
                              if (widget.user == null) return;
                              final success = await provider.sendRequest(
                                nurse: widget.user!,
                                patient: patient,
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      success
                                          ? '✓ Request sent to ${patient.name}'
                                          : 'Failed to send request',
                                    ),
                                    backgroundColor: success
                                        ? const Color(0xFF3FB950)
                                        : const Color(0xFFCF6679),
                                    behavior: SnackBarBehavior.floating,
                                    margin: const EdgeInsets.all(12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                );
                              }
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _PatientCard extends StatelessWidget {
  final UserModel patient;
  final VoidCallback onRequest;

  const _PatientCard({
    required this.patient,
    required this.onRequest,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFF58A6FF).withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                patient.name.isNotEmpty ? patient.name[0].toUpperCase() : 'P',
                style: const TextStyle(
                  color: Color(0xFF58A6FF),
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
                  patient.name,
                  style: const TextStyle(
                    color: Color(0xFFE6EDF3),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  patient.email,
                  style: const TextStyle(
                    color: Color(0xFF8B949E),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF58A6FF).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Patient',
                    style: TextStyle(
                        color: Color(0xFF58A6FF),
                        fontSize: 10,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: onRequest,
            icon: const Icon(Icons.chat_bubble_outline, size: 14),
            label: const Text('Chat', style: TextStyle(fontSize: 12)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3FB950),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyPatients extends StatelessWidget {
  const _EmptyPatients();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 52, color: Color(0xFF30363D)),
          SizedBox(height: 12),
          Text('No patients found',
              style: TextStyle(color: Color(0xFF8B949E), fontSize: 15)),
          SizedBox(height: 6),
          Text('Patients appear here once they register',
              style: TextStyle(color: Color(0xFF8B949E), fontSize: 12)),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(14),
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
              GestureDetector(
                onTap: onToggle,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 54,
                  height: 54,
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
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(width: 12),
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
                    const Text(
                      'Voice → text → send to patient',
                      style: TextStyle(color: Color(0xFF8B949E), fontSize: 11),
                    ),
                  ],
                ),
              ),
              if (isListening) _PulsingDot(),
            ],
          ),
          if (liveText.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1117),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF30363D)),
              ),
              child: Text(
                liveText,
                style: const TextStyle(color: Color(0xFFE6EDF3), fontSize: 14),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

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
        vsync: this, duration: const Duration(milliseconds: 700))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 1.0).animate(_ctrl);
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
        width: 10,
        height: 10,
        decoration: const BoxDecoration(
          color: Color(0xFF3FB950),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

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
          if (liveText.isNotEmpty) ...[
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
            const SizedBox(width: 6),
          ],
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
          Text('Patient messages will appear here',
              style: TextStyle(color: Color(0xFF8B949E), fontSize: 12)),
        ],
      ),
    );
  }
}

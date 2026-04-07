import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/conversation_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/message_model.dart';
import '../../widgets/message_bubble.dart';

class ConversationHistoryScreen extends StatelessWidget {
  const ConversationHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final conv = context.watch<ConversationProvider>();
    final auth = context.watch<AuthProvider>();
    final messages = conv.messages;

    // Group messages by date
    final grouped = _groupByDate(messages);

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        title: const Text(
          'Conversation History',
          style: TextStyle(
            color: Color(0xFFE6EDF3),
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios,
              color: Color(0xFFE6EDF3), size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '${messages.length} messages',
                style: const TextStyle(
                  color: Color(0xFF8B949E),
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
      body: messages.isEmpty
          ? const _EmptyHistory()
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: grouped.length,
              itemBuilder: (_, i) {
                final entry = grouped[i];
                if (entry['type'] == 'date') {
                  return _DateDivider(label: entry['label']!);
                }
                final msg = entry['message'] as MessageModel;
                final isMe =
                    auth.user != null && msg.senderId == auth.user!.uid;
                return MessageBubble(
                  message: msg,
                  isMe: isMe,
                  onSpeak: () => conv.speakText(msg.text),
                );
              },
            ),
    );
  }

  List<Map<String, dynamic>> _groupByDate(List<MessageModel> messages) {
    final result = <Map<String, dynamic>>[];
    String? lastDate;

    for (final msg in messages) {
      final dateStr = DateFormat('MMMM d, yyyy').format(msg.timestamp);
      if (dateStr != lastDate) {
        result.add({'type': 'date', 'label': dateStr});
        lastDate = dateStr;
      }
      result.add({'type': 'message', 'message': msg});
    }

    return result;
  }
}

class _DateDivider extends StatelessWidget {
  final String label;
  const _DateDivider({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          const Expanded(child: Divider(color: Color(0xFF30363D), height: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF8B949E),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Expanded(child: Divider(color: Color(0xFF30363D), height: 1)),
        ],
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 56, color: Color(0xFF30363D)),
          SizedBox(height: 16),
          Text(
            'No conversation history',
            style: TextStyle(
              color: Color(0xFF8B949E),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Messages will appear here once you start communicating',
            style: TextStyle(color: Color(0xFF8B949E), fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

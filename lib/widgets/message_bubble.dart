import 'package:flutter/material.dart';
import '../models/message_model.dart';

class MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;
  final VoidCallback? onSpeak;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.onSpeak,
  });

  @override
  Widget build(BuildContext context) {
    final bubbleColor = isMe
        ? const Color(0xFF00BFA5).withOpacity(0.2)
        : const Color(0xFF21262D);
    final borderColor = isMe
        ? const Color(0xFF00BFA5).withOpacity(0.5)
        : const Color(0xFF30363D);
    final align = isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final radius = isMe
        ? const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(4),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
          );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      child: Column(
        crossAxisAlignment: align,
        children: [
          // Role label
          Padding(
            padding: const EdgeInsets.only(bottom: 4, left: 4, right: 4),
            child: Text(
              message.typeLabel,
              style: const TextStyle(
                color: Color(0xFF8B949E),
                fontSize: 11,
              ),
            ),
          ),
          // Bubble
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: radius,
              border: Border.all(color: borderColor),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.text,
                  style: const TextStyle(
                    color: Color(0xFFE6EDF3),
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatTime(message.timestamp),
                      style: const TextStyle(
                        color: Color(0xFF8B949E),
                        fontSize: 10,
                      ),
                    ),
                    if (onSpeak != null) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: onSpeak,
                        child: const Icon(
                          Icons.volume_up_outlined,
                          size: 14,
                          color: Color(0xFF8B949E),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

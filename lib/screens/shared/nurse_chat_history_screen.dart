import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../models/chat_request_model.dart';
import '../../services/firestore_service.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;

class NurseChatHistoryScreen extends StatelessWidget {
  const NurseChatHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    if (user == null) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios,
              color: Color(0xFFE6EDF3), size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Chat History',
          style: TextStyle(
            color: Color(0xFFE6EDF3),
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: StreamBuilder<List<ChatRequestModel>>(
        stream: FirestoreService().getNurseChatHistoryStream(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF3FB950),
                strokeWidth: 2,
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading history',
                style: TextStyle(color: Colors.red.shade300),
              ),
            );
          }

          final history = snapshot.data ?? [];

          if (history.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history,
                      size: 56, color: Color(0xFF30363D)),
                  SizedBox(height: 16),
                  Text(
                    'No chat history yet',
                    style: TextStyle(
                      color: Color(0xFF8B949E),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Ended conversations will appear here',
                    style: TextStyle(
                        color: Color(0xFF8B949E), fontSize: 12),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: history.length,
            itemBuilder: (_, i) {
              final chat = history[i];
              return _HistoryCard(chat: chat);
            },
          );
        },
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final ChatRequestModel chat;
  const _HistoryCard({required this.chat});

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('MMM d, yyyy • h:mm a').format(chat.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFF58A6FF).withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                chat.patientName.isNotEmpty
                    ? chat.patientName[0].toUpperCase()
                    : 'P',
                style: const TextStyle(
                  color: Color(0xFF58A6FF),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  chat.patientName,
                  style: const TextStyle(
                    color: Color(0xFFE6EDF3),
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.access_time,
                        size: 11, color: Color(0xFF8B949E)),
                    const SizedBox(width: 4),
                    Text(
                      date,
                      style: const TextStyle(
                        color: Color(0xFF8B949E),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Ended badge
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF8B949E).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: const Color(0xFF8B949E).withOpacity(0.3)),
            ),
            child: const Text(
              'Ended',
              style: TextStyle(
                color: Color(0xFF8B949E),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
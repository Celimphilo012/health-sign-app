import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/conversation_provider.dart';
import '../../services/gesture_service.dart';

class GestureDemoScreen extends StatefulWidget {
  const GestureDemoScreen({super.key});

  @override
  State<GestureDemoScreen> createState() => _GestureDemoScreenState();
}

class _GestureDemoScreenState extends State<GestureDemoScreen> {
  String _selectedGesture = '';
  bool _isSpeaking = false;

  final List<Map<String, String>> _allGestures =
      GestureService.gestureMap.entries
          .where((e) => e.key != 'None')
          .map((e) => {
                'key': e.key,
                'text': e.value,
                'emoji': GestureService.gestureEmoji[e.key] ?? '🤚',
              })
          .toList();

  Future<void> _demoGesture(Map<String, String> gesture) async {
    setState(() {
      _selectedGesture = gesture['key']!;
      _isSpeaking = true;
    });

    final conv = context.read<ConversationProvider>();
    await conv.speakText(gesture['text']!);

    if (mounted) {
      setState(() => _isSpeaking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        title: const Text(
          'Gesture Reference',
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
      ),
      body: Column(
        children: [
          // Header
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF161B22),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF30363D)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00BFA5).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.sign_language,
                    color: Color(0xFF00BFA5),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Supported Gestures',
                        style: TextStyle(
                          color: Color(0xFFE6EDF3),
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'Tap any gesture to hear it spoken aloud',
                        style: TextStyle(
                          color: Color(0xFF8B949E),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Gesture grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.4,
              ),
              itemCount: _allGestures.length,
              itemBuilder: (_, i) {
                final g = _allGestures[i];
                final isSelected = _selectedGesture == g['key'];

                return GestureDetector(
                  onTap: () => _demoGesture(g),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF00BFA5).withOpacity(0.15)
                          : const Color(0xFF161B22),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF00BFA5)
                            : const Color(0xFF30363D),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          g['emoji']!,
                          style: const TextStyle(fontSize: 32),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          g['text']!,
                          style: TextStyle(
                            color: isSelected
                                ? const Color(0xFF00BFA5)
                                : const Color(0xFFE6EDF3),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (isSelected && _isSpeaking) ...[
                          const SizedBox(height: 4),
                          const Text(
                            '🔊 Speaking...',
                            style: TextStyle(
                              color: Color(0xFF00BFA5),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

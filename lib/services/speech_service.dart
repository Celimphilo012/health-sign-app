import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class SpeechService {
  final FlutterTts _tts = FlutterTts();
  final stt.SpeechToText _stt = stt.SpeechToText();

  bool _sttInitialized = false;
  bool get isSttInitialized => _sttInitialized;

  // ── TTS Setup ─────────────────────────────────────────
  Future<void> initTts() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.45);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
  }

  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> stopSpeaking() async {
    await _tts.stop();
  }

  void setTtsCompletionHandler(VoidCallback onComplete) {
    _tts.setCompletionHandler(onComplete);
  }

  // ── STT Setup ─────────────────────────────────────────
  Future<bool> initStt() async {
    _sttInitialized = await _stt.initialize(
      onError: (error) => print('STT error: $error'),
      onStatus: (status) => print('STT status: $status'),
    );
    return _sttInitialized;
  }

  Future<void> startListening({
    required Function(String text) onResult,
    required Function(bool isListening) onListeningChanged,
  }) async {
    if (!_sttInitialized) await initStt();
    if (!_sttInitialized) return;

    await _stt.listen(
      onResult: (result) {
        onResult(result.recognizedWords);
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 4),
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        cancelOnError: false,
      ),
    );
    onListeningChanged(true);
  }

  Future<void> stopListening({
    required Function(bool isListening) onListeningChanged,
  }) async {
    await _stt.stop();
    onListeningChanged(false);
  }

  bool get isListening => _stt.isListening;

  void dispose() {
    _tts.stop();
    _stt.stop();
  }
}

// needed for setTtsCompletionHandler
typedef VoidCallback = void Function();

import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

/// TFLite-based gesture classifier
/// Uses hand landmark coordinates as input
class TFLiteClassifier {
  Interpreter? _interpreter;
  List<String> _labels = [];
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;

  // ── Gesture labels (matches model output) ─────────────
  static const List<String> defaultLabels = [
    'Open_Palm',
    'Closed_Fist',
    'Thumb_Up',
    'Thumb_Down',
    'Victory',
    'Pointing_Up',
    'ILoveYou',
    'None',
  ];

  // ── Load model ────────────────────────────────────────
  Future<void> loadModel() async {
    try {
      // Load TFLite model from assets
      _interpreter = await Interpreter.fromAsset(
        'assets/models/gesture_model.tflite',
        options: InterpreterOptions()..threads = 2,
      );

      // Load labels
      try {
        final labelsData =
            await rootBundle.loadString('assets/models/gesture_labels.txt');
        _labels =
            labelsData.split('\n').where((l) => l.trim().isNotEmpty).toList();
      } catch (_) {
        _labels = defaultLabels;
      }

      _isLoaded = true;
      print('TFLite model loaded successfully');
      print('Input shape: ${_interpreter!.getInputTensor(0).shape}');
      print('Output shape: ${_interpreter!.getOutputTensor(0).shape}');
    } catch (e) {
      _isLoaded = false;
      print('TFLite load error: $e — using mock mode');
    }
  }

  // ── Run inference on hand landmarks ───────────────────
  // Input: 21 hand landmarks × 3 coordinates (x, y, z) = 63 floats
  Future<Map<String, dynamic>> classify(List<double> landmarks) async {
    if (!_isLoaded || _interpreter == null) {
      return _mockClassify(landmarks);
    }

    try {
      // Prepare input tensor [1, 63]
      final input = [landmarks];
      final outputSize = _labels.length;
      final output = [List<double>.filled(outputSize, 0.0)];

      _interpreter!.run(input, output);

      // Get highest confidence result
      final scores = output[0];
      double maxScore = 0;
      int maxIdx = scores.length - 1; // Default to 'None'

      for (int i = 0; i < scores.length; i++) {
        if (scores[i] > maxScore) {
          maxScore = scores[i];
          maxIdx = i;
        }
      }

      final gesture = maxIdx < _labels.length ? _labels[maxIdx] : 'None';

      return {
        'gesture': gesture,
        'confidence': maxScore,
        'scores': scores,
      };
    } catch (e) {
      print('Inference error: $e');
      return {'gesture': 'None', 'confidence': 0.0};
    }
  }

  // ── Mock classify for demo ─────────────────────────────
  Map<String, dynamic> _mockClassify(List<double> landmarks) {
    if (landmarks.isEmpty) {
      return {'gesture': 'None', 'confidence': 0.0};
    }
    // Use landmark variance to detect gross gestures
    double variance = _calculateVariance(landmarks);

    if (variance < 0.01) {
      return {'gesture': 'Closed_Fist', 'confidence': 0.82};
    } else if (variance > 0.05) {
      return {'gesture': 'Open_Palm', 'confidence': 0.79};
    }
    return {'gesture': 'None', 'confidence': 0.0};
  }

  double _calculateVariance(List<double> values) {
    if (values.isEmpty) return 0;
    final mean = values.reduce((a, b) => a + b) / values.length;
    final variance =
        values.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) /
            values.length;
    return variance;
  }

  void dispose() {
    _interpreter?.close();
    _isLoaded = false;
  }
}

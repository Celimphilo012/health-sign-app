import 'dart:io';
import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';

class GestureService {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isInitialized = false;
  bool _isDetecting = false;
  bool _isProcessing = false;

  // Gesture detection callback
  Function(String gesture, String text, double confidence)? _onGestureDetected;

  CameraController? get controller => _controller;
  bool get isInitialized => _isInitialized;
  bool get isDetecting => _isDetecting;

  // ── Gesture definitions ───────────────────────────────
  // Maps gesture names to display text
  static const Map<String, String> gestureMap = {
    'Open_Palm': 'Stop / Wait',
    'Closed_Fist': 'I am in pain',
    'Thumb_Up': 'Yes / I agree',
    'Thumb_Down': 'No / I disagree',
    'Victory': 'I am okay / Peace',
    'Pointing_Up': 'I need attention',
    'ILoveYou': 'I love you / Thank you',
    'None': '',
  };

  static const Map<String, String> gestureEmoji = {
    'Open_Palm': '✋',
    'Closed_Fist': '✊',
    'Thumb_Up': '👍',
    'Thumb_Down': '👎',
    'Victory': '✌️',
    'Pointing_Up': '☝️',
    'ILoveYou': '🤟',
    'None': '🤚',
  };

  // ── Initialize camera ─────────────────────────────────
  Future<void> initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) return;

      final camera = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras.first,
      );

      _controller = CameraController(
        camera,
        ResolutionPreset.low, // Lower for faster ML processing
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21, // Best for ML Kit
      );

      await _controller!.initialize();
      _isInitialized = true;
    } catch (e) {
      _isInitialized = false;
      debugPrint('Camera init error: $e');
    }
  }

  // ── Start gesture detection ───────────────────────────
  Future<void> startDetection({
    required Function(String gesture, String text, double confidence)
        onGestureDetected,
  }) async {
    if (!_isInitialized || _controller == null) return;
    _onGestureDetected = onGestureDetected;
    _isDetecting = true;

    await _controller!.startImageStream((CameraImage image) async {
      if (_isProcessing || !_isDetecting) return;
      _isProcessing = true;

      try {
        await _processFrame(image);
      } catch (e) {
        debugPrint('Frame processing error: $e');
      } finally {
        _isProcessing = false;
      }
    });
  }

  // ── Process camera frame ──────────────────────────────
  Future<void> _processFrame(CameraImage image) async {
    // Run in isolate to avoid blocking UI
    final result = await compute(_analyzeFrame, {
      'planes': image.planes
          .map((p) => {
                'bytes': p.bytes,
                'bytesPerRow': p.bytesPerRow,
                'bytesPerPixel': p.bytesPerPixel,
                'width': image.width,
                'height': image.height,
              })
          .toList(),
      'width': image.width,
      'height': image.height,
      'format': image.format.raw,
    });

    if (result != null && _onGestureDetected != null) {
      final gestureName = result['gesture'] as String;
      final confidence = result['confidence'] as double;

      if (gestureName != 'None' && confidence > 0.75) {
        final text = gestureMap[gestureName] ?? '';
        _onGestureDetected!(gestureName, text, confidence);
      }
    }
  }

  void stopDetection() {
    _isDetecting = false;
    _isProcessing = false;
    if (_controller != null && _controller!.value.isStreamingImages) {
      _controller!.stopImageStream();
    }
  }

  Future<void> switchCamera() async {
    if (_cameras.length < 2) return;
    stopDetection();
    final current = _controller!.description;
    final next = _cameras.firstWhere(
      (c) => c != current,
      orElse: () => _cameras.first,
    );
    await _controller?.dispose();
    _controller = CameraController(
      next,
      ResolutionPreset.low,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.nv21,
    );
    await _controller!.initialize();
  }

  Future<void> dispose() async {
    stopDetection();
    await _controller?.dispose();
    _controller = null;
    _isInitialized = false;
  }
}

// ── Top-level function for compute isolate ────────────────
Map<String, dynamic>? _analyzeFrame(Map<String, dynamic> data) {
  try {
    // Extract frame data
    final width = data['width'] as int;
    final height = data['height'] as int;
    final planes = data['planes'] as List;

    if (planes.isEmpty) return null;

    final yPlane = planes[0];
    final yBytes = yPlane['bytes'] as Uint8List;

    // Simple brightness-based hand detection mock
    // In production: replace with actual TFLite inference
    return _mockGestureDetection(yBytes, width, height);
  } catch (e) {
    return null;
  }
}

// ── Mock gesture logic (replace with TFLite) ─────────────
Map<String, dynamic> _mockGestureDetection(
    Uint8List bytes, int width, int height) {
  // Analyze pixel brightness in center region
  // This is a placeholder — real model goes here
  int centerBrightness = 0;
  int count = 0;

  final centerX = width ~/ 2;
  final centerY = height ~/ 2;
  final regionSize = min(width, height) ~/ 4;

  for (int y = centerY - regionSize; y < centerY + regionSize; y++) {
    for (int x = centerX - regionSize; x < centerX + regionSize; x++) {
      if (x >= 0 && x < width && y >= 0 && y < height) {
        centerBrightness += bytes[y * width + x];
        count++;
      }
    }
  }

  // Just return None for mock — buttons handle gestures
  return {'gesture': 'None', 'confidence': 0.0};
}

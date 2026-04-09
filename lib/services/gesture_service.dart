import 'dart:io';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class GestureService {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isInitialized = false;
  bool _isDetecting = false;
  bool _isProcessing = false;

  late PoseDetector _poseDetector;

  CameraController? get controller => _controller;
  bool get isInitialized => _isInitialized;
  bool get isDetecting => _isDetecting;

  static const Map<String, String> gestureMap = {
    'Open_Palm': 'Stop / Wait',
    'Closed_Fist': 'I am in pain',
    'Thumb_Up': 'Yes / I agree',
    'Thumb_Down': 'No / I disagree',
    'Victory': 'I am okay',
    'Pointing_Up': 'I need attention',
    'None': '',
    'Wave': 'Hello / Goodbye',
    'Hand_on_chest': 'I have chest pain',
    'Head_touch': 'I have a headache',
    'Arms_crossed': 'I am cold',
    'Hand_on_belly': 'I have stomach pain',
  };

  static const Map<String, String> gestureEmoji = {
    'Open_Palm': '✋',
    'Closed_Fist': '✊',
    'Thumb_Up': '👍',
    'Thumb_Down': '👎',
    'Victory': '✌️',
    'Pointing_Up': '☝️',
    'None': '🤚',
    'Wave': '👋',
    'Hand_on_chest': '💔',
    'Head_touch': '🤕',
    'Arms_crossed': '🥶',
    'Hand_on_belly': '🤢',
  };

  Future<void> initCamera() async {
    try {
      _poseDetector = PoseDetector(
        options: PoseDetectorOptions(
          mode: PoseDetectionMode.stream,
          model: PoseDetectionModel.accurate,
        ),
      );

      _cameras = await availableCameras();
      if (_cameras.isEmpty) return;

      final camera = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras.first,
      );

      _controller = CameraController(
        camera,
        ResolutionPreset.low,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );

      await _controller!.initialize();
      _isInitialized = true;
    } catch (e) {
      _isInitialized = false;
      debugPrint('Camera init error: $e');
    }
  }

  Future<void> startDetection({
    required Function(String gesture, String text, double confidence)
        onGestureDetected,
  }) async {
    if (!_isInitialized || _controller == null) return;
    _isDetecting = true;

    String _lastGesture = '';
    int _count = 0;

    await _controller!.startImageStream((CameraImage image) async {
      if (_isProcessing || !_isDetecting) return;
      _isProcessing = true;

      try {
        final inputImage = _toInputImage(image);
        if (inputImage == null) {
          _isProcessing = false;
          return;
        }

        final poses = await _poseDetector.processImage(inputImage);
        final gesture = _classifyFromPose(poses);

        if (gesture != null && gesture != 'None') {
          if (gesture == _lastGesture) {
            _count++;
            if (_count == 4) {
              onGestureDetected(
                gesture,
                gestureMap[gesture] ?? '',
                0.82,
              );
            }
          } else {
            _lastGesture = gesture;
            _count = 1;
          }
        } else {
          _count = 0;
        }
      } catch (e) {
        debugPrint('Detection error: $e');
      } finally {
        _isProcessing = false;
      }
    });
  }

  // ── Classify gesture from pose landmarks ──────────────
  // Uses wrist + elbow positions for basic gesture detection
  String? _classifyFromPose(List<Pose> poses) {
    if (poses.isEmpty) return 'None';

    final pose = poses.first;
    final landmarks = pose.landmarks;

    // Get hand/wrist landmarks
    final leftWrist = landmarks[PoseLandmarkType.leftWrist];
    final rightWrist = landmarks[PoseLandmarkType.rightWrist];
    final leftElbow = landmarks[PoseLandmarkType.leftElbow];
    final rightElbow = landmarks[PoseLandmarkType.rightElbow];
    final leftShoulder = landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = landmarks[PoseLandmarkType.rightShoulder];
    final nose = landmarks[PoseLandmarkType.nose];

    if (leftWrist == null && rightWrist == null) return 'None';

    // Use the more confident hand
    final wrist = (rightWrist?.likelihood ?? 0) > (leftWrist?.likelihood ?? 0)
        ? rightWrist
        : leftWrist;
    final elbow = wrist == rightWrist ? rightElbow : leftElbow;
    final shoulder = wrist == rightWrist ? rightShoulder : leftShoulder;

    if (wrist == null || wrist.likelihood < 0.5) return 'None';

    // ── Gesture detection using body positions ─────────

    // ✋ Open Palm / Stop: wrist raised above shoulder
    if (shoulder != null && wrist.y < shoulder.y - 50) {
      return 'Open_Palm';
    }

    // 👍 Thumb Up: wrist above elbow, arm pointing up
    if (elbow != null &&
        wrist.y < elbow.y - 30 &&
        nose != null &&
        wrist.y < nose.y) {
      return 'Thumb_Up';
    }

    // 👎 Thumb Down: wrist below elbow pointing down
    if (elbow != null && wrist.y > elbow.y + 40) {
      return 'Thumb_Down';
    }

    // ☝️ Pointing: wrist raised to face level
    if (nose != null && wrist.y < nose.y + 30 && wrist.y > nose.y - 80) {
      return 'Pointing_Up';
    }

    // ✊ Fist/Pain: wrist near chest level
    if (shoulder != null &&
        wrist.y > shoulder.y - 20 &&
        wrist.y < shoulder.y + 80) {
      return 'Closed_Fist';
    }
    // ✋ Open Palm: wrist above shoulder
    if (shoulder != null && wrist.y < shoulder.y - 50) {
      return 'Open_Palm';
    }

    // ── NEW HOSPITAL GESTURES ─────────────────────────────

    // 👋 Wave: wrist moves rapidly side to side above shoulder
    // (detect by wrist being high + x position varying)
    if (shoulder != null &&
        wrist.y < shoulder.y &&
        wrist.x > 200 &&
        wrist.x < 500) {
      return 'Wave';
    }

    // 💔 Hand on chest: wrist very close to chest/shoulder level
    // and close to body center (x near nose x)
    if (nose != null &&
        shoulder != null &&
        (wrist.y - shoulder.y).abs() < 40 &&
        (wrist.x - nose.x).abs() < 80) {
      return 'Hand_on_chest';
    }

    // 🤕 Head touch: wrist is at or above head (above nose)
    if (nose != null && wrist.y < nose.y - 40) {
      return 'Head_touch';
    }

    // 🥶 Arms crossed: both wrists visible and crossing midpoint
    final leftW = landmarks[PoseLandmarkType.leftWrist];
    final rightW = landmarks[PoseLandmarkType.rightWrist];
    if (leftW != null && rightW != null) {
      final midX = (leftW.x + rightW.x) / 2;
      // Left wrist is to the right of midpoint = arms crossed
      if (leftW.x > midX + 30 && rightW.x < midX - 30) {
        return 'Arms_crossed';
      }
    }

    // 🤢 Hand on belly: wrist below shoulder and near center
    if (shoulder != null &&
        nose != null &&
        wrist.y > shoulder.y + 60 &&
        wrist.y < shoulder.y + 180 &&
        (wrist.x - nose.x).abs() < 100) {
      return 'Hand_on_belly';
    }

    return 'None';
  }

  InputImage? _toInputImage(CameraImage image) {
    try {
      final camera = _controller!.description;
      final sensorOrientation = camera.sensorOrientation;

      var rotationCompensation = sensorOrientation;
      if (camera.lensDirection == CameraLensDirection.front) {
        rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
      }

      final rotation =
          InputImageRotationValue.fromRawValue(rotationCompensation);
      if (rotation == null) return null;

      final format = InputImageFormatValue.fromRawValue(image.format.raw);
      if (format == null) return null;

      if (image.planes.isEmpty) return null;
      final plane = image.planes.first;

      return InputImage.fromBytes(
        bytes: plane.bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: format,
          bytesPerRow: plane.bytesPerRow,
        ),
      );
    } catch (e) {
      return null;
    }
  }

  void stopDetection() {
    _isDetecting = false;
    _isProcessing = false;
    try {
      if (_controller != null && _controller!.value.isStreamingImages) {
        _controller!.stopImageStream();
      }
    } catch (e) {
      debugPrint('Stop stream error: $e');
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
    await _poseDetector.close();
    await _controller?.dispose();
    _controller = null;
    _isInitialized = false;
  }
}

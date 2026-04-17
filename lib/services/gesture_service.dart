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
    // ── Basic responses ───────────────────────────────
    'Open_Palm': 'Stop / Wait',
    'Closed_Fist': 'I am in pain',
    'Thumb_Up': 'Yes / I agree',
    'Thumb_Down': 'No / I disagree',
    'Victory': 'I am okay',
    'Pointing_Up': 'I need attention',
    'Wave': 'Hello / Goodbye',
    'None': '',

    // ── Pain & medical ────────────────────────────────
    'Hand_on_chest': 'I have chest pain',
    'Head_touch': 'I have a headache',
    'Arms_crossed': 'I feel cold',
    'Hand_on_belly': 'I feel nauseous',
    'Throat_touch': 'I have a sore throat / I am thirsty',
    'Both_hands_chest': 'I have difficulty breathing',
    'Scratch_arm': 'I am itching',
    'Cup_area': 'I have swelling',

    // ── Urgency & emergency ───────────────────────────
    'Hands_on_throat': 'I cannot breathe — EMERGENCY',
    'Hand_over_mouth': 'I am going to vomit',
    'Point_wound': 'I am bleeding',
    'Allergic': 'I am having an allergic reaction',
    'Pain_worse': 'My pain is getting worse',
    'Pain_better': 'My pain is getting better',

    // ── Basic needs ───────────────────────────────────
    'Rub_stomach': 'I am hungry',
    'Fan_face': 'I feel hot / I have a fever',
    'Sleep_gesture': 'I want to sleep / I am tired',
    'Phone_gesture': 'Please call my family',
    'Toilet_gesture': 'I need to use the toilet',
    'Water_gesture': 'I need water',
    'Medicine_gesture': 'I need my medicine',

    // ── Positioning ───────────────────────────────────
    'Palm_down': 'I want to lie down',
    'Palm_up': 'Please help me sit up',

    // ── Communication ─────────────────────────────────
    'Confused': 'I am confused / I do not understand',
    'Circle_finger': 'Please repeat that',
    'Nod_gesture': 'I understand',
    'Call_nurse': 'Please call a nurse',
    'Call_family': 'Please call my family',
  };

  static const Map<String, String> gestureEmoji = {
    // ── Basic responses ───────────────────────────────
    'Open_Palm': '✋',
    'Closed_Fist': '✊',
    'Thumb_Up': '👍',
    'Thumb_Down': '👎',
    'Victory': '✌️',
    'Pointing_Up': '☝️',
    'Wave': '👋',
    'None': '🤚',

    // ── Pain & medical ────────────────────────────────
    'Hand_on_chest': '💔',
    'Head_touch': '🤕',
    'Arms_crossed': '🥶',
    'Hand_on_belly': '🤢',
    'Throat_touch': '🗣️',
    'Both_hands_chest': '😮‍💨',
    'Scratch_arm': '🦟',
    'Cup_area': '🫧',

    // ── Urgency & emergency ───────────────────────────
    'Hands_on_throat': '🚨',
    'Hand_over_mouth': '🤮',
    'Point_wound': '🩸',
    'Allergic': '⚠️',
    'Pain_worse': '📈',
    'Pain_better': '📉',

    // ── Basic needs ───────────────────────────────────
    'Rub_stomach': '🍽️',
    'Fan_face': '🥵',
    'Sleep_gesture': '😴',
    'Phone_gesture': '📞',
    'Toilet_gesture': '🚽',
    'Water_gesture': '💧',
    'Medicine_gesture': '💊',

    // ── Positioning ───────────────────────────────────
    'Palm_down': '🛏️',
    'Palm_up': '🙋',

    // ── Communication ─────────────────────────────────
    'Confused': '😕',
    'Circle_finger': '🔁',
    'Nod_gesture': '👆',
    'Call_nurse': '📣',
    'Call_family': '👨‍👩‍👧',
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
  String? _classifyFromPose(List<Pose> poses) {
    if (poses.isEmpty) return 'None';

    final pose = poses.first;
    final lm = pose.landmarks;

    // Core landmarks
    final leftWrist = lm[PoseLandmarkType.leftWrist];
    final rightWrist = lm[PoseLandmarkType.rightWrist];
    final leftElbow = lm[PoseLandmarkType.leftElbow];
    final rightElbow = lm[PoseLandmarkType.rightElbow];
    final leftShoulder = lm[PoseLandmarkType.leftShoulder];
    final rightShoulder = lm[PoseLandmarkType.rightShoulder];
    final leftHip = lm[PoseLandmarkType.leftHip];
    final rightHip = lm[PoseLandmarkType.rightHip];
    final nose = lm[PoseLandmarkType.nose];
    final leftEar = lm[PoseLandmarkType.leftEar];
    final rightEar = lm[PoseLandmarkType.rightEar];

    if (leftWrist == null && rightWrist == null) return 'None';

    // Use the more confident/visible hand
    final wrist = (rightWrist?.likelihood ?? 0) > (leftWrist?.likelihood ?? 0)
        ? rightWrist!
        : leftWrist!;
    final elbow = wrist == rightWrist ? rightElbow : leftElbow;
    final shoulder = wrist == rightWrist ? rightShoulder : leftShoulder;
    final hip = wrist == rightWrist ? rightHip : leftHip;
    final ear = wrist == rightWrist ? rightEar : leftEar;

    if (wrist.likelihood < 0.5) return 'None';

    // ── Helper values ──────────────────────────────────
    final double wX = wrist.x;
    final double wY = wrist.y;
    final double shoulderY = shoulder?.y ?? 0;
    final double shoulderX = shoulder?.x ?? 0;
    final double elbowY = elbow?.y ?? 0;
    final double hipY = hip?.y ?? 0;
    final double noseY = nose?.y ?? 0;
    final double noseX = nose?.x ?? 0;
    final double earY = ear?.y ?? 0;

    // Both wrists for two-handed gestures
    final lW = leftWrist;
    final rW = rightWrist;
    final bothVisible =
        lW != null && rW != null && lW.likelihood > 0.5 && rW.likelihood > 0.5;

    // ── EMERGENCY — check first ────────────────────────

    // 🚨 Cannot breathe — both hands on throat
    // Both wrists near nose/throat level, close to face
    if (bothVisible &&
        lW.y < noseY + 60 &&
        lW.y > noseY - 40 &&
        rW.y < noseY + 60 &&
        rW.y > noseY - 40 &&
        (lW.x - noseX).abs() < 100 &&
        (rW.x - noseX).abs() < 100) {
      return 'Hands_on_throat';
    }

    // ⚠️ Allergic reaction — both wrists at shoulder, spread wide
    if (bothVisible &&
        lW.y.between(shoulderY - 30, shoulderY + 50) &&
        rW.y.between(shoulderY - 30, shoulderY + 50) &&
        (rW.x - lW.x).abs() > 200) {
      return 'Allergic';
    }

    // ── TWO-HANDED GESTURES ────────────────────────────

    // 😮‍💨 Difficulty breathing — both hands on chest
    if (bothVisible &&
        lW.y.between(shoulderY - 10, shoulderY + 100) &&
        rW.y.between(shoulderY - 10, shoulderY + 100) &&
        (lW.x - noseX).abs() < 120 &&
        (rW.x - noseX).abs() < 120) {
      return 'Both_hands_chest';
    }

    // 🥶 Arms crossed — wrists crossing midpoint
    if (bothVisible) {
      final midX = (lW.x + rW.x) / 2;
      if (lW.x > midX + 30 && rW.x < midX - 30) {
        return 'Arms_crossed';
      }
    }

    // 🛏️ Lie down — both wrists below hips, palms down
    if (bothVisible && lW.y > hipY + 30 && rW.y > hipY + 30) {
      return 'Palm_down';
    }

    // 🙋 Sit up — both wrists at mid torso, palms up
    if (bothVisible &&
        lW.y.between(shoulderY + 30, hipY - 30) &&
        rW.y.between(shoulderY + 30, hipY - 30) &&
        (rW.x - lW.x).abs() > 80) {
      return 'Palm_up';
    }

    // ── SINGLE-HANDED GESTURES ─────────────────────────
    // Ordered from most specific to least specific

    // 🤕 Head touch — wrist above ear/head level
    if (earY > 0 && wY < earY - 20) {
      return 'Head_touch';
    }

    // 🗣️ Throat touch — wrist between nose and shoulder, near center
    if (nose != null &&
        shoulder != null &&
        wY > noseY + 20 &&
        wY < shoulderY - 10 &&
        (wX - noseX).abs() < 70) {
      return 'Throat_touch';
    }

    // 🤮 Hand over mouth — wrist at nose level, close to face
    if (nose != null &&
        wY.between(noseY - 20, noseY + 40) &&
        (wX - noseX).abs() < 60) {
      return 'Hand_over_mouth';
    }

    // ☝️ Pointing up — wrist at face level, arm extended
    if (nose != null &&
        wY < noseY + 30 &&
        wY > noseY - 80 &&
        elbow != null &&
        wY < elbowY - 20) {
      return 'Pointing_Up';
    }

    // ✋ Open palm / Stop — wrist raised above shoulder
    if (shoulder != null && wY < shoulderY - 50) {
      return 'Open_Palm';
    }

    // 📣 Call nurse — wrist high above shoulder, arm extended
    if (shoulder != null && wY < shoulderY - 80) {
      return 'Call_nurse';
    }

    // 👋 Wave — wrist above shoulder, x position near center
    if (shoulder != null && wY < shoulderY && wX > 150 && wX < 600) {
      return 'Wave';
    }

    // 👍 Thumb up — wrist above elbow, arm pointing up
    if (elbow != null && nose != null && wY < elbowY - 30 && wY < noseY) {
      return 'Thumb_Up';
    }

    // 👎 Thumb down — wrist below elbow, pointing down
    if (elbow != null && wY > elbowY + 40) {
      return 'Thumb_Down';
    }

    // 📈 Pain worse — wrist rising, elbow lower (arm going up)
    if (elbow != null &&
        shoulder != null &&
        wY < elbowY - 10 &&
        wY > shoulderY - 20 &&
        wY < shoulderY + 40) {
      return 'Pain_worse';
    }

    // 📉 Pain better — open palm lowering (arm going down)
    if (elbow != null &&
        shoulder != null &&
        hip != null &&
        wY > shoulderY + 40 &&
        wY < hipY - 20) {
      return 'Pain_better';
    }

    // 💔 Hand on chest — wrist near shoulder, close to body center
    if (nose != null &&
        shoulder != null &&
        (wY - shoulderY).abs() < 50 &&
        (wX - noseX).abs() < 90) {
      return 'Hand_on_chest';
    }

    // 🩸 Point to wound — wrist at shoulder, arm extended sideways
    if (shoulder != null &&
        wY.between(shoulderY - 20, shoulderY + 80) &&
        (wX - shoulderX).abs() > 100) {
      return 'Point_wound';
    }

    // ✊ Closed fist / Pain — wrist near chest level
    if (shoulder != null && wY > shoulderY - 20 && wY < shoulderY + 80) {
      return 'Closed_Fist';
    }

    // 🫧 Cup area / Swelling — wrist below shoulder, cupped
    if (shoulder != null &&
        hip != null &&
        wY.between(shoulderY + 40, hipY - 10) &&
        (wX - noseX).abs() > 80) {
      return 'Cup_area';
    }

    // 🦟 Scratch arm — wrist at elbow level, crossing body
    if (elbow != null &&
        wY.between(elbowY - 30, elbowY + 50) &&
        (wX - (elbow.x)).abs() > 60) {
      return 'Scratch_arm';
    }

    // 🍽️ Rub stomach — wrist well below shoulder near center
    if (shoulder != null &&
        hip != null &&
        nose != null &&
        wY > shoulderY + 80 &&
        wY < hipY + 20 &&
        (wX - noseX).abs() < 100) {
      return 'Rub_stomach';
    }

    // 🤢 Hand on belly / Nausea — wrist below shoulder near center
    if (shoulder != null &&
        nose != null &&
        wY > shoulderY + 60 &&
        wY < shoulderY + 180 &&
        (wX - noseX).abs() < 100) {
      return 'Hand_on_belly';
    }

    // 🥵 Fan face — wrist at face level, arm to the side
    if (nose != null &&
        wY.between(noseY - 40, noseY + 60) &&
        (wX - noseX).abs() > 80) {
      return 'Fan_face';
    }

    // 😴 Sleep gesture — wrist near cheek/ear, tilted
    if (earY > 0 &&
        wY.between(earY - 20, earY + 60) &&
        (wX - noseX).abs() < 80) {
      return 'Sleep_gesture';
    }

    // 📞 Phone gesture — wrist near ear, like holding phone
    if (earY > 0 &&
        wY.between(earY - 30, earY + 50) &&
        (wX - noseX).abs() > 60) {
      return 'Phone_gesture';
    }

    // 💧 Water gesture — wrist at mouth/chin level
    if (nose != null &&
        wY.between(noseY + 20, noseY + 80) &&
        (wX - noseX).abs() < 50) {
      return 'Water_gesture';
    }

    // 💊 Medicine gesture — tap wrist (wrist at opposite wrist level)
    if (bothVisible && (lW.y - rW.y).abs() < 40 && (lW.x - rW.x).abs() < 60) {
      return 'Medicine_gesture';
    }

    // 🚽 Toilet gesture — wrist low, crossed legs approximation
    if (hip != null && wY > hipY + 30 && (wX - noseX).abs() < 60) {
      return 'Toilet_gesture';
    }

    // 😕 Confused — wrist pointing to head, shaking
    if (earY > 0 &&
        nose != null &&
        wY.between(noseY - 60, earY + 30) &&
        (wX - noseX).abs() > 60) {
      return 'Confused';
    }

    // 🔁 Circle finger — wrist at shoulder level, arm extended
    if (shoulder != null &&
        elbow != null &&
        wY.between(shoulderY - 40, shoulderY + 40) &&
        (wX - shoulderX).abs() > 80) {
      return 'Circle_finger';
    }

    // ✌️ Victory / OK — wrist at chest with arm not fully extended
    if (elbow != null &&
        shoulder != null &&
        wY.between(shoulderY + 20, shoulderY + 100) &&
        wY < elbowY) {
      return 'Victory';
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

// ── Extension helper ───────────────────────────────────
extension DoubleRange on double {
  bool between(double min, double max) => this >= min && this <= max;
}

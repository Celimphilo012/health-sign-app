import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../services/gesture_service.dart';
import '../services/permission_service.dart';

class CameraPreviewWidget extends StatefulWidget {
  final Function(String gesture, String text)? onGestureDetected;
  final bool autoDetect;

  const CameraPreviewWidget({
    super.key,
    this.onGestureDetected,
    this.autoDetect = true, // Manual mode by default for demo
  });

  @override
  State<CameraPreviewWidget> createState() => _CameraPreviewWidgetState();
}

class _CameraPreviewWidgetState extends State<CameraPreviewWidget>
    with WidgetsBindingObserver {
  final GestureService _gestureService = GestureService();
  final PermissionService _permissionService = PermissionService();

  bool _hasPermission = false;
  bool _isLoading = true;
  bool _isDetecting = false;
  String _currentGesture = '';
  String _currentEmoji = '🤚';
  double _confidence = 0;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  Future<void> _initCamera() async {
    setState(() => _isLoading = true);

    final granted = await _permissionService.requestCamera();
    if (!granted) {
      setState(() {
        _hasPermission = false;
        _isLoading = false;
        _errorMessage = 'Camera permission denied.\nTap to open settings.';
      });
      return;
    }

    await _gestureService.initCamera();

    if (mounted) {
      setState(() {
        _hasPermission = true;
        _isLoading = false;
      });

      // Auto-start detection if enabled
      if (widget.autoDetect) {
        _startDetection();
      }
      // ── Gesture guide ─────────────────────────────────────
      Positioned(
        bottom: 50,
        left: 0,
        right: 0,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Hold gesture steady for 1 second',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 10,
              ),
            ),
          ),
        ),
      );
    }
  }

  Future<void> _startDetection() async {
    setState(() => _isDetecting = true);

    await _gestureService.startDetection(
      onGestureDetected: (gesture, text, confidence) {
        if (!mounted) return;
        setState(() {
          _currentGesture = gesture;
          _currentEmoji = GestureService.gestureEmoji[gesture] ?? '🤚';
          _confidence = confidence;
        });

        // Debounce: only callback every 2 seconds
        widget.onGestureDetected?.call(gesture, text);
      },
    );
  }

  void _stopDetection() {
    _gestureService.stopDetection();
    setState(() => _isDetecting = false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      _stopDetection();
    } else if (state == AppLifecycleState.resumed && _hasPermission) {
      _initCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _gestureService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildState(
        icon: Icons.camera_alt_outlined,
        message: 'Starting camera...',
        showLoader: true,
      );
    }

    if (!_hasPermission) {
      return GestureDetector(
        onTap: () => _permissionService.openSettings(),
        child: _buildState(
          icon: Icons.no_photography_outlined,
          message: _errorMessage,
          showSettings: true,
        ),
      );
    }

    if (!_gestureService.isInitialized || _gestureService.controller == null) {
      return _buildState(
        icon: Icons.camera_alt_outlined,
        message: 'Camera unavailable\non this device',
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Camera Preview ───────────────────────────
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: CameraPreview(_gestureService.controller!),
        ),

        // ── Corner bracket overlay ───────────────────
        CustomPaint(painter: _CornerPainter()),

        // ── Gesture detected badge ───────────────────
        if (_currentGesture.isNotEmpty && _currentGesture != 'None')
          Positioned(
            bottom: 8,
            left: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF00BFA5).withOpacity(0.5),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_currentEmoji, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      GestureService.gestureMap[_currentGesture] ??
                          _currentGesture,
                      style: const TextStyle(
                        color: Color(0xFF00BFA5),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${(_confidence * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                      color: Color(0xFF8B949E),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // ── Top controls ─────────────────────────────
        Positioned(
          top: 8,
          right: 8,
          child: Row(
            children: [
              // Switch camera
              _ControlBtn(
                icon: Icons.flip_camera_android,
                onTap: () async {
                  _stopDetection();
                  await _gestureService.switchCamera();
                  setState(() {});
                  if (_isDetecting) _startDetection();
                },
              ),
              const SizedBox(width: 6),
              // Toggle detection
              _ControlBtn(
                icon: _isDetecting
                    ? Icons.stop_circle_outlined
                    : Icons.play_circle_outlined,
                color: _isDetecting
                    ? const Color(0xFFCF6679)
                    : const Color(0xFF00BFA5),
                onTap: () {
                  if (_isDetecting) {
                    _stopDetection();
                  } else {
                    _startDetection();
                  }
                },
              ),
            ],
          ),
        ),

        // ── Detecting indicator ──────────────────────
        if (_isDetecting)
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFF3FB950),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Text(
                    'LIVE',
                    style: TextStyle(
                      color: Color(0xFF3FB950),
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildState({
    required IconData icon,
    required String message,
    bool showLoader = false,
    bool showSettings = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF21262D),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (showLoader)
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                color: Color(0xFF00BFA5),
                strokeWidth: 2,
              ),
            )
          else
            Icon(icon, color: const Color(0xFF8B949E), size: 32),
          const SizedBox(height: 10),
          Text(
            message,
            style: const TextStyle(
              color: Color(0xFF8B949E),
              fontSize: 11,
            ),
            textAlign: TextAlign.center,
          ),
          if (showSettings) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF00BFA5).withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'Open Settings',
                style: TextStyle(
                  color: Color(0xFF00BFA5),
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ControlBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  const _ControlBtn({
    required this.icon,
    required this.onTap,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.55),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }
}

// ── Corner bracket painter ────────────────────────────────
class _CornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00BFA5)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const len = 18.0;
    const pad = 8.0;

    // Top-left
    canvas.drawLine(
        const Offset(pad, pad + len), const Offset(pad, pad), paint);
    canvas.drawLine(
        const Offset(pad, pad), const Offset(pad + len, pad), paint);
    // Top-right
    canvas.drawLine(Offset(size.width - pad - len, pad),
        Offset(size.width - pad, pad), paint);
    canvas.drawLine(Offset(size.width - pad, pad),
        Offset(size.width - pad, pad + len), paint);
    // Bottom-left
    canvas.drawLine(Offset(pad, size.height - pad - len),
        Offset(pad, size.height - pad), paint);
    canvas.drawLine(Offset(pad, size.height - pad),
        Offset(pad + len, size.height - pad), paint);
    // Bottom-right
    canvas.drawLine(Offset(size.width - pad - len, size.height - pad),
        Offset(size.width - pad, size.height - pad), paint);
    canvas.drawLine(Offset(size.width - pad, size.height - pad - len),
        Offset(size.width - pad, size.height - pad), paint);
  }

  @override
  bool shouldRepaint(_) => false;
}

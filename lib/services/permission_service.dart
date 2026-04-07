import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  // ── Request camera permission ─────────────────────────
  Future<bool> requestCamera() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  // ── Request microphone permission ─────────────────────
  Future<bool> requestMicrophone() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  // ── Request both at once ──────────────────────────────
  Future<Map<Permission, PermissionStatus>> requestAll() async {
    return await [
      Permission.camera,
      Permission.microphone,
    ].request();
  }

  // ── Check statuses ────────────────────────────────────
  Future<bool> isCameraGranted() async => await Permission.camera.isGranted;

  Future<bool> isMicGranted() async => await Permission.microphone.isGranted;

  // ── Open app settings if permanently denied ───────────
  Future<void> openSettings() async {
    await openAppSettings();
  }
}

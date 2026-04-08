import 'package:vibration/vibration.dart';
import 'package:flutter/services.dart';

class HapticService {
  static Future<bool> _canVibrate() async {
    final hasVibrator = await Vibration.hasVibrator() ?? false;
    return hasVibrator;
  }

  // ── Incoming chat request from nurse ─────────────────
  // Pattern: strong-pause-strong-pause-strong (urgent feel)
  static Future<void> incomingRequest() async {
    if (!await _canVibrate()) {
      // Fallback to Flutter haptics
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 200));
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 200));
      await HapticFeedback.heavyImpact();
      return;
    }

    // Distinct pattern: 3 strong pulses — "urgent alert"
    await Vibration.vibrate(
      pattern: [0, 300, 150, 300, 150, 300],
      intensities: [0, 255, 0, 255, 0, 255],
    );
  }

  // ── New message received ──────────────────────────────
  // Pattern: short-short (gentle notification feel)
  static Future<void> newMessage() async {
    if (!await _canVibrate()) {
      await HapticFeedback.mediumImpact();
      await Future.delayed(const Duration(milliseconds: 100));
      await HapticFeedback.lightImpact();
      return;
    }

    // Distinct pattern: 2 short soft taps — "message ping"
    await Vibration.vibrate(
      pattern: [0, 80, 80, 80],
      intensities: [0, 180, 0, 180],
    );
  }

  // ── Request accepted (for nurse side) ─────────────────
  // Pattern: long smooth pulse — "success"
  static Future<void> requestAccepted() async {
    if (!await _canVibrate()) {
      await HapticFeedback.lightImpact();
      return;
    }
    await Vibration.vibrate(
      pattern: [0, 50, 50, 100, 50, 200],
      intensities: [0, 100, 0, 150, 0, 200],
    );
  }

  // ── Request declined ──────────────────────────────────
  static Future<void> requestDeclined() async {
    if (!await _canVibrate()) {
      await HapticFeedback.heavyImpact();
      return;
    }
    await Vibration.vibrate(
      pattern: [0, 500],
      intensities: [0, 200],
    );
  }
}

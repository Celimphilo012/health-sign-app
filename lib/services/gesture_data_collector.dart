import 'dart:convert';
import 'package:flutter/material.dart';

/// Collects gesture training data for custom model training
/// Use this to build your own dataset
class GestureDataCollector {
  final List<Map<String, dynamic>> _samples = [];

  static const List<String> gesturesToCollect = [
    'Open_Palm',
    'Closed_Fist',
    'Thumb_Up',
    'Thumb_Down',
    'Victory',
    'Pointing_Up',
  ];

  // ── Add a sample ──────────────────────────────────────
  void addSample({
    required String gestureName,
    required List<double> landmarks,
  }) {
    _samples.add({
      'gesture': gestureName,
      'landmarks': landmarks,
      'timestamp': DateTime.now().toIso8601String(),
    });
    debugPrint('Sample added: $gestureName (total: ${_samples.length})');
  }

  // ── Export as JSON ────────────────────────────────────
  String exportJson() {
    return jsonEncode({
      'version': '1.0',
      'totalSamples': _samples.length,
      'gestures': gesturesToCollect,
      'samples': _samples,
    });
  }

  int get sampleCount => _samples.length;

  Map<String, int> get samplesByGesture {
    final counts = <String, int>{};
    for (final s in _samples) {
      final g = s['gesture'] as String;
      counts[g] = (counts[g] ?? 0) + 1;
    }
    return counts;
  }

  void clear() => _samples.clear();
}

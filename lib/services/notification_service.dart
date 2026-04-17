import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// ── Background message handler (must be top-level) ───────
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Background message: ${message.messageId}');
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotif =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'healthsign_alerts';
  static const String _channelName = 'HealthSign Alerts';
  static const String _emergencyChannelId = 'healthsign_emergency';
  static const String _emergencyChannelName = 'HealthSign Emergency Calls';

  // ── Initialize ────────────────────────────────────────
  Future<void> initialize() async {
    // Request FCM permission
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Local notifications init
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings =
        InitializationSettings(android: androidSettings);

    await _localNotif.initialize(initSettings);

    // Create notification channel
    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
        _localNotif.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      ),
    );

    // High-priority emergency channel for call alerts
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _emergencyChannelId,
        _emergencyChannelName,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        enableLights: true,
        ledColor: Color(0xFFCF6679),
      ),
    );

    // Register background handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showLocalNotification(message);
    });
  }

  // ── Get FCM token ─────────────────────────────────────
  Future<String?> getToken() async {
    try {
      return await _fcm.getToken();
    } catch (e) {
      debugPrint('FCM token error: $e');
      return null;
    }
  }

  // ── Save nurse FCM token + location to Firestore ──────
  Future<void> saveNurseToken({
    required String nurseId,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final token = await getToken();
      if (token == null) return;

      await FirebaseFirestore.instance.collection('users').doc(nurseId).update({
        'fcmToken': token,
        'location': GeoPoint(latitude, longitude),
        'lastSeen': Timestamp.now(),
        'isAvailable': true,
      });

      debugPrint('Nurse token + location saved');
    } catch (e) {
      debugPrint('Save nurse token error: $e');
    }
  }

  // ── Show local notification ───────────────────────────
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final RemoteNotification? notification = message.notification;
    if (notification == null) return;

    final isEmergency = message.data['urgency'] == 'emergency';
    final channelId = isEmergency ? _emergencyChannelId : _channelId;
    final channelName = isEmergency ? _emergencyChannelName : _channelName;
    final color = isEmergency ? const Color(0xFFCF6679) : const Color(0xFF00BFA5);

    await _localNotif.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          importance: Importance.max,
          priority: Priority.max,
          icon: '@mipmap/ic_launcher',
          color: color,
          playSound: true,
          enableVibration: true,
          enableLights: true,
          ledColor: color,
          ledOnMs: 300,
          ledOffMs: 300,
          fullScreenIntent: true,
          category: AndroidNotificationCategory.call,
          visibility: NotificationVisibility.public,
          autoCancel: false,
          ongoing: isEmergency,
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  // ── Broadcast to nearby nurses ────────────────────────
  Future<void> broadcastToNearbyNurses({
    required String patientId,
    required String patientName,
    required String urgency,
    required double patientLat,
    required double patientLng,
    required String callRequestId,
  }) async {
    try {
      final List<Map<String, dynamic>> nurses = await _getNearbyNurses(
        patientLat: patientLat,
        patientLng: patientLng,
        radiusMeters: 100,
      );

      debugPrint('Found ${nurses.length} nurses within 100m');

      // Update the call request with nearby nurse IDs
      await FirebaseFirestore.instance
          .collection('chat_requests')
          .doc(callRequestId)
          .update({
        'nearbyNurseIds': nurses.map((n) => n['uid'] as String).toList(),
        'patientLocation': GeoPoint(patientLat, patientLng),
      });
    } catch (e) {
      debugPrint('Broadcast error: $e');
    }
  }

  // ── Find nurses within radius ─────────────────────────
  Future<List<Map<String, dynamic>>> _getNearbyNurses({
    required double patientLat,
    required double patientLng,
    required double radiusMeters,
  }) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'nurse')
          .where('isAvailable', isEqualTo: true)
          .get();

      final List<Map<String, dynamic>> nearby = [];

      for (final doc in snap.docs) {
        final data = doc.data();
        final GeoPoint? location = data['location'] as GeoPoint?;
        if (location == null) continue;

        final double distance = _calculateDistance(
          patientLat,
          patientLng,
          location.latitude,
          location.longitude,
        );

        if (distance <= radiusMeters) {
          nearby.add({
            'uid': doc.id,
            'name': data['name'] ?? '',
            'fcmToken': data['fcmToken'] ?? '',
            'distance': distance,
          });
        }
      }

      // Sort by closest first
      nearby.sort((a, b) =>
          (a['distance'] as double).compareTo(b['distance'] as double));

      return nearby;
    } catch (e) {
      debugPrint('Get nearby nurses error: $e');
      return [];
    }
  }

  // ── Haversine distance formula (meters) ───────────────
  double _calculateDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const double earthRadius = 6371000.0;
    final double dLat = _toRad(lat2 - lat1);
    final double dLng = _toRad(lng2 - lng1);

    final double a = (dLat / 2) * (dLat / 2) +
        _toRad(lat1) * _toRad(lat2) * (dLng / 2) * (dLng / 2);

    final double c = 2 * _asin(_sqrt(a));
    return earthRadius * c;
  }

  double _toRad(double deg) => deg * 3.141592653589793 / 180;

  double _sqrt(double x) => x < 0
      ? 0
      : x < 1
          ? x
          : 1;

  double _asin(double x) {
    if (x >= 1) return 3.141592653589793 / 2;
    if (x <= 0) return 0;
    return x + (x * x * x) / 6;
  }
}

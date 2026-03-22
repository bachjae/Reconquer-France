import 'dart:io';
import 'package:flutter/material.dart' show Color;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await _NotificationServiceImpl.handleBackgroundMessage(message);
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static const String _cornChannelId = 'corn_alert';
  static const String _huskerChannelId = 'husker_emergency';

  static Future<void> initialize() async {
    // Request permissions
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      criticalAlert: true,
      provisional: false,
    );

    // Setup local notifications
    const androidInit = AndroidInitializationSettings('ic_flag');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      requestCriticalPermission: true,
    );

    await _localNotifications.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create Android notification channels
    if (Platform.isAndroid) {
      await _createAndroidChannels();
    }

    // Handle FCM background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Handle FCM foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Get and save FCM token
    final token = await _messaging.getToken();
    if (token != null) {
      await AuthService().updateFcmToken(token);
    }

    // Refresh token
    _messaging.onTokenRefresh.listen((token) {
      AuthService().updateFcmToken(token);
    });
  }

  static Future<void> _createAndroidChannels() async {
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin == null) return;

    // Corn alert channel — normal priority
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        _cornChannelId,
        'Corn Alerts',
        description: 'Group member needs a hand',
        importance: Importance.defaultImportance,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('corn_pop'),
      ),
    );

    // Husker emergency channel — MAX priority, bypasses DND
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        _huskerChannelId,
        'HUSKER Emergency',
        description: 'URGENT emergency alert — bypasses silent mode',
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('husker_alarm'),
        enableVibration: true,
        enableLights: true,
        ledColor: Color.fromARGB(255, 204, 0, 0),
      ),
    );
  }

  static void _onNotificationTapped(NotificationResponse response) {
    // Handle navigation based on payload
    final payload = response.payload;
    if (payload != null) {
      // Parse and navigate — handled by app router
    }
  }

  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final isHusker = message.data['type'] == 'husker';

    await _localNotifications.show(
      message.hashCode,
      message.notification?.title ?? (isHusker ? '🚨 HUSKER ALERT' : '🌽 Alert'),
      message.notification?.body ?? '',
      NotificationDetails(
        android: AndroidNotificationDetails(
          isHusker ? _huskerChannelId : _cornChannelId,
          isHusker ? 'HUSKER Emergency' : 'Corn Alerts',
          channelDescription: isHusker
              ? 'URGENT emergency alert'
              : 'Group member needs a hand',
          importance:
              isHusker ? Importance.max : Importance.defaultImportance,
          priority: isHusker ? Priority.max : Priority.defaultPriority,
          fullScreenIntent: isHusker,
          playSound: true,
          sound: isHusker
              ? const RawResourceAndroidNotificationSound('husker_alarm')
              : const RawResourceAndroidNotificationSound('corn_pop'),
        ),
        iOS: DarwinNotificationDetails(
          sound: isHusker ? 'husker_alarm.wav' : 'corn_pop.wav',
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          interruptionLevel: isHusker
              ? InterruptionLevel.critical
              : InterruptionLevel.active,
        ),
      ),
      payload: '${message.data['type']}|${message.data['groupId']}|'
          '${message.data['lat']}|${message.data['lng']}',
    );
  }

  /// Send a Corn alert (group-only, normal priority)
  static Future<void> sendCornAlert({
    required String groupId,
    required String senderName,
    required double lat,
    required double lng,
    required String message,
  }) async {
    await FirebaseFirestore.instance
        .collection('groups')
        .doc(groupId)
        .collection('alerts')
        .add({
      'type': 'corn',
      'sentBy': FirebaseAuth.instance.currentUser!.uid,
      'senderName': senderName,
      'lat': lat,
      'lng': lng,
      'message': message,
      'timestamp': FieldValue.serverTimestamp(),
      'resolvedAt': null,
    });
  }

  /// Send a Husker alert (all friends + group, high priority, bypasses DND)
  static Future<void> sendHuskerAlert({
    required String groupId,
    required String senderName,
    required double lat,
    required double lng,
  }) async {
    await FirebaseFirestore.instance
        .collection('groups')
        .doc(groupId)
        .collection('alerts')
        .add({
      'type': 'husker',
      'sentBy': FirebaseAuth.instance.currentUser!.uid,
      'senderName': senderName,
      'lat': lat,
      'lng': lng,
      'message': 'URGENT — needs immediate help',
      'timestamp': FieldValue.serverTimestamp(),
      'resolvedAt': null,
    });
  }

  /// Resolve an alert (mark as handled)
  static Future<void> resolveAlert(String groupId, String alertId) async {
    await FirebaseFirestore.instance
        .collection('groups')
        .doc(groupId)
        .collection('alerts')
        .doc(alertId)
        .update({'resolvedAt': FieldValue.serverTimestamp()});
  }
}

class _NotificationServiceImpl {
  static Future<void> handleBackgroundMessage(RemoteMessage message) async {
    // Handle silently in background
  }
}

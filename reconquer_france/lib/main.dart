import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'firebase_options.dart';
import 'services/sync_service.dart';
import 'services/notification_service.dart';
import 'app.dart';

// Your Mapbox public token — replace with your actual token
const String _mapboxAccessToken =
    'pk.YOUR_MAPBOX_ACCESS_TOKEN_HERE';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait orientation
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set status bar style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0A0A0F),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Mapbox
  MapboxOptions.setAccessToken(_mapboxAccessToken);

  // Initialize Hive + SyncService
  await SyncService.init();

  // Initialize notifications
  await NotificationService.initialize();

  // Handle FCM background messages
  FirebaseMessaging.onBackgroundMessage(_backgroundMessageHandler);

  runApp(
    const ProviderScope(
      child: ReconquerFranceApp(),
    ),
  );
}

@pragma('vm:entry-point')
Future<void> _backgroundMessageHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}

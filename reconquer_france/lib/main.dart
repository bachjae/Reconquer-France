import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'firebase_options.dart';
import 'services/sync_service.dart';
import 'services/notification_service.dart';
import 'services/offline_tile_service.dart';
import 'services/photo_service.dart';
import 'app.dart';

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

  // Initialize flutter_map tile caching (FMTC v9) — no API key needed
  await FMTCObjectBoxBackend().initialise();

  // Initialize Hive + SyncService (also inits StreakService + ElevationService)
  await SyncService.init();

  // Initialize offline tile service (creates FMTC store if needed)
  await OfflineTileService.init();

  // Initialize notifications
  await NotificationService.initialize();

  // Start watching the device photo library for new images. This runs in the
  // background and auto-imports photos to France hexes whenever a new photo
  // is taken, without any user action required.
  await PhotoService.startAutoImport('local');

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

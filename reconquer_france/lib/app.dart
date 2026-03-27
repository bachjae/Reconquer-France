import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme.dart';
import 'core/router.dart';
import 'services/photo_service.dart';

class ReconquerFranceApp extends ConsumerStatefulWidget {
  const ReconquerFranceApp({super.key});

  @override
  ConsumerState<ReconquerFranceApp> createState() => _ReconquerFranceAppState();
}

class _ReconquerFranceAppState extends ConsumerState<ReconquerFranceApp>
    with WidgetsBindingObserver {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Ask for photo library access as soon as the app starts so the user
    // sees the permission dialog immediately rather than buried in the gallery.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await PhotoService.requestPhotoPermission();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Every time the user brings the app to the foreground — even just to
  /// check it briefly after taking photos in the native camera — pull any
  /// new photos silently without them having to navigate anywhere.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      PhotoService.importPhotosFromLibrary('local');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Reconquer France',
      theme: AppTheme.dark,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/constants.dart';
import '../../providers/map_provider.dart';
import '../../providers/photo_provider.dart';
import '../../providers/test_mode_provider.dart';
import '../../services/photo_service.dart';
import '../../services/location_service.dart';
import '../../services/hex_grid_service.dart';

class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _initialized = false;
  bool _capturing = false;
  File? _capturedImage;
  Position? _currentPosition;
  int _selectedCameraIndex = 0;
  double _zoom = 1.0;
  double _minZoom = 1.0;
  double _maxZoom = 8.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
    _getLocation();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      _controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    _cameras = await availableCameras();
    if (_cameras.isEmpty) return;

    await _setupCamera(_cameras[_selectedCameraIndex]);
  }

  Future<void> _setupCamera(CameraDescription camera) async {
    _controller?.dispose();

    final controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    _controller = controller;

    try {
      await controller.initialize();
      _minZoom = await controller.getMinZoomLevel();
      _maxZoom = await controller.getMaxZoomLevel();

      if (mounted) setState(() => _initialized = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Camera error: $e')),
        );
      }
    }
  }

  Future<void> _getLocation() async {
    _currentPosition = await LocationService.getCurrentPosition();
    if (mounted) setState(() {});
  }

  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_capturing) return;

    setState(() => _capturing = true);

    try {
      final xFile = await _controller!.takePicture();
      final file = File(xFile.path);

      setState(() {
        _capturedImage = file;
        _capturing = false;
      });
    } catch (e) {
      setState(() => _capturing = false);
    }
  }

  Future<void> _savePhoto() async {
    if (_capturedImage == null) return;

    final pos = _currentPosition;
    if (pos == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No GPS signal. Photo not saved.')),
      );
      return;
    }

    final testMode = ref.read(testModeProvider);
    if (!HexGridService.isInActiveArea(pos.latitude, pos.longitude, testMode: testMode)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('You are not in France. Photo not saved.')),
      );
      return;
    }

    final tripId = ref.read(currentTripIdProvider);
    if (tripId == null) return;

    final photo = await PhotoService.captureAndSave(
      photoFile: _capturedImage!,
      lat: pos.latitude,
      lng: pos.longitude,
      tripId: tripId,
    );

    if (photo != null) {
      ref.read(allPhotosProvider.notifier).addCameraPhoto(photo);
      ref.read(unlockedCellsProvider.notifier).unlockCell(photo.hexId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('📍 Photo saved to hex ${photo.hexId}'),
            backgroundColor: const Color(kColorUnlockedHex),
          ),
        );
        context.pop();
      }
    }
  }

  void _switchCamera() async {
    if (_cameras.length < 2) return;
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    await _setupCamera(_cameras[_selectedCameraIndex]);
  }

  @override
  Widget build(BuildContext context) {
    if (_capturedImage != null) {
      return _PreviewScreen(
        imageFile: _capturedImage!,
        position: _currentPosition,
        onRetake: () => setState(() => _capturedImage = null),
        onSave: _savePhoto,
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera preview
          if (_initialized && _controller != null)
            GestureDetector(
              onScaleUpdate: (details) {
                double newZoom = (_zoom * details.scale)
                    .clamp(_minZoom, _maxZoom);
                _controller!.setZoomLevel(newZoom);
                setState(() => _zoom = newZoom);
              },
              child: CameraPreview(_controller!),
            )
          else
            const Center(
              child: CircularProgressIndicator(color: Color(kColorAccent)),
            ),

          // Top bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                  16, MediaQuery.of(context).padding.top + 8, 16, 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black87, Colors.transparent],
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                  const Spacer(),
                  // GPS indicator
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 16,
                        color: _currentPosition != null
                            ? const Color(kColorAccent)
                            : Colors.white38,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _currentPosition != null
                            ? '${_currentPosition!.latitude.toStringAsFixed(4)}°'
                            : 'No GPS',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  // Flash toggle
                  IconButton(
                    onPressed: () {
                      final current =
                          _controller?.value.flashMode ?? FlashMode.off;
                      _controller?.setFlashMode(current == FlashMode.off
                          ? FlashMode.auto
                          : FlashMode.off);
                    },
                    icon: const Icon(Icons.flash_auto, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),

          // Bottom controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                  32, 24, 32, MediaQuery.of(context).padding.bottom + 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black87, Colors.transparent],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Gallery shortcut
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.photo_library,
                          color: Colors.white),
                    ),
                  ),

                  // Shutter button
                  GestureDetector(
                    onTap: _initialized ? _takePicture : null,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.white, width: 4),
                        color: _capturing
                            ? const Color(kColorAccent)
                            : Colors.white24,
                      ),
                      child: Center(
                        child: _capturing
                            ? const CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 3)
                            : Container(
                                width: 60,
                                height: 60,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ),

                  // Flip camera
                  IconButton(
                    onPressed: _switchCamera,
                    icon: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.flip_camera_ios,
                          color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewScreen extends StatelessWidget {
  final File imageFile;
  final Position? position;
  final VoidCallback onRetake;
  final VoidCallback onSave;

  const _PreviewScreen({
    required this.imageFile,
    this.position,
    required this.onRetake,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.file(imageFile, fit: BoxFit.cover),
          // GPS overlay
          if (position != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.location_on,
                        size: 14, color: Color(kColorAccent)),
                    const SizedBox(width: 4),
                    Text(
                      '${position!.latitude.toStringAsFixed(5)}, '
                      '${position!.longitude.toStringAsFixed(5)}',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          // Bottom buttons
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                  32, 24, 32, MediaQuery.of(context).padding.bottom + 24),
              color: Colors.black54,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  OutlinedButton.icon(
                    onPressed: onRetake,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retake'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white54),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: onSave,
                    icon: const Icon(Icons.save),
                    label: const Text('Save Photo'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

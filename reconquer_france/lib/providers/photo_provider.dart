import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/photo_service.dart';
import '../models/trip_photo.dart';

/// All locally stored photos
final allPhotosProvider =
    StateNotifierProvider<PhotoNotifier, List<Map<String, dynamic>>>(
  (ref) => PhotoNotifier(),
);

class PhotoNotifier extends StateNotifier<List<Map<String, dynamic>>> {
  PhotoNotifier() : super([]) {
    _load();
  }

  void _load() {
    state = PhotoService.getAllPhotos();
  }

  void refresh() => _load();

  List<Map<String, dynamic>> getPhotosForHex(String hexId) {
    return state.where((p) => p['hexId'] == hexId).toList();
  }

  Future<void> importFromLibrary(String tripId) async {
    await PhotoService.importPhotosFromLibrary(tripId);
    _load();
  }

  Future<void> addCameraPhoto(TripPhoto photo) async {
    state = [...state, photo.toHiveMap()];
  }
}

/// Photos for a specific hex cell
final hexPhotosProvider =
    Provider.family<List<Map<String, dynamic>>, String>((ref, hexId) {
  final photos = ref.watch(allPhotosProvider);
  return photos.where((p) => p['hexId'] == hexId).toList();
});

/// Import state
final importingPhotosProvider = StateProvider<bool>((ref) => false);
final importProgressProvider = StateProvider<double>((ref) => 0.0);

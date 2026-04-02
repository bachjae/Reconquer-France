import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';
import '../../providers/photo_provider.dart';
import 'hex_stories_screen.dart';

// ─── Trip Collection Screen ──────────────────────────────────────────────────

/// Full-screen view of all photos from one trip, with a cover header,
/// stats bar, and photo grid.
class TripCollectionScreen extends ConsumerStatefulWidget {
  final String tripId;

  const TripCollectionScreen({super.key, required this.tripId});

  @override
  ConsumerState<TripCollectionScreen> createState() =>
      _TripCollectionScreenState();
}

class _TripCollectionScreenState extends ConsumerState<TripCollectionScreen> {
  String? _tripName;
  DateTime? _tripStart;
  DateTime? _tripEnd;
  bool _loadingMeta = true;

  @override
  void initState() {
    super.initState();
    _loadTripMeta();
  }

  Future<void> _loadTripMeta() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null && widget.tripId != 'local') {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('trips')
            .doc(widget.tripId)
            .get();

        if (doc.exists && mounted) {
          final data = doc.data()!;
          setState(() {
            _tripName = data['name'] as String?;
            final s = data['startDate'] as Timestamp?;
            final e = data['endDate'] as Timestamp?;
            _tripStart = s?.toDate();
            _tripEnd = e?.toDate();
          });
        }
      }
    } catch (e) {
      debugPrint('[TripCollectionScreen] _loadTripMeta error: $e');
    }
    if (mounted) setState(() => _loadingMeta = false);
  }

  @override
  Widget build(BuildContext context) {
    final allPhotos = ref.watch(allPhotosProvider);

    // Filter and sort newest-first
    final photos = allPhotos
        .where((p) => (p['tripId'] as String? ?? 'local') == widget.tripId)
        .toList()
      ..sort((a, b) {
        final aDate = a['takenAt'] as String? ?? '';
        final bDate = b['takenAt'] as String? ?? '';
        return bDate.compareTo(aDate);
      });

    // Derive date range from photos when Firestore metadata is unavailable
    DateTime? earliest, latest;
    for (final p in photos) {
      final ts = p['takenAt'] as String?;
      if (ts == null) continue;
      try {
        final d = DateTime.parse(ts);
        if (earliest == null || d.isBefore(earliest)) earliest = d;
        if (latest == null || d.isAfter(latest)) latest = d;
      } catch (_) {}
    }

    final displayName = _tripName ??
        (widget.tripId == 'local'
            ? 'Local Photos'
            : earliest != null
                ? 'Trip ${DateFormat('MMM yyyy').format(earliest)}'
                : 'Collection');

    final uniqueHexes =
        photos.map((p) => p['hexId'] as String? ?? '').toSet();

    final coverPhoto = photos.isNotEmpty ? photos.first : null;

    return Scaffold(
      backgroundColor: const Color(kColorBackground),
      body: CustomScrollView(
        slivers: [
          // ── Cover header ──────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            backgroundColor: const Color(kColorBackground),
            leading: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back, color: Colors.white),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: _CoverHeader(
                photo: coverPhoto,
                tripName: displayName,
                loading: _loadingMeta,
              ),
            ),
          ),

          // ── Stats bar ─────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _StatsBar(
              photoCount: photos.length,
              hexCount: uniqueHexes.length,
              startDate: _tripStart ?? earliest,
              endDate: _tripEnd ?? latest,
            ),
          ),

          const SliverToBoxAdapter(
            child: Divider(color: Colors.white12, height: 1),
          ),

          // ── Photo grid ────────────────────────────────────────────────────
          if (photos.isEmpty)
            const SliverFillRemaining(
              child: Center(
                child: Text(
                  'No photos in this collection yet.',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(2),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _CollectionPhoto(photo: photos[i]),
                  childCount: photos.length,
                ),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 2,
                  mainAxisSpacing: 2,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Cover header ────────────────────────────────────────────────────────────

class _CoverHeader extends StatelessWidget {
  final Map<String, dynamic>? photo;
  final String tripName;
  final bool loading;

  const _CoverHeader({
    required this.photo,
    required this.tripName,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    final localPath = photo?['localPath'] as String?;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Cover photo or fallback gradient
        if (localPath != null)
          Image.file(
            File(localPath),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _fallbackGradient(),
          )
        else
          _fallbackGradient(),

        // Dark gradient overlay so title is readable
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black87],
            ),
          ),
        ),

        // Trip name at bottom
        Positioned(
          left: 20,
          right: 20,
          bottom: 20,
          child: loading
              ? const SizedBox.shrink()
              : Text(
                  tripName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(blurRadius: 8, color: Colors.black)],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _fallbackGradient() => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A1A2E), Color(0xFF0A0A0F)],
          ),
        ),
        child: const Center(
          child: Text('📷', style: TextStyle(fontSize: 64)),
        ),
      );
}

// ─── Stats bar ───────────────────────────────────────────────────────────────

class _StatsBar extends StatelessWidget {
  final int photoCount;
  final int hexCount;
  final DateTime? startDate;
  final DateTime? endDate;

  const _StatsBar({
    required this.photoCount,
    required this.hexCount,
    required this.startDate,
    required this.endDate,
  });

  @override
  Widget build(BuildContext context) {
    String dateStr = '';
    if (startDate != null) {
      final same = endDate == null ||
          (endDate!.year == startDate!.year &&
              endDate!.month == startDate!.month &&
              endDate!.day == startDate!.day);
      dateStr = same
          ? DateFormat('d MMM yyyy').format(startDate!)
          : '${DateFormat('d MMM').format(startDate!)} – ${DateFormat('d MMM yyyy').format(endDate!)}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          _Stat(icon: Icons.photo_library_outlined, label: '$photoCount photos'),
          const SizedBox(width: 20),
          _Stat(icon: Icons.hexagon_outlined, label: '$hexCount cells'),
          if (dateStr.isNotEmpty) ...[
            const SizedBox(width: 20),
            Expanded(
              child: _Stat(
                icon: Icons.calendar_today_outlined,
                label: dateStr,
                compact: true,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool compact;

  const _Stat({required this.icon, required this.label, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: const Color(kColorAccent)),
        const SizedBox(width: 5),
        compact
            ? Flexible(
                child: Text(
                  label,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              )
            : Text(
                label,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
      ],
    );
  }
}

// ─── Collection photo tile ────────────────────────────────────────────────────

class _CollectionPhoto extends StatelessWidget {
  final Map<String, dynamic> photo;

  const _CollectionPhoto({required this.photo});

  @override
  Widget build(BuildContext context) {
    final localPath = photo['localPath'] as String?;

    return GestureDetector(
      onTap: () => _showOptions(context),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (localPath != null)
            Image.file(
              File(localPath),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _placeholder(),
            )
          else
            _placeholder(),
        ],
      ),
    );
  }

  Widget _placeholder() => Container(
        color: const Color(0xFF1A1A2E),
        child: const Icon(Icons.image_outlined, color: Colors.white24),
      );

  void _showOptions(BuildContext context) {
    final hexId = photo['hexId'] as String?;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading:
                  const Icon(Icons.fullscreen, color: Color(kColorAccent)),
              title: const Text('View Photo'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => _FullscreenPhoto(photo: photo)),
                );
              },
            ),
            if (hexId != null)
              ListTile(
                leading: const Icon(Icons.auto_stories_outlined,
                    color: Color(kColorAccent)),
                title: const Text('View Hex Stories'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            HexStoriesScreen(startHexId: hexId)),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Fullscreen photo viewer (reused from gallery) ───────────────────────────

class _FullscreenPhoto extends StatelessWidget {
  final Map<String, dynamic> photo;

  const _FullscreenPhoto({required this.photo});

  @override
  Widget build(BuildContext context) {
    final localPath = photo['localPath'] as String?;
    final hexId = photo['hexId'] as String? ?? '';
    final lat = (photo['lat'] as num?)?.toDouble() ?? 0;
    final lng = (photo['lng'] as num?)?.toDouble() ?? 0;
    final takenAt = photo['takenAt'] as String?;
    DateTime? date;
    if (takenAt != null) {
      try {
        date = DateTime.parse(takenAt);
      } catch (_) {}
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (localPath != null)
            InteractiveViewer(
              child: Image.file(
                File(localPath),
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) =>
                    const Center(child: Icon(Icons.broken_image, size: 64)),
              ),
            )
          else
            const Center(
              child: Icon(Icons.image_not_supported,
                  size: 64, color: Colors.white38),
            ),

          // Top bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                  8, MediaQuery.of(context).padding.top + 4, 8, 8),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black87, Colors.transparent],
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),

          // Bottom info
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                  24, 24, 24, MediaQuery.of(context).padding.bottom + 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black87, Colors.transparent],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on,
                          size: 14, color: Color(kColorAccent)),
                      const SizedBox(width: 4),
                      Text(
                        '${lat.toStringAsFixed(4)}°N, ${lng.toStringAsFixed(4)}°E',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Hex: $hexId',
                    style: const TextStyle(
                        color: Color(kColorAccent), fontSize: 12),
                  ),
                  if (date != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('MMMM d, yyyy • HH:mm').format(date),
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Trip Collections bottom sheet ──────────────────────────────────────────

/// Lists all trips that have photos, sorted by most recent first.
/// Opened from the gallery book icon.
class TripCollectionsSheet extends StatefulWidget {
  final List<Map<String, dynamic>> photos;

  const TripCollectionsSheet({super.key, required this.photos});

  @override
  State<TripCollectionsSheet> createState() => _TripCollectionsSheetState();
}

class _TripCollectionsSheetState extends State<TripCollectionsSheet> {
  final Map<String, String> _tripNames = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadNames();
  }

  Future<void> _loadNames() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    final tripIds = widget.photos
        .map((p) => p['tripId'] as String? ?? 'local')
        .where((id) => id != 'local')
        .toSet();

    for (final id in tripIds) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('trips')
            .doc(id)
            .get();
        final name = doc.data()?['name'] as String?;
        if (name != null && mounted) {
          setState(() => _tripNames[id] = name);
        }
      } catch (_) {}
    }

    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    // Group by tripId
    final Map<String, List<Map<String, dynamic>>> byTrip = {};
    for (final p in widget.photos) {
      final id = p['tripId'] as String? ?? 'local';
      byTrip.putIfAbsent(id, () => []).add(p);
    }

    // Sort by most recent photo in each trip
    final trips = byTrip.entries.toList()
      ..sort((a, b) {
        String latest(List<Map<String, dynamic>> ps) => ps
            .map((p) => p['takenAt'] as String? ?? '')
            .fold('', (m, d) => d.compareTo(m) > 0 ? d : m);
        return latest(b.value).compareTo(latest(a.value));
      });

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      maxChildSize: 0.9,
      minChildSize: 0.3,
      builder: (context, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF12121C),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            // Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Icon(Icons.collections_bookmark,
                      color: Color(kColorAccent), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Trip Collections',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Spacer(),
                  Text(
                    '${trips.length} trip${trips.length == 1 ? '' : 's'}',
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Divider(color: Colors.white12, height: 1),
            if (_loading)
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(
                      color: Color(kColorAccent)),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: trips.length,
                  itemBuilder: (context, i) {
                    final entry = trips[i];
                    final tripId = entry.key;
                    final photos = entry.value;

                    // Date range from photos
                    DateTime? first, last;
                    for (final p in photos) {
                      final ts = p['takenAt'] as String?;
                      if (ts == null) continue;
                      try {
                        final d = DateTime.parse(ts);
                        if (first == null || d.isBefore(first)) first = d;
                        if (last == null || d.isAfter(last)) last = d;
                      } catch (_) {}
                    }

                    final name = _tripNames[tripId] ??
                        (tripId == 'local'
                            ? 'Local Photos'
                            : first != null
                                ? 'Trip ${DateFormat('MMM yyyy').format(first)}'
                                : 'Collection');

                    final same = first == null ||
                        last == null ||
                        (last.year == first.year &&
                            last.month == first.month &&
                            last.day == first.day);
                    final dateStr = first == null
                        ? ''
                        : same
                            ? DateFormat('d MMM yyyy').format(first)
                            : '${DateFormat('d MMM').format(first)} – ${DateFormat('d MMM yyyy').format(last)}';

                    final cover = photos
                        .where((p) => p['localPath'] != null)
                        .fold<Map<String, dynamic>?>(null, (_, p) => p);

                    return _TripCard(
                      tripId: tripId,
                      name: name,
                      dateStr: dateStr,
                      photoCount: photos.length,
                      coverPhoto: cover,
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Trip card (inside bottom sheet) ─────────────────────────────────────────

class _TripCard extends StatelessWidget {
  final String tripId;
  final String name;
  final String dateStr;
  final int photoCount;
  final Map<String, dynamic>? coverPhoto;

  const _TripCard({
    required this.tripId,
    required this.name,
    required this.dateStr,
    required this.photoCount,
    required this.coverPhoto,
  });

  @override
  Widget build(BuildContext context) {
    final localPath = coverPhoto?['localPath'] as String?;

    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => TripCollectionScreen(tripId: tripId)),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        height: 76,
        decoration: BoxDecoration(
          color: const Color(kColorBackground),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: const Color(kColorAccent).withValues(alpha: 0.15), width: 1),
        ),
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius:
                  const BorderRadius.horizontal(left: Radius.circular(12)),
              child: SizedBox(
                width: 76,
                height: 76,
                child: localPath != null
                    ? Image.file(File(localPath),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _placeholder())
                    : _placeholder(),
              ),
            ),

            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (dateStr.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        dateStr,
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 3),
                    Text(
                      '$photoCount photo${photoCount == 1 ? '' : 's'}',
                      style: const TextStyle(
                          color: Color(kColorAccent), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),

            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(Icons.chevron_right, color: Colors.white24),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
        color: const Color(0xFF1A1A2E),
        child: const Icon(Icons.photo_library_outlined,
            color: Colors.white24, size: 28),
      );
}

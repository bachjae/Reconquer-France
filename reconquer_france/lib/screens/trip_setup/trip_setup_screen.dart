import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';
import '../../providers/map_provider.dart';
import '../../providers/social_provider.dart';
import '../../services/offline_tile_service.dart';
import '../../services/photo_service.dart';
import '../../services/sync_service.dart';

class TripSetupScreen extends ConsumerStatefulWidget {
  const TripSetupScreen({super.key});

  @override
  ConsumerState<TripSetupScreen> createState() => _TripSetupScreenState();
}

class _TripSetupScreenState extends ConsumerState<TripSetupScreen> {
  final _nameCtrl = TextEditingController();
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  bool _creating = false;
  bool _downloadingMap = false;
  double _downloadProgress = 0.0;

  bool _showJoinGroup = false;
  final _inviteCodeCtrl = TextEditingController();
  bool _isAlreadyDownloaded = false;
  String _downloadStatus = '';

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = 'France ${DateTime.now().year}';
    _isAlreadyDownloaded = OfflineTileService.isFranceDownloaded;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _inviteCodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _createTrip() async {
    if (_nameCtrl.text.isEmpty) return;
    setState(() => _creating = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('Not authenticated');

      final tripId = const Uuid().v4();

      // Validate invite code before creating anything
      String? groupId;
      final inviteCode = _inviteCodeCtrl.text.trim().toUpperCase();
      if (_showJoinGroup && inviteCode.isNotEmpty) {
        final groupSnap = await FirebaseFirestore.instance
            .collection('groups')
            .where('inviteCode', isEqualTo: inviteCode)
            .limit(1)
            .get();
        if (groupSnap.docs.isEmpty) {
          throw Exception('Invite code "$inviteCode" not found — check with your group leader.');
        }
        groupId = groupSnap.docs.first.id;
      }

      // Create trip in Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('trips')
          .doc(tripId)
          .set({
        'name': _nameCtrl.text.trim(),
        'uid': uid,
        'groupId': groupId,
        'startDate': Timestamp.fromDate(_startDate),
        'endDate': _endDate != null ? Timestamp.fromDate(_endDate!) : null,
        'unlockedCells': [],
        'totalCellsUnlocked': 0,
        'percentFrance': 0.0,
      });

      // Join the group now that the trip exists
      if (groupId != null) {
        await SocialActions.joinGroupByCode(inviteCode);
      }

      // Update user's active trip
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'activeTripId': tripId,
      });

      // Set in Riverpod
      ref.read(currentTripIdProvider.notifier).state = tripId;

      // Tell PhotoService so future auto-imports go to this trip
      PhotoService.setActiveTripId(tripId);

      // Sync any existing local cells
      await SyncService.syncAllCellsToFirestore(tripId);

      if (mounted) context.go('/map');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : (_endDate ?? DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _downloadMap() async {
    setState(() {
      _downloadingMap = true;
      _downloadProgress = 0.0;
      _downloadStatus = 'Starting download…';
    });

    await OfflineTileService.downloadFrance(
      onProgress: (progress, downloaded, total) {
        if (!mounted) return;
        setState(() {
          _downloadProgress = progress;
          _downloadStatus = '$downloaded / $total tiles';
        });
      },
      onComplete: () {
        if (!mounted) return;
        setState(() {
          _downloadingMap = false;
          _isAlreadyDownloaded = true;
          _downloadStatus = '';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('France map downloaded for offline use ✅'),
            backgroundColor: Color(kColorUnlockedHex),
          ),
        );
      },
      onError: (err) {
        if (!mounted) return;
        setState(() {
          _downloadingMap = false;
          _downloadStatus = '';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $err')),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(kColorBackground),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              // Header
              Text(
                '🏰',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 64),
              ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
              const SizedBox(height: 8),
              Text(
                'Setup Your Trip',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: const Color(kColorAccent),
                    ),
              ).animate().fadeIn(delay: 200.ms),
              const SizedBox(height: 32),

              // Trip name
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Trip Name',
                  prefixIcon: Icon(Icons.edit_outlined),
                ),
              ).animate().fadeIn(delay: 300.ms),
              const SizedBox(height: 16),

              // Dates
              Row(
                children: [
                  Expanded(
                    child: _DatePicker(
                      label: 'Start Date',
                      date: _startDate,
                      onTap: () => _pickDate(true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DatePicker(
                      label: 'End Date',
                      date: _endDate,
                      onTap: () => _pickDate(false),
                      optional: true,
                    ),
                  ),
                ],
              ).animate().fadeIn(delay: 400.ms),
              const SizedBox(height: 24),

              // Group section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF2A2A4E)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Trip Group',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(
                      'Travel solo or with a group',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
                    if (!_showJoinGroup) ...[
                      OutlinedButton.icon(
                        onPressed: () =>
                            setState(() => _showJoinGroup = true),
                        icon: const Icon(Icons.group_add),
                        label: const Text('Join Existing Group'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                        ),
                      ),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _inviteCodeCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Invite Code',
                                hintText: 'e.g. FR2026',
                              ),
                              textCapitalization: TextCapitalization.characters,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () =>
                                setState(() => _showJoinGroup = false),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ).animate().fadeIn(delay: 500.ms),
              const SizedBox(height: 16),

              // Offline map download
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF2A2A4E)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.download_outlined,
                            color: Color(kColorAccent)),
                        const SizedBox(width: 8),
                        Text('Offline Map',
                            style: Theme.of(context).textTheme.titleMedium),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Download France map for offline use (~500MB)',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    if (_downloadingMap) ...[
                      LinearProgressIndicator(
                        value: _downloadProgress,
                        backgroundColor: const Color(0xFF2A2A4E),
                        color: const Color(kColorAccent),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${(_downloadProgress * 100).round()}%',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Text(
                            _downloadStatus,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          TextButton(
                            onPressed: () async {
                              await OfflineTileService.cancelDownload();
                              if (mounted) setState(() => _downloadingMap = false);
                            },
                            child: const Text('Cancel',
                                style: TextStyle(color: Colors.redAccent)),
                          ),
                        ],
                      ),
                    ] else if (_isAlreadyDownloaded)
                      Row(
                        children: [
                          const Icon(Icons.check_circle,
                              color: Color(kColorUnlockedHex), size: 18),
                          const SizedBox(width: 8),
                          Text('France map ready for offline use',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: const Color(kColorUnlockedHex))),
                        ],
                      )
                    else
                      OutlinedButton.icon(
                        onPressed: _downloadMap,
                        icon: const Icon(Icons.download),
                        label: const Text('Download France Map (~280 MB)'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                        ),
                      ),
                  ],
                ),
              ).animate().fadeIn(delay: 600.ms),
              const SizedBox(height: 32),

              // CTA
              ElevatedButton(
                onPressed: _creating ? null : _createTrip,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  textStyle: const TextStyle(fontSize: 18),
                ),
                child: _creating
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.black),
                          ),
                          SizedBox(width: 12),
                          Text('Creating Trip...'),
                        ],
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('⚔️ Start Conquering!',
                              style: TextStyle(fontSize: 18)),
                        ],
                      ),
              ).animate().fadeIn(delay: 700.ms),
            ],
          ),
        ),
      ),
    );
  }
}

class _DatePicker extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;
  final bool optional;

  const _DatePicker({
    required this.label,
    required this.date,
    required this.onTap,
    this.optional = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF2A2A4E)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined,
                    size: 14, color: Color(kColorAccent)),
                const SizedBox(width: 6),
                Text(
                  date != null
                      ? DateFormat('MMM d, yyyy').format(date!)
                      : optional
                          ? 'Optional'
                          : 'Select',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: date != null ? Colors.white : Colors.white38,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

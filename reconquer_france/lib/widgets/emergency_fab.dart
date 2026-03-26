import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import '../core/constants.dart';
import '../providers/auth_provider.dart';
import '../providers/social_provider.dart';
import '../services/notification_service.dart';
import '../services/location_service.dart';

class EmergencyFAB extends ConsumerStatefulWidget {
  const EmergencyFAB({super.key});

  @override
  ConsumerState<EmergencyFAB> createState() => _EmergencyFABState();
}

class _EmergencyFABState extends ConsumerState<EmergencyFAB> {
  final ValueNotifier<bool> _isOpen = ValueNotifier(false);

  Future<void> _sendCornAlert() async {
    final profile = ref.read(refreshableProfileProvider).value;
    if (profile == null) return;

    final group = ref.read(activeGroupProvider).value;
    if (group == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Join a group first to send alerts!')),
        );
      }
      return;
    }

    // Show message picker
    final message = await _showMessagePicker(isCorn: true);
    if (message == null) return;

    final pos = LocationService.lastPosition;

    await NotificationService.sendCornAlert(
      groupId: group.id,
      senderName: profile.displayName,
      lat: pos?.latitude ?? 0,
      lng: pos?.longitude ?? 0,
      message: message,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🌽 Alert sent to ${group.leaderIds.length} group leader(s)'),
          backgroundColor: const Color(kColorCorn).withValues(alpha: 0.8),
        ),
      );
    }
  }

  Future<void> _sendHuskerAlert() async {
    final profile = ref.read(refreshableProfileProvider).value;
    if (profile == null) return;

    final group = ref.read(activeGroupProvider).value;
    if (group == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Join a group first to send alerts!')),
        );
      }
      return;
    }

    // Confirm before sending
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF12121A),
        title: const Text(
          '🚨 HUSKER ALERT',
          style: TextStyle(color: Color(kColorHusker)),
        ),
        content: const Text(
          'This will send an URGENT emergency alert to all group leaders. '
          'This bypasses silent mode.\n\n'
          'Only use in a real emergency!',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(kColorHusker)),
            child: const Text('SEND HUSKER'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final pos = LocationService.lastPosition;

    await NotificationService.sendHuskerAlert(
      groupId: group.id,
      senderName: profile.displayName,
      lat: pos?.latitude ?? 0,
      lng: pos?.longitude ?? 0,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🚨 HUSKER ALERT sent! Help is on the way.'),
          backgroundColor: Color(kColorHusker),
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  Future<String?> _showMessagePicker({required bool isCorn}) async {
    const cornMessages = [
      'I need help 🌽',
      'Wait for me!',
      'Lost signal, please wait',
      'Meet me at my location',
      'I\'m running late',
    ];

    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF12121A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Send Corn Alert 🌽',
              style: Theme.of(ctx).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ...cornMessages.map((msg) => ListTile(
                  title: Text(msg),
                  onTap: () => Navigator.pop(ctx, msg),
                  leading: const Icon(Icons.message_outlined,
                      color: Color(kColorCorn)),
                )),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SpeedDial(
      openCloseDial: _isOpen,
      backgroundColor: const Color(0xFF12121A),
      foregroundColor: Colors.white,
      overlayColor: Colors.black,
      overlayOpacity: 0.5,
      spacing: 12,
      icon: Icons.warning_amber_rounded,
      activeIcon: Icons.close,
      iconTheme: const IconThemeData(size: 28),
      shape: const CircleBorder(),
      children: [
        SpeedDialChild(
          child: const Text('🌽', style: TextStyle(fontSize: 22)),
          backgroundColor: const Color(0xFF1A1A2E),
          foregroundColor: const Color(kColorCorn),
          label: 'Corn Alert',
          labelStyle: const TextStyle(
            color: Color(kColorCorn),
            fontWeight: FontWeight.bold,
          ),
          labelBackgroundColor: const Color(0xFF12121A),
          onTap: _sendCornAlert,
          shape: const CircleBorder(),
        ),
        SpeedDialChild(
          child: const Text('🔴', style: TextStyle(fontSize: 22)),
          backgroundColor: const Color(0xFF1A1A2E),
          foregroundColor: const Color(kColorHusker),
          label: 'HUSKER — Emergency',
          labelStyle: const TextStyle(
            color: Color(kColorHusker),
            fontWeight: FontWeight.bold,
          ),
          labelBackgroundColor: const Color(0xFF12121A),
          onTap: _sendHuskerAlert,
          shape: const CircleBorder(),
        ),
      ],
    );
  }
}

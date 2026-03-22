import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../providers/social_provider.dart';
import '../../providers/auth_provider.dart';
import 'friends_tab.dart';
import 'leaderboard_tab.dart';

class SocialScreen extends ConsumerStatefulWidget {
  const SocialScreen({super.key});

  @override
  ConsumerState<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends ConsumerState<SocialScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final group = ref.watch(activeGroupProvider);

    return Scaffold(
      backgroundColor: const Color(kColorBackground),
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverAppBar(
            floating: true,
            backgroundColor: const Color(kColorBackground),
            title: Text(
              'Social',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: const Color(kColorAccent),
              labelColor: const Color(kColorAccent),
              unselectedLabelColor: Colors.white38,
              tabs: const [
                Tab(icon: Icon(Icons.people), text: 'Friends'),
                Tab(icon: Icon(Icons.leaderboard), text: 'Leaderboard'),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            const FriendsTab(),
            LeaderboardTab(group: group.value),
          ],
        ),
      ),
    );
  }
}

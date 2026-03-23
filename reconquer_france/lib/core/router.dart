import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../screens/splash/splash_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/map/map_screen.dart';
import '../screens/camera/camera_screen.dart';
import '../screens/gallery/gallery_screen.dart';
import '../screens/social/social_screen.dart';
import '../screens/social/group_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/export/export_screen.dart';
import '../screens/trip_setup/trip_setup_screen.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/badges/badges_screen.dart';
import '../screens/offline/offline_tiles_screen.dart';
import '../screens/map/route_planner_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    redirect: (context, state) {
      final isLoading = authState.isLoading;
      if (isLoading) return '/splash';

      final isAuthenticated = authState.value != null;
      final isOnSplash = state.matchedLocation == '/splash';
      final isOnAuth = state.matchedLocation.startsWith('/auth') ||
          state.matchedLocation == '/onboarding';

      if (isOnSplash) return null;
      if (!isAuthenticated && !isOnAuth) return '/auth/login';
      if (isAuthenticated && isOnAuth) return '/map';

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/auth/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/auth/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/trip-setup',
        builder: (context, state) => const TripSetupScreen(),
      ),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/map',
            builder: (context, state) => const MapScreen(),
          ),
          GoRoute(
            path: '/gallery',
            builder: (context, state) => const GalleryScreen(),
          ),
          GoRoute(
            path: '/social',
            builder: (context, state) => const SocialScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/camera',
        builder: (context, state) => const CameraScreen(),
      ),
      GoRoute(
        path: '/group/:groupId',
        builder: (context, state) =>
            GroupScreen(groupId: state.pathParameters['groupId']!),
      ),
      GoRoute(
        path: '/export',
        builder: (context, state) => const ExportScreen(),
      ),
      GoRoute(
        path: '/badges',
        builder: (context, state) => const BadgesScreen(),
      ),
      GoRoute(
        path: '/offline-tiles',
        builder: (context, state) => const OfflineTilesScreen(),
      ),
      GoRoute(
        path: '/route-planner',
        builder: (context, state) => const RoutePlannerScreen(),
      ),
    ],
  );
});

class MainShell extends ConsumerStatefulWidget {
  final Widget child;

  const MainShell({required this.child, super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _currentIndex = 0;

  final List<({String route, IconData icon, String label})> _tabs = [
    (route: '/map', icon: Icons.map_outlined, label: 'Map'),
    (route: '/gallery', icon: Icons.photo_library_outlined, label: 'Gallery'),
    (route: '/social', icon: Icons.people_outline, label: 'Social'),
    (route: '/profile', icon: Icons.person_outline, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF12121A),
          border: Border(
            top: BorderSide(color: const Color(0xFF2A2A4E), width: 1),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() => _currentIndex = index);
            context.go(_tabs[index].route);
          },
          items: _tabs
              .map((t) => BottomNavigationBarItem(
                    icon: Icon(t.icon),
                    label: t.label,
                  ))
              .toList(),
        ),
      ),
    );
  }
}

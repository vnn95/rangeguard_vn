import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rangeguard_vn/providers/auth_provider.dart';
import 'package:rangeguard_vn/screens/auth/login_screen.dart';
import 'package:rangeguard_vn/screens/auth/register_screen.dart';
import 'package:rangeguard_vn/screens/dashboard/dashboard_screen.dart';
import 'package:rangeguard_vn/screens/map/map_screen.dart';
import 'package:rangeguard_vn/screens/patrol/patrol_list_screen.dart';
import 'package:rangeguard_vn/screens/patrol/patrol_detail_screen.dart';
import 'package:rangeguard_vn/screens/patrol/start_patrol_screen.dart';
import 'package:rangeguard_vn/screens/patrol/import_patrol_screen.dart';
import 'package:rangeguard_vn/screens/schedule/schedule_screen.dart';
import 'package:rangeguard_vn/screens/reports/reports_screen.dart';
import 'package:rangeguard_vn/screens/settings/settings_screen.dart';
import 'package:rangeguard_vn/screens/profile/profile_screen.dart';
import 'package:rangeguard_vn/screens/admin/admin_screen.dart';
import 'package:rangeguard_vn/screens/admin/ranger_management_screen.dart';
import 'package:rangeguard_vn/screens/admin/photo_gallery_screen.dart';
import 'package:rangeguard_vn/screens/admin/station_management_screen.dart';
import 'package:rangeguard_vn/widgets/common/main_scaffold.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/dashboard',
    debugLogDiagnostics: false,
    redirect: (context, state) {
      final isLoggedIn = authState.value?.session != null;
      final isAuthRoute = state.matchedLocation.startsWith('/auth');

      if (!isLoggedIn && !isAuthRoute) return '/auth/login';
      if (isLoggedIn && isAuthRoute) return '/dashboard';
      return null;
    },
    routes: [
      // Auth routes (không có shell)
      GoRoute(
        path: '/auth/login',
        name: 'login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/auth/register',
        name: 'register',
        builder: (_, __) => const RegisterScreen(),
      ),

      // Main shell with bottom nav / rail
      ShellRoute(
        builder: (_, __, child) => MainScaffold(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            name: 'dashboard',
            builder: (_, __) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/map',
            name: 'map',
            builder: (_, __) => const MapScreen(),
          ),
          GoRoute(
            path: '/patrols',
            name: 'patrols',
            builder: (_, __) => const PatrolListScreen(),
            routes: [
              GoRoute(
                path: ':id',
                name: 'patrol-detail',
                builder: (_, state) => PatrolDetailScreen(
                  patrolId: state.pathParameters['id']!,
                ),
              ),
              GoRoute(
                path: 'start',
                name: 'start-patrol',
                builder: (_, __) => const StartPatrolScreen(),
              ),
              GoRoute(
                path: 'import',
                name: 'import-patrol',
                builder: (_, __) => const ImportPatrolScreen(),
              ),
            ],
          ),
          GoRoute(
            path: '/schedule',
            name: 'schedule',
            builder: (_, __) => const ScheduleScreen(),
          ),
          GoRoute(
            path: '/reports',
            name: 'reports',
            builder: (_, __) => const ReportsScreen(),
          ),
          GoRoute(
            path: '/settings',
            name: 'settings',
            builder: (_, __) => const SettingsScreen(),
          ),
          GoRoute(
            path: '/profile',
            name: 'profile',
            builder: (_, __) => const ProfileScreen(),
          ),

          // ── Admin routes ──────────────────────────────────────────
          GoRoute(
            path: '/admin',
            name: 'admin',
            builder: (_, __) => const AdminScreen(),
            routes: [
              GoRoute(
                path: 'rangers',
                name: 'admin-rangers',
                builder: (_, __) => const RangerManagementScreen(),
              ),
              GoRoute(
                path: 'photos',
                name: 'admin-photos',
                builder: (_, state) => PhotoGalleryScreen(
                  patrolId: state.uri.queryParameters['patrol_id'],
                ),
              ),
              GoRoute(
                path: 'stations',
                name: 'admin-stations',
                builder: (_, __) => const StationManagementScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (_, state) => Scaffold(
      body: Center(child: Text('Trang không tồn tại: ${state.error}')),
    ),
  );
});

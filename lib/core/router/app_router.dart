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
import 'package:rangeguard_vn/widgets/common/main_scaffold.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/dashboard',
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final isLoggedIn = authState.value?.session != null;
      final isAuthRoute = state.matchedLocation.startsWith('/auth');

      if (!isLoggedIn && !isAuthRoute) return '/auth/login';
      if (isLoggedIn && isAuthRoute) return '/dashboard';
      return null;
    },
    routes: [
      // Auth routes
      GoRoute(
        path: '/auth/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/auth/register',
        name: 'register',
        builder: (context, state) => const RegisterScreen(),
      ),

      // Main shell with navigation
      ShellRoute(
        builder: (context, state, child) => MainScaffold(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            name: 'dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/map',
            name: 'map',
            builder: (context, state) => const MapScreen(),
          ),
          GoRoute(
            path: '/patrols',
            name: 'patrols',
            builder: (context, state) => const PatrolListScreen(),
            routes: [
              GoRoute(
                path: ':id',
                name: 'patrol-detail',
                builder: (context, state) => PatrolDetailScreen(
                  patrolId: state.pathParameters['id']!,
                ),
              ),
              GoRoute(
                path: 'start',
                name: 'start-patrol',
                builder: (context, state) => const StartPatrolScreen(),
              ),
              GoRoute(
                path: 'import',
                name: 'import-patrol',
                builder: (context, state) => const ImportPatrolScreen(),
              ),
            ],
          ),
          GoRoute(
            path: '/schedule',
            name: 'schedule',
            builder: (context, state) => const ScheduleScreen(),
          ),
          GoRoute(
            path: '/reports',
            name: 'reports',
            builder: (context, state) => const ReportsScreen(),
          ),
          GoRoute(
            path: '/settings',
            name: 'settings',
            builder: (context, state) => const SettingsScreen(),
          ),
          GoRoute(
            path: '/profile',
            name: 'profile',
            builder: (context, state) => const ProfileScreen(),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Trang không tồn tại: ${state.error}'),
      ),
    ),
  );
});

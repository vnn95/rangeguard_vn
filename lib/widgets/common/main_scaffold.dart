import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:badges/badges.dart' as badges;
import 'package:rangeguard_vn/core/constants/app_colors.dart';
import 'package:rangeguard_vn/core/utils/offline_sync.dart';
import 'package:rangeguard_vn/providers/auth_provider.dart';

class MainScaffold extends ConsumerStatefulWidget {
  final Widget child;

  const MainScaffold({super.key, required this.child});

  @override
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends ConsumerState<MainScaffold> {
  int _selectedIndex = 0;

  static const _navItems = [
    _NavItem(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard,
        label: 'Tổng quan', route: '/dashboard'),
    _NavItem(icon: Icons.map_outlined, activeIcon: Icons.map,
        label: 'Bản đồ', route: '/map'),
    _NavItem(icon: Icons.hiking_outlined, activeIcon: Icons.hiking,
        label: 'Tuần tra', route: '/patrols'),
    _NavItem(icon: Icons.calendar_month_outlined, activeIcon: Icons.calendar_month,
        label: 'Lịch', route: '/schedule'),
    _NavItem(icon: Icons.bar_chart_outlined, activeIcon: Icons.bar_chart,
        label: 'Báo cáo', route: '/reports'),
  ];

  void _onNavTap(int index) {
    setState(() => _selectedIndex = index);
    context.go(_navItems[index].route);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final location = GoRouterState.of(context).matchedLocation;
    final idx = _navItems.indexWhere((n) => location.startsWith(n.route));
    if (idx >= 0) _selectedIndex = idx;
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 720;
    final profile = ref.watch(authNotifierProvider).valueOrNull;
    final syncPending = OfflineSyncService().pendingCount;

    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _selectedIndex,
              onDestinationSelected: _onNavTap,
              labelType: NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.forest,
                          color: Colors.white, size: 28),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'RangerGuard',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              trailing: Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (syncPending > 0)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: badges.Badge(
                              badgeContent: Text(
                                '$syncPending',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 10),
                              ),
                              child: const Icon(Icons.sync,
                                  color: AppColors.warning),
                            ),
                          ),
                        IconButton(
                          onPressed: () => context.go('/profile'),
                          icon: CircleAvatar(
                            radius: 18,
                            backgroundColor: AppColors.primaryContainer,
                            backgroundImage: profile?.avatarUrl != null
                                ? NetworkImage(profile!.avatarUrl!)
                                : null,
                            child: profile?.avatarUrl == null
                                ? Text(
                                    profile?.fullName.isNotEmpty == true
                                        ? profile!.fullName[0].toUpperCase()
                                        : 'U',
                                    style: const TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.bold),
                                  )
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              destinations: _navItems
                  .map((n) => NavigationRailDestination(
                        icon: Icon(n.icon),
                        selectedIcon: Icon(n.activeIcon),
                        label: Text(n.label),
                      ))
                  .toList(),
            ),
            const VerticalDivider(thickness: 0.5, width: 0.5),
            Expanded(child: widget.child),
          ],
        ),
      );
    }

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onNavTap,
        destinations: _navItems
            .map((n) => NavigationDestination(
                  icon: Icon(n.icon),
                  selectedIcon: Icon(n.activeIcon),
                  label: n.label,
                ))
            .toList(),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String route;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.route,
  });
}

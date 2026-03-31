import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import 'package:rangeguard_vn/core/constants/app_colors.dart';
import 'package:rangeguard_vn/core/utils/date_utils.dart';
import 'package:rangeguard_vn/core/utils/geo_utils.dart';
import 'package:rangeguard_vn/providers/auth_provider.dart';
import 'package:rangeguard_vn/providers/patrol_provider.dart';
import 'package:rangeguard_vn/widgets/common/app_loading.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(authNotifierProvider).valueOrNull;
    final statsAsync = ref.watch(patrolStatsProvider);
    final patrolsAsync = ref.watch(patrolsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('RangerGuard VN'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () => context.go('/profile'),
              child: CircleAvatar(
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
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(patrolStatsProvider);
          ref.invalidate(patrolsProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Greeting
              Text(
                'Xin chào, ${profile?.fullName ?? 'Ranger'}!',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryDark,
                ),
              ),
              Text(
                AppDateUtils.formatDate(DateTime.now()),
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 24),

              // Quick actions
              _QuickActions(),
              const SizedBox(height: 24),

              // Stats cards
              statsAsync.when(
                data: (stats) => _StatsGrid(stats: stats),
                loading: () => const AppLoading(),
                error: (e, _) => AppError(message: e.toString()),
              ),
              const SizedBox(height: 24),

              // Chart
              const Text(
                'Hoạt động tuần tra (tháng này)',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: 12),
              statsAsync.when(
                data: (stats) => _PatrolChart(
                  patrolsByDay: Map<String, int>.from(
                    stats['patrols_by_day'] as Map? ?? {},
                  ),
                ),
                loading: () => const SizedBox(height: 200, child: AppLoading()),
                error: (_, __) => const SizedBox(),
              ),
              const SizedBox(height: 24),

              // Recent patrols
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Tuần tra gần đây',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.go('/patrols'),
                    child: const Text('Xem tất cả'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              patrolsAsync.when(
                data: (patrols) => patrols.isEmpty
                    ? const AppEmpty(
                        message: 'Chưa có chuyến tuần tra nào',
                        icon: Icons.hiking_outlined,
                      )
                    : Column(
                        children: patrols
                            .take(5)
                            .map((p) => _PatrolCard(
                                  title: p.patrolId,
                                  subtitle: p.leaderName,
                                  date: AppDateUtils.formatDateTime(p.startTime),
                                  distance: GeoUtils.formatDistance(
                                      p.totalDistanceMeters ?? 0),
                                  status: p.status.name,
                                  onTap: () =>
                                      context.go('/patrols/${p.id}'),
                                ))
                            .toList(),
                      ),
                loading: () => const AppLoading(),
                error: (e, _) => AppError(message: e.toString()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      children: [
        _ActionButton(
          icon: Icons.play_circle_outline,
          label: 'Bắt đầu\ntuần tra',
          color: AppColors.primary,
          onTap: () => context.go('/patrols/start'),
        ),
        _ActionButton(
          icon: Icons.upload_file_outlined,
          label: 'Import\nSMART',
          color: AppColors.accent,
          onTap: () => context.go('/patrols/import'),
        ),
        _ActionButton(
          icon: Icons.map_outlined,
          label: 'Xem\nbản đồ',
          color: AppColors.secondary,
          onTap: () => context.go('/map'),
        ),
        _ActionButton(
          icon: Icons.calendar_today_outlined,
          label: 'Lập\nlịch',
          color: const Color(0xFF6A1B9A),
          onTap: () => context.go('/schedule'),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final Map<String, dynamic> stats;

  const _StatsGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _StatCard(
          label: 'Chuyến tuần tra',
          value: '${stats['total_patrols'] ?? 0}',
          icon: Icons.hiking,
          color: AppColors.primary,
          subtitle: 'tháng này',
        ),
        _StatCard(
          label: 'Tổng quãng đường',
          value: '${((stats['total_distance_km'] as double?) ?? 0).toStringAsFixed(1)} km',
          icon: Icons.route,
          color: AppColors.accent,
          subtitle: 'tháng này',
        ),
        _StatCard(
          label: 'Tuần tra viên',
          value: '${stats['active_rangers'] ?? 0}',
          icon: Icons.groups,
          color: AppColors.secondary,
          subtitle: 'đang hoạt động',
        ),
        _StatCard(
          label: 'Sync chờ',
          value: '0',
          icon: Icons.sync,
          color: AppColors.warning,
          subtitle: 'offline items',
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String subtitle;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider, width: 0.5),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                  maxLines: 2,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PatrolChart extends StatelessWidget {
  final Map<String, int> patrolsByDay;

  const _PatrolChart({required this.patrolsByDay});

  @override
  Widget build(BuildContext context) {
    if (patrolsByDay.isEmpty) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider, width: 0.5),
        ),
        child: const AppEmpty(
          message: 'Chưa có dữ liệu',
          icon: Icons.bar_chart_outlined,
        ),
      );
    }

    final sorted = patrolsByDay.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final maxVal = sorted.map((e) => e.value).reduce((a, b) => a > b ? a : b);

    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider, width: 0.5),
      ),
      padding: const EdgeInsets.all(16),
      child: BarChart(
        BarChartData(
          maxY: (maxVal + 1).toDouble(),
          barGroups: sorted.asMap().entries.map((entry) {
            return BarChartGroupData(
              x: entry.key,
              barRods: [
                BarChartRodData(
                  toY: entry.value.value.toDouble(),
                  color: AppColors.primary,
                  width: 12,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(6),
                  ),
                ),
              ],
            );
          }).toList(),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (val, meta) {
                  final idx = val.toInt();
                  if (idx >= sorted.length) return const SizedBox();
                  final key = sorted[idx].key;
                  final day = key.split('-').last;
                  return Text(day,
                      style: const TextStyle(fontSize: 10, color: Colors.grey));
                },
                reservedSize: 20,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                getTitlesWidget: (val, meta) => Text(
                  val.toInt().toString(),
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ),
            ),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 1,
            getDrawingHorizontalLine: (_) => FlLine(
              color: AppColors.divider,
              strokeWidth: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _PatrolCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String date;
  final String distance;
  final String status;
  final VoidCallback onTap;

  const _PatrolCard({
    required this.title,
    required this.subtitle,
    required this.date,
    required this.distance,
    required this.status,
    required this.onTap,
  });

  Color get _statusColor {
    switch (status) {
      case 'active':
        return AppColors.patrolActive;
      case 'completed':
        return AppColors.patrolCompleted;
      case 'scheduled':
        return AppColors.patrolScheduled;
      default:
        return AppColors.patrolCancelled;
    }
  }

  String get _statusLabel {
    switch (status) {
      case 'active':
        return 'Đang tuần tra';
      case 'completed':
        return 'Hoàn thành';
      case 'scheduled':
        return 'Đã lên lịch';
      default:
        return 'Đã huỷ';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.hiking, color: _statusColor, size: 24),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subtitle, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 2),
            Text(date, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _statusLabel,
                style: TextStyle(
                  color: _statusColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              distance,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }
}

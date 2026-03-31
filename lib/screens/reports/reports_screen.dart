import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rangeguard_vn/core/constants/app_colors.dart';
import 'package:rangeguard_vn/core/utils/date_utils.dart';
import 'package:rangeguard_vn/providers/patrol_provider.dart';
import 'package:rangeguard_vn/widgets/common/app_loading.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(patrolStatsProvider);
    final patrolsAsync = ref.watch(patrolsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Báo cáo & Thống kê'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_outlined),
            onPressed: () => _showExportDialog(context),
            tooltip: 'Xuất báo cáo',
          ),
        ],
      ),
      body: statsAsync.when(
        loading: () => const AppLoading(message: 'Đang tổng hợp dữ liệu...'),
        error: (e, _) => AppError(message: e.toString()),
        data: (stats) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Period selector
              _PeriodSelector(),
              const SizedBox(height: 20),

              // Summary cards
              _SummaryCards(stats: stats),
              const SizedBox(height: 24),

              // Activity chart
              const Text(
                'Hoạt động tuần tra',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: 12),
              _ActivityBarChart(
                patrolsByDay: Map<String, int>.from(
                  stats['patrols_by_day'] as Map? ?? {},
                ),
              ),
              const SizedBox(height: 24),

              // Pie chart - transport type
              patrolsAsync.when(
                data: (patrols) {
                  if (patrols.isEmpty) return const SizedBox();
                  final byTransport = <String, int>{};
                  for (final p in patrols) {
                    byTransport[p.transportType] =
                        (byTransport[p.transportType] ?? 0) + 1;
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Phân loại phương tiện',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _TransportPieChart(data: byTransport),
                    ],
                  );
                },
                loading: () => const SizedBox(),
                error: (_, __) => const SizedBox(),
              ),
              const SizedBox(height: 24),

              // Rangers performance table
              patrolsAsync.when(
                data: (patrols) {
                  if (patrols.isEmpty) return const SizedBox();
                  final byRanger = <String, Map<String, dynamic>>{};
                  for (final p in patrols) {
                    final r = byRanger[p.leaderName] ??
                        {'count': 0, 'distance': 0.0};
                    r['count'] = (r['count'] as int) + 1;
                    r['distance'] = (r['distance'] as double) +
                        (p.totalDistanceMeters ?? 0);
                    byRanger[p.leaderName] = r;
                  }
                  final sorted = byRanger.entries.toList()
                    ..sort((a, b) =>
                        (b.value['count'] as int)
                            .compareTo(a.value['count'] as int));

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Thống kê tuần tra viên',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...sorted.take(10).map((e) => _RangerRow(
                            name: e.key,
                            count: e.value['count'] as int,
                            distanceKm: (e.value['distance'] as double) / 1000,
                          )),
                    ],
                  );
                },
                loading: () => const SizedBox(),
                error: (_, __) => const SizedBox(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showExportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xuất báo cáo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.table_chart_outlined,
                  color: AppColors.success),
              title: const Text('Xuất Excel (.xlsx)'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đang xuất Excel...')),
                );
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.picture_as_pdf, color: AppColors.error),
              title: const Text('Xuất PDF'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đang xuất PDF...')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PeriodSelector extends StatefulWidget {
  @override
  State<_PeriodSelector> createState() => _PeriodSelectorState();
}

class _PeriodSelectorState extends State<_PeriodSelector> {
  int _selectedIndex = 0;
  final _options = ['Tháng này', 'Quý này', 'Năm nay', 'Tất cả'];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _options.asMap().entries.map((e) {
        final selected = e.key == _selectedIndex;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text(e.value),
            selected: selected,
            onSelected: (_) => setState(() => _selectedIndex = e.key),
            selectedColor: AppColors.primaryContainer,
            labelStyle: TextStyle(
              color: selected ? AppColors.primary : Colors.grey,
              fontWeight:
                  selected ? FontWeight.w600 : FontWeight.normal,
              fontSize: 12,
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _SummaryCards extends StatelessWidget {
  final Map<String, dynamic> stats;

  const _SummaryCards({required this.stats});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: [
        _SummaryCard(
          label: 'Tổng chuyến tuần tra',
          value: '${stats['total_patrols'] ?? 0}',
          icon: Icons.hiking,
          color: AppColors.primary,
        ),
        _SummaryCard(
          label: 'Tổng quãng đường',
          value:
              '${((stats['total_distance_km'] as double?) ?? 0).toStringAsFixed(1)} km',
          icon: Icons.route,
          color: AppColors.accent,
        ),
        _SummaryCard(
          label: 'Tuần tra viên',
          value: '${stats['active_rangers'] ?? 0}',
          icon: Icons.groups,
          color: AppColors.secondary,
        ),
        _SummaryCard(
          label: 'TB ngày/tuần',
          value: _calcAvgPerDay(stats),
          icon: Icons.trending_up,
          color: AppColors.success,
        ),
      ],
    );
  }

  String _calcAvgPerDay(Map stats) {
    final count = stats['total_patrols'] as int? ?? 0;
    final byDay = stats['patrols_by_day'] as Map? ?? {};
    if (byDay.isEmpty) return '0';
    return (count / byDay.length).toStringAsFixed(1);
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 24),
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
                label,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActivityBarChart extends StatelessWidget {
  final Map<String, int> patrolsByDay;

  const _ActivityBarChart({required this.patrolsByDay});

  @override
  Widget build(BuildContext context) {
    if (patrolsByDay.isEmpty) {
      return Container(
        height: 160,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
        ),
        child: const Center(
          child: Text('Chưa có dữ liệu',
              style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    final sorted = patrolsByDay.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final maxVal = sorted.map((e) => e.value).reduce((a, b) => a > b ? a : b);

    return Container(
      height: 200,
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
                  gradient: const LinearGradient(
                    colors: [AppColors.primaryLight, AppColors.primary],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                  width: 14,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(6)),
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
                  final day = sorted[idx].key.split('-').last;
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(day,
                        style: const TextStyle(
                            fontSize: 10, color: Colors.grey)),
                  );
                },
                reservedSize: 22,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                getTitlesWidget: (val, meta) => Text(
                  val.toInt().toString(),
                  style:
                      const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ),
            ),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                const FlLine(color: AppColors.divider, strokeWidth: 0.5),
          ),
        ),
      ),
    );
  }
}

class _TransportPieChart extends StatelessWidget {
  final Map<String, int> data;

  const _TransportPieChart({required this.data});

  static const _colors = [
    AppColors.primary,
    AppColors.accent,
    AppColors.secondary,
    AppColors.success,
    AppColors.warning,
  ];

  @override
  Widget build(BuildContext context) {
    final entries = data.entries.toList();
    final total = data.values.fold(0, (a, b) => a + b);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider, width: 0.5),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 160,
            height: 160,
            child: PieChart(
              PieChartData(
                sections: entries.asMap().entries.map((e) {
                  final color = _colors[e.key % _colors.length];
                  final pct = e.value.value / total * 100;
                  return PieChartSectionData(
                    color: color,
                    value: e.value.value.toDouble(),
                    title: '${pct.toStringAsFixed(0)}%',
                    radius: 60,
                    titleStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  );
                }).toList(),
                sectionsSpace: 2,
                centerSpaceRadius: 30,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: entries.asMap().entries.map((e) {
                final color = _colors[e.key % _colors.length];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          e.value.key,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      Text(
                        '${e.value.value}',
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _RangerRow extends StatelessWidget {
  final String name;
  final int count;
  final double distanceKm;

  const _RangerRow({
    required this.name,
    required this.count,
    required this.distanceKm,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider, width: 0.5),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primaryContainer,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : 'R',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$count chuyến',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              Text(
                '${distanceKm.toStringAsFixed(1)} km',
                style: const TextStyle(color: Colors.grey, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

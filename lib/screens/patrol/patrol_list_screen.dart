import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rangeguard_vn/core/constants/app_colors.dart';
import 'package:rangeguard_vn/core/utils/date_utils.dart';
import 'package:rangeguard_vn/core/utils/geo_utils.dart';
import 'package:rangeguard_vn/models/patrol_model.dart';
import 'package:rangeguard_vn/providers/patrol_provider.dart';
import 'package:rangeguard_vn/widgets/common/app_loading.dart';

class PatrolListScreen extends ConsumerStatefulWidget {
  const PatrolListScreen({super.key});

  @override
  ConsumerState<PatrolListScreen> createState() => _PatrolListScreenState();
}

class _PatrolListScreenState extends ConsumerState<PatrolListScreen> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final patrolsAsync = ref.watch(patrolsProvider);
    final filter = ref.watch(patrolFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý tuần tra'),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file_outlined),
            onPressed: () => context.go('/patrols/import'),
            tooltip: 'Import SMART',
          ),
          IconButton(
            icon: const Icon(Icons.filter_alt_outlined),
            onPressed: () => _showFilterDialog(context),
            tooltip: 'Lọc',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Tìm theo PatrolID, tên người...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
              ),
              onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
            ),
          ),

          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _FilterChip(
                  label:
                      '${AppDateUtils.formatDate(filter.from ?? DateTime.now())} - ${AppDateUtils.formatDate(filter.to ?? DateTime.now())}',
                  icon: Icons.date_range,
                  onTap: () => _showFilterDialog(context),
                ),
              ],
            ),
          ),

          // List
          Expanded(
            child: patrolsAsync.when(
              data: (patrols) {
                final filtered = _searchQuery.isEmpty
                    ? patrols
                    : patrols.where((p) {
                        return p.patrolId.toLowerCase().contains(_searchQuery) ||
                            p.leaderName.toLowerCase().contains(_searchQuery) ||
                            p.stationName.toLowerCase().contains(_searchQuery);
                      }).toList();

                if (filtered.isEmpty) {
                  return const AppEmpty(
                    message: 'Không tìm thấy chuyến tuần tra nào',
                    icon: Icons.hiking_outlined,
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(patrolsProvider),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) => _PatrolListCard(
                      patrol: filtered[i],
                      onTap: () => context.go('/patrols/${filtered[i].id}'),
                    ),
                  ),
                );
              },
              loading: () => const AppLoading(message: 'Đang tải danh sách...'),
              error: (e, _) => AppError(
                message: 'Lỗi tải dữ liệu: $e',
                onRetry: () => ref.invalidate(patrolsProvider),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/patrols/start'),
        icon: const Icon(Icons.play_arrow),
        label: const Text('Bắt đầu tuần tra'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  void _showFilterDialog(BuildContext context) {
    final filter = ref.read(patrolFilterProvider);
    DateTime? from = filter.from;
    DateTime? to = filter.to;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Lọc tuần tra'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.date_range),
              title: const Text('Từ ngày'),
              subtitle: Text(from != null ? AppDateUtils.formatDate(from!) : 'Tất cả'),
              onTap: () async {
                final picked = await showDatePicker(
                  context: ctx,
                  initialDate: from ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null) from = picked;
              },
            ),
            ListTile(
              leading: const Icon(Icons.date_range),
              title: const Text('Đến ngày'),
              subtitle: Text(to != null ? AppDateUtils.formatDate(to!) : 'Tất cả'),
              onTap: () async {
                final picked = await showDatePicker(
                  context: ctx,
                  initialDate: to ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) to = picked;
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              ref.read(patrolFilterProvider.notifier).state = const PatrolFilter();
              Navigator.pop(ctx);
            },
            child: const Text('Xóa lọc'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(patrolFilterProvider.notifier).state =
                  PatrolFilter(from: from, to: to);
              Navigator.pop(ctx);
            },
            child: const Text('Áp dụng'),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.primaryContainer,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PatrolListCard extends StatelessWidget {
  final Patrol patrol;
  final VoidCallback onTap;

  const _PatrolListCard({required this.patrol, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(patrol.status);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      patrol.patrolId,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _statusLabel(patrol.status),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _MetaItem(
                    icon: Icons.person_outline,
                    value: patrol.leaderName,
                  ),
                  const SizedBox(width: 16),
                  _MetaItem(
                    icon: Icons.home_work_outlined,
                    value: patrol.stationName,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  _MetaItem(
                    icon: Icons.access_time,
                    value: AppDateUtils.formatDateTime(patrol.startTime),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Row(
                children: [
                  _StatPill(
                    icon: Icons.route,
                    value: GeoUtils.formatDistance(
                        patrol.totalDistanceMeters ?? 0),
                  ),
                  const SizedBox(width: 8),
                  if (patrol.totalWaypoints != null)
                    _StatPill(
                      icon: Icons.location_on_outlined,
                      value: '${patrol.totalWaypoints} điểm',
                    ),
                  const SizedBox(width: 8),
                  if (patrol.duration != null)
                    _StatPill(
                      icon: Icons.timer_outlined,
                      value: _formatDuration(patrol.duration!),
                    ),
                  const Spacer(),
                  Icon(Icons.chevron_right,
                      color: Colors.grey[400], size: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(PatrolStatus s) {
    switch (s) {
      case PatrolStatus.active:
        return AppColors.patrolActive;
      case PatrolStatus.completed:
        return AppColors.patrolCompleted;
      case PatrolStatus.scheduled:
        return AppColors.patrolScheduled;
      case PatrolStatus.cancelled:
        return AppColors.patrolCancelled;
    }
  }

  String _statusLabel(PatrolStatus s) {
    switch (s) {
      case PatrolStatus.active:
        return 'Đang tuần tra';
      case PatrolStatus.completed:
        return 'Hoàn thành';
      case PatrolStatus.scheduled:
        return 'Đã lên lịch';
      case PatrolStatus.cancelled:
        return 'Đã huỷ';
    }
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }
}

class _MetaItem extends StatelessWidget {
  final IconData icon;
  final String value;

  const _MetaItem({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey),
        const SizedBox(width: 4),
        Text(value,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
      ],
    );
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String value;

  const _StatPill({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(value,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryDark)),
        ],
      ),
    );
  }
}

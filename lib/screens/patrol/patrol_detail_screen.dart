import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:rangeguard_vn/core/constants/app_colors.dart';
import 'package:rangeguard_vn/core/constants/app_constants.dart';
import 'package:rangeguard_vn/core/utils/date_utils.dart';
import 'package:rangeguard_vn/core/utils/geo_utils.dart';
import 'package:rangeguard_vn/models/patrol_model.dart';
import 'package:rangeguard_vn/models/waypoint_model.dart';
import 'package:rangeguard_vn/providers/patrol_provider.dart';
import 'package:rangeguard_vn/widgets/common/app_loading.dart';

class PatrolDetailScreen extends ConsumerStatefulWidget {
  final String patrolId;
  const PatrolDetailScreen({super.key, required this.patrolId});

  @override
  ConsumerState<PatrolDetailScreen> createState() => _PatrolDetailScreenState();
}

class _PatrolDetailScreenState extends ConsumerState<PatrolDetailScreen> {
  int _pageSize = 20;
  int _page = 0;

  // Highlight a waypoint on the map when tapped in list
  int? _highlightedIndex;

  @override
  Widget build(BuildContext context) {
    final patrolAsync = ref.watch(patrolDetailProvider(widget.patrolId));
    final waypointsAsync = ref.watch(waypointsProvider(widget.patrolId));

    return Scaffold(
      appBar: AppBar(
        title: patrolAsync.when(
          data: (p) => Text(p?.patrolId ?? 'Chi tiết tuần tra'),
          loading: () => const Text('Chi tiết tuần tra'),
          error: (_, __) => const Text('Chi tiết tuần tra'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Tải lại',
            onPressed: () {
              ref.invalidate(patrolDetailProvider(widget.patrolId));
              ref.invalidate(waypointsProvider(widget.patrolId));
            },
          ),
        ],
      ),
      body: patrolAsync.when(
        loading: () => const AppLoading(message: 'Đang tải dữ liệu...'),
        error: (e, _) => AppError(
          message: 'Lỗi tải tuần tra: $e',
          onRetry: () => ref.invalidate(patrolDetailProvider(widget.patrolId)),
        ),
        data: (patrol) {
          if (patrol == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.search_off, size: 64, color: Colors.grey),
                  const SizedBox(height: 12),
                  const Text('Không tìm thấy chuyến tuần tra',
                      style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 8),
                  Text('ID: ${widget.patrolId}',
                      style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                          fontFamily: 'monospace')),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('Thử lại'),
                    onPressed: () =>
                        ref.invalidate(patrolDetailProvider(widget.patrolId)),
                  ),
                ],
              ),
            );
          }

          return waypointsAsync.when(
            loading: () => const AppLoading(message: 'Đang tải waypoints...'),
            error: (e, _) => AppError(message: 'Lỗi tải waypoints: $e'),
            data: (waypoints) =>
                _buildContent(context, patrol, waypoints),
          );
        },
      ),
    );
  }

  Widget _buildContent(
      BuildContext context, Patrol patrol, List<Waypoint> waypoints) {
    final points = waypoints.map((w) => w.latLng).toList();
    final center = points.isNotEmpty
        ? GeoUtils.centerOf(points)
        : const LatLng(15.88, 108.33);

    // Pagination
    final totalPages = (_pageSize > 0 && waypoints.isNotEmpty)
        ? ((waypoints.length - 1) ~/ _pageSize) + 1
        : 1;
    final safePage = _page.clamp(0, totalPages - 1);
    final start = safePage * _pageSize;
    final end = (start + _pageSize).clamp(0, waypoints.length);
    final pageWaypoints = waypoints.sublist(start, end);

    return CustomScrollView(
      slivers: [
        // ── Map ─────────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: SizedBox(
            height: 300,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: center,
                initialZoom: points.length <= 1 ? 13 : 12,
              ),
              children: [
                TileLayer(
                  urlTemplate: AppConstants.osmTileUrl,
                  userAgentPackageName: 'com.rangeguard.vn',
                ),
                if (points.length >= 2)
                  PolylineLayer(polylines: [
                    Polyline(
                      points: points,
                      strokeWidth: 3.5,
                      color: AppColors.primary.withValues(alpha: 0.85),
                    ),
                  ]),
                MarkerLayer(
                  markers: _buildMarkers(waypoints),
                ),
              ],
            ),
          ),
        ),

        // ── Stats bar ────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                _StatCard(
                  icon: Icons.route,
                  label: 'Quãng đường',
                  value: GeoUtils.formatDistance(
                      patrol.totalDistanceMeters ?? 0),
                  color: AppColors.primary,
                ),
                const SizedBox(width: 10),
                _StatCard(
                  icon: Icons.timer_outlined,
                  label: 'Thời gian',
                  value: patrol.duration != null
                      ? AppDateUtils.formatDuration(patrol.duration!)
                      : '--',
                  color: AppColors.accent,
                ),
                const SizedBox(width: 10),
                _StatCard(
                  icon: Icons.location_on_outlined,
                  label: 'Điểm GPS',
                  value: '${waypoints.length}',
                  color: AppColors.secondary,
                ),
                const SizedBox(width: 10),
                _StatCard(
                  icon: Icons.speed,
                  label: 'Tốc độ TB',
                  value: patrol.avgSpeedKmh != null
                      ? '${patrol.avgSpeedKmh!.toStringAsFixed(1)} km/h'
                      : '--',
                  color: AppColors.warning,
                ),
              ],
            ),
          ),
        ),

        // ── Patrol info ──────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionHeader('Thông tin chuyến tuần tra'),
                const SizedBox(height: 8),
                _InfoTable([
                  _InfoRow('Mã tuần tra', patrol.patrolId,
                      icon: Icons.tag),
                  _InfoRow('Trưởng đội', patrol.leaderName,
                      icon: Icons.person_outline),
                  _InfoRow('Trạm', patrol.stationName.isNotEmpty
                      ? patrol.stationName
                      : '–',
                      icon: Icons.home_work_outlined),
                  _InfoRow('Phương tiện', patrol.transportType,
                      icon: Icons.directions_walk_outlined),
                  _InfoRow('Nhiệm vụ', patrol.mandate,
                      icon: Icons.assignment_outlined),
                  _InfoRow(
                      'Bắt đầu',
                      AppDateUtils.formatDateTime(patrol.startTime),
                      icon: Icons.play_circle_outline),
                  if (patrol.endTime != null)
                    _InfoRow(
                        'Kết thúc',
                        AppDateUtils.formatDateTime(patrol.endTime!),
                        icon: Icons.stop_circle_outlined),
                  _InfoRow('Trạng thái', _statusLabel(patrol.status),
                      icon: Icons.info_outline,
                      valueColor: _statusColor(patrol.status)),
                  if (patrol.comments != null && patrol.comments!.isNotEmpty)
                    _InfoRow('Ghi chú', patrol.comments!,
                        icon: Icons.notes_outlined),
                ]),
              ],
            ),
          ),
        ),

        // ── Waypoint observation summary ─────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
            child: _ObservationSummary(waypoints: waypoints),
          ),
        ),

        // ── Waypoints section header + pagination controls ───────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionHeader('Danh sách điểm GPS'),
                const SizedBox(height: 10),
                _PaginationBar(
                  total: waypoints.length,
                  pageSize: _pageSize,
                  page: safePage,
                  totalPages: totalPages,
                  onPageSizeChanged: (s) =>
                      setState(() { _pageSize = s; _page = 0; }),
                  onPrev: safePage > 0
                      ? () => setState(() => _page = safePage - 1)
                      : null,
                  onNext: safePage < totalPages - 1
                      ? () => setState(() => _page = safePage + 1)
                      : null,
                ),
              ],
            ),
          ),
        ),

        // ── Waypoint list ────────────────────────────────────────────
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, i) {
              final globalIndex = start + i;
              return _WaypointRow(
                index: globalIndex + 1,
                waypoint: pageWaypoints[i],
                highlighted: _highlightedIndex == globalIndex,
                onTap: () => setState(() =>
                    _highlightedIndex =
                        _highlightedIndex == globalIndex ? null : globalIndex),
              );
            },
            childCount: pageWaypoints.length,
          ),
        ),

        // ── Bottom pagination ────────────────────────────────────────
        if (totalPages > 1)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: _PaginationBar(
                total: waypoints.length,
                pageSize: _pageSize,
                page: safePage,
                totalPages: totalPages,
                onPageSizeChanged: (s) =>
                    setState(() { _pageSize = s; _page = 0; }),
                onPrev: safePage > 0
                    ? () => setState(() => _page = safePage - 1)
                    : null,
                onNext: safePage < totalPages - 1
                    ? () => setState(() => _page = safePage + 1)
                    : null,
              ),
            ),
          ),

        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  List<Marker> _buildMarkers(List<Waypoint> waypoints) {
    final markers = <Marker>[];
    for (int i = 0; i < waypoints.length; i++) {
      final w = waypoints[i];
      final color = _waypointColor(w);
      final icon = _waypointIcon(w);
      final isHighlighted = _highlightedIndex == i;

      markers.add(Marker(
        point: w.latLng,
        width: isHighlighted ? 36 : 24,
        height: isHighlighted ? 36 : 24,
        child: Container(
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
                color: Colors.white, width: isHighlighted ? 2.5 : 1.5),
            boxShadow: [
              BoxShadow(
                  color: color.withValues(alpha: 0.5),
                  blurRadius: isHighlighted ? 8 : 4)
            ],
          ),
          child: Icon(icon,
              color: Colors.white, size: isHighlighted ? 20 : 13),
        ),
      ));
    }
    return markers;
  }

  Color _waypointColor(Waypoint w) {
    switch (w.observationType) {
      case 'NewPatrol':
        return AppColors.mapStartMarker;
      case 'StopPatrol':
        return AppColors.mapEndMarker;
      case 'Animal':
        return const Color(0xFF8B4513);
      case 'Threat':
        return AppColors.error;
      case 'Photo':
        return const Color(0xFF6A1B9A);
      default:
        return AppColors.mapWaypoint;
    }
  }

  IconData _waypointIcon(Waypoint w) {
    switch (w.observationType) {
      case 'NewPatrol':
        return Icons.play_arrow;
      case 'StopPatrol':
        return Icons.stop;
      case 'Animal':
        return Icons.pets;
      case 'Threat':
        return Icons.warning_amber;
      case 'Photo':
        return Icons.photo_camera;
      default:
        return Icons.circle;
    }
  }

  String _statusLabel(PatrolStatus s) {
    switch (s) {
      case PatrolStatus.active:     return 'Đang tuần tra';
      case PatrolStatus.completed:  return 'Hoàn thành';
      case PatrolStatus.scheduled:  return 'Đã lên lịch';
      case PatrolStatus.cancelled:  return 'Đã huỷ';
    }
  }

  Color _statusColor(PatrolStatus s) {
    switch (s) {
      case PatrolStatus.active:     return AppColors.patrolActive;
      case PatrolStatus.completed:  return AppColors.patrolCompleted;
      case PatrolStatus.scheduled:  return AppColors.patrolScheduled;
      case PatrolStatus.cancelled:  return AppColors.patrolCancelled;
    }
  }
}

// ── Observation summary chips ─────────────────────────────────────────────────

class _ObservationSummary extends StatelessWidget {
  final List<Waypoint> waypoints;
  const _ObservationSummary({required this.waypoints});

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    for (final w in waypoints) {
      counts[w.observationType] = (counts[w.observationType] ?? 0) + 1;
    }
    if (counts.isEmpty) return const SizedBox.shrink();

    final labels = {
      'NewPatrol': ('Bắt đầu', Icons.play_circle_outline, AppColors.mapStartMarker),
      'StopPatrol': ('Kết thúc', Icons.stop_circle_outlined, AppColors.mapEndMarker),
      'Waypoint': ('GPS', Icons.location_on_outlined, AppColors.mapWaypoint),
      'Animal': ('Động vật', Icons.pets, const Color(0xFF8B4513)),
      'Threat': ('Mối đe dọa', Icons.warning_amber_outlined, AppColors.error),
      'Photo': ('Ảnh', Icons.photo_camera_outlined, const Color(0xFF6A1B9A)),
    };

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: counts.entries.map((e) {
        final info = labels[e.key];
        final label = info?.$1 ?? e.key;
        final icon = info?.$2 ?? Icons.place;
        final color = info?.$3 ?? AppColors.primary;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 5),
              Text('$label: ${e.value}',
                  style: TextStyle(
                      fontSize: 12,
                      color: color,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ── Pagination bar ────────────────────────────────────────────────────────────

class _PaginationBar extends StatelessWidget {
  final int total;
  final int pageSize;
  final int page;
  final int totalPages;
  final ValueChanged<int> onPageSizeChanged;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  const _PaginationBar({
    required this.total,
    required this.pageSize,
    required this.page,
    required this.totalPages,
    required this.onPageSizeChanged,
    this.onPrev,
    this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final start = page * pageSize + 1;
    final end = ((page + 1) * pageSize).clamp(1, total);

    return Row(
      children: [
        // Page size dropdown
        const Text('Hiển thị',
            style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(6),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: pageSize,
              isDense: true,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.primaryDark),
              items: [10, 20, 50, 100].map((s) => DropdownMenuItem(
                value: s,
                child: Text('$s'),
              )).toList(),
              onChanged: (v) => onPageSizeChanged(v!),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            total == 0
                ? 'Không có dữ liệu'
                : '$start–$end trong $total điểm',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
        // Prev / Next
        Text('Trang ${page + 1}/$totalPages',
            style: const TextStyle(
                fontSize: 12,
                color: AppColors.primaryDark,
                fontWeight: FontWeight.w600)),
        const SizedBox(width: 4),
        IconButton(
          icon: const Icon(Icons.chevron_left),
          iconSize: 20,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          onPressed: onPrev,
          color: onPrev != null ? AppColors.primary : Colors.grey.shade300,
          tooltip: 'Trang trước',
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          iconSize: 20,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          onPressed: onNext,
          color: onNext != null ? AppColors.primary : Colors.grey.shade300,
          tooltip: 'Trang sau',
        ),
      ],
    );
  }
}

// ── Waypoint row ──────────────────────────────────────────────────────────────

class _WaypointRow extends StatelessWidget {
  final int index;
  final Waypoint waypoint;
  final bool highlighted;
  final VoidCallback onTap;

  const _WaypointRow({
    required this.index,
    required this.waypoint,
    required this.highlighted,
    required this.onTap,
  });

  static const _typeLabels = {
    'NewPatrol':  'Bắt đầu',
    'StopPatrol': 'Kết thúc',
    'Waypoint':   'GPS',
    'Animal':     'Động vật',
    'Threat':     'Mối đe dọa',
    'Photo':      'Ảnh',
  };

  Color get _color {
    switch (waypoint.observationType) {
      case 'NewPatrol':  return AppColors.mapStartMarker;
      case 'StopPatrol': return AppColors.mapEndMarker;
      case 'Animal':     return const Color(0xFF8B4513);
      case 'Threat':     return AppColors.error;
      case 'Photo':      return const Color(0xFF6A1B9A);
      default:           return AppColors.mapWaypoint;
    }
  }

  IconData get _icon {
    switch (waypoint.observationType) {
      case 'NewPatrol':  return Icons.play_arrow;
      case 'StopPatrol': return Icons.stop;
      case 'Animal':     return Icons.pets;
      case 'Threat':     return Icons.warning_amber;
      case 'Photo':      return Icons.photo_camera;
      default:           return Icons.location_on;
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = _typeLabels[waypoint.observationType] ?? waypoint.observationType;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      decoration: BoxDecoration(
        color: highlighted
            ? _color.withValues(alpha: 0.06)
            : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: highlighted
              ? _color.withValues(alpha: 0.4)
              : Colors.grey.shade200,
          width: highlighted ? 1.5 : 0.5,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Index + icon
              Column(
                children: [
                  Text(
                    '$index',
                    style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: _color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(_icon, color: _color, size: 14),
                  ),
                ],
              ),
              const SizedBox(width: 10),
              // Main content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Type badge + timestamp
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: _color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            label,
                            style: TextStyle(
                                fontSize: 11,
                                color: _color,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            AppDateUtils.formatDateTime(waypoint.timestamp),
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Coordinates
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 11, color: Colors.grey),
                        const SizedBox(width: 3),
                        Text(
                          '${waypoint.latitude.toStringAsFixed(6)}, '
                          '${waypoint.longitude.toStringAsFixed(6)}',
                          style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                              fontFamily: 'monospace'),
                        ),
                      ],
                    ),
                    // Altitude + accuracy row
                    if (waypoint.altitude != null || waypoint.accuracy != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          children: [
                            if (waypoint.altitude != null) ...[
                              const Icon(Icons.height,
                                  size: 11, color: Colors.grey),
                              const SizedBox(width: 3),
                              Text(
                                '${waypoint.altitude!.toStringAsFixed(0)} m',
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.grey),
                              ),
                              const SizedBox(width: 10),
                            ],
                            if (waypoint.accuracy != null) ...[
                              const Icon(Icons.gps_fixed,
                                  size: 11, color: Colors.grey),
                              const SizedBox(width: 3),
                              Text(
                                '±${waypoint.accuracy!.toStringAsFixed(0)} m',
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ],
                        ),
                      ),
                    // Notes
                    if (waypoint.notes != null && waypoint.notes!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.notes,
                                size: 12, color: Colors.grey),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                waypoint.notes!,
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic),
                              ),
                            ),
                          ],
                        ),
                      ),
                    // Photo indicator
                    if (waypoint.hasPhoto)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            Icon(Icons.photo_camera,
                                size: 12,
                                color: const Color(0xFF6A1B9A)
                                    .withValues(alpha: 0.7)),
                            const SizedBox(width: 4),
                            const Text('Có ảnh đính kèm',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF6A1B9A))),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) => Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppColors.primaryDark,
        ),
      );
}

class _InfoTable extends StatelessWidget {
  final List<_InfoRow> rows;
  const _InfoTable(this.rows);

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: rows.asMap().entries.map((e) {
            final isLast = e.key == rows.length - 1;
            return _InfoRowWidget(row: e.value, isLast: isLast);
          }).toList(),
        ),
      );
}

class _InfoRow {
  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;
  const _InfoRow(this.label, this.value,
      {required this.icon, this.valueColor});
}

class _InfoRowWidget extends StatelessWidget {
  final _InfoRow row;
  final bool isLast;
  const _InfoRowWidget({required this.row, required this.isLast});

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(
              children: [
                Icon(row.icon, size: 15, color: Colors.grey),
                const SizedBox(width: 8),
                SizedBox(
                  width: 110,
                  child: Text(row.label,
                      style: const TextStyle(
                          fontSize: 12, color: Colors.grey)),
                ),
                Expanded(
                  child: Text(
                    row.value,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: row.valueColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (!isLast)
            Divider(
                height: 1,
                indent: 12,
                endIndent: 12,
                color: Colors.grey.shade100),
        ],
      );
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(height: 3),
              Text(value,
                  style: TextStyle(
                      color: color,
                      fontSize: 13,
                      fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center),
              Text(label,
                  style: const TextStyle(fontSize: 9, color: Colors.grey),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      );
}

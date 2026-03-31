import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:rangeguard_vn/core/constants/app_colors.dart';
import 'package:rangeguard_vn/core/constants/app_constants.dart';
import 'package:rangeguard_vn/core/utils/date_utils.dart';
import 'package:rangeguard_vn/core/utils/geo_utils.dart';
import 'package:rangeguard_vn/models/waypoint_model.dart';
import 'package:rangeguard_vn/providers/patrol_provider.dart';
import 'package:rangeguard_vn/widgets/common/app_loading.dart';

class PatrolDetailScreen extends ConsumerWidget {
  final String patrolId;

  const PatrolDetailScreen({super.key, required this.patrolId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patrolAsync = ref.watch(patrolDetailProvider(patrolId));
    final waypointsAsync = ref.watch(waypointsProvider(patrolId));

    return Scaffold(
      appBar: AppBar(
        title: patrolAsync.when(
          data: (p) => Text(p?.patrolId ?? 'Chi tiết tuần tra'),
          loading: () => const Text('Chi tiết tuần tra'),
          error: (_, __) => const Text('Chi tiết tuần tra'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.download_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: patrolAsync.when(
        data: (patrol) {
          if (patrol == null) {
            return const AppEmpty(
              message: 'Không tìm thấy chuyến tuần tra',
              icon: Icons.search_off,
            );
          }

          return waypointsAsync.when(
            data: (waypoints) {
              final points = waypoints.map((w) => w.latLng).toList();
              final center = points.isNotEmpty
                  ? GeoUtils.centerOf(points)
                  : const LatLng(15.88, 108.33);

              return CustomScrollView(
                slivers: [
                  // Map header
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 250,
                      child: FlutterMap(
                        options: MapOptions(
                          initialCenter: center,
                          initialZoom: 13,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: AppConstants.osmTileUrl,
                            userAgentPackageName: 'com.rangeguard.vn',
                          ),
                          if (points.length >= 2)
                            PolylineLayer(
                              polylines: [
                                Polyline(
                                  points: points,
                                  strokeWidth: 4,
                                  color: AppColors.primary,
                                ),
                              ],
                            ),
                          MarkerLayer(
                            markers: [
                              if (points.isNotEmpty)
                                Marker(
                                  point: points.first,
                                  child: const Icon(
                                    Icons.play_circle,
                                    color: AppColors.mapStartMarker,
                                    size: 28,
                                  ),
                                ),
                              if (points.length > 1)
                                Marker(
                                  point: points.last,
                                  child: const Icon(
                                    Icons.stop_circle,
                                    color: AppColors.mapEndMarker,
                                    size: 28,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Details
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Stats row
                          Row(
                            children: [
                              _StatCard(
                                icon: Icons.route,
                                label: 'Quãng đường',
                                value: GeoUtils.formatDistance(
                                    patrol.totalDistanceMeters ?? 0),
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 12),
                              _StatCard(
                                icon: Icons.timer_outlined,
                                label: 'Thời gian',
                                value: patrol.duration != null
                                    ? AppDateUtils.formatDuration(patrol.duration!)
                                    : '--',
                                color: AppColors.accent,
                              ),
                              const SizedBox(width: 12),
                              _StatCard(
                                icon: Icons.speed,
                                label: 'Tốc độ TB',
                                value: patrol.avgSpeedKmh != null
                                    ? '${patrol.avgSpeedKmh!.toStringAsFixed(1)} km/h'
                                    : '--',
                                color: AppColors.secondary,
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Info section
                          const Text(
                            'Thông tin chuyến',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryDark,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _InfoItem('Mã tuần tra', patrol.patrolId),
                          _InfoItem('Trưởng đội', patrol.leaderName),
                          _InfoItem('Trạm', patrol.stationName),
                          _InfoItem('Phương tiện', patrol.transportType),
                          _InfoItem('Nhiệm vụ', patrol.mandate),
                          _InfoItem('Bắt đầu',
                              AppDateUtils.formatDateTime(patrol.startTime)),
                          if (patrol.endTime != null)
                            _InfoItem('Kết thúc',
                                AppDateUtils.formatDateTime(patrol.endTime!)),
                          if (patrol.comments != null)
                            _InfoItem('Ghi chú', patrol.comments!),
                          const SizedBox(height: 20),

                          // Waypoints
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Điểm GPS (${waypoints.length})',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Waypoints list
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => _WaypointTile(waypoint: waypoints[i]),
                      childCount: waypoints.length,
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
              );
            },
            loading: () => const AppLoading(),
            error: (e, _) => AppError(message: e.toString()),
          );
        },
        loading: () => const AppLoading(),
        error: (e, _) => AppError(message: e.toString()),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final String label;
  final String value;

  const _InfoItem(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _WaypointTile extends StatelessWidget {
  final Waypoint waypoint;

  const _WaypointTile({required this.waypoint});

  @override
  Widget build(BuildContext context) {
    final color = waypoint.isStartPoint
        ? AppColors.mapStartMarker
        : waypoint.isEndPoint
            ? AppColors.mapEndMarker
            : waypoint.isObservation
                ? AppColors.warning
                : AppColors.mapWaypoint;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider, width: 0.5),
      ),
      child: ListTile(
        dense: true,
        leading: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(
            waypoint.isStartPoint
                ? Icons.play_arrow
                : waypoint.isEndPoint
                    ? Icons.stop
                    : waypoint.hasPhoto
                        ? Icons.photo_camera
                        : Icons.location_on,
            color: color,
            size: 16,
          ),
        ),
        title: Text(
          waypoint.observationType,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppDateUtils.formatDateTime(waypoint.timestamp),
              style: const TextStyle(fontSize: 11),
            ),
            Text(
              '${waypoint.latitude.toStringAsFixed(5)}, ${waypoint.longitude.toStringAsFixed(5)}',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        trailing: waypoint.accuracy != null
            ? Text(
                '±${waypoint.accuracy!.toStringAsFixed(0)}m',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              )
            : null,
        isThreeLine: true,
      ),
    );
  }
}

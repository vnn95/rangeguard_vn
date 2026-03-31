import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:rangeguard_vn/core/constants/app_colors.dart';
import 'package:rangeguard_vn/core/constants/app_constants.dart';
import 'package:rangeguard_vn/core/utils/geo_utils.dart';
import 'package:rangeguard_vn/models/patrol_model.dart';
import 'package:rangeguard_vn/models/waypoint_model.dart';
import 'package:rangeguard_vn/providers/map_provider.dart';
import 'package:rangeguard_vn/providers/patrol_provider.dart';
import 'package:rangeguard_vn/widgets/common/app_loading.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final _mapController = MapController();
  Patrol? _selectedPatrol;
  List<Waypoint> _selectedWaypoints = [];
  bool _showFilterPanel = false;

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  String _getTileUrl(MapLayer layer) {
    switch (layer) {
      case MapLayer.osm:
        return AppConstants.osmTileUrl;
      case MapLayer.satellite:
        return AppConstants.esriSatelliteTileUrl;
      case MapLayer.terrain:
        return AppConstants.esriTerrainTileUrl;
      case MapLayer.googleSatellite:
        return AppConstants.googleSatelliteTileUrl;
    }
  }

  Future<void> _selectPatrol(Patrol patrol) async {
    setState(() => _selectedPatrol = patrol);
    final repo = ref.read(patrolRepositoryProvider);
    final waypoints = await repo.getWaypoints(patrol.id);
    setState(() => _selectedWaypoints = waypoints);

    if (waypoints.isNotEmpty) {
      final center = GeoUtils.centerOf(waypoints.map((w) => w.latLng).toList());
      _mapController.move(center, 13);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mapSettings = ref.watch(mapSettingsProvider);
    final patrolsAsync = ref.watch(patrolsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bản đồ tuần tra'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () =>
                setState(() => _showFilterPanel = !_showFilterPanel),
          ),
          IconButton(
            icon: const Icon(Icons.layers_outlined),
            onPressed: () => _showLayerPicker(context),
          ),
          IconButton(
            icon: Icon(mapSettings.showHeatmap
                ? Icons.whatshot
                : Icons.whatshot_outlined),
            onPressed: () =>
                ref.read(mapSettingsProvider.notifier).toggleHeatmap(),
            tooltip: 'Heatmap',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: mapSettings.center,
              initialZoom: mapSettings.zoom,
              onTap: (_, __) => setState(() => _selectedPatrol = null),
            ),
            children: [
              // Tile layer
              TileLayer(
                urlTemplate: _getTileUrl(mapSettings.activeLayer),
                userAgentPackageName: 'com.rangeguard.vn',
                maxZoom: AppConstants.maxMapZoom,
              ),

              // Patrol polylines
              if (mapSettings.showPolylines)
                patrolsAsync.when(
                  data: (patrols) => PolylineLayer(
                    polylines: patrols.asMap().entries.map((entry) {
                      final patrol = entry.value;
                      final isSelected = _selectedPatrol?.id == patrol.id;
                      return Polyline(
                        points: _parseTrackGeometry(patrol.trackGeometry),
                        strokeWidth: isSelected ? 5 : 3,
                        color: isSelected
                            ? AppColors.mapPolylineSelected
                            : ref
                                .read(patrolColorProvider(entry.key))
                                .withOpacity(0.8),
                      );
                    }).toList(),
                  ),
                  loading: () => const PolylineLayer(polylines: []),
                  error: (_, __) => const PolylineLayer(polylines: []),
                ),

              // Selected waypoint markers
              if (_selectedWaypoints.isNotEmpty && mapSettings.showWaypoints)
                MarkerLayer(
                  markers: _selectedWaypoints.map((w) {
                    return Marker(
                      point: w.latLng,
                      width: 28,
                      height: 28,
                      child: GestureDetector(
                        onTap: () => _showWaypointInfo(w),
                        child: Container(
                          decoration: BoxDecoration(
                            color: _waypointColor(w),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: Icon(
                            _waypointIcon(w),
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

              // Clickable patrol markers (start points)
              patrolsAsync.when(
                data: (patrols) => MarkerLayer(
                  markers: patrols.expand((patrol) {
                    final points =
                        _parseTrackGeometry(patrol.trackGeometry);
                    if (points.isEmpty) return <Marker>[];
                    return [
                      Marker(
                        point: points.first,
                        width: 36,
                        height: 36,
                        child: GestureDetector(
                          onTap: () => _selectPatrol(patrol),
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.mapStartMarker,
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.play_arrow,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ];
                  }).toList(),
                ),
                loading: () => const MarkerLayer(markers: []),
                error: (_, __) => const MarkerLayer(markers: []),
              ),

              // Attribution
              const RichAttributionWidget(
                attributions: [
                  TextSourceAttribution('OpenStreetMap contributors'),
                ],
              ),
            ],
          ),

          // Loading overlay
          patrolsAsync.when(
            loading: () => const Positioned(
              top: 16,
              left: 0,
              right: 0,
              child: Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text('Đang tải dữ liệu...'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            data: (_) => const SizedBox(),
            error: (_, __) => const SizedBox(),
          ),

          // Selected patrol info panel
          if (_selectedPatrol != null)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: _PatrolInfoCard(
                patrol: _selectedPatrol!,
                waypointsCount: _selectedWaypoints.length,
                onClose: () => setState(() {
                  _selectedPatrol = null;
                  _selectedWaypoints = [];
                }),
              ),
            ),

          // Layer indicator
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Text(
                mapSettings.layerLabel,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'zoom_in',
            onPressed: () {
              final cam = _mapController.camera;
              _mapController.move(cam.center, cam.zoom + 1);
            },
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.small(
            heroTag: 'zoom_out',
            onPressed: () {
              final cam = _mapController.camera;
              _mapController.move(cam.center, cam.zoom - 1);
            },
            child: const Icon(Icons.remove),
          ),
        ],
      ),
    );
  }

  List<LatLng> _parseTrackGeometry(String? wkt) {
    if (wkt == null || wkt.isEmpty) return [];
    try {
      final regex = RegExp(r'LINESTRING\((.+)\)');
      final match = regex.firstMatch(wkt);
      if (match == null) return [];
      final coordsStr = match.group(1)!;
      return coordsStr.split(', ').map((pair) {
        final parts = pair.trim().split(' ');
        return LatLng(double.parse(parts[1]), double.parse(parts[0]));
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Color _waypointColor(Waypoint w) {
    if (w.isStartPoint) return AppColors.mapStartMarker;
    if (w.isEndPoint) return AppColors.mapEndMarker;
    if (w.isObservation) return AppColors.warning;
    return AppColors.mapWaypoint;
  }

  IconData _waypointIcon(Waypoint w) {
    if (w.isStartPoint) return Icons.play_arrow;
    if (w.isEndPoint) return Icons.stop;
    if (w.hasPhoto) return Icons.photo_camera;
    if (w.isObservation) return Icons.warning_amber;
    return Icons.circle;
  }

  void _showWaypointInfo(Waypoint w) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              w.observationType,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            _InfoRow(
                icon: Icons.access_time,
                label: 'Thời gian',
                value: w.timestamp.toLocal().toString()),
            _InfoRow(
                icon: Icons.gps_fixed,
                label: 'Toạ độ',
                value:
                    '${w.latitude.toStringAsFixed(6)}, ${w.longitude.toStringAsFixed(6)}'),
            if (w.accuracy != null)
              _InfoRow(
                  icon: Icons.my_location,
                  label: 'Độ chính xác',
                  value: '${w.accuracy!.toStringAsFixed(1)} m'),
            if (w.altitude != null)
              _InfoRow(
                  icon: Icons.terrain,
                  label: 'Độ cao',
                  value: '${w.altitude!.toStringAsFixed(0)} m'),
            if (w.notes != null)
              _InfoRow(icon: Icons.notes, label: 'Ghi chú', value: w.notes!),
          ],
        ),
      ),
    );
  }

  void _showLayerPicker(BuildContext context) {
    final notifier = ref.read(mapSettingsProvider.notifier);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Chọn lớp bản đồ',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ),
          ...MapLayer.values.map((layer) {
            final labels = {
              MapLayer.osm: ('OpenStreetMap', Icons.map),
              MapLayer.satellite: ('Vệ tinh ESRI', Icons.satellite_alt),
              MapLayer.terrain: ('Địa hình', Icons.terrain),
              MapLayer.googleSatellite:
                  ('Google Vệ tinh', Icons.satellite_alt_rounded),
            };
            final (label, icon) = labels[layer]!;
            return ListTile(
              leading: Icon(icon),
              title: Text(label),
              onTap: () {
                notifier.setLayer(layer);
                Navigator.pop(context);
              },
            );
          }),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _PatrolInfoCard extends StatelessWidget {
  final Patrol patrol;
  final int waypointsCount;
  final VoidCallback onClose;

  const _PatrolInfoCard({
    required this.patrol,
    required this.waypointsCount,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.hiking, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    patrol.patrolId,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: onClose,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const Divider(height: 16),
            Row(
              children: [
                Expanded(
                  child: _InfoRow(
                    icon: Icons.person_outline,
                    label: 'Dẫn đội',
                    value: patrol.leaderName,
                    compact: true,
                  ),
                ),
                Expanded(
                  child: _InfoRow(
                    icon: Icons.route,
                    label: 'Quãng đường',
                    value: GeoUtils.formatDistance(
                        patrol.totalDistanceMeters ?? 0),
                    compact: true,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: _InfoRow(
                    icon: Icons.location_on_outlined,
                    label: 'Điểm GPS',
                    value: '$waypointsCount điểm',
                    compact: true,
                  ),
                ),
                if (patrol.duration != null)
                  Expanded(
                    child: _InfoRow(
                      icon: Icons.timer_outlined,
                      label: 'Thời gian',
                      value: _formatDuration(patrol.duration!),
                      compact: true,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool compact;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 14, color: Colors.grey),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 10, color: Colors.grey)),
                  Text(value,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              Text(value,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}

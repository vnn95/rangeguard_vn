import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:rangeguard_vn/core/constants/app_colors.dart';
import 'package:rangeguard_vn/core/constants/app_constants.dart';
import 'package:rangeguard_vn/core/utils/date_utils.dart';
import 'package:rangeguard_vn/core/utils/geo_utils.dart';
import 'package:rangeguard_vn/models/patrol_model.dart';
import 'package:rangeguard_vn/models/waypoint_model.dart';
import 'package:rangeguard_vn/providers/auth_provider.dart';
import 'package:rangeguard_vn/providers/patrol_provider.dart';
import 'package:rangeguard_vn/providers/settings_provider.dart';

class StartPatrolScreen extends ConsumerStatefulWidget {
  const StartPatrolScreen({super.key});

  @override
  ConsumerState<StartPatrolScreen> createState() => _StartPatrolScreenState();
}

class _StartPatrolScreenState extends ConsumerState<StartPatrolScreen> {
  final _uuid = const Uuid();
  final _mapController = MapController();
  final _formKey = GlobalKey<FormState>();
  final _mandateCtrl = TextEditingController(text: 'Tuần tra định kỳ');
  final _commentsCtrl = TextEditingController();

  bool _isPatrolStarted = false;
  bool _isLoading = false;
  Position? _currentPosition;
  StreamSubscription<Position>? _positionSubscription;
  Timer? _waypointTimer;
  Position? _lastSavedPosition;

  // Form fields
  String _transportType = 'Đi bộ';
  String _stationName = 'Trạm 1';

  static const _transportOptions = [
    'Đi bộ',
    'Xe máy',
    'Ô tô',
    'Thuyền',
    'Ngựa',
  ];

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _waypointTimer?.cancel();
    _mandateCtrl.dispose();
    _commentsCtrl.dispose();
    _mapController.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  Future<void> _initLocation() async {
    final permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cần quyền truy cập GPS để tuần tra'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((pos) {
      setState(() => _currentPosition = pos);
      if (_isPatrolStarted) {
        _mapController.move(
          LatLng(pos.latitude, pos.longitude),
          _mapController.camera.zoom,
        );
      }
    });
  }

  Future<void> _startPatrol() async {
    if (!_formKey.currentState!.validate()) return;
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đang chờ tín hiệu GPS...')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final profile = ref.read(authNotifierProvider).valueOrNull;
      final settings = ref.read(settingsProvider);
      final patrolId = _uuid.v4();

      final patrol = Patrol(
        id: patrolId,
        patrolId: 'P-${DateTime.now().millisecondsSinceEpoch}',
        leaderId: profile?.id ?? '',
        leaderName: profile?.fullName ?? '',
        stationId: '',
        stationName: _stationName,
        transportType: _transportType,
        mandate: _mandateCtrl.text.trim(),
        comments: _commentsCtrl.text.trim().isEmpty ? null : _commentsCtrl.text.trim(),
        startTime: DateTime.now(),
        status: PatrolStatus.active,
        createdBy: profile?.id ?? '',
        createdAt: DateTime.now(),
      );

      await ref.read(activePatrolProvider.notifier).startPatrol(patrol);

      // Save start waypoint
      final startWp = Waypoint(
        id: _uuid.v4(),
        patrolId: patrolId,
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
        altitude: _currentPosition!.altitude,
        accuracy: _currentPosition!.accuracy,
        observationType: AppConstants.obsNewPatrol,
        timestamp: DateTime.now(),
        isSynced: false,
      );
      await ref.read(activePatrolProvider.notifier).addWaypoint(startWp);

      // Start auto tracking
      WakelockPlus.enable();
      _lastSavedPosition = _currentPosition;
      _waypointTimer = Timer.periodic(
        Duration(seconds: settings.waypointIntervalSeconds),
        (_) => _autoSaveWaypoint(),
      );

      setState(() {
        _isPatrolStarted = true;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _autoSaveWaypoint() async {
    if (_currentPosition == null) return;
    final settings = ref.read(settingsProvider);

    if (_lastSavedPosition != null) {
      final dist = Geolocator.distanceBetween(
        _lastSavedPosition!.latitude,
        _lastSavedPosition!.longitude,
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );
      if (dist < settings.minMovementMeters) return;
    }

    final patrol = ref.read(activePatrolProvider).patrol;
    if (patrol == null) return;

    final wp = Waypoint(
      id: _uuid.v4(),
      patrolId: patrol.id,
      latitude: _currentPosition!.latitude,
      longitude: _currentPosition!.longitude,
      altitude: _currentPosition!.altitude,
      accuracy: _currentPosition!.accuracy,
      bearing: _currentPosition!.heading,
      speed: _currentPosition!.speed,
      observationType: AppConstants.obsWaypoint,
      timestamp: DateTime.now(),
      isSynced: false,
    );

    await ref.read(activePatrolProvider.notifier).addWaypoint(wp);
    _lastSavedPosition = _currentPosition;
  }

  Future<void> _capturePhoto() async {
    final patrol = ref.read(activePatrolProvider).patrol;
    if (patrol == null) return;

    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );
    if (image == null) return;

    // Show note dialog
    String? note;
    if (mounted) {
      note = await showDialog<String>(
        context: context,
        builder: (ctx) {
          final ctrl = TextEditingController();
          return AlertDialog(
            title: const Text('Ghi chú bất thường'),
            content: TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                hintText: 'Mô tả bất thường (tuỳ chọn)',
              ),
              maxLines: 3,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Bỏ qua'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, ctrl.text),
                child: const Text('Lưu'),
              ),
            ],
          );
        },
      );
    }

    final wp = Waypoint(
      id: _uuid.v4(),
      patrolId: patrol.id,
      latitude: _currentPosition?.latitude ?? 0,
      longitude: _currentPosition?.longitude ?? 0,
      altitude: _currentPosition?.altitude,
      accuracy: _currentPosition?.accuracy,
      observationType: AppConstants.obsPhoto,
      notes: note?.isEmpty == true ? null : note,
      timestamp: DateTime.now(),
      isSynced: false,
    );

    await ref.read(activePatrolProvider.notifier).addWaypoint(wp);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã lưu ảnh bất thường'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _stopPatrol() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Kết thúc tuần tra'),
        content: const Text(
          'Bạn có chắc muốn kết thúc chuyến tuần tra này?\nToàn bộ dữ liệu sẽ được lưu và upload.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Huỷ'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Kết thúc'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    _waypointTimer?.cancel();
    WakelockPlus.disable();

    final patrol = ref.read(activePatrolProvider).patrol;
    if (patrol == null) return;

    final stopWp = Waypoint(
      id: _uuid.v4(),
      patrolId: patrol.id,
      latitude: _currentPosition?.latitude ?? 0,
      longitude: _currentPosition?.longitude ?? 0,
      altitude: _currentPosition?.altitude,
      accuracy: _currentPosition?.accuracy,
      observationType: AppConstants.obsStopPatrol,
      timestamp: DateTime.now(),
      isSynced: false,
    );

    final completed =
        await ref.read(activePatrolProvider.notifier).stopPatrol(stopWp);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            completed != null
                ? 'Tuần tra hoàn thành! Quãng đường: ${GeoUtils.formatDistance(completed.totalDistanceMeters ?? 0)}'
                : 'Đã kết thúc tuần tra',
          ),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeState = ref.watch(activePatrolProvider);
    final waypoints = activeState.waypoints;
    final pos = _currentPosition;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isPatrolStarted ? 'Đang tuần tra' : 'Bắt đầu tuần tra'),
        backgroundColor:
            _isPatrolStarted ? AppColors.patrolActive : AppColors.primary,
        actions: [
          if (_isPatrolStarted)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${waypoints.length} GPS',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _isPatrolStarted
          ? _buildActiveTracking(waypoints, pos)
          : _buildStartForm(),
    );
  }

  Widget _buildStartForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // GPS status
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _currentPosition != null
                    ? AppColors.success.withOpacity(0.1)
                    : AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _currentPosition != null
                      ? AppColors.success.withOpacity(0.3)
                      : AppColors.warning.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _currentPosition != null
                        ? Icons.gps_fixed
                        : Icons.gps_not_fixed,
                    color: _currentPosition != null
                        ? AppColors.success
                        : AppColors.warning,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _currentPosition != null
                          ? 'GPS: ${_currentPosition!.latitude.toStringAsFixed(5)}, ${_currentPosition!.longitude.toStringAsFixed(5)}\nĐộ chính xác: ±${_currentPosition!.accuracy.toStringAsFixed(0)}m'
                          : 'Đang tìm tín hiệu GPS...',
                      style: TextStyle(
                        color: _currentPosition != null
                            ? AppColors.success
                            : AppColors.warning,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Station
            DropdownButtonFormField<String>(
              value: _stationName,
              decoration: const InputDecoration(
                labelText: 'Trạm kiểm lâm',
                prefixIcon: Icon(Icons.home_work_outlined),
              ),
              items: ['Trạm 1', 'Trạm 2', 'Trạm 3', 'Trạm Trung tâm']
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) => setState(() => _stationName = v!),
            ),
            const SizedBox(height: 16),

            // Transport
            DropdownButtonFormField<String>(
              value: _transportType,
              decoration: const InputDecoration(
                labelText: 'Phương tiện di chuyển',
                prefixIcon: Icon(Icons.directions_walk_outlined),
              ),
              items: _transportOptions
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (v) => setState(() => _transportType = v!),
            ),
            const SizedBox(height: 16),

            // Mandate
            TextFormField(
              controller: _mandateCtrl,
              decoration: const InputDecoration(
                labelText: 'Nhiệm vụ / Mục tiêu',
                prefixIcon: Icon(Icons.assignment_outlined),
              ),
              validator: (v) =>
                  v?.isEmpty == true ? 'Vui lòng nhập nhiệm vụ' : null,
            ),
            const SizedBox(height: 16),

            // Comments
            TextFormField(
              controller: _commentsCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Ghi chú (tuỳ chọn)',
                prefixIcon: Icon(Icons.notes_outlined),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 32),

            ElevatedButton.icon(
              onPressed: _isLoading ? null : _startPatrol,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.play_arrow),
              label: const Text('Bắt đầu tuần tra'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.patrolActive,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveTracking(List<Waypoint> waypoints, Position? pos) {
    final points = waypoints.map((w) => w.latLng).toList();
    final center = pos != null
        ? LatLng(pos.latitude, pos.longitude)
        : const LatLng(15.88, 108.33);
    final activeState = ref.watch(activePatrolProvider);
    final startTime = activeState.startedAt ?? DateTime.now();
    final elapsed = DateTime.now().difference(startTime);

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: center,
            initialZoom: 15,
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
                    color: AppColors.patrolActive,
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                if (pos != null)
                  Marker(
                    point: LatLng(pos.latitude, pos.longitude),
                    width: 48,
                    height: 48,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                        ),
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),

        // Status bar
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            color: AppColors.primaryDark.withOpacity(0.9),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _TrackStat(
                  label: 'Thời gian',
                  value: AppDateUtils.formatDuration(elapsed),
                  icon: Icons.timer,
                ),
                _TrackStat(
                  label: 'Điểm GPS',
                  value: '${waypoints.length}',
                  icon: Icons.location_on,
                ),
                _TrackStat(
                  label: 'Tốc độ',
                  value: pos != null
                      ? '${(pos.speed * 3.6).toStringAsFixed(1)} km/h'
                      : '--',
                  icon: Icons.speed,
                ),
              ],
            ),
          ),
        ),

        // Action buttons
        Positioned(
          bottom: 24,
          left: 16,
          right: 16,
          child: Row(
            children: [
              // Photo button
              FloatingActionButton(
                heroTag: 'photo',
                onPressed: _capturePhoto,
                backgroundColor: AppColors.warning,
                child: const Icon(Icons.photo_camera),
              ),
              const SizedBox(width: 12),
              // Center on me
              FloatingActionButton(
                heroTag: 'center',
                onPressed: () {
                  if (pos != null) {
                    _mapController.move(
                        LatLng(pos.latitude, pos.longitude), 15);
                  }
                },
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primary,
                child: const Icon(Icons.my_location),
              ),
              const Spacer(),
              // Stop patrol
              FloatingActionButton.extended(
                heroTag: 'stop',
                onPressed: _stopPatrol,
                backgroundColor: AppColors.error,
                icon: const Icon(Icons.stop),
                label: const Text('Kết thúc'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TrackStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _TrackStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white54, size: 16),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700)),
        Text(label,
            style:
                const TextStyle(color: Colors.white54, fontSize: 10)),
      ],
    );
  }
}

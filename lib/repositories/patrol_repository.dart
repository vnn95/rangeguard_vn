import 'package:uuid/uuid.dart';
import 'package:latlong2/latlong.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:rangeguard_vn/core/constants/app_constants.dart';
import 'package:rangeguard_vn/core/supabase/supabase_config.dart';
import 'package:rangeguard_vn/core/utils/geo_utils.dart';
import 'package:rangeguard_vn/core/utils/offline_sync.dart';
import 'package:rangeguard_vn/models/patrol_model.dart';
import 'package:rangeguard_vn/models/waypoint_model.dart';
import 'package:rangeguard_vn/models/smart_import_model.dart';

class PatrolRepository {
  final _uuid = const Uuid();
  final _sync = OfflineSyncService();

  get _client => SupabaseConfig.client;
  late Box _patrolBox;
  late Box _waypointBox;

  Future<void> init() async {
    _patrolBox = await Hive.openBox(AppConstants.patrolBox);
    _waypointBox = await Hive.openBox(AppConstants.waypointBox);
  }

  // ── Patrol CRUD ─────────────────────────────────────────────────────────

  Future<List<Patrol>> getPatrols({
    String? leaderId,
    DateTime? from,
    DateTime? to,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      var query = _client
          .from(AppConstants.patrolsTable)
          .select()
          .order('start_time', ascending: false)
          .range(offset, offset + limit - 1);

      if (leaderId != null) {
        query = query.eq('leader_id', leaderId);
      }
      if (from != null) {
        query = query.gte('start_time', from.toUtc().toIso8601String());
      }
      if (to != null) {
        query = query.lte('start_time', to.toUtc().toIso8601String());
      }

      final data = await query;
      return data.map((e) => Patrol.fromMap(e)).toList();
    } catch (_) {
      return _getPatrolsLocal();
    }
  }

  List<Patrol> _getPatrolsLocal() {
    return _patrolBox.values
        .map((e) => Patrol.fromMap(Map<String, dynamic>.from(e)))
        .toList()
      ..sort((a, b) => b.startTime.compareTo(a.startTime));
  }

  Future<Patrol?> getPatrolById(String id) async {
    try {
      final data = await _client
          .from(AppConstants.patrolsTable)
          .select()
          .eq('id', id)
          .maybeSingle();
      if (data == null) return null;
      return Patrol.fromMap(data);
    } catch (_) {
      final local = _patrolBox.get(id);
      if (local == null) return null;
      return Patrol.fromMap(Map<String, dynamic>.from(local));
    }
  }

  Future<Patrol> createPatrol(Patrol patrol) async {
    final map = patrol.toMap();
    _patrolBox.put(patrol.id, map);

    try {
      await _client.from(AppConstants.patrolsTable).insert(map);
    } catch (_) {
      await _sync.addToQueue(SyncQueueItem(
        id: patrol.id,
        table: AppConstants.patrolsTable,
        action: SyncAction.insert,
        data: map,
        createdAt: DateTime.now(),
      ));
    }
    return patrol;
  }

  Future<Patrol> updatePatrol(Patrol patrol) async {
    final map = patrol.toMap();
    _patrolBox.put(patrol.id, map);

    try {
      await _client
          .from(AppConstants.patrolsTable)
          .update(map)
          .eq('id', patrol.id);
    } catch (_) {
      await _sync.addToQueue(SyncQueueItem(
        id: patrol.id,
        table: AppConstants.patrolsTable,
        action: SyncAction.update,
        data: map,
        createdAt: DateTime.now(),
      ));
    }
    return patrol;
  }

  Future<void> deletePatrol(String id) async {
    await _patrolBox.delete(id);
    try {
      await _client.from(AppConstants.patrolsTable).delete().eq('id', id);
    } catch (_) {
      await _sync.addToQueue(SyncQueueItem(
        id: id,
        table: AppConstants.patrolsTable,
        action: SyncAction.delete,
        data: {'id': id},
        createdAt: DateTime.now(),
      ));
    }
  }

  // ── Waypoint CRUD ────────────────────────────────────────────────────────

  Future<List<Waypoint>> getWaypoints(String patrolId) async {
    try {
      final data = await _client
          .from(AppConstants.waypointsTable)
          .select()
          .eq('patrol_id', patrolId)
          .order('timestamp');
      return data.map((e) => Waypoint.fromMap(e)).toList();
    } catch (_) {
      return _getWaypointsLocal(patrolId);
    }
  }

  List<Waypoint> _getWaypointsLocal(String patrolId) {
    return _waypointBox.values
        .map((e) => Waypoint.fromMap(Map<String, dynamic>.from(e)))
        .where((w) => w.patrolId == patrolId)
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  Future<Waypoint> addWaypoint(Waypoint waypoint) async {
    final map = waypoint.toMap();
    _waypointBox.put(waypoint.id, map);

    try {
      await _client.from(AppConstants.waypointsTable).insert(map);
    } catch (_) {
      await _sync.addToQueue(SyncQueueItem(
        id: waypoint.id,
        table: AppConstants.waypointsTable,
        action: SyncAction.insert,
        data: map,
        createdAt: DateTime.now(),
      ));
    }
    return waypoint;
  }

  Future<List<Waypoint>> addWaypointsBatch(List<Waypoint> waypoints) async {
    for (final w in waypoints) {
      _waypointBox.put(w.id, w.toMap());
    }

    try {
      await _client
          .from(AppConstants.waypointsTable)
          .upsert(waypoints.map((w) => w.toMap()).toList());
    } catch (_) {
      for (final w in waypoints) {
        await _sync.addToQueue(SyncQueueItem(
          id: w.id,
          table: AppConstants.waypointsTable,
          action: SyncAction.insert,
          data: w.toMap(),
          createdAt: DateTime.now(),
        ));
      }
    }
    return waypoints;
  }

  // ── SMART Import ─────────────────────────────────────────────────────────

  Future<Patrol> importFromSmartJson(
    Map<String, dynamic> json,
    String createdBy,
  ) async {
    final smartData = SmartPatrolData.fromGeoJson(json);
    final np = smartData.newPatrol;

    final patrolId = _uuid.v4();
    final now = DateTime.now();

    // Build waypoints
    final waypoints = <Waypoint>[];
    final latLngs = <LatLng>[];

    // Start waypoint
    if (np?.latitude != null && np?.longitude != null) {
      final startWp = Waypoint(
        id: _uuid.v4(),
        patrolId: patrolId,
        latitude: np!.latitude!,
        longitude: np.longitude!,
        observationType: 'NewPatrol',
        timestamp: np.startTime,
        isSynced: false,
      );
      waypoints.add(startWp);
      latLngs.add(startWp.latLng);
    }

    // Track waypoints
    for (final sw in smartData.waypoints) {
      final w = Waypoint(
        id: _uuid.v4(),
        patrolId: patrolId,
        latitude: sw.latitude,
        longitude: sw.longitude,
        altitude: sw.altitude,
        accuracy: sw.accuracy,
        observationType: sw.observationType,
        photoUrl: sw.photoUrl,
        notes: sw.notes,
        timestamp: sw.timestamp,
        isSynced: false,
      );
      waypoints.add(w);
      latLngs.add(w.latLng);
    }

    // End waypoint
    final sp = smartData.stopPatrol;
    DateTime? endTime = sp?.endTime;
    if (sp?.latitude != null && sp?.longitude != null) {
      final endWp = Waypoint(
        id: _uuid.v4(),
        patrolId: patrolId,
        latitude: sp!.latitude!,
        longitude: sp.longitude!,
        observationType: 'StopPatrol',
        timestamp: sp.endTime,
        isSynced: false,
      );
      waypoints.add(endWp);
      latLngs.add(endWp.latLng);
    }

    final totalDist = GeoUtils.totalDistance(latLngs);
    final trackWkt = latLngs.length >= 2
        ? 'LINESTRING(${latLngs.map((p) => '${p.longitude} ${p.latitude}').join(', ')})'
        : null;

    final patrol = Patrol(
      id: patrolId,
      patrolId: np?.patrolId ?? 'P-${now.millisecondsSinceEpoch}',
      leaderId: createdBy,
      leaderName: np?.leader ?? 'Unknown',
      stationId: '',
      stationName: np?.station ?? '',
      transportType: np?.transport ?? 'Đi bộ',
      mandate: np?.mandate ?? 'Tuần tra định kỳ',
      comments: np?.comments,
      startTime: np?.startTime ?? now,
      endTime: endTime,
      totalDistanceMeters: totalDist,
      totalWaypoints: waypoints.length,
      status: PatrolStatus.completed,
      trackGeometry: trackWkt,
      createdBy: createdBy,
      createdAt: now,
    );

    await createPatrol(patrol);
    await addWaypointsBatch(waypoints);

    return patrol;
  }

  // ── Stats ─────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getStats({
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      final patrols = await getPatrols(from: from, to: to, limit: 1000);
      final totalDist = patrols.fold<double>(
        0,
        (sum, p) => sum + (p.totalDistanceMeters ?? 0),
      );

      return {
        'total_patrols': patrols.length,
        'total_distance_km': totalDist / 1000,
        'active_rangers': patrols.map((p) => p.leaderId).toSet().length,
        'patrols_by_day': _groupByDay(patrols),
      };
    } catch (_) {
      return {
        'total_patrols': 0,
        'total_distance_km': 0.0,
        'active_rangers': 0,
        'patrols_by_day': <String, int>{},
      };
    }
  }

  Map<String, int> _groupByDay(List<Patrol> patrols) {
    final result = <String, int>{};
    for (final p in patrols) {
      final key =
          '${p.startTime.year}-${p.startTime.month.toString().padLeft(2, '0')}-${p.startTime.day.toString().padLeft(2, '0')}';
      result[key] = (result[key] ?? 0) + 1;
    }
    return result;
  }
}

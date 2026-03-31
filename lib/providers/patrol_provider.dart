import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rangeguard_vn/models/patrol_model.dart';
import 'package:rangeguard_vn/models/waypoint_model.dart';
import 'package:rangeguard_vn/repositories/patrol_repository.dart';

final patrolRepositoryProvider = Provider<PatrolRepository>((ref) {
  final repo = PatrolRepository();
  repo.init();
  return repo;
});

// Filter state
class PatrolFilter {
  final String? leaderId;
  final DateTime? from;
  final DateTime? to;
  final String? searchQuery;

  const PatrolFilter({
    this.leaderId,
    this.from,
    this.to,
    this.searchQuery,
  });

  PatrolFilter copyWith({
    String? leaderId,
    DateTime? from,
    DateTime? to,
    String? searchQuery,
  }) =>
      PatrolFilter(
        leaderId: leaderId ?? this.leaderId,
        from: from ?? this.from,
        to: to ?? this.to,
        searchQuery: searchQuery ?? this.searchQuery,
      );
}

final patrolFilterProvider = StateProvider<PatrolFilter>((ref) {
  final now = DateTime.now();
  return PatrolFilter(
    from: DateTime(now.year, now.month, 1),
    to: DateTime(now.year, now.month + 1, 0),
  );
});

final patrolsProvider = FutureProvider<List<Patrol>>((ref) async {
  final repo = ref.watch(patrolRepositoryProvider);
  final filter = ref.watch(patrolFilterProvider);

  return repo.getPatrols(
    leaderId: filter.leaderId,
    from: filter.from,
    to: filter.to,
  );
});

final patrolDetailProvider =
    FutureProvider.family<Patrol?, String>((ref, id) async {
  final repo = ref.watch(patrolRepositoryProvider);
  return repo.getPatrolById(id);
});

final waypointsProvider =
    FutureProvider.family<List<Waypoint>, String>((ref, patrolId) async {
  final repo = ref.watch(patrolRepositoryProvider);
  return repo.getWaypoints(patrolId);
});

final patrolStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final repo = ref.watch(patrolRepositoryProvider);
  final now = DateTime.now();
  return repo.getStats(
    from: DateTime(now.year, now.month, 1),
    to: now,
  );
});

// ── Active Patrol State ─────────────────────────────────────────────────────

class ActivePatrolState {
  final Patrol? patrol;
  final List<Waypoint> waypoints;
  final bool isTracking;
  final DateTime? startedAt;

  const ActivePatrolState({
    this.patrol,
    this.waypoints = const [],
    this.isTracking = false,
    this.startedAt,
  });

  ActivePatrolState copyWith({
    Patrol? patrol,
    List<Waypoint>? waypoints,
    bool? isTracking,
    DateTime? startedAt,
  }) =>
      ActivePatrolState(
        patrol: patrol ?? this.patrol,
        waypoints: waypoints ?? this.waypoints,
        isTracking: isTracking ?? this.isTracking,
        startedAt: startedAt ?? this.startedAt,
      );

  double get totalDistanceMeters {
    if (waypoints.length < 2) return 0;
    return 0; // calculated via GeoUtils
  }
}

class ActivePatrolNotifier extends StateNotifier<ActivePatrolState> {
  final PatrolRepository _repo;

  ActivePatrolNotifier(this._repo) : super(const ActivePatrolState());

  void startPatrol(Patrol patrol) {
    state = ActivePatrolState(
      patrol: patrol,
      waypoints: [],
      isTracking: true,
      startedAt: DateTime.now(),
    );
  }

  Future<void> addWaypoint(Waypoint waypoint) async {
    final saved = await _repo.addWaypoint(waypoint);
    state = state.copyWith(
      waypoints: [...state.waypoints, saved],
    );
  }

  Future<Patrol?> stopPatrol(Waypoint stopWaypoint) async {
    if (state.patrol == null) return null;

    await _repo.addWaypoint(stopWaypoint);
    final allWaypoints = [...state.waypoints, stopWaypoint];

    final endTime = DateTime.now();
    final updatedPatrol = state.patrol!.copyWith(
      endTime: endTime,
      status: PatrolStatus.completed,
      totalWaypoints: allWaypoints.length,
    );

    await _repo.updatePatrol(updatedPatrol);
    state = const ActivePatrolState();
    return updatedPatrol;
  }

  void cancelPatrol() {
    state = const ActivePatrolState();
  }
}

final activePatrolProvider =
    StateNotifierProvider<ActivePatrolNotifier, ActivePatrolState>((ref) {
  final repo = ref.watch(patrolRepositoryProvider);
  return ActivePatrolNotifier(repo);
});

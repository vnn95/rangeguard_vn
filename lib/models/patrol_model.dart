import 'package:latlong2/latlong.dart';
import 'package:rangeguard_vn/core/utils/geo_utils.dart';

enum PatrolStatus { scheduled, active, completed, cancelled }

class Patrol {
  final String id;
  final String patrolId; // SMART PatrolID
  final String leaderId;
  final String leaderName;
  final String stationId;
  final String stationName;
  final String transportType;
  final String mandate;
  final String? comments;
  final DateTime startTime;
  final DateTime? endTime;
  final double? totalDistanceMeters;
  final int? totalWaypoints;
  final PatrolStatus status;
  final String? trackGeometry; // WKT LineString
  final String createdBy;
  final DateTime createdAt;

  const Patrol({
    required this.id,
    required this.patrolId,
    required this.leaderId,
    required this.leaderName,
    required this.stationId,
    required this.stationName,
    required this.transportType,
    required this.mandate,
    this.comments,
    required this.startTime,
    this.endTime,
    this.totalDistanceMeters,
    this.totalWaypoints,
    required this.status,
    this.trackGeometry,
    required this.createdBy,
    required this.createdAt,
  });

  Duration? get duration =>
      endTime != null ? endTime!.difference(startTime) : null;

  double? get avgSpeedKmh {
    if (totalDistanceMeters == null || duration == null) return null;
    if (duration!.inSeconds == 0) return 0;
    return (totalDistanceMeters! / duration!.inSeconds) * 3.6;
  }

  factory Patrol.fromMap(Map<String, dynamic> map) => Patrol(
        id: map['id'] as String,
        patrolId: map['patrol_id'] as String? ?? '',
        leaderId: map['leader_id'] as String? ?? '',
        leaderName: map['leader_name'] as String? ?? '',
        stationId: map['station_id'] as String? ?? '',
        stationName: map['station_name'] as String? ?? '',
        transportType: map['transport_type'] as String? ?? '',
        mandate: map['mandate'] as String? ?? '',
        comments: map['comments'] as String?,
        startTime: DateTime.parse(map['start_time'] as String),
        endTime: map['end_time'] != null
            ? DateTime.parse(map['end_time'] as String)
            : null,
        totalDistanceMeters: (map['total_distance_meters'] as num?)?.toDouble(),
        totalWaypoints: map['total_waypoints'] as int?,
        status: PatrolStatus.values.byName(
            map['status'] as String? ?? 'completed'),
        trackGeometry: map['track_geometry'] as String?,
        createdBy: map['created_by'] as String? ?? '',
        createdAt: DateTime.parse(
            map['created_at'] as String? ?? DateTime.now().toIso8601String()),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'patrol_id': patrolId,
        'leader_id': leaderId,
        'leader_name': leaderName,
        'station_id': stationId,
        'station_name': stationName,
        'transport_type': transportType,
        'mandate': mandate,
        'comments': comments,
        'start_time': startTime.toUtc().toIso8601String(),
        'end_time': endTime?.toUtc().toIso8601String(),
        'total_distance_meters': totalDistanceMeters,
        'total_waypoints': totalWaypoints,
        'status': status.name,
        'track_geometry': trackGeometry,
        'created_by': createdBy,
        'created_at': createdAt.toUtc().toIso8601String(),
      };

  Patrol copyWith({
    DateTime? endTime,
    double? totalDistanceMeters,
    int? totalWaypoints,
    PatrolStatus? status,
    String? trackGeometry,
  }) =>
      Patrol(
        id: id,
        patrolId: patrolId,
        leaderId: leaderId,
        leaderName: leaderName,
        stationId: stationId,
        stationName: stationName,
        transportType: transportType,
        mandate: mandate,
        comments: comments,
        startTime: startTime,
        endTime: endTime ?? this.endTime,
        totalDistanceMeters: totalDistanceMeters ?? this.totalDistanceMeters,
        totalWaypoints: totalWaypoints ?? this.totalWaypoints,
        status: status ?? this.status,
        trackGeometry: trackGeometry ?? this.trackGeometry,
        createdBy: createdBy,
        createdAt: createdAt,
      );
}

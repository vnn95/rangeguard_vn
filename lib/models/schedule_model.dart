enum ScheduleStatus { planned, ongoing, completed, cancelled }

class PatrolSchedule {
  final String id;
  final String title;
  final String? description;
  final DateTime scheduledDate;
  final DateTime startTime;
  final DateTime? endTime;
  final String leaderId;
  final String leaderName;
  final List<String> rangerIds;
  final List<String> rangerNames;
  final String stationId;
  final String stationName;
  final String? areaPolygon; // WKT Polygon
  final String? mandate;
  final ScheduleStatus status;
  final String? linkedPatrolId;
  final String createdBy;
  final DateTime createdAt;

  const PatrolSchedule({
    required this.id,
    required this.title,
    this.description,
    required this.scheduledDate,
    required this.startTime,
    this.endTime,
    required this.leaderId,
    required this.leaderName,
    required this.rangerIds,
    required this.rangerNames,
    required this.stationId,
    required this.stationName,
    this.areaPolygon,
    this.mandate,
    required this.status,
    this.linkedPatrolId,
    required this.createdBy,
    required this.createdAt,
  });

  factory PatrolSchedule.fromMap(Map<String, dynamic> map) => PatrolSchedule(
        id: map['id'] as String,
        title: map['title'] as String? ?? '',
        description: map['description'] as String?,
        scheduledDate: DateTime.parse(map['scheduled_date'] as String),
        startTime: DateTime.parse(map['start_time'] as String),
        endTime: map['end_time'] != null
            ? DateTime.parse(map['end_time'] as String)
            : null,
        leaderId: map['leader_id'] as String? ?? '',
        leaderName: map['leader_name'] as String? ?? '',
        rangerIds: List<String>.from(map['ranger_ids'] as List? ?? []),
        rangerNames: List<String>.from(map['ranger_names'] as List? ?? []),
        stationId: map['station_id'] as String? ?? '',
        stationName: map['station_name'] as String? ?? '',
        areaPolygon: map['area_polygon'] as String?,
        mandate: map['mandate'] as String?,
        status: ScheduleStatus.values.byName(
            map['status'] as String? ?? 'planned'),
        linkedPatrolId: map['linked_patrol_id'] as String?,
        createdBy: map['created_by'] as String? ?? '',
        createdAt: DateTime.parse(
            map['created_at'] as String? ?? DateTime.now().toIso8601String()),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'description': description,
        'scheduled_date': scheduledDate.toUtc().toIso8601String(),
        'start_time': startTime.toUtc().toIso8601String(),
        'end_time': endTime?.toUtc().toIso8601String(),
        'leader_id': leaderId,
        'leader_name': leaderName,
        'ranger_ids': rangerIds,
        'ranger_names': rangerNames,
        'station_id': stationId,
        'station_name': stationName,
        'area_polygon': areaPolygon,
        'mandate': mandate,
        'status': status.name,
        'linked_patrol_id': linkedPatrolId,
        'created_by': createdBy,
        'created_at': createdAt.toUtc().toIso8601String(),
      };
}

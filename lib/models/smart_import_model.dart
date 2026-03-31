/// Model để parse file patrol2.json (SMART Conservation Tools format)
class SmartPatrolData {
  final SmartNewPatrol? newPatrol;
  final List<SmartWaypoint> waypoints;
  final SmartStopPatrol? stopPatrol;

  const SmartPatrolData({
    this.newPatrol,
    required this.waypoints,
    this.stopPatrol,
  });

  /// Parse từ GeoJSON Feature Collection (SMART export format)
  factory SmartPatrolData.fromGeoJson(Map<String, dynamic> json) {
    SmartNewPatrol? newPatrol;
    SmartStopPatrol? stopPatrol;
    final waypoints = <SmartWaypoint>[];

    final features = json['features'] as List? ?? [];
    for (final feature in features) {
      final props = feature['properties'] as Map<String, dynamic>? ?? {};
      final geometry = feature['geometry'] as Map<String, dynamic>? ?? {};
      final coords = geometry['coordinates'] as List? ?? [];

      final double? lon = coords.isNotEmpty ? (coords[0] as num?)?.toDouble() : null;
      final double? lat = coords.length > 1 ? (coords[1] as num?)?.toDouble() : null;
      final double? alt = coords.length > 2 ? (coords[2] as num?)?.toDouble() : null;

      final type = props['type'] as String? ?? '';

      if (type == 'NewPatrol') {
        newPatrol = SmartNewPatrol.fromProps(props, lat: lat, lon: lon);
      } else if (type == 'StopPatrol') {
        stopPatrol = SmartStopPatrol.fromProps(props, lat: lat, lon: lon);
      } else {
        if (lat != null && lon != null) {
          waypoints.add(SmartWaypoint.fromProps(
            props,
            lat: lat,
            lon: lon,
            alt: alt,
          ));
        }
      }
    }

    return SmartPatrolData(
      newPatrol: newPatrol,
      waypoints: waypoints,
      stopPatrol: stopPatrol,
    );
  }
}

class SmartNewPatrol {
  final String patrolId;
  final String leader;
  final String station;
  final String transport;
  final String mandate;
  final String? comments;
  final DateTime startTime;
  final double? latitude;
  final double? longitude;
  final List<String> members;

  const SmartNewPatrol({
    required this.patrolId,
    required this.leader,
    required this.station,
    required this.transport,
    required this.mandate,
    this.comments,
    required this.startTime,
    this.latitude,
    this.longitude,
    required this.members,
  });

  factory SmartNewPatrol.fromProps(
    Map<String, dynamic> props, {
    double? lat,
    double? lon,
  }) {
    final dateStr = props['date'] as String? ??
        props['start_date'] as String? ??
        DateTime.now().toIso8601String();

    return SmartNewPatrol(
      patrolId: props['patrol_id'] as String? ??
          props['id'] as String? ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      leader: props['leader'] as String? ??
          props['rangers']?.toString() ??
          'Unknown',
      station: props['station'] as String? ??
          props['base_station'] as String? ??
          '',
      transport: props['transport'] as String? ??
          props['transport_type'] as String? ??
          'Đi bộ',
      mandate: props['mandate'] as String? ??
          props['objective'] as String? ??
          'Tuần tra định kỳ',
      comments: props['comments'] as String?,
      startTime: _parseDateTime(dateStr),
      latitude: lat,
      longitude: lon,
      members: _parseMembers(props),
    );
  }

  static List<String> _parseMembers(Map<String, dynamic> props) {
    final rangers = props['rangers'];
    if (rangers is List) return rangers.map((e) => e.toString()).toList();
    if (rangers is String) return [rangers];
    return [];
  }

  static DateTime _parseDateTime(String s) {
    try {
      return DateTime.parse(s);
    } catch (_) {
      return DateTime.now();
    }
  }
}

class SmartWaypoint {
  final double latitude;
  final double longitude;
  final double? altitude;
  final double? accuracy;
  final String observationType;
  final String? photoUrl;
  final String? notes;
  final DateTime timestamp;

  const SmartWaypoint({
    required this.latitude,
    required this.longitude,
    this.altitude,
    this.accuracy,
    required this.observationType,
    this.photoUrl,
    this.notes,
    required this.timestamp,
  });

  factory SmartWaypoint.fromProps(
    Map<String, dynamic> props, {
    required double lat,
    required double lon,
    double? alt,
  }) {
    final dateStr = props['date'] as String? ??
        props['timestamp'] as String? ??
        DateTime.now().toIso8601String();

    return SmartWaypoint(
      latitude: lat,
      longitude: lon,
      altitude: alt ?? (props['altitude'] as num?)?.toDouble(),
      accuracy: (props['accuracy'] as num?)?.toDouble(),
      observationType: props['type'] as String? ?? 'Waypoint',
      photoUrl: props['photo'] as String? ?? props['photo_url'] as String?,
      notes: props['notes'] as String? ?? props['description'] as String?,
      timestamp: _parseDateTime(dateStr),
    );
  }

  static DateTime _parseDateTime(String s) {
    try {
      return DateTime.parse(s);
    } catch (_) {
      return DateTime.now();
    }
  }
}

class SmartStopPatrol {
  final DateTime endTime;
  final double? latitude;
  final double? longitude;
  final String? comments;

  const SmartStopPatrol({
    required this.endTime,
    this.latitude,
    this.longitude,
    this.comments,
  });

  factory SmartStopPatrol.fromProps(
    Map<String, dynamic> props, {
    double? lat,
    double? lon,
  }) {
    final dateStr = props['date'] as String? ??
        props['end_date'] as String? ??
        DateTime.now().toIso8601String();

    return SmartStopPatrol(
      endTime: _parseDateTime(dateStr),
      latitude: lat,
      longitude: lon,
      comments: props['comments'] as String?,
    );
  }

  static DateTime _parseDateTime(String s) {
    try {
      return DateTime.parse(s);
    } catch (_) {
      return DateTime.now();
    }
  }
}

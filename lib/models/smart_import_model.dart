/// Parser for SMART Conservation Tools GeoJSON export format.
///
/// Supports both:
///   • Real SMART CT format  (SMART_ObservationType inside props or props.sighting)
///   • Simple demo format    (props.type = 'NewPatrol' / 'Waypoint' etc.)
class SmartPatrolData {
  final SmartNewPatrol? newPatrol;
  final List<SmartWaypoint> waypoints;
  final SmartStopPatrol? stopPatrol;

  const SmartPatrolData({
    this.newPatrol,
    required this.waypoints,
    this.stopPatrol,
  });

  /// Entry point – call this inside compute() to avoid blocking the main thread.
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

      // ── Determine observation type ──────────────────────────────────────
      // Real SMART format: type is in props.sighting.SMART_ObservationType
      //                    or in props.SMART_ObservationType (for waypoints)
      // Demo format:       type is in props.type
      final sighting = props['sighting'] as Map<String, dynamic>?;
      final smartType = sighting?['SMART_ObservationType'] as String? ??
          props['SMART_ObservationType'] as String? ??
          '';
      final demoType = props['type'] as String? ?? '';

      // Resolve to canonical type string
      final type = _resolveType(smartType, demoType);

      if (type == 'NewPatrol') {
        newPatrol = SmartNewPatrol.fromProps(props, sighting: sighting, lat: lat, lon: lon);
      } else if (type == 'StopPatrol') {
        stopPatrol = SmartStopPatrol.fromProps(props, sighting: sighting, lat: lat, lon: lon);
      } else if (lat != null && lon != null) {
        waypoints.add(SmartWaypoint.fromProps(
          props,
          sighting: sighting,
          lat: lat,
          lon: lon,
          alt: alt ?? (props['altitude'] as num?)?.toDouble(),
          type: type,
        ));
      }
    }

    // Sort waypoints chronologically
    waypoints.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    return SmartPatrolData(
      newPatrol: newPatrol,
      waypoints: waypoints,
      stopPatrol: stopPatrol,
    );
  }

  static String _resolveType(String smartType, String demoType) {
    // Real SMART types (case-insensitive match)
    switch (smartType.toLowerCase()) {
      case 'newpatrol':   return 'NewPatrol';
      case 'stoppatrol':  return 'StopPatrol';
      case 'waypoint':    return 'Waypoint';
      case 'observation': return 'Observation';
    }
    // Demo / simplified format fallback
    if (demoType.isNotEmpty) return demoType;
    return 'Waypoint';
  }
}

// ── NewPatrol ─────────────────────────────────────────────────────────────────

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
    Map<String, dynamic>? sighting,
    double? lat,
    double? lon,
  }) {
    final s = sighting ?? {};

    // Timestamp: real SMART uses camelCase 'dateTime'; demo uses 'date'
    final dateStr = props['dateTime'] as String? ??
        props['date'] as String? ??
        props['start_date'] as String? ??
        DateTime.now().toIso8601String();

    // Patrol ID
    final patrolId = s['SMART_PatrolID'] as String? ??
        props['patrol_id'] as String? ??
        props['id'] as String? ??
        DateTime.now().millisecondsSinceEpoch.toString();

    // Leader: real SMART may encode as 'e:uuid' – prefer appName for display
    final rawLeader = s['SMART_Leader'] as String? ?? props['leader'] as String? ?? '';
    final appName   = props['appName'] as String? ?? '';
    final leader    = _humanReadable(rawLeader, fallback: appName.isNotEmpty ? appName : 'Unknown');

    // Station: may be encoded as 'ps:uuid'
    final rawStation = s['SMART_Station'] as String? ?? props['station'] as String? ?? '';
    final station    = _humanReadable(rawStation, fallback: '');

    // Transport: may be encoded as 'tt:uuid'
    final rawTransport = s['SMART_PatrolTransport'] as String? ??
        props['transport'] as String? ?? '';
    final transport    = _humanReadable(rawTransport, fallback: 'Đi bộ');

    // Mandate: may be encoded as 'pm:uuid'
    final rawMandate = s['SMART_Mandate'] as String? ??
        props['mandate'] as String? ?? '';
    final mandate    = _humanReadable(rawMandate, fallback: 'Tuần tra định kỳ');

    return SmartNewPatrol(
      patrolId:  patrolId,
      leader:    leader,
      station:   station,
      transport: transport,
      mandate:   mandate,
      comments:  props['comments'] as String?,
      startTime: _parseDateTime(dateStr),
      latitude:  lat,
      longitude: lon,
      members:   _parseMembers(props),
    );
  }

  /// Real SMART encodes references as 'prefix:uuid' (e.g. 'e:abc123').
  /// Strip the prefix and return just the UUID, or use [fallback] if unreadable.
  static String _humanReadable(String raw, {required String fallback}) {
    if (raw.isEmpty) return fallback;
    // If it looks like a prefixed UUID (e.g. "e:abc123" / "ps:abc123")
    final colonIdx = raw.indexOf(':');
    if (colonIdx > 0 && colonIdx <= 3) {
      // Just a UUID ref – can't resolve without SMART DB, use fallback
      return fallback;
    }
    return raw;
  }

  static List<String> _parseMembers(Map<String, dynamic> props) {
    final rangers = props['rangers'];
    if (rangers is List) return rangers.map((e) => e.toString()).toList();
    if (rangers is String) return [rangers];
    return [];
  }

  static DateTime _parseDateTime(String s) {
    try { return DateTime.parse(s); } catch (_) { return DateTime.now(); }
  }
}

// ── Waypoint ──────────────────────────────────────────────────────────────────

class SmartWaypoint {
  final double latitude;
  final double longitude;
  final double? altitude;
  final double? accuracy;
  final String observationType;
  final String? photoUrl;
  /// Base64-encoded photos extracted from SMART sighting fields (SMART_Photo0:0 etc.)
  final List<String> base64Photos;
  final String? notes;
  final DateTime timestamp;

  const SmartWaypoint({
    required this.latitude,
    required this.longitude,
    this.altitude,
    this.accuracy,
    required this.observationType,
    this.photoUrl,
    this.base64Photos = const [],
    this.notes,
    required this.timestamp,
  });

  factory SmartWaypoint.fromProps(
    Map<String, dynamic> props, {
    Map<String, dynamic>? sighting,
    required double lat,
    required double lon,
    double? alt,
    String type = 'Waypoint',
  }) {
    final s = sighting ?? {};

    // Timestamp: real SMART → 'dateTime'; demo → 'date' / 'timestamp'
    final dateStr = props['dateTime'] as String? ??
        props['date'] as String? ??
        props['timestamp'] as String? ??
        DateTime.now().toIso8601String();

    // URL-based photos (simple format)
    final photoUrl = props['photo'] as String? ?? props['photo_url'] as String?;

    // Base64 photos from real SMART: keys are SMART_Photo0:0, SMART_Photo0:1 ...
    final base64Photos = s.entries
        .where((e) => e.key.startsWith('SMART_Photo') &&
            e.value is String &&
            (e.value as String).length > 100) // real base64, not empty markers
        .map((e) => e.value as String)
        .toList();

    // Notes from sighting attributes
    final notes = s['SMART_Notes'] as String? ??
        props['notes'] as String? ??
        props['description'] as String?;

    // Map 'Observation' type to something more meaningful if sub-type available
    final obsType = type == 'Observation'
        ? (s['SMART_ObsCategoryLabel'] as String? ?? 'Observation')
        : type;

    return SmartWaypoint(
      latitude:        lat,
      longitude:       lon,
      altitude:        alt,
      accuracy:        (props['accuracy'] as num?)?.toDouble(),
      observationType: obsType,
      photoUrl:        photoUrl,
      base64Photos:    base64Photos,
      notes:           notes,
      timestamp:       _parseDateTime(dateStr),
    );
  }

  static DateTime _parseDateTime(String s) {
    try { return DateTime.parse(s); } catch (_) { return DateTime.now(); }
  }
}

// ── StopPatrol ────────────────────────────────────────────────────────────────

class SmartStopPatrol {
  final DateTime endTime;
  final double? latitude;
  final double? longitude;
  final String? comments;
  /// Distance in meters from SMART's own calculation (more accurate than haversine)
  final double? smartDistanceMeters;

  const SmartStopPatrol({
    required this.endTime,
    this.latitude,
    this.longitude,
    this.comments,
    this.smartDistanceMeters,
  });

  factory SmartStopPatrol.fromProps(
    Map<String, dynamic> props, {
    Map<String, dynamic>? sighting,
    double? lat,
    double? lon,
  }) {
    final s = sighting ?? {};

    final dateStr = props['dateTime'] as String? ??
        props['date'] as String? ??
        props['end_date'] as String? ??
        DateTime.now().toIso8601String();

    // SMART_PatrolLegDistance is in meters (float)
    final distRaw = s['SMART_PatrolLegDistance'];
    final distMeters = distRaw != null ? (distRaw as num).toDouble() : null;

    return SmartStopPatrol(
      endTime:              _parseDateTime(dateStr),
      latitude:             lat,
      longitude:            lon,
      comments:             props['comments'] as String?,
      smartDistanceMeters:  distMeters,
    );
  }

  static DateTime _parseDateTime(String s) {
    try { return DateTime.parse(s); } catch (_) { return DateTime.now(); }
  }
}

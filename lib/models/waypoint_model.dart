import 'package:latlong2/latlong.dart';

class Waypoint {
  final String id;
  final String patrolId;
  final double latitude;
  final double longitude;
  final double? altitude;
  final double? accuracy;
  final double? bearing;
  final double? speed;
  final String observationType;
  final String? photoUrl;
  final String? notes;
  final DateTime timestamp;
  final bool isSynced;

  const Waypoint({
    required this.id,
    required this.patrolId,
    required this.latitude,
    required this.longitude,
    this.altitude,
    this.accuracy,
    this.bearing,
    this.speed,
    required this.observationType,
    this.photoUrl,
    this.notes,
    required this.timestamp,
    this.isSynced = false,
  });

  LatLng get latLng => LatLng(latitude, longitude);

  bool get hasPhoto => photoUrl != null && photoUrl!.isNotEmpty;
  bool get isStartPoint => observationType == 'NewPatrol';
  bool get isEndPoint => observationType == 'StopPatrol';
  bool get isObservation =>
      observationType != 'NewPatrol' &&
      observationType != 'StopPatrol' &&
      observationType != 'Waypoint';

  factory Waypoint.fromMap(Map<String, dynamic> map) => Waypoint(
        id: map['id'] as String,
        patrolId: map['patrol_id'] as String? ?? '',
        latitude: (map['latitude'] as num).toDouble(),
        longitude: (map['longitude'] as num).toDouble(),
        altitude: (map['altitude'] as num?)?.toDouble(),
        accuracy: (map['accuracy'] as num?)?.toDouble(),
        bearing: (map['bearing'] as num?)?.toDouble(),
        speed: (map['speed'] as num?)?.toDouble(),
        observationType: map['observation_type'] as String? ?? 'Waypoint',
        photoUrl: map['photo_url'] as String?,
        notes: map['notes'] as String?,
        timestamp: DateTime.parse(map['timestamp'] as String),
        isSynced: map['is_synced'] as bool? ?? true,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'patrol_id': patrolId,
        'latitude': latitude,
        'longitude': longitude,
        'altitude': altitude,
        'accuracy': accuracy,
        'bearing': bearing,
        'speed': speed,
        'observation_type': observationType,
        'photo_url': photoUrl,
        'notes': notes,
        'timestamp': timestamp.toUtc().toIso8601String(),
      };

  Waypoint copyWith({
    String? photoUrl,
    String? notes,
    bool? isSynced,
  }) =>
      Waypoint(
        id: id,
        patrolId: patrolId,
        latitude: latitude,
        longitude: longitude,
        altitude: altitude,
        accuracy: accuracy,
        bearing: bearing,
        speed: speed,
        observationType: observationType,
        photoUrl: photoUrl ?? this.photoUrl,
        notes: notes ?? this.notes,
        timestamp: timestamp,
        isSynced: isSynced ?? this.isSynced,
      );
}

class AppConstants {
  AppConstants._();

  static const String appName = 'RangerGuard VN';
  static const String appVersion = '1.0.0';

  // Patrol tracking
  static const int waypointIntervalSeconds = 10;
  static const double minMovementMeters = 10.0;
  static const double defaultMapZoom = 13.0;
  static const double minMapZoom = 5.0;
  static const double maxMapZoom = 18.0;

  // Tile layer URLs
  static const String osmTileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const String esriSatelliteTileUrl =
      'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
  static const String esriTerrainTileUrl =
      'https://server.arcgisonline.com/ArcGIS/rest/services/World_Topo_Map/MapServer/tile/{z}/{y}/{x}';
  static const String stadiaSatelliteTileUrl =
      'https://tiles.stadiamaps.com/tiles/alidade_satellite/{z}/{x}/{y}.jpg';
  static const String googleSatelliteTileUrl =
      'https://mt1.google.com/vt/lyrs=s&x={x}&y={y}&z={z}';

  // Hive box names
  static const String patrolBox = 'patrols';
  static const String waypointBox = 'waypoints';
  static const String scheduleBox = 'schedules';
  static const String settingsBox = 'settings';
  static const String syncQueueBox = 'sync_queue';

  // Supabase table names
  static const String profilesTable = 'profiles';
  static const String patrolsTable = 'patrols';
  static const String waypointsTable = 'waypoints';
  static const String schedulesTable = 'schedules';
  static const String stationsTable = 'stations';
  static const String mandatesTable = 'mandates';
  static const String transportsTable = 'transports';

  // File size limits
  static const int maxPhotoSizeMB = 10;
  static const int maxImportFileSizeMB = 50;

  // Observation types
  static const String obsNewPatrol = 'NewPatrol';
  static const String obsStopPatrol = 'StopPatrol';
  static const String obsWaypoint = 'Waypoint';
  static const String obsAnimal = 'Animal';
  static const String obsThreat = 'Threat';
  static const String obsPhoto = 'Photo';

  // User roles
  static const String roleAdmin = 'admin';
  static const String roleLeader = 'leader';
  static const String roleRanger = 'ranger';
  static const String roleViewer = 'viewer';
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

enum MapLayer { osm, satellite, terrain, googleSatellite }

class MapSettings {
  final MapLayer activeLayer;
  final double zoom;
  final LatLng center;
  final bool showHeatmap;
  final bool showWaypoints;
  final bool showPolylines;
  final List<String> selectedPatrolIds;

  const MapSettings({
    this.activeLayer = MapLayer.osm,
    this.zoom = 13.0,
    this.center = const LatLng(15.8801, 108.3380), // Đà Nẵng
    this.showHeatmap = false,
    this.showWaypoints = true,
    this.showPolylines = true,
    this.selectedPatrolIds = const [],
  });

  MapSettings copyWith({
    MapLayer? activeLayer,
    double? zoom,
    LatLng? center,
    bool? showHeatmap,
    bool? showWaypoints,
    bool? showPolylines,
    List<String>? selectedPatrolIds,
  }) =>
      MapSettings(
        activeLayer: activeLayer ?? this.activeLayer,
        zoom: zoom ?? this.zoom,
        center: center ?? this.center,
        showHeatmap: showHeatmap ?? this.showHeatmap,
        showWaypoints: showWaypoints ?? this.showWaypoints,
        showPolylines: showPolylines ?? this.showPolylines,
        selectedPatrolIds: selectedPatrolIds ?? this.selectedPatrolIds,
      );

  String get layerLabel {
    switch (activeLayer) {
      case MapLayer.osm:
        return 'OpenStreetMap';
      case MapLayer.satellite:
        return 'Vệ tinh ESRI';
      case MapLayer.terrain:
        return 'Địa hình';
      case MapLayer.googleSatellite:
        return 'Google Vệ tinh';
    }
  }
}

class MapSettingsNotifier extends StateNotifier<MapSettings> {
  MapSettingsNotifier() : super(const MapSettings());

  void setLayer(MapLayer layer) =>
      state = state.copyWith(activeLayer: layer);

  void toggleHeatmap() =>
      state = state.copyWith(showHeatmap: !state.showHeatmap);

  void toggleWaypoints() =>
      state = state.copyWith(showWaypoints: !state.showWaypoints);

  void togglePolylines() =>
      state = state.copyWith(showPolylines: !state.showPolylines);

  void setCenter(LatLng center) => state = state.copyWith(center: center);

  void selectPatrol(String patrolId) {
    final ids = [...state.selectedPatrolIds];
    if (ids.contains(patrolId)) {
      ids.remove(patrolId);
    } else {
      ids.add(patrolId);
    }
    state = state.copyWith(selectedPatrolIds: ids);
  }

  void clearSelection() => state = state.copyWith(selectedPatrolIds: []);
}

final mapSettingsProvider =
    StateNotifierProvider<MapSettingsNotifier, MapSettings>((ref) {
  return MapSettingsNotifier();
});

// Polyline colors for different patrols
final patrolColorProvider = Provider.family<Color, int>((ref, index) {
  const colors = [
    Color(0xFF1B4332),
    Color(0xFF2D6A4F),
    Color(0xFF40916C),
    Color(0xFF52B788),
    Color(0xFF1565C0),
    Color(0xFF6A1B9A),
    Color(0xFF8B5E3C),
    Color(0xFFE65100),
    Color(0xFF00695C),
    Color(0xFF37474F),
  ];
  return colors[index % colors.length];
});

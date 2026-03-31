import 'dart:math';
import 'package:latlong2/latlong.dart';

class GeoUtils {
  GeoUtils._();

  static const double _earthRadius = 6371000; // meters

  /// Tính khoảng cách giữa 2 điểm GPS (Haversine formula)
  static double haversineDistance(LatLng p1, LatLng p2) {
    final lat1 = _toRadians(p1.latitude);
    final lat2 = _toRadians(p2.latitude);
    final dLat = _toRadians(p2.latitude - p1.latitude);
    final dLon = _toRadians(p2.longitude - p1.longitude);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return _earthRadius * c;
  }

  /// Tính tổng quãng đường từ danh sách waypoints
  static double totalDistance(List<LatLng> points) {
    if (points.length < 2) return 0;
    double total = 0;
    for (int i = 0; i < points.length - 1; i++) {
      total += haversineDistance(points[i], points[i + 1]);
    }
    return total;
  }

  /// Format khoảng cách: m hoặc km
  static String formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)} m';
    }
    return '${(meters / 1000).toStringAsFixed(2)} km';
  }

  /// Format tốc độ km/h
  static String formatSpeed(double metersPerSecond) {
    final kmh = metersPerSecond * 3.6;
    return '${kmh.toStringAsFixed(1)} km/h';
  }

  /// Tính bounding box của danh sách điểm
  static ({double minLat, double maxLat, double minLon, double maxLon})
      boundingBox(List<LatLng> points) {
    if (points.isEmpty) {
      return (minLat: 0, maxLat: 0, minLon: 0, maxLon: 0);
    }
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLon = points.first.longitude;
    double maxLon = points.first.longitude;

    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLon) minLon = p.longitude;
      if (p.longitude > maxLon) maxLon = p.longitude;
    }
    return (
      minLat: minLat,
      maxLat: maxLat,
      minLon: minLon,
      maxLon: maxLon,
    );
  }

  /// Center của bounding box
  static LatLng centerOf(List<LatLng> points) {
    if (points.isEmpty) return const LatLng(16.0, 108.0);
    final bb = boundingBox(points);
    return LatLng(
      (bb.minLat + bb.maxLat) / 2,
      (bb.minLon + bb.maxLon) / 2,
    );
  }

  static double _toRadians(double degree) => degree * pi / 180;

  /// Convert WKT Point to LatLng
  static LatLng? parseWkt(String? wkt) {
    if (wkt == null) return null;
    final regex = RegExp(r'POINT\(([0-9.\-]+)\s+([0-9.\-]+)\)');
    final match = regex.firstMatch(wkt);
    if (match == null) return null;
    return LatLng(double.parse(match.group(2)!), double.parse(match.group(1)!));
  }

  /// Convert LatLng to WKT
  static String toWkt(LatLng point) =>
      'POINT(${point.longitude} ${point.latitude})';
}

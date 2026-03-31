import 'dart:convert';
import 'dart:typed_data';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rangeguard_vn/core/supabase/supabase_config.dart';

class PatrolPhoto {
  final String id;
  final String patrolId;
  final String? waypointId;
  final String? storagePath;
  final String? originalUrl;
  final String? thumbnailUrl;
  final DateTime? takenAt;
  final double? latitude;
  final double? longitude;
  final String observationType;
  final String? notes;
  final List<String> tags;
  final String? uploadedBy;
  final DateTime createdAt;

  // Joined fields from view
  final String? patrolCode;
  final String? leaderName;
  final String? stationName;
  final DateTime? patrolDate;

  const PatrolPhoto({
    required this.id,
    required this.patrolId,
    this.waypointId,
    this.storagePath,
    this.originalUrl,
    this.thumbnailUrl,
    this.takenAt,
    this.latitude,
    this.longitude,
    this.observationType = 'Photo',
    this.notes,
    this.tags = const [],
    this.uploadedBy,
    required this.createdAt,
    this.patrolCode,
    this.leaderName,
    this.stationName,
    this.patrolDate,
  });

  String? get displayUrl => storagePath != null
      ? SupabaseConfig.client.storage
          .from('patrol-photos')
          .getPublicUrl(storagePath!)
      : originalUrl;

  factory PatrolPhoto.fromMap(Map<String, dynamic> map) => PatrolPhoto(
        id: map['id'] as String,
        patrolId: map['patrol_id'] as String,
        waypointId: map['waypoint_id'] as String?,
        storagePath: map['storage_path'] as String?,
        originalUrl: map['original_url'] as String?,
        thumbnailUrl: map['thumbnail_url'] as String?,
        takenAt: map['taken_at'] != null
            ? DateTime.parse(map['taken_at'] as String)
            : null,
        latitude: (map['latitude'] as num?)?.toDouble(),
        longitude: (map['longitude'] as num?)?.toDouble(),
        observationType: map['observation_type'] as String? ?? 'Photo',
        notes: map['notes'] as String?,
        tags: List<String>.from(map['tags'] as List? ?? []),
        uploadedBy: map['uploaded_by'] as String?,
        createdAt: DateTime.parse(
            map['created_at'] as String? ?? DateTime.now().toIso8601String()),
        patrolCode: map['patrol_code'] as String?,
        leaderName: map['leader_name'] as String?,
        stationName: map['station_name'] as String?,
        patrolDate: map['patrol_date'] != null
            ? DateTime.parse(map['patrol_date'] as String)
            : null,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'patrol_id': patrolId,
        'waypoint_id': waypointId,
        'storage_path': storagePath,
        'original_url': originalUrl,
        'thumbnail_url': thumbnailUrl,
        'taken_at': takenAt?.toUtc().toIso8601String(),
        'latitude': latitude,
        'longitude': longitude,
        'observation_type': observationType,
        'notes': notes,
        'tags': tags,
        'uploaded_by': uploadedBy,
        'created_at': createdAt.toUtc().toIso8601String(),
      };
}

class PhotoRepository {
  final _uuid = const Uuid();
  SupabaseClient get _client => SupabaseConfig.client;

  Future<List<PatrolPhoto>> getPhotosByPatrol(String patrolId) async {
    final data = await _client
        .from('patrol_photos')
        .select()
        .eq('patrol_id', patrolId)
        .order('taken_at', ascending: true);
    return data.map((e) => PatrolPhoto.fromMap(e)).toList();
  }

  Future<List<PatrolPhoto>> getGallery({
    String? patrolId,
    DateTime? from,
    DateTime? to,
    String? observationType,
    int limit = 50,
    int offset = 0,
  }) async {
    // Build filters first, then apply ordering + paging
    var filterQuery = _client.from('photo_gallery').select();

    if (patrolId != null) filterQuery = filterQuery.eq('patrol_id', patrolId);
    if (observationType != null) {
      filterQuery = filterQuery.eq('observation_type', observationType);
    }
    if (from != null) {
      filterQuery =
          filterQuery.gte('taken_at', from.toUtc().toIso8601String());
    }
    if (to != null) {
      filterQuery =
          filterQuery.lte('taken_at', to.toUtc().toIso8601String());
    }

    final data = await filterQuery
        .order('taken_at', ascending: false)
        .range(offset, offset + limit - 1);
    return data.map((e) => PatrolPhoto.fromMap(e)).toList();
  }

  /// Upload ảnh từ device lên Supabase Storage
  Future<PatrolPhoto> uploadPhoto({
    required String patrolId,
    String? waypointId,
    required Uint8List bytes,
    required String fileName,
    String? notes,
    double? latitude,
    double? longitude,
    String observationType = 'Photo',
    String? uploadedBy,
  }) async {
    final id = _uuid.v4();
    final path = '$patrolId/$id-$fileName';

    await _client.storage.from('patrol-photos').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            upsert: false,
            contentType: 'image/jpeg',
          ),
        );

    final photo = PatrolPhoto(
      id: id,
      patrolId: patrolId,
      waypointId: waypointId,
      storagePath: path,
      takenAt: DateTime.now(),
      latitude: latitude,
      longitude: longitude,
      observationType: observationType,
      notes: notes,
      uploadedBy: uploadedBy,
      createdAt: DateTime.now(),
    );

    await _client.from('patrol_photos').insert(photo.toMap());
    return photo;
  }

  /// Lưu reference đến ảnh từ JSON import (URL ngoài)
  Future<PatrolPhoto> savePhotoReference({
    required String patrolId,
    String? waypointId,
    required String originalUrl,
    double? latitude,
    double? longitude,
    DateTime? takenAt,
    String? notes,
    String observationType = 'Photo',
    String? uploadedBy,
  }) async {
    final photo = PatrolPhoto(
      id: _uuid.v4(),
      patrolId: patrolId,
      waypointId: waypointId,
      originalUrl: originalUrl,
      takenAt: takenAt,
      latitude: latitude,
      longitude: longitude,
      observationType: observationType,
      notes: notes,
      uploadedBy: uploadedBy,
      createdAt: DateTime.now(),
    );

    await _client.from('patrol_photos').insert(photo.toMap());
    return photo;
  }

  /// Trích xuất và lưu tất cả ảnh từ waypoints của 1 patrol.
  /// Hỗ trợ cả URL-based và base64-encoded (SMART CT format).
  Future<int> extractPhotosFromWaypoints({
    required String patrolId,
    required List<Map<String, dynamic>> waypointMaps,
    String? uploadedBy,
  }) async {
    int count = 0;
    for (final wp in waypointMaps) {
      final waypointId = wp['id'] as String?;
      final lat  = (wp['latitude']  as num?)?.toDouble();
      final lon  = (wp['longitude'] as num?)?.toDouble();
      final takenAt = wp['timestamp'] != null
          ? DateTime.tryParse(wp['timestamp'] as String)
          : null;
      final notes   = wp['notes'] as String?;
      final obsType = wp['observation_type'] as String? ?? 'Photo';

      // URL-based photo (simple format)
      final photoUrl = wp['photo_url'] as String? ?? wp['photo'] as String?;
      if (photoUrl != null && photoUrl.isNotEmpty) {
        await savePhotoReference(
          patrolId: patrolId,
          waypointId: waypointId,
          originalUrl: photoUrl,
          latitude: lat,
          longitude: lon,
          takenAt: takenAt,
          notes: notes,
          observationType: obsType,
          uploadedBy: uploadedBy,
        );
        count++;
      }

      // Base64-encoded photos from real SMART CT export
      final b64List = wp['base64_photos'] as List?;
      if (b64List != null && b64List.isNotEmpty) {
        for (int i = 0; i < b64List.length; i++) {
          final b64 = b64List[i] as String?;
          if (b64 == null || b64.isEmpty) continue;
          try {
            // Strip data URI prefix if present (data:image/jpeg;base64,...)
            final raw = b64.contains(',') ? b64.split(',').last : b64;
            final bytes = base64Decode(raw);
            final fileName = '${waypointId ?? _uuid.v4()}_$i.jpg';
            await uploadPhoto(
              patrolId: patrolId,
              waypointId: waypointId,
              bytes: bytes,
              fileName: fileName,
              latitude: lat,
              longitude: lon,
              notes: notes,
              observationType: obsType,
              uploadedBy: uploadedBy,
            );
            count++;
          } catch (_) {
            // Skip corrupt base64 silently
          }
        }
      }
    }
    return count;
  }

  Future<void> deletePhoto(String id) async {
    final data = await _client
        .from('patrol_photos')
        .select('storage_path')
        .eq('id', id)
        .maybeSingle();

    if (data?['storage_path'] != null) {
      await _client.storage
          .from('patrol-photos')
          .remove([data!['storage_path'] as String]);
    }
    await _client.from('patrol_photos').delete().eq('id', id);
  }

  Future<Map<String, dynamic>> getPhotoStats() async {
    final data = await _client.from('patrol_photos').select('observation_type');
    final byType = <String, int>{};
    for (final row in data) {
      final t = row['observation_type'] as String? ?? 'Photo';
      byType[t] = (byType[t] ?? 0) + 1;
    }
    return {
      'total': data.length,
      'by_type': byType,
    };
  }
}

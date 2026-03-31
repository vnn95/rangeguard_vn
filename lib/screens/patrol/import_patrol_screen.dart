import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rangeguard_vn/core/constants/app_colors.dart';
import 'package:rangeguard_vn/providers/auth_provider.dart';
import 'package:rangeguard_vn/providers/patrol_provider.dart';

class ImportPatrolScreen extends ConsumerStatefulWidget {
  const ImportPatrolScreen({super.key});

  @override
  ConsumerState<ImportPatrolScreen> createState() => _ImportPatrolScreenState();
}

class _ImportPatrolScreenState extends ConsumerState<ImportPatrolScreen> {
  bool _isLoading = false;
  String? _lastImportInfo;
  String? _lastPatrolId;

  Future<void> _importFromFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json', 'geojson'],
    );

    if (result == null || result.files.isEmpty) return;

    // On Android/iOS, bytes is null – read from path instead
    String jsonStr;
    final file = result.files.first;
    if (file.bytes != null) {
      jsonStr = utf8.decode(file.bytes!);
    } else if (file.path != null) {
      jsonStr = await File(file.path!).readAsString();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không đọc được file')),
        );
      }
      return;
    }
    await _processJson(jsonStr, file.name);
  }

  Future<void> _importSampleData() async {
    setState(() => _isLoading = true);
    try {
      final jsonStr =
          await rootBundle.loadString('assets/data/patrol2_sample.json');
      await _processJson(jsonStr, 'patrol2_sample.json');
    } catch (e) {
      // If sample file doesn't exist, use embedded demo data
      await _processJson(_demoPatrolJson, 'demo_patrol.json');
    }
  }

  Future<void> _processJson(String jsonStr, String filename) async {
    setState(() => _isLoading = true);
    try {
      final profile = ref.read(authNotifierProvider).valueOrNull;
      final repo = ref.read(patrolRepositoryProvider);

      // importFromSmartJson now runs jsonDecode + parse in a background isolate
      final patrol = await repo.importFromSmartJson(
        jsonStr,
        profile?.id ?? 'demo',
      );

      ref.invalidate(patrolsProvider);
      ref.invalidate(patrolStatsProvider);

      _lastPatrolId = patrol.id;
      setState(() {
        final dist = (patrol.totalDistanceMeters ?? 0) / 1000;
        final dur = patrol.duration;
        final durStr = dur != null
            ? '${dur.inHours}h ${dur.inMinutes.remainder(60)}m'
            : '--';
        _lastImportInfo =
            'File: $filename\n'
            'PatrolID: ${patrol.patrolId}\n'
            'Trưởng đội: ${patrol.leaderName}\n'
            'Trạm: ${patrol.stationName.isNotEmpty ? patrol.stationName : '--'}\n'
            'Phương tiện: ${patrol.transportType}\n'
            'Điểm GPS: ${patrol.totalWaypoints ?? 0} điểm\n'
            'Quãng đường: ${dist.toStringAsFixed(2)} km\n'
            'Thời gian: $durStr';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Import thành công!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi import: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Import tuần tra SMART')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Info card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.info_outline, color: AppColors.primary),
                      SizedBox(width: 8),
                      Text(
                        'Hỗ trợ định dạng',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryDark,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• GeoJSON từ SMART Conservation Tools\n'
                    '• Tự động parse NewPatrol, Waypoints, StopPatrol\n'
                    '• Tính quãng đường tự động\n'
                    '• Hỗ trợ ảnh và ghi chú',
                    style: TextStyle(color: AppColors.primaryDark, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Import from file
            OutlinedButton.icon(
              onPressed: _isLoading ? null : _importFromFile,
              icon: const Icon(Icons.folder_open_outlined),
              label: const Text('Chọn file JSON/GeoJSON'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 12),

            // Import sample
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _importSampleData,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.download_outlined),
              label: const Text('Import dữ liệu mẫu (patrol2.json)'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: AppColors.accent,
              ),
            ),

            // Result
            if (_lastImportInfo != null) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.success.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.check_circle,
                            color: AppColors.success, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Kết quả import',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _lastImportInfo!,
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.hiking, size: 16),
                            label: const Text('Xem chuyến'),
                            onPressed: _lastPatrolId != null
                                ? () => context.go('/patrols/$_lastPatrolId')
                                : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.photo_library, size: 16),
                            label: const Text('Xem ảnh'),
                            onPressed: _lastPatrolId != null
                                ? () => context.go(
                                    '/admin/photos?patrol_id=$_lastPatrolId')
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),
            // Format hint
            const Text(
              'Định dạng GeoJSON mẫu:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                '{\n'
                '  "type": "FeatureCollection",\n'
                '  "features": [\n'
                '    {\n'
                '      "type": "Feature",\n'
                '      "geometry": {"type":"Point","coordinates":[108.33,15.88]},\n'
                '      "properties": {\n'
                '        "type": "NewPatrol",\n'
                '        "patrol_id": "P-2024-001",\n'
                '        "leader": "Nguyễn Văn A",\n'
                '        "date": "2024-01-15T08:00:00"\n'
                '      }\n'
                '    }\n'
                '  ]\n'
                '}',
                style: TextStyle(
                  color: Color(0xFF98C379),
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Demo patrol JSON for testing (embedded fallback)
const String _demoPatrolJson = '''
{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "geometry": {"type": "Point", "coordinates": [108.3380, 15.8801, 250.0]},
      "properties": {
        "type": "NewPatrol",
        "patrol_id": "P-2024-DEMO-001",
        "leader": "Nguyễn Văn Bảo",
        "station": "Trạm Kiểm Lâm Số 3",
        "transport": "Đi bộ",
        "mandate": "Tuần tra bảo vệ rừng định kỳ",
        "date": "2024-03-15T07:30:00+07:00",
        "rangers": ["Nguyễn Văn Bảo", "Trần Thị Lan", "Lê Văn Đức"]
      }
    },
    {
      "type": "Feature",
      "geometry": {"type": "Point", "coordinates": [108.3420, 15.8830, 260.0]},
      "properties": {
        "type": "Waypoint",
        "date": "2024-03-15T07:45:00+07:00",
        "accuracy": 4.5,
        "altitude": 260.0
      }
    },
    {
      "type": "Feature",
      "geometry": {"type": "Point", "coordinates": [108.3465, 15.8862, 275.0]},
      "properties": {
        "type": "Waypoint",
        "date": "2024-03-15T08:00:00+07:00",
        "accuracy": 3.8
      }
    },
    {
      "type": "Feature",
      "geometry": {"type": "Point", "coordinates": [108.3510, 15.8895, 290.0]},
      "properties": {
        "type": "Animal",
        "date": "2024-03-15T08:15:00+07:00",
        "notes": "Phát hiện dấu vết heo rừng",
        "accuracy": 5.0
      }
    },
    {
      "type": "Feature",
      "geometry": {"type": "Point", "coordinates": [108.3555, 15.8920, 285.0]},
      "properties": {
        "type": "Waypoint",
        "date": "2024-03-15T08:30:00+07:00",
        "accuracy": 4.2
      }
    },
    {
      "type": "Feature",
      "geometry": {"type": "Point", "coordinates": [108.3598, 15.8948, 270.0]},
      "properties": {
        "type": "Threat",
        "date": "2024-03-15T08:45:00+07:00",
        "notes": "Phát hiện bẫy thú - đã tháo gỡ",
        "accuracy": 3.5
      }
    },
    {
      "type": "Feature",
      "geometry": {"type": "Point", "coordinates": [108.3640, 15.8970, 265.0]},
      "properties": {
        "type": "Waypoint",
        "date": "2024-03-15T09:00:00+07:00",
        "accuracy": 4.8
      }
    },
    {
      "type": "Feature",
      "geometry": {"type": "Point", "coordinates": [108.3640, 15.8970, 265.0]},
      "properties": {
        "type": "StopPatrol",
        "date": "2024-03-15T09:30:00+07:00",
        "comments": "Hoàn thành tuần tra, không phát hiện vi phạm nghiêm trọng"
      }
    }
  ]
}
''';

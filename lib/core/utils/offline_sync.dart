import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logger/logger.dart';
import 'package:rangeguard_vn/core/constants/app_constants.dart';
import 'package:rangeguard_vn/core/supabase/supabase_config.dart';

final _log = Logger();

enum SyncAction { insert, update, delete }

class SyncQueueItem {
  final String id;
  final String table;
  final SyncAction action;
  final Map<String, dynamic> data;
  final DateTime createdAt;

  SyncQueueItem({
    required this.id,
    required this.table,
    required this.action,
    required this.data,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'table': table,
        'action': action.name,
        'data': data,
        'created_at': createdAt.toIso8601String(),
      };

  factory SyncQueueItem.fromMap(Map<String, dynamic> map) => SyncQueueItem(
        id: map['id'],
        table: map['table'],
        action: SyncAction.values.byName(map['action']),
        data: Map<String, dynamic>.from(map['data']),
        createdAt: DateTime.parse(map['created_at']),
      );
}

class OfflineSyncService {
  static final OfflineSyncService _instance = OfflineSyncService._();
  factory OfflineSyncService() => _instance;
  OfflineSyncService._();

  late Box _syncBox;
  bool _isSyncing = false;

  Future<void> init() async {
    _syncBox = await Hive.openBox(AppConstants.syncQueueBox);
    _listenConnectivity();
  }

  void _listenConnectivity() {
    Connectivity().onConnectivityChanged.listen((results) {
      if (results.any((r) => r != ConnectivityResult.none)) {
        syncPendingItems();
      }
    });
  }

  Future<bool> isOnline() async {
    final result = await Connectivity().checkConnectivity();
    return result.any((r) => r != ConnectivityResult.none);
  }

  Future<void> addToQueue(SyncQueueItem item) async {
    await _syncBox.put(item.id, item.toMap());
  }

  Future<void> syncPendingItems() async {
    if (_isSyncing) return;
    if (!await isOnline()) return;

    _isSyncing = true;
    _log.i('Starting offline sync: ${_syncBox.length} items');

    final keys = _syncBox.keys.toList();
    for (final key in keys) {
      try {
        final item = SyncQueueItem.fromMap(
          Map<String, dynamic>.from(_syncBox.get(key)),
        );
        await _processItem(item);
        await _syncBox.delete(key);
      } catch (e) {
        _log.e('Sync failed for $key: $e');
      }
    }

    _isSyncing = false;
    _log.i('Sync completed');
  }

  Future<void> _processItem(SyncQueueItem item) async {
    final client = SupabaseConfig.client;
    switch (item.action) {
      case SyncAction.insert:
        await client.from(item.table).upsert(item.data);
      case SyncAction.update:
        await client.from(item.table).update(item.data).eq('id', item.data['id']);
      case SyncAction.delete:
        await client.from(item.table).delete().eq('id', item.data['id']);
    }
  }

  int get pendingCount => _syncBox.length;
}

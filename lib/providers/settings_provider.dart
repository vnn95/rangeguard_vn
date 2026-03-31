import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:rangeguard_vn/core/constants/app_constants.dart';

class AppSettings {
  final ThemeMode themeMode;
  final Locale locale;
  final int waypointIntervalSeconds;
  final double minMovementMeters;
  final bool enableNotifications;
  final bool enableLiveTracking;
  final bool keepScreenOn;

  const AppSettings({
    this.themeMode = ThemeMode.light,
    this.locale = const Locale('vi'),
    this.waypointIntervalSeconds = AppConstants.waypointIntervalSeconds,
    this.minMovementMeters = AppConstants.minMovementMeters,
    this.enableNotifications = true,
    this.enableLiveTracking = true,
    this.keepScreenOn = true,
  });

  AppSettings copyWith({
    ThemeMode? themeMode,
    Locale? locale,
    int? waypointIntervalSeconds,
    double? minMovementMeters,
    bool? enableNotifications,
    bool? enableLiveTracking,
    bool? keepScreenOn,
  }) =>
      AppSettings(
        themeMode: themeMode ?? this.themeMode,
        locale: locale ?? this.locale,
        waypointIntervalSeconds:
            waypointIntervalSeconds ?? this.waypointIntervalSeconds,
        minMovementMeters: minMovementMeters ?? this.minMovementMeters,
        enableNotifications: enableNotifications ?? this.enableNotifications,
        enableLiveTracking: enableLiveTracking ?? this.enableLiveTracking,
        keepScreenOn: keepScreenOn ?? this.keepScreenOn,
      );

  Map<String, dynamic> toMap() => {
        'theme_mode': themeMode.index,
        'locale': locale.languageCode,
        'waypoint_interval': waypointIntervalSeconds,
        'min_movement': minMovementMeters,
        'enable_notifications': enableNotifications,
        'enable_live_tracking': enableLiveTracking,
        'keep_screen_on': keepScreenOn,
      };

  factory AppSettings.fromMap(Map<String, dynamic> map) => AppSettings(
        themeMode: ThemeMode.values[map['theme_mode'] as int? ?? 0],
        locale: Locale(map['locale'] as String? ?? 'vi'),
        waypointIntervalSeconds: map['waypoint_interval'] as int? ??
            AppConstants.waypointIntervalSeconds,
        minMovementMeters: (map['min_movement'] as num?)?.toDouble() ??
            AppConstants.minMovementMeters,
        enableNotifications: map['enable_notifications'] as bool? ?? true,
        enableLiveTracking: map['enable_live_tracking'] as bool? ?? true,
        keepScreenOn: map['keep_screen_on'] as bool? ?? true,
      );
}

class SettingsNotifier extends StateNotifier<AppSettings> {
  late Box _box;

  SettingsNotifier() : super(const AppSettings()) {
    _load();
  }

  Future<void> _load() async {
    _box = await Hive.openBox(AppConstants.settingsBox);
    final raw = _box.get('settings');
    if (raw != null) {
      state = AppSettings.fromMap(Map<String, dynamic>.from(raw));
    }
  }

  Future<void> _save() async {
    await _box.put('settings', state.toMap());
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _save();
  }

  Future<void> setLocale(Locale locale) async {
    state = state.copyWith(locale: locale);
    await _save();
  }

  Future<void> setWaypointInterval(int seconds) async {
    state = state.copyWith(waypointIntervalSeconds: seconds);
    await _save();
  }

  Future<void> setMinMovement(double meters) async {
    state = state.copyWith(minMovementMeters: meters);
    await _save();
  }

  Future<void> toggleNotifications() async {
    state = state.copyWith(enableNotifications: !state.enableNotifications);
    await _save();
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier();
});

final themeModeProvider = Provider<ThemeMode>((ref) {
  return ref.watch(settingsProvider).themeMode;
});

final localeProvider = Provider<Locale>((ref) {
  return ref.watch(settingsProvider).locale;
});

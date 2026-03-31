import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rangeguard_vn/core/constants/app_colors.dart';
import 'package:rangeguard_vn/providers/auth_provider.dart';
import 'package:rangeguard_vn/providers/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Cài đặt')),
      body: ListView(
        children: [
          _SectionHeader('Giao diện'),
          ListTile(
            leading: const Icon(Icons.dark_mode_outlined),
            title: const Text('Chế độ tối'),
            trailing: Switch(
              value: settings.themeMode == ThemeMode.dark,
              onChanged: (v) => notifier.setThemeMode(
                  v ? ThemeMode.dark : ThemeMode.light),
              activeColor: AppColors.primary,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('Ngôn ngữ'),
            trailing: DropdownButton<String>(
              value: settings.locale.languageCode,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: 'vi', child: Text('Tiếng Việt')),
                DropdownMenuItem(value: 'en', child: Text('English')),
              ],
              onChanged: (v) {
                if (v != null) notifier.setLocale(Locale(v));
              },
            ),
          ),

          _SectionHeader('Tuần tra & GPS'),
          ListTile(
            leading: const Icon(Icons.timer_outlined),
            title: const Text('Khoảng thời gian lưu GPS'),
            subtitle: Text('${settings.waypointIntervalSeconds} giây'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showIntervalPicker(context, ref, settings),
          ),
          ListTile(
            leading: const Icon(Icons.straighten),
            title: const Text('Khoảng cách tối thiểu di chuyển'),
            subtitle: Text('${settings.minMovementMeters.toStringAsFixed(0)} mét'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showDistancePicker(context, ref, settings),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.screen_lock_landscape_outlined),
            title: const Text('Giữ màn hình sáng khi tuần tra'),
            value: settings.keepScreenOn,
            onChanged: (v) => notifier.setThemeMode(settings.themeMode),
            activeColor: AppColors.primary,
          ),

          _SectionHeader('Thông báo'),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_outlined),
            title: const Text('Bật thông báo'),
            subtitle: const Text('Nhận thông báo lịch và sự kiện'),
            value: settings.enableNotifications,
            onChanged: (v) => notifier.toggleNotifications(),
            activeColor: AppColors.primary,
          ),

          _SectionHeader('Tài khoản'),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Hồ sơ cá nhân'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.key_outlined),
            title: const Text('Đổi mật khẩu'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: AppColors.error),
            title: const Text(
              'Đăng xuất',
              style: TextStyle(color: AppColors.error),
            ),
            onTap: () => _confirmSignOut(context, ref),
          ),

          _SectionHeader('Về ứng dụng'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Phiên bản'),
            trailing: Text('1.0.0', style: TextStyle(color: Colors.grey)),
          ),
          const ListTile(
            leading: Icon(Icons.forest_outlined, color: AppColors.primary),
            title: Text('RangerGuard VN'),
            subtitle: Text('Hệ thống quản lý tuần tra rừng\nDựa trên chuẩn SMART Conservation Tools'),
            isThreeLine: true,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _SectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
          fontSize: 12,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  void _showIntervalPicker(
      BuildContext context, WidgetRef ref, AppSettings settings) {
    final options = [5, 10, 15, 30, 60];
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Khoảng thời gian lưu GPS'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: options
              .map((s) => RadioListTile<int>(
                    value: s,
                    groupValue: settings.waypointIntervalSeconds,
                    title: Text('$s giây'),
                    onChanged: (v) {
                      if (v != null) {
                        ref.read(settingsProvider.notifier).setWaypointInterval(v);
                        Navigator.pop(context);
                      }
                    },
                    activeColor: AppColors.primary,
                  ))
              .toList(),
        ),
      ),
    );
  }

  void _showDistancePicker(
      BuildContext context, WidgetRef ref, AppSettings settings) {
    final options = [5.0, 10.0, 15.0, 20.0, 30.0];
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Khoảng cách tối thiểu'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: options
              .map((d) => RadioListTile<double>(
                    value: d,
                    groupValue: settings.minMovementMeters,
                    title: Text('${d.toStringAsFixed(0)} mét'),
                    onChanged: (v) {
                      if (v != null) {
                        ref.read(settingsProvider.notifier).setMinMovement(v);
                        Navigator.pop(context);
                      }
                    },
                    activeColor: AppColors.primary,
                  ))
              .toList(),
        ),
      ),
    );
  }

  void _confirmSignOut(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có chắc muốn đăng xuất không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Huỷ'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(authNotifierProvider.notifier).signOut();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
  }
}

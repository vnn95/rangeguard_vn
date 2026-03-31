import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rangeguard_vn/core/constants/app_colors.dart';
import 'package:rangeguard_vn/providers/auth_provider.dart';

class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(authNotifierProvider).valueOrNull;

    if (profile == null || !profile.isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Quản trị')),
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'Bạn không có quyền truy cập trang này.',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Quản trị hệ thống')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionHeader('Quản lý người dùng'),
          _AdminCard(
            icon: Icons.people_outline,
            title: 'Tuần tra viên',
            subtitle: 'Thêm, sửa, vô hiệu hóa tài khoản tuần tra viên',
            color: AppColors.primary,
            onTap: () => context.go('/admin/rangers'),
          ),
          _AdminCard(
            icon: Icons.manage_accounts_outlined,
            title: 'Phân quyền',
            subtitle: 'Cấp quyền Admin / Leader / Ranger / Viewer',
            color: AppColors.accent,
            onTap: () => context.go('/admin/rangers'),
          ),

          _SectionHeader('Quản lý dữ liệu'),
          _AdminCard(
            icon: Icons.home_work_outlined,
            title: 'Trạm kiểm lâm',
            subtitle: 'Quản lý các trạm và thông tin liên hệ',
            color: AppColors.secondary,
            onTap: () => context.go('/admin/stations'),
          ),
          _AdminCard(
            icon: Icons.photo_library_outlined,
            title: 'Thư viện ảnh',
            subtitle: 'Duyệt, tra cứu ảnh từ tất cả chuyến tuần tra',
            color: const Color(0xFF6A1B9A),
            onTap: () => context.go('/admin/photos'),
          ),
          _AdminCard(
            icon: Icons.upload_file_outlined,
            title: 'Import dữ liệu hàng loạt',
            subtitle: 'Import nhiều file SMART JSON cùng lúc',
            color: const Color(0xFF00695C),
            onTap: () => context.go('/patrols/import'),
          ),

          _SectionHeader('Hệ thống'),
          _AdminCard(
            icon: Icons.sync_outlined,
            title: 'Đồng bộ dữ liệu',
            subtitle: 'Kiểm tra và xử lý hàng đợi đồng bộ offline',
            color: AppColors.warning,
            onTap: () => _showSyncDialog(context),
          ),
          _AdminCard(
            icon: Icons.bar_chart_outlined,
            title: 'Thống kê hệ thống',
            subtitle: 'Tổng quan toàn bộ dữ liệu trong hệ thống',
            color: AppColors.success,
            onTap: () => context.go('/reports'),
          ),
          _AdminCard(
            icon: Icons.settings_outlined,
            title: 'Cài đặt hệ thống',
            subtitle: 'Cấu hình thông số toàn cục',
            color: Colors.grey,
            onTap: () => context.go('/settings'),
          ),

          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.person_outline, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Đang đăng nhập với quyền Admin',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      Text(
                        profile.fullName,
                        style: const TextStyle(
                            color: AppColors.primary, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showSyncDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Đồng bộ dữ liệu'),
        content: const Text(
            'Tất cả dữ liệu offline đang được đồng bộ lên server...'),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
        child: Text(
          title,
          style: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w700,
            fontSize: 13,
            letterSpacing: 0.5,
          ),
        ),
      );
}

class _AdminCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _AdminCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
        isThreeLine: false,
      ),
    );
  }
}

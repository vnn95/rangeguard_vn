import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:rangeguard_vn/core/constants/app_colors.dart';

/// Hub for all system category management screens.
/// Add new category entries here as the app grows.
class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Danh mục hệ thống')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionHeader('Tổ chức'),
          _CategoryCard(
            icon: Icons.business_outlined,
            color: const Color(0xFF1565C0),
            title: 'Đơn vị',
            subtitle:
                'Chi cục, Hạt kiểm lâm, phòng ban và các đơn vị trực thuộc',
            onTap: () => context.go('/admin/categories/units'),
          ),
          _CategoryCard(
            icon: Icons.home_work_outlined,
            color: AppColors.primary,
            title: 'Trạm kiểm lâm',
            subtitle: 'Các trạm tuần tra và thông tin liên hệ',
            onTap: () => context.go('/admin/stations'),
          ),

          _SectionHeader('Danh mục nghiệp vụ'),
          _CategoryCard(
            icon: Icons.directions_walk_outlined,
            color: const Color(0xFF2E7D32),
            title: 'Phương tiện tuần tra',
            subtitle: 'Đi bộ, xe máy, thuyền, ...',
            badge: 'Sắp có',
            onTap: null,
          ),
          _CategoryCard(
            icon: Icons.warning_amber_outlined,
            color: AppColors.error,
            title: 'Loại vi phạm',
            subtitle: 'Bẫy thú, khai thác gỗ trái phép, xâm lấn rừng...',
            badge: 'Sắp có',
            onTap: null,
          ),
          _CategoryCard(
            icon: Icons.pets_outlined,
            color: const Color(0xFF6A1B9A),
            title: 'Loài động / thực vật',
            subtitle: 'Danh mục loài quan sát trong tuần tra',
            badge: 'Sắp có',
            onTap: null,
          ),
          _CategoryCard(
            icon: Icons.assignment_outlined,
            color: AppColors.accent,
            title: 'Nhiệm vụ tuần tra',
            subtitle: 'Mẫu nhiệm vụ mặc định cho lịch tuần tra',
            badge: 'Sắp có',
            onTap: null,
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
        padding: const EdgeInsets.fromLTRB(0, 12, 0, 8),
        child: Text(
          title.toUpperCase(),
          style: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w700,
            fontSize: 11,
            letterSpacing: 1.0,
          ),
        ),
      );
}

class _CategoryCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String? badge;
  final VoidCallback? onTap;

  const _CategoryCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.badge,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        enabled: enabled,
        onTap: onTap,
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: enabled
                ? color.withValues(alpha: 0.1)
                : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon,
              color: enabled ? color : Colors.grey, size: 22),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: enabled ? null : Colors.grey,
                ),
              ),
            ),
            if (badge != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badge!,
                  style: const TextStyle(
                      fontSize: 10,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500),
                ),
              ),
          ],
        ),
        subtitle: Text(subtitle,
            style: TextStyle(
                fontSize: 12,
                color: enabled ? null : Colors.grey)),
        trailing: enabled
            ? Icon(Icons.chevron_right, color: Colors.grey[400])
            : null,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rangeguard_vn/core/constants/app_colors.dart';
import 'package:rangeguard_vn/models/user_model.dart';
import 'package:rangeguard_vn/providers/auth_provider.dart';
import 'package:rangeguard_vn/core/constants/app_constants.dart';
import 'package:rangeguard_vn/widgets/common/app_loading.dart';

final allRangersProvider = FutureProvider<List<UserProfile>>((ref) async {
  final repo = ref.watch(authRepositoryProvider);
  return repo.getAllRangers();
});

class RangerManagementScreen extends ConsumerStatefulWidget {
  const RangerManagementScreen({super.key});

  @override
  ConsumerState<RangerManagementScreen> createState() =>
      _RangerManagementScreenState();
}

class _RangerManagementScreenState
    extends ConsumerState<RangerManagementScreen> {
  String _searchQuery = '';
  String? _roleFilter;

  @override
  Widget build(BuildContext context) {
    final rangersAsync = ref.watch(allRangersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý tuần tra viên'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showRoleFilter(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Tìm theo tên, mã nhân viên...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
              ),
              onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
            ),
          ),

          // Role filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildRoleChip(null, 'Tất cả'),
                _buildRoleChip(AppConstants.roleAdmin, 'Admin'),
                _buildRoleChip(AppConstants.roleLeader, 'Trưởng đội'),
                _buildRoleChip(AppConstants.roleRanger, 'Tuần tra viên'),
                _buildRoleChip(AppConstants.roleViewer, 'Xem báo cáo'),
              ],
            ),
          ),

          // List
          Expanded(
            child: rangersAsync.when(
              loading: () => const AppLoading(message: 'Đang tải...'),
              error: (e, _) => AppError(message: e.toString()),
              data: (rangers) {
                final filtered = rangers.where((r) {
                  final matchSearch = _searchQuery.isEmpty ||
                      r.fullName.toLowerCase().contains(_searchQuery) ||
                      r.employeeId.toLowerCase().contains(_searchQuery) ||
                      r.unit.toLowerCase().contains(_searchQuery);
                  final matchRole =
                      _roleFilter == null || r.role == _roleFilter;
                  return matchSearch && matchRole;
                }).toList();

                if (filtered.isEmpty) {
                  return const AppEmpty(
                    message: 'Không tìm thấy tuần tra viên',
                    icon: Icons.person_search,
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(allRangersProvider),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) => _RangerCard(
                      ranger: filtered[i],
                      onEdit: () => _showEditDialog(filtered[i]),
                      onToggleActive: () => _toggleActive(filtered[i]),
                      onChangeRole: () => _showRoleDialog(filtered[i]),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(),
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('Thêm tuần tra viên'),
      ),
    );
  }

  Widget _buildRoleChip(String? role, String label) {
    final selected = _roleFilter == role;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _roleFilter = role),
        selectedColor: AppColors.primaryContainer,
        labelStyle: TextStyle(
          color: selected ? AppColors.primary : Colors.grey,
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          fontSize: 12,
        ),
      ),
    );
  }

  void _showRoleFilter() {}

  Future<void> _toggleActive(UserProfile ranger) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(ranger.isActive ? 'Vô hiệu hóa tài khoản' : 'Kích hoạt tài khoản'),
        content: Text(
          ranger.isActive
              ? '${ranger.fullName} sẽ không thể đăng nhập hệ thống.'
              : 'Kích hoạt lại tài khoản ${ranger.fullName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Huỷ'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: ranger.isActive ? AppColors.error : AppColors.success,
            ),
            child: Text(ranger.isActive ? 'Vô hiệu hóa' : 'Kích hoạt'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref
          .read(authRepositoryProvider)
          .toggleRangerActive(ranger.id, !ranger.isActive);
      ref.invalidate(allRangersProvider);
    }
  }

  Future<void> _showRoleDialog(UserProfile ranger) async {
    String selectedRole = ranger.role;
    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text('Phân quyền - ${ranger.fullName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppConstants.roleAdmin,
              AppConstants.roleLeader,
              AppConstants.roleRanger,
              AppConstants.roleViewer,
            ].map((role) {
              final label = {
                AppConstants.roleAdmin: 'Quản trị viên',
                AppConstants.roleLeader: 'Trưởng đội tuần tra',
                AppConstants.roleRanger: 'Tuần tra viên',
                AppConstants.roleViewer: 'Xem báo cáo',
              }[role]!;
              return RadioListTile<String>(
                value: role,
                groupValue: selectedRole,
                title: Text(label),
                onChanged: (v) => setState(() => selectedRole = v!),
                activeColor: AppColors.primary,
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Huỷ'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final updated = ranger.copyWith(role: selectedRole);
                await ref.read(authRepositoryProvider).updateProfile(updated);
                ref.invalidate(allRangersProvider);
              },
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditDialog(UserProfile ranger) async {
    final nameCtrl = TextEditingController(text: ranger.fullName);
    final empIdCtrl = TextEditingController(text: ranger.employeeId);
    final unitCtrl = TextEditingController(text: ranger.unit);
    final phoneCtrl = TextEditingController(text: ranger.phone ?? '');

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Chỉnh sửa thông tin'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Họ và tên'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: empIdCtrl,
                decoration: const InputDecoration(labelText: 'Mã nhân viên'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: unitCtrl,
                decoration: const InputDecoration(labelText: 'Đơn vị'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Điện thoại'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Huỷ'),
          ),
          ElevatedButton(
            onPressed: () async {
              final updated = ranger.copyWith(
                fullName: nameCtrl.text.trim(),
                employeeId: empIdCtrl.text.trim(),
                unit: unitCtrl.text.trim(),
                phone: phoneCtrl.text.trim().isEmpty
                    ? null
                    : phoneCtrl.text.trim(),
              );
              await ref.read(authRepositoryProvider).updateProfile(updated);
              ref.invalidate(allRangersProvider);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddDialog() async {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final empIdCtrl = TextEditingController();
    final unitCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    String role = AppConstants.roleRanger;
    bool obscure = true;

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('Thêm tuần tra viên'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Họ và tên *',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (v) =>
                        v?.trim().isEmpty == true ? 'Bắt buộc' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: empIdCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Mã nhân viên *',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                    validator: (v) =>
                        v?.trim().isEmpty == true ? 'Bắt buộc' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: unitCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Đơn vị *',
                      prefixIcon: Icon(Icons.business_outlined),
                    ),
                    validator: (v) =>
                        v?.trim().isEmpty == true ? 'Bắt buộc' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Số điện thoại',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: role,
                    decoration: const InputDecoration(
                      labelText: 'Vai trò',
                      prefixIcon: Icon(Icons.manage_accounts_outlined),
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: AppConstants.roleRanger,
                          child: Text('Tuần tra viên')),
                      DropdownMenuItem(
                          value: AppConstants.roleLeader,
                          child: Text('Trưởng đội')),
                      DropdownMenuItem(
                          value: AppConstants.roleViewer,
                          child: Text('Xem báo cáo')),
                    ],
                    onChanged: (v) => setDlgState(() => role = v!),
                  ),
                  const Divider(height: 24),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Tài khoản đăng nhập',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email *',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (v) {
                      if (v?.trim().isEmpty == true) return 'Bắt buộc';
                      if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v!.trim())) {
                        return 'Email không hợp lệ';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: passwordCtrl,
                    obscureText: obscure,
                    decoration: InputDecoration(
                      labelText: 'Mật khẩu * (ít nhất 6 ký tự)',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                            obscure ? Icons.visibility_off : Icons.visibility),
                        onPressed: () =>
                            setDlgState(() => obscure = !obscure),
                      ),
                    ),
                    validator: (v) {
                      if (v?.isEmpty == true) return 'Bắt buộc';
                      if ((v?.length ?? 0) < 6) return 'Ít nhất 6 ký tự';
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Huỷ'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                try {
                  await ref.read(authRepositoryProvider).createRanger(
                        email: emailCtrl.text.trim(),
                        password: passwordCtrl.text,
                        fullName: nameCtrl.text.trim(),
                        employeeId: empIdCtrl.text.trim(),
                        unit: unitCtrl.text.trim(),
                        role: role,
                        phone: phoneCtrl.text.trim().isEmpty
                            ? null
                            : phoneCtrl.text.trim(),
                      );
                  ref.invalidate(allRangersProvider);
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                        content: Text('Đã thêm tuần tra viên thành công'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: Text('Lỗi: $e'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                }
              },
              child: const Text('Thêm'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RangerCard extends StatelessWidget {
  final UserProfile ranger;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;
  final VoidCallback onChangeRole;

  const _RangerCard({
    required this.ranger,
    required this.onEdit,
    required this.onToggleActive,
    required this.onChangeRole,
  });

  @override
  Widget build(BuildContext context) {
    final roleColor = _roleColor(ranger.role);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Avatar
            Stack(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: roleColor.withValues(alpha: 0.1),
                  backgroundImage: ranger.avatarUrl != null
                      ? NetworkImage(ranger.avatarUrl!)
                      : null,
                  child: ranger.avatarUrl == null
                      ? Text(
                          ranger.fullName.isNotEmpty
                              ? ranger.fullName[0].toUpperCase()
                              : 'R',
                          style: TextStyle(
                            color: roleColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        )
                      : null,
                ),
                if (!ranger.isActive)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: const BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.block,
                          size: 10, color: Colors.white),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          ranger.fullName,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: ranger.isActive ? null : Colors.grey,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: roleColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          ranger.roleLabel,
                          style: TextStyle(
                            color: roleColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${ranger.employeeId} · ${ranger.unit}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  if (ranger.phone != null)
                    Text(
                      ranger.phone!,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                ],
              ),
            ),

            // Actions
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 20, color: Colors.grey),
              onSelected: (val) {
                if (val == 'edit') onEdit();
                if (val == 'role') onChangeRole();
                if (val == 'toggle') onToggleActive();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    dense: true,
                    leading: Icon(Icons.edit_outlined),
                    title: Text('Chỉnh sửa'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'role',
                  child: ListTile(
                    dense: true,
                    leading: Icon(Icons.manage_accounts_outlined),
                    title: Text('Phân quyền'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: 'toggle',
                  child: ListTile(
                    dense: true,
                    leading: Icon(
                      ranger.isActive ? Icons.block : Icons.check_circle_outline,
                      color: ranger.isActive ? AppColors.error : AppColors.success,
                    ),
                    title: Text(
                      ranger.isActive ? 'Vô hiệu hóa' : 'Kích hoạt',
                      style: TextStyle(
                        color: ranger.isActive
                            ? AppColors.error
                            : AppColors.success,
                      ),
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _roleColor(String role) {
    switch (role) {
      case AppConstants.roleAdmin:
        return const Color(0xFF6A1B9A);
      case AppConstants.roleLeader:
        return AppColors.accent;
      case AppConstants.roleRanger:
        return AppColors.primary;
      default:
        return Colors.grey;
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rangeguard_vn/core/constants/app_colors.dart';
import 'package:rangeguard_vn/core/supabase/supabase_config.dart';

// ── Model ────────────────────────────────────────────────────────────────────

class Station {
  final String id;
  final String name;
  final String? code;
  final String? province;
  final String? district;
  final String? address;
  final String? phone;
  final String? managerId;
  final String? managerName; // joined from profiles
  final bool isActive;
  final DateTime createdAt;

  const Station({
    required this.id,
    required this.name,
    this.code,
    this.province,
    this.district,
    this.address,
    this.phone,
    this.managerId,
    this.managerName,
    required this.isActive,
    required this.createdAt,
  });

  factory Station.fromMap(Map<String, dynamic> map) => Station(
        id: map['id'] as String,
        name: map['name'] as String,
        code: map['code'] as String?,
        province: map['province'] as String?,
        district: map['district'] as String?,
        address: map['address'] as String?,
        phone: map['phone'] as String?,
        managerId: map['manager_id'] as String?,
        managerName: map['manager_name'] as String?,
        isActive: map['is_active'] as bool? ?? true,
        createdAt: DateTime.parse(
            map['created_at'] as String? ?? DateTime.now().toIso8601String()),
      );

  Map<String, dynamic> toInsertMap() => {
        'name': name,
        'code': code,
        'province': province,
        'district': district,
        'address': address,
        'phone': phone,
        'manager_id': managerId,
        'is_active': isActive,
      };
}

// ── Provider ─────────────────────────────────────────────────────────────────

final stationsProvider = FutureProvider<List<Station>>((ref) async {
  final data = await SupabaseConfig.client
      .from('stations')
      .select('*, profiles!manager_id(full_name)')
      .order('name');

  return data.map<Station>((e) {
    final profileData = e['profiles'] as Map<String, dynamic>?;
    return Station.fromMap({
      ...e,
      'manager_name': profileData?['full_name'],
    });
  }).toList();
});

// ── Screen ────────────────────────────────────────────────────────────────────

class StationManagementScreen extends ConsumerStatefulWidget {
  const StationManagementScreen({super.key});

  @override
  ConsumerState<StationManagementScreen> createState() =>
      _StationManagementScreenState();
}

class _StationManagementScreenState
    extends ConsumerState<StationManagementScreen> {
  String _search = '';
  bool _showInactive = false;

  @override
  Widget build(BuildContext context) {
    final stationsAsync = ref.watch(stationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trạm kiểm lâm'),
        actions: [
          IconButton(
            icon: Icon(
              _showInactive ? Icons.visibility : Icons.visibility_off_outlined,
              color: _showInactive ? AppColors.primary : null,
            ),
            tooltip: _showInactive ? 'Ẩn trạm không hoạt động' : 'Hiện tất cả',
            onPressed: () => setState(() => _showInactive = !_showInactive),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showStationDialog(context, null),
        icon: const Icon(Icons.add),
        label: const Text('Thêm trạm'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Tìm kiếm trạm...',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _search = v.toLowerCase()),
            ),
          ),
          Expanded(
            child: stationsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        color: AppColors.error, size: 48),
                    const SizedBox(height: 8),
                    Text('Lỗi: $e',
                        style: const TextStyle(color: AppColors.error)),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(stationsProvider),
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
              data: (stations) {
                final filtered = stations.where((s) {
                  if (!_showInactive && !s.isActive) return false;
                  if (_search.isEmpty) return true;
                  return s.name.toLowerCase().contains(_search) ||
                      (s.code?.toLowerCase().contains(_search) ?? false) ||
                      (s.province?.toLowerCase().contains(_search) ?? false) ||
                      (s.district?.toLowerCase().contains(_search) ?? false);
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.home_work_outlined,
                            size: 64, color: Colors.grey),
                        SizedBox(height: 12),
                        Text('Không có trạm nào',
                            style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) =>
                      _StationCard(station: filtered[i], onAction: () {
                    ref.invalidate(stationsProvider);
                  }, onEdit: () => _showStationDialog(context, filtered[i])),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showStationDialog(
      BuildContext context, Station? existing) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => _StationDialog(station: existing),
    );
    if (result == true) ref.invalidate(stationsProvider);
  }
}

// ── Station Card ──────────────────────────────────────────────────────────────

class _StationCard extends StatelessWidget {
  final Station station;
  final VoidCallback onAction;
  final VoidCallback onEdit;

  const _StationCard({
    required this.station,
    required this.onAction,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: station.isActive
                ? AppColors.primaryContainer
                : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.home_work_outlined,
            color: station.isActive ? AppColors.primary : Colors.grey,
            size: 24,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                station.name,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: station.isActive ? null : Colors.grey,
                ),
              ),
            ),
            if (station.code != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  station.code!,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (!station.isActive)
              Container(
                margin: const EdgeInsets.only(left: 4),
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Ngừng HĐ',
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (station.province != null || station.district != null)
              Text(
                [station.district, station.province]
                    .where((s) => s != null)
                    .join(', '),
                style: const TextStyle(fontSize: 12),
              ),
            if (station.managerName != null)
              Row(
                children: [
                  const Icon(Icons.person_outline,
                      size: 12, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    station.managerName!,
                    style:
                        const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            if (station.phone != null)
              Row(
                children: [
                  const Icon(Icons.phone_outlined,
                      size: 12, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    station.phone!,
                    style:
                        const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
          ],
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          onSelected: (action) => _handleAction(context, action),
          itemBuilder: (_) => [
            const PopupMenuItem(
                value: 'edit',
                child: Row(children: [
                  Icon(Icons.edit_outlined, size: 18),
                  SizedBox(width: 8),
                  Text('Chỉnh sửa'),
                ])),
            PopupMenuItem(
                value: 'toggle',
                child: Row(children: [
                  Icon(
                    station.isActive
                        ? Icons.pause_circle_outline
                        : Icons.play_circle_outline,
                    size: 18,
                    color: station.isActive ? AppColors.warning : AppColors.success,
                  ),
                  const SizedBox(width: 8),
                  Text(station.isActive ? 'Ngừng hoạt động' : 'Kích hoạt lại'),
                ])),
          ],
        ),
      ),
    );
  }

  Future<void> _handleAction(BuildContext context, String action) async {
    if (action == 'edit') {
      onEdit();
      return;
    }
    if (action == 'toggle') {
      try {
        await SupabaseConfig.client
            .from('stations')
            .update({'is_active': !station.isActive}).eq('id', station.id);
        onAction();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Lỗi: $e'),
                backgroundColor: AppColors.error),
          );
        }
      }
    }
  }
}

// ── Add/Edit Dialog ──────────────────────────────────────────────────────────

class _StationDialog extends StatefulWidget {
  final Station? station;
  const _StationDialog({this.station});

  @override
  State<_StationDialog> createState() => _StationDialogState();
}

class _StationDialogState extends State<_StationDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _code;
  late final TextEditingController _province;
  late final TextEditingController _district;
  late final TextEditingController _address;
  late final TextEditingController _phone;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final s = widget.station;
    _name = TextEditingController(text: s?.name ?? '');
    _code = TextEditingController(text: s?.code ?? '');
    _province = TextEditingController(text: s?.province ?? '');
    _district = TextEditingController(text: s?.district ?? '');
    _address = TextEditingController(text: s?.address ?? '');
    _phone = TextEditingController(text: s?.phone ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _province.dispose();
    _district.dispose();
    _address.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final map = {
      'name': _name.text.trim(),
      'code': _code.text.trim().isEmpty ? null : _code.text.trim(),
      'province': _province.text.trim().isEmpty ? null : _province.text.trim(),
      'district': _district.text.trim().isEmpty ? null : _district.text.trim(),
      'address': _address.text.trim().isEmpty ? null : _address.text.trim(),
      'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
    };

    try {
      if (widget.station == null) {
        await SupabaseConfig.client.from('stations').insert(map);
      } else {
        await SupabaseConfig.client
            .from('stations')
            .update(map)
            .eq('id', widget.station!.id);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Lỗi: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.station != null;
    return AlertDialog(
      title: Text(isEdit ? 'Chỉnh sửa trạm' : 'Thêm trạm mới'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(
                    labelText: 'Tên trạm *',
                    prefixIcon: Icon(Icons.home_work_outlined),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Bắt buộc' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _code,
                  decoration: const InputDecoration(
                    labelText: 'Mã trạm',
                    prefixIcon: Icon(Icons.tag),
                    hintText: 'VD: TKL-01',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _province,
                        decoration: const InputDecoration(
                          labelText: 'Tỉnh / Thành phố',
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _district,
                        decoration: const InputDecoration(
                          labelText: 'Huyện / Xã',
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _address,
                  decoration: const InputDecoration(
                    labelText: 'Địa chỉ',
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Số điện thoại',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context, false),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(isEdit ? 'Lưu' : 'Thêm'),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rangeguard_vn/core/constants/app_colors.dart';
import 'package:rangeguard_vn/core/supabase/supabase_config.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

enum UnitType {
  department('department', 'Chi cục / Sở'),
  division('division', 'Hạt / Phòng ban'),
  unit('unit', 'Đơn vị cơ sở'),
  other('other', 'Khác');

  final String value;
  final String label;
  const UnitType(this.value, this.label);

  static UnitType fromValue(String v) =>
      UnitType.values.firstWhere((e) => e.value == v, orElse: () => UnitType.unit);
}

class OrgUnit {
  final String id;
  final String name;
  final String? code;
  final UnitType unitType;
  final String? province;
  final String? district;
  final String? commune;
  final String? address;
  final String? phone;
  final String? fax;
  final String? email;
  final String? website;
  final String? contactPerson;
  final String? contactPhone;
  final String? contactEmail;
  final String? parentId;
  final String? parentName; // joined
  final String? notes;
  final bool isActive;
  final DateTime createdAt;

  const OrgUnit({
    required this.id,
    required this.name,
    this.code,
    required this.unitType,
    this.province,
    this.district,
    this.commune,
    this.address,
    this.phone,
    this.fax,
    this.email,
    this.website,
    this.contactPerson,
    this.contactPhone,
    this.contactEmail,
    this.parentId,
    this.parentName,
    this.notes,
    required this.isActive,
    required this.createdAt,
  });

  factory OrgUnit.fromMap(Map<String, dynamic> map) => OrgUnit(
        id: map['id'] as String,
        name: map['name'] as String,
        code: map['code'] as String?,
        unitType: UnitType.fromValue(map['unit_type'] as String? ?? 'unit'),
        province: map['province'] as String?,
        district: map['district'] as String?,
        commune: map['commune'] as String?,
        address: map['address'] as String?,
        phone: map['phone'] as String?,
        fax: map['fax'] as String?,
        email: map['email'] as String?,
        website: map['website'] as String?,
        contactPerson: map['contact_person'] as String?,
        contactPhone: map['contact_phone'] as String?,
        contactEmail: map['contact_email'] as String?,
        parentId: map['parent_id'] as String?,
        parentName: map['parent_name'] as String?,
        notes: map['notes'] as String?,
        isActive: map['is_active'] as bool? ?? true,
        createdAt: DateTime.parse(
            map['created_at'] as String? ?? DateTime.now().toIso8601String()),
      );
}

// ── Providers ─────────────────────────────────────────────────────────────────

final unitsProvider = FutureProvider<List<OrgUnit>>((ref) async {
  final data = await SupabaseConfig.client
      .from('units')
      .select('*, parent:units!parent_id(name)')
      .order('unit_type')
      .order('name');

  return data.map<OrgUnit>((e) {
    final parent = e['parent'] as Map<String, dynamic>?;
    return OrgUnit.fromMap({...e, 'parent_name': parent?['name']});
  }).toList();
});

// ── Screen ────────────────────────────────────────────────────────────────────

class UnitManagementScreen extends ConsumerStatefulWidget {
  const UnitManagementScreen({super.key});

  @override
  ConsumerState<UnitManagementScreen> createState() =>
      _UnitManagementScreenState();
}

class _UnitManagementScreenState extends ConsumerState<UnitManagementScreen> {
  String _search = '';
  UnitType? _typeFilter;
  bool _showInactive = false;

  static const _typeColors = {
    UnitType.department: Color(0xFF1565C0),
    UnitType.division: Color(0xFF2E7D32),
    UnitType.unit: AppColors.primary,
    UnitType.other: Colors.grey,
  };

  @override
  Widget build(BuildContext context) {
    final unitsAsync = ref.watch(unitsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý đơn vị'),
        actions: [
          IconButton(
            icon: Icon(
              _showInactive ? Icons.visibility : Icons.visibility_off_outlined,
              color: _showInactive ? AppColors.primary : null,
            ),
            tooltip: _showInactive ? 'Ẩn không hoạt động' : 'Hiện tất cả',
            onPressed: () => setState(() => _showInactive = !_showInactive),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openDialog(null),
        icon: const Icon(Icons.add),
        label: const Text('Thêm đơn vị'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Search + filter bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Tìm theo tên, mã, tỉnh...',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _search = v.toLowerCase()),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                _FilterChip(
                  label: 'Tất cả',
                  selected: _typeFilter == null,
                  onTap: () => setState(() => _typeFilter = null),
                ),
                for (final t in UnitType.values)
                  _FilterChip(
                    label: t.label,
                    selected: _typeFilter == t,
                    color: _typeColors[t],
                    onTap: () =>
                        setState(() => _typeFilter = _typeFilter == t ? null : t),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          // List
          Expanded(
            child: unitsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorView(
                error: e.toString(),
                onRetry: () => ref.invalidate(unitsProvider),
              ),
              data: (units) {
                final filtered = units.where((u) {
                  if (!_showInactive && !u.isActive) return false;
                  if (_typeFilter != null && u.unitType != _typeFilter) return false;
                  if (_search.isNotEmpty) {
                    final q = _search;
                    return u.name.toLowerCase().contains(q) ||
                        (u.code?.toLowerCase().contains(q) ?? false) ||
                        (u.province?.toLowerCase().contains(q) ?? false) ||
                        (u.district?.toLowerCase().contains(q) ?? false) ||
                        (u.contactPerson?.toLowerCase().contains(q) ?? false);
                  }
                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.business_outlined,
                            size: 64, color: Colors.grey),
                        SizedBox(height: 12),
                        Text('Không có đơn vị nào',
                            style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => _UnitCard(
                    unit: filtered[i],
                    color: _typeColors[filtered[i].unitType] ?? AppColors.primary,
                    onEdit: () => _openDialog(filtered[i]),
                    onToggle: () => _toggleActive(filtered[i]),
                    onViewDetail: () => _showDetail(filtered[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openDialog(OrgUnit? unit) async {
    final unitsAsync = ref.read(unitsProvider);
    final allUnits = unitsAsync.valueOrNull ?? [];
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => _UnitDialog(unit: unit, allUnits: allUnits),
    );
    if (result == true) ref.invalidate(unitsProvider);
  }

  Future<void> _toggleActive(OrgUnit unit) async {
    try {
      await SupabaseConfig.client
          .from('units')
          .update({'is_active': !unit.isActive}).eq('id', unit.id);
      ref.invalidate(unitsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Lỗi: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _showDetail(OrgUnit unit) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _UnitDetailSheet(unit: unit),
    );
  }
}

// ── Unit Card ─────────────────────────────────────────────────────────────────

class _UnitCard extends StatelessWidget {
  final OrgUnit unit;
  final Color color;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onViewDetail;

  const _UnitCard({
    required this.unit,
    required this.color,
    required this.onEdit,
    required this.onToggle,
    required this.onViewDetail,
  });

  @override
  Widget build(BuildContext context) {
    final locationParts = [unit.commune, unit.district, unit.province]
        .where((s) => s != null && s.isNotEmpty)
        .join(', ');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onViewDetail,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: unit.isActive
                      ? color.withValues(alpha: 0.12)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _iconForType(unit.unitType),
                  color: unit.isActive ? color : Colors.grey,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            unit.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: unit.isActive ? null : Colors.grey,
                            ),
                          ),
                        ),
                        if (unit.code != null)
                          _Badge(unit.code!, color: color),
                        if (!unit.isActive)
                          const _Badge('Ngừng HĐ', color: Colors.grey),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      unit.unitType.label,
                      style: TextStyle(
                          fontSize: 11, color: color, fontWeight: FontWeight.w500),
                    ),
                    if (locationParts.isNotEmpty)
                      Text(locationParts,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey)),
                    if (unit.contactPerson != null)
                      Row(
                        children: [
                          const Icon(Icons.person_outline,
                              size: 12, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(unit.contactPerson!,
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey)),
                          if (unit.contactPhone != null) ...[
                            const Text(' · ',
                                style: TextStyle(color: Colors.grey)),
                            Text(unit.contactPhone!,
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.grey)),
                          ],
                        ],
                      ),
                    if (unit.parentName != null)
                      Row(
                        children: [
                          const Icon(Icons.account_tree_outlined,
                              size: 12, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text('Trực thuộc: ${unit.parentName}',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                  fontStyle: FontStyle.italic)),
                        ],
                      ),
                  ],
                ),
              ),
              // Menu
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'edit') onEdit();
                  if (v == 'toggle') onToggle();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(children: [
                      Icon(Icons.edit_outlined, size: 18),
                      SizedBox(width: 8),
                      Text('Chỉnh sửa'),
                    ]),
                  ),
                  PopupMenuItem(
                    value: 'toggle',
                    child: Row(children: [
                      Icon(
                        unit.isActive
                            ? Icons.pause_circle_outline
                            : Icons.play_circle_outline,
                        size: 18,
                        color: unit.isActive
                            ? AppColors.warning
                            : AppColors.success,
                      ),
                      const SizedBox(width: 8),
                      Text(unit.isActive ? 'Ngừng hoạt động' : 'Kích hoạt'),
                    ]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconForType(UnitType t) {
    switch (t) {
      case UnitType.department:
        return Icons.account_balance_outlined;
      case UnitType.division:
        return Icons.business_outlined;
      case UnitType.unit:
        return Icons.corporate_fare_outlined;
      case UnitType.other:
        return Icons.domain_outlined;
    }
  }
}

// ── Detail Bottom Sheet ───────────────────────────────────────────────────────

class _UnitDetailSheet extends StatelessWidget {
  final OrgUnit unit;
  const _UnitDetailSheet({required this.unit});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, ctrl) => ListView(
        controller: ctrl,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(unit.name,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w700)),
          if (unit.code != null)
            Text(unit.code!,
                style: const TextStyle(color: AppColors.primary, fontSize: 13)),
          const SizedBox(height: 4),
          Text(unit.unitType.label,
              style: const TextStyle(color: Colors.grey, fontSize: 13)),
          const Divider(height: 24),
          _DetailSection('Địa điểm', [
            if (unit.commune != null) _DetailRow(Icons.place_outlined, 'Xã/Phường', unit.commune!),
            if (unit.district != null) _DetailRow(Icons.map_outlined, 'Huyện/Quận', unit.district!),
            if (unit.province != null) _DetailRow(Icons.location_city_outlined, 'Tỉnh/TP', unit.province!),
            if (unit.address != null) _DetailRow(Icons.home_outlined, 'Địa chỉ', unit.address!),
          ]),
          _DetailSection('Liên hệ', [
            if (unit.phone != null) _DetailRow(Icons.phone_outlined, 'Điện thoại', unit.phone!),
            if (unit.fax != null) _DetailRow(Icons.fax_outlined, 'Fax', unit.fax!),
            if (unit.email != null) _DetailRow(Icons.email_outlined, 'Email', unit.email!),
            if (unit.website != null) _DetailRow(Icons.language_outlined, 'Website', unit.website!),
          ]),
          _DetailSection('Đầu mối liên hệ', [
            if (unit.contactPerson != null) _DetailRow(Icons.person_outline, 'Người liên hệ', unit.contactPerson!),
            if (unit.contactPhone != null) _DetailRow(Icons.phone_outlined, 'Điện thoại', unit.contactPhone!),
            if (unit.contactEmail != null) _DetailRow(Icons.email_outlined, 'Email', unit.contactEmail!),
          ]),
          if (unit.parentName != null)
            _DetailSection('Cơ cấu', [
              _DetailRow(Icons.account_tree_outlined, 'Trực thuộc', unit.parentName!),
            ]),
          if (unit.notes != null && unit.notes!.isNotEmpty)
            _DetailSection('Ghi chú', [
              Padding(
                padding: const EdgeInsets.only(left: 8, top: 4),
                child: Text(unit.notes!,
                    style: const TextStyle(fontSize: 13, color: Colors.grey)),
              ),
            ]),
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _DetailSection(this.title, this.children);

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  letterSpacing: 0.5)),
          const SizedBox(height: 6),
          ...children,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          SizedBox(
            width: 110,
            child: Text(label,
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

// ── Add / Edit Dialog ─────────────────────────────────────────────────────────

class _UnitDialog extends StatefulWidget {
  final OrgUnit? unit;
  final List<OrgUnit> allUnits;
  const _UnitDialog({this.unit, required this.allUnits});

  @override
  State<_UnitDialog> createState() => _UnitDialogState();
}

class _UnitDialogState extends State<_UnitDialog>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late TabController _tabs;

  // Tab 0 – Thông tin chung
  late final TextEditingController _name;
  late final TextEditingController _code;
  UnitType _type = UnitType.unit;
  String? _parentId;

  // Tab 1 – Địa chỉ
  late final TextEditingController _province;
  late final TextEditingController _district;
  late final TextEditingController _commune;
  late final TextEditingController _address;

  // Tab 2 – Liên hệ
  late final TextEditingController _phone;
  late final TextEditingController _fax;
  late final TextEditingController _email;
  late final TextEditingController _website;
  late final TextEditingController _contactPerson;
  late final TextEditingController _contactPhone;
  late final TextEditingController _contactEmail;

  // Tab 3 – Ghi chú
  late final TextEditingController _notes;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    final u = widget.unit;
    _name = TextEditingController(text: u?.name ?? '');
    _code = TextEditingController(text: u?.code ?? '');
    _type = u?.unitType ?? UnitType.unit;
    _parentId = u?.parentId;
    _province = TextEditingController(text: u?.province ?? '');
    _district = TextEditingController(text: u?.district ?? '');
    _commune = TextEditingController(text: u?.commune ?? '');
    _address = TextEditingController(text: u?.address ?? '');
    _phone = TextEditingController(text: u?.phone ?? '');
    _fax = TextEditingController(text: u?.fax ?? '');
    _email = TextEditingController(text: u?.email ?? '');
    _website = TextEditingController(text: u?.website ?? '');
    _contactPerson = TextEditingController(text: u?.contactPerson ?? '');
    _contactPhone = TextEditingController(text: u?.contactPhone ?? '');
    _contactEmail = TextEditingController(text: u?.contactEmail ?? '');
    _notes = TextEditingController(text: u?.notes ?? '');
  }

  @override
  void dispose() {
    _tabs.dispose();
    for (final c in [
      _name, _code, _province, _district, _commune, _address,
      _phone, _fax, _email, _website,
      _contactPerson, _contactPhone, _contactEmail, _notes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _nonEmpty(TextEditingController c) {
    final v = c.text.trim();
    return v.isEmpty ? null : v;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      _tabs.animateTo(0);
      return;
    }
    setState(() => _isLoading = true);

    final map = {
      'name': _name.text.trim(),
      'code': _nonEmpty(_code),
      'unit_type': _type.value,
      'parent_id': _parentId,
      'province': _nonEmpty(_province),
      'district': _nonEmpty(_district),
      'commune': _nonEmpty(_commune),
      'address': _nonEmpty(_address),
      'phone': _nonEmpty(_phone),
      'fax': _nonEmpty(_fax),
      'email': _nonEmpty(_email),
      'website': _nonEmpty(_website),
      'contact_person': _nonEmpty(_contactPerson),
      'contact_phone': _nonEmpty(_contactPhone),
      'contact_email': _nonEmpty(_contactEmail),
      'notes': _nonEmpty(_notes),
    };

    try {
      if (widget.unit == null) {
        await SupabaseConfig.client.from('units').insert(map);
      } else {
        await SupabaseConfig.client
            .from('units')
            .update(map)
            .eq('id', widget.unit!.id);
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
    final isEdit = widget.unit != null;
    // Exclude self from parent choices to avoid circular reference
    final parentChoices = widget.allUnits
        .where((u) => u.isActive && u.id != widget.unit?.id)
        .toList();

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 640),
        child: Column(
          children: [
            // Title
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      isEdit ? 'Chỉnh sửa đơn vị' : 'Thêm đơn vị mới',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context, false),
                  ),
                ],
              ),
            ),
            // Tabs
            TabBar(
              controller: _tabs,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: const [
                Tab(text: 'Thông tin'),
                Tab(text: 'Địa chỉ'),
                Tab(text: 'Liên hệ'),
                Tab(text: 'Ghi chú'),
              ],
            ),
            // Tab content
            Expanded(
              child: Form(
                key: _formKey,
                child: TabBarView(
                  controller: _tabs,
                  children: [
                    // ── Tab 0: Thông tin chung ──────────────────────────
                    _TabPage(children: [
                      TextFormField(
                        controller: _name,
                        decoration: const InputDecoration(
                          labelText: 'Tên đơn vị *',
                          prefixIcon: Icon(Icons.business_outlined),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Bắt buộc nhập tên'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _code,
                        decoration: const InputDecoration(
                          labelText: 'Mã đơn vị',
                          prefixIcon: Icon(Icons.tag),
                          hintText: 'VD: CCKL-01',
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<UnitType>(
                        value: _type,
                        decoration: const InputDecoration(
                          labelText: 'Loại đơn vị',
                          prefixIcon: Icon(Icons.category_outlined),
                        ),
                        items: UnitType.values
                            .map((t) => DropdownMenuItem(
                                value: t, child: Text(t.label)))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _type = v ?? UnitType.unit),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String?>(
                        value: _parentId,
                        decoration: const InputDecoration(
                          labelText: 'Trực thuộc đơn vị',
                          prefixIcon: Icon(Icons.account_tree_outlined),
                        ),
                        items: [
                          const DropdownMenuItem(
                              value: null, child: Text('— Không có —')),
                          ...parentChoices.map((u) => DropdownMenuItem(
                              value: u.id, child: Text(u.name))),
                        ],
                        onChanged: (v) => setState(() => _parentId = v),
                      ),
                    ]),

                    // ── Tab 1: Địa chỉ ─────────────────────────────────
                    _TabPage(children: [
                      TextFormField(
                        controller: _province,
                        decoration: const InputDecoration(
                          labelText: 'Tỉnh / Thành phố',
                          prefixIcon: Icon(Icons.location_city_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _district,
                        decoration: const InputDecoration(
                          labelText: 'Huyện / Quận',
                          prefixIcon: Icon(Icons.map_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _commune,
                        decoration: const InputDecoration(
                          labelText: 'Xã / Phường / Thị trấn',
                          prefixIcon: Icon(Icons.place_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _address,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Địa chỉ chi tiết',
                          prefixIcon: Icon(Icons.home_outlined),
                          alignLabelWithHint: true,
                        ),
                      ),
                    ]),

                    // ── Tab 2: Liên hệ ─────────────────────────────────
                    _TabPage(children: [
                      TextFormField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Số điện thoại',
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _fax,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Số Fax',
                          prefixIcon: Icon(Icons.fax_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email đơn vị',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _website,
                        keyboardType: TextInputType.url,
                        decoration: const InputDecoration(
                          labelText: 'Website',
                          prefixIcon: Icon(Icons.language_outlined),
                        ),
                      ),
                      const Divider(height: 24),
                      const Text('Đầu mối liên hệ',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryDark,
                              fontSize: 13)),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _contactPerson,
                        decoration: const InputDecoration(
                          labelText: 'Họ và tên',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _contactPhone,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Điện thoại',
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _contactEmail,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email cá nhân',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                      ),
                    ]),

                    // ── Tab 3: Ghi chú ─────────────────────────────────
                    _TabPage(children: [
                      TextFormField(
                        controller: _notes,
                        maxLines: 8,
                        decoration: const InputDecoration(
                          labelText: 'Ghi chú',
                          alignLabelWithHint: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
            // Actions
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed:
                        _isLoading ? null : () => Navigator.pop(context, false),
                    child: const Text('Hủy'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _submit,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child:
                                CircularProgressIndicator(strokeWidth: 2))
                        : Icon(isEdit ? Icons.save_outlined : Icons.add),
                    label: Text(isEdit ? 'Lưu thay đổi' : 'Thêm đơn vị'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _TabPage extends StatelessWidget {
  final List<Widget> children;
  const _TabPage({required this.children});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      );
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;
  const _FilterChip(
      {required this.label,
      required this.selected,
      this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label,
            style: TextStyle(
                fontSize: 12,
                color: selected ? Colors.white : c,
                fontWeight: FontWeight.w500)),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: c,
        backgroundColor: c.withValues(alpha: 0.08),
        checkmarkColor: Colors.white,
        side: BorderSide(color: c.withValues(alpha: 0.3)),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge(this.text, {required this.color});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(left: 4),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(text,
            style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.w600)),
      );
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 48),
            const SizedBox(height: 8),
            Text('Lỗi: $error',
                style: const TextStyle(color: AppColors.error),
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: onRetry, child: const Text('Thử lại')),
          ],
        ),
      );
}

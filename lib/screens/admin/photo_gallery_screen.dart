import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rangeguard_vn/core/constants/app_colors.dart';
import 'package:rangeguard_vn/core/utils/date_utils.dart';
import 'package:rangeguard_vn/repositories/photo_repository.dart';
import 'package:rangeguard_vn/widgets/common/app_loading.dart';

final photoGalleryProvider =
    FutureProvider.family<List<PatrolPhoto>, Map<String, dynamic>>(
        (ref, params) async {
  final repo = PhotoRepository();
  return repo.getGallery(
    patrolId: params['patrol_id'] as String?,
    observationType: params['obs_type'] as String?,
    limit: params['limit'] as int? ?? 60,
    offset: params['offset'] as int? ?? 0,
  );
});

class PhotoGalleryScreen extends ConsumerStatefulWidget {
  final String? patrolId;
  const PhotoGalleryScreen({super.key, this.patrolId});

  @override
  ConsumerState<PhotoGalleryScreen> createState() => _PhotoGalleryScreenState();
}

class _PhotoGalleryScreenState extends ConsumerState<PhotoGalleryScreen> {
  String? _obsTypeFilter;
  bool _isGrid = true;

  static const _obsTypes = [
    (null, 'Tất cả'),
    ('Photo', 'Ảnh chụp'),
    ('Animal', 'Động vật'),
    ('Threat', 'Vi phạm'),
  ];

  @override
  Widget build(BuildContext context) {
    final params = {
      'patrol_id': widget.patrolId,
      'obs_type': _obsTypeFilter,
      'limit': 60,
      'offset': 0,
    };
    final photosAsync = ref.watch(photoGalleryProvider(params));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.patrolId != null ? 'Ảnh chuyến tuần tra' : 'Thư viện ảnh'),
        actions: [
          IconButton(
            icon: Icon(_isGrid ? Icons.view_list : Icons.grid_view),
            onPressed: () => setState(() => _isGrid = !_isGrid),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: _obsTypes.map((t) {
                final (value, label) = t;
                final selected = _obsTypeFilter == value;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(label),
                    selected: selected,
                    onSelected: (_) =>
                        setState(() => _obsTypeFilter = value),
                    selectedColor: AppColors.primaryContainer,
                    labelStyle: TextStyle(
                      color: selected ? AppColors.primary : Colors.grey,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                      fontSize: 12,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          Expanded(
            child: photosAsync.when(
              loading: () => const AppLoading(message: 'Đang tải ảnh...'),
              error: (e, _) => AppError(message: e.toString()),
              data: (photos) {
                if (photos.isEmpty) {
                  return const AppEmpty(
                    message: 'Chưa có ảnh nào',
                    icon: Icons.photo_library_outlined,
                  );
                }

                // Stats bar
                return Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      color: AppColors.surfaceVariant,
                      child: Row(
                        children: [
                          const Icon(Icons.photo, size: 16, color: Colors.grey),
                          const SizedBox(width: 6),
                          Text(
                            '${photos.length} ảnh',
                            style: const TextStyle(
                                fontSize: 13, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _isGrid
                          ? _buildGrid(photos)
                          : _buildList(photos),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(List<PatrolPhoto> photos) {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: photos.length,
      itemBuilder: (_, i) => _PhotoGridItem(
        photo: photos[i],
        onTap: () => _showPhotoDetail(photos[i]),
      ),
    );
  }

  Widget _buildList(List<PatrolPhoto> photos) {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: photos.length,
      itemBuilder: (_, i) => _PhotoListItem(
        photo: photos[i],
        onTap: () => _showPhotoDetail(photos[i]),
      ),
    );
  }

  void _showPhotoDetail(PatrolPhoto photo) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (_, ctrl) => SingleChildScrollView(
          controller: ctrl,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Photo
              if (photo.displayUrl != null)
                CachedNetworkImage(
                  imageUrl: photo.displayUrl!,
                  height: 300,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    height: 300,
                    color: AppColors.surfaceVariant,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    height: 300,
                    color: AppColors.surfaceVariant,
                    child: const Icon(Icons.broken_image,
                        size: 64, color: Colors.grey),
                  ),
                )
              else
                Container(
                  height: 200,
                  color: AppColors.surfaceVariant,
                  child: const Center(
                    child: Icon(Icons.image_not_supported,
                        size: 64, color: Colors.grey),
                  ),
                ),

              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Type badge
                    _TypeBadge(photo.observationType),
                    const SizedBox(height: 12),

                    // Info grid
                    if (photo.takenAt != null)
                      _DetailRow(
                        Icons.access_time,
                        'Thời gian chụp',
                        AppDateUtils.formatDateTime(photo.takenAt!),
                      ),
                    if (photo.patrolCode != null)
                      _DetailRow(
                        Icons.hiking,
                        'Chuyến tuần tra',
                        photo.patrolCode!,
                      ),
                    if (photo.leaderName != null)
                      _DetailRow(
                        Icons.person_outline,
                        'Tuần tra viên',
                        photo.leaderName!,
                      ),
                    if (photo.stationName != null)
                      _DetailRow(
                        Icons.home_work_outlined,
                        'Trạm',
                        photo.stationName!,
                      ),
                    if (photo.latitude != null && photo.longitude != null)
                      _DetailRow(
                        Icons.gps_fixed,
                        'Toạ độ',
                        '${photo.latitude!.toStringAsFixed(5)}, ${photo.longitude!.toStringAsFixed(5)}',
                      ),
                    if (photo.notes != null && photo.notes!.isNotEmpty) ...[
                      const Divider(height: 20),
                      Text(
                        'Ghi chú',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        photo.notes!,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoGridItem extends StatelessWidget {
  final PatrolPhoto photo;
  final VoidCallback onTap;

  const _PhotoGridItem({required this.photo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (photo.displayUrl != null)
              CachedNetworkImage(
                imageUrl: photo.displayUrl!,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  color: AppColors.surfaceVariant,
                  child: const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
                errorWidget: (_, __, ___) => Container(
                  color: AppColors.surfaceVariant,
                  child: const Icon(Icons.broken_image, color: Colors.grey),
                ),
              )
            else
              Container(
                color: AppColors.surfaceVariant,
                child: const Icon(Icons.photo, color: Colors.grey),
              ),

            // Type overlay
            Positioned(
              top: 4,
              right: 4,
              child: _TypeBadge(photo.observationType, small: true),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoListItem extends StatelessWidget {
  final PatrolPhoto photo;
  final VoidCallback onTap;

  const _PhotoListItem({required this.photo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 64,
            height: 64,
            child: photo.displayUrl != null
                ? CachedNetworkImage(
                    imageUrl: photo.displayUrl!,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) =>
                        const Icon(Icons.broken_image),
                  )
                : Container(
                    color: AppColors.surfaceVariant,
                    child: const Icon(Icons.photo, color: Colors.grey),
                  ),
          ),
        ),
        title: Text(
          photo.observationType,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (photo.takenAt != null)
              Text(AppDateUtils.formatDateTime(photo.takenAt!),
                  style: const TextStyle(fontSize: 12)),
            if (photo.patrolCode != null)
              Text('Chuyến: ${photo.patrolCode}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        isThreeLine: photo.patrolCode != null,
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final String type;
  final bool small;
  const _TypeBadge(this.type, {this.small = false});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (type) {
      'Threat' => (AppColors.error, 'Vi phạm'),
      'Animal' => (AppColors.warning, 'Động vật'),
      'Photo' => (AppColors.accent, 'Ảnh'),
      _ => (AppColors.primary, type),
    };

    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: small ? 4 : 8, vertical: small ? 2 : 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white,
          fontSize: small ? 9 : 12,
          fontWeight: FontWeight.w600,
        ),
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
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style:
                      const TextStyle(fontSize: 11, color: Colors.grey)),
              Text(value,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }
}

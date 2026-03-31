import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:uuid/uuid.dart';
import 'package:rangeguard_vn/core/constants/app_colors.dart';
import 'package:rangeguard_vn/core/utils/date_utils.dart';
import 'package:rangeguard_vn/models/schedule_model.dart';
import 'package:rangeguard_vn/providers/auth_provider.dart';
import 'package:rangeguard_vn/core/supabase/supabase_config.dart';

// Local schedule provider (simple, no Supabase for now)
final scheduleListProvider =
    StateNotifierProvider<ScheduleNotifier, List<PatrolSchedule>>((ref) {
  return ScheduleNotifier();
});

class ScheduleNotifier extends StateNotifier<List<PatrolSchedule>> {
  ScheduleNotifier() : super([]) {
    _loadFromSupabase();
  }

  Future<void> _loadFromSupabase() async {
    try {
      final data = await SupabaseConfig.client
          .from('schedules')
          .select()
          .order('scheduled_date', ascending: true);
      state = data.map((e) => PatrolSchedule.fromMap(e)).toList();
    } catch (_) {}
  }

  Future<void> addSchedule(PatrolSchedule schedule) async {
    state = [...state, schedule];
    try {
      await SupabaseConfig.client.from('schedules').insert(schedule.toMap());
    } catch (_) {}
  }

  Future<void> deleteSchedule(String id) async {
    state = state.where((s) => s.id != id).toList();
    try {
      await SupabaseConfig.client.from('schedules').delete().eq('id', id);
    } catch (_) {}
  }
}

class ScheduleScreen extends ConsumerStatefulWidget {
  const ScheduleScreen({super.key});

  @override
  ConsumerState<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends ConsumerState<ScheduleScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  List<PatrolSchedule> _getSchedulesForDay(
      List<PatrolSchedule> schedules, DateTime day) {
    return schedules.where((s) => isSameDay(s.scheduledDate, day)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final schedules = ref.watch(scheduleListProvider);
    final daySchedules = _getSchedulesForDay(
      schedules,
      _selectedDay ?? _focusedDay,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch tuần tra'),
      ),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime(2020),
            lastDay: DateTime(2030),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            calendarFormat: _calendarFormat,
            eventLoader: (day) => _getSchedulesForDay(schedules, day),
            onDaySelected: (selected, focused) {
              setState(() {
                _selectedDay = selected;
                _focusedDay = focused;
              });
            },
            onFormatChanged: (format) {
              setState(() => _calendarFormat = format);
            },
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              selectedDecoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              markerDecoration: const BoxDecoration(
                color: AppColors.accent,
                shape: BoxShape.circle,
              ),
            ),
            headerStyle: const HeaderStyle(
              formatButtonVisible: true,
              titleCentered: true,
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: daySchedules.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.event_available,
                            size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        const Text(
                          'Chưa có lịch trong ngày này',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: daySchedules.length,
                    itemBuilder: (_, i) => _ScheduleCard(
                      schedule: daySchedules[i],
                      onDelete: () => ref
                          .read(scheduleListProvider.notifier)
                          .deleteSchedule(daySchedules[i].id),
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Lập lịch'),
      ),
    );
  }

  void _showCreateDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    DateTime selectedDate = _selectedDay ?? DateTime.now();
    TimeOfDay selectedTime = const TimeOfDay(hour: 7, minute: 0);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Tạo lịch tuần tra',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Tiêu đề lịch *',
                    prefixIcon: Icon(Icons.title),
                  ),
                  validator: (v) =>
                      v?.isEmpty == true ? 'Vui lòng nhập tiêu đề' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: descCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Mô tả / Ghi chú',
                    prefixIcon: Icon(Icons.notes),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text(AppDateUtils.formatDate(selectedDate)),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: selectedDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) {
                            setModalState(() => selectedDate = picked);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.access_time, size: 16),
                        label: Text(selectedTime.format(ctx)),
                        onPressed: () async {
                          final picked = await showTimePicker(
                            context: ctx,
                            initialTime: selectedTime,
                          );
                          if (picked != null) {
                            setModalState(() => selectedTime = picked);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    if (!formKey.currentState!.validate()) return;
                    final profile = ref.read(authNotifierProvider).valueOrNull;
                    final schedule = PatrolSchedule(
                      id: const Uuid().v4(),
                      title: titleCtrl.text.trim(),
                      description: descCtrl.text.trim().isEmpty
                          ? null
                          : descCtrl.text.trim(),
                      scheduledDate: selectedDate,
                      startTime: DateTime(
                        selectedDate.year,
                        selectedDate.month,
                        selectedDate.day,
                        selectedTime.hour,
                        selectedTime.minute,
                      ),
                      leaderId: profile?.id ?? '',
                      leaderName: profile?.fullName ?? '',
                      rangerIds: [],
                      rangerNames: [],
                      stationId: '',
                      stationName: '',
                      status: ScheduleStatus.planned,
                      createdBy: profile?.id ?? '',
                      createdAt: DateTime.now(),
                    );
                    ref
                        .read(scheduleListProvider.notifier)
                        .addSchedule(schedule);
                    Navigator.pop(ctx);
                    setState(() => _selectedDay = selectedDate);
                  },
                  child: const Text('Tạo lịch'),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  final PatrolSchedule schedule;
  final VoidCallback onDelete;

  const _ScheduleCard({required this.schedule, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(schedule.status);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.event, color: statusColor),
        ),
        title: Text(
          schedule.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppDateUtils.formatDateTime(schedule.startTime)),
            if (schedule.description != null)
              Text(schedule.description!,
                  style: const TextStyle(fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: AppColors.error),
          onPressed: onDelete,
        ),
        isThreeLine: schedule.description != null,
      ),
    );
  }

  Color _statusColor(ScheduleStatus s) {
    switch (s) {
      case ScheduleStatus.planned:
        return AppColors.patrolScheduled;
      case ScheduleStatus.ongoing:
        return AppColors.patrolActive;
      case ScheduleStatus.completed:
        return AppColors.patrolCompleted;
      case ScheduleStatus.cancelled:
        return AppColors.patrolCancelled;
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/theme/app_theme.dart';
import '../../../../shared/presentation/widgets/primary_button.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/domain/entities/user_role.dart';
import '../providers/scheduling_providers.dart';

Future<void> showCreateShiftSheet(BuildContext context, WidgetRef ref, String clinicId) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _CreateShiftSheet(clinicId: clinicId),
  );
}

class _CreateShiftSheet extends ConsumerStatefulWidget {
  const _CreateShiftSheet({required this.clinicId});

  final String clinicId;

  @override
  ConsumerState<_CreateShiftSheet> createState() => _CreateShiftSheetState();
}

class _CreateShiftSheetState extends ConsumerState<_CreateShiftSheet> {
  UserRole _role = UserRole.pharmacist;
  DateTime _date = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 17, minute: 0);
  String? _staffId;
  final _notesController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  DateTime get _start =>
      DateTime(_date.year, _date.month, _date.day, _startTime.hour, _startTime.minute);
  DateTime get _end => DateTime(_date.year, _date.month, _date.day, _endTime.hour, _endTime.minute);

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 180)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(context: context, initialTime: isStart ? _startTime : _endTime);
    if (picked == null) return;
    setState(() => isStart ? _startTime = picked : _endTime = picked);
  }

  void _suggest(List<AppUser> candidates) {
    if (candidates.isEmpty) return;
    setState(() => _staffId = candidates.first.id);
  }

  Future<void> _save() async {
    if (_staffId == null || !_end.isAfter(_start)) return;
    setState(() => _saving = true);
    await ref.read(schedulingRepositoryProvider).createShift(
          staffId: _staffId!,
          clinicId: widget.clinicId,
          start: _start,
          end: _end,
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        );
    ref.read(schedulingRevisionProvider.notifier).state++;
    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.of(context).pop();
  }

  String _fmtDate(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  String _fmtTime(TimeOfDay t) => t.format(context);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final allStaff = ref
        .watch(schedulingRepositoryProvider)
        .suggestStaff(role: _role, clinicId: widget.clinicId, start: _start, end: _end);
    final hasConflictForSelected =
        _staffId != null && ref.read(schedulingRepositoryProvider).hasConflict(_staffId!, _start, _end);
    // Selected staff might not be in the "available" suggestion list (e.g.
    // picked manually despite a conflict) — still show them as an option.
    final candidates = <AppUser>[...allStaff];

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(color: colors.border, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                Text('Add Shift', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 18),
                Row(
                  children: [
                    for (final role in [UserRole.doctor, UserRole.pharmacist]) ...[
                      Expanded(
                        child: ChoiceChip(
                          label: Text(role.label, style: const TextStyle(fontSize: 12)),
                          selected: _role == role,
                          onSelected: (_) => setState(() {
                            _role = role;
                            _staffId = null;
                          }),
                          selectedColor: colors.clinicianAccent,
                          labelStyle: TextStyle(color: _role == role ? Colors.white : colors.textPrimary),
                          backgroundColor: Theme.of(context).cardTheme.color,
                          side: BorderSide(color: colors.border),
                        ),
                      ),
                      if (role != UserRole.pharmacist) const SizedBox(width: 8),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _pickDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Date', border: OutlineInputBorder(), isDense: true),
                    child: Text(_fmtDate(_date), style: const TextStyle(fontSize: 13.5)),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _pickTime(isStart: true),
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'Start', border: OutlineInputBorder(), isDense: true),
                          child: Text(_fmtTime(_startTime), style: const TextStyle(fontSize: 13.5)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: InkWell(
                        onTap: () => _pickTime(isStart: false),
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'End', border: OutlineInputBorder(), isDense: true),
                          child: Text(_fmtTime(_endTime), style: const TextStyle(fontSize: 13.5)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _staffId,
                        decoration: const InputDecoration(
                          labelText: 'Staff member',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: [
                          for (final s in candidates) DropdownMenuItem(value: s.id, child: Text(s.fullName)),
                        ],
                        onChanged: (v) => setState(() => _staffId = v),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => _suggest(allStaff),
                      icon: const Icon(Icons.auto_awesome_rounded),
                      tooltip: 'Suggest least-busy available staff',
                    ),
                  ],
                ),
                if (candidates.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'No ${_role.label.toLowerCase()} is available for this time (conflict, leave, or marked unavailable).',
                      style: TextStyle(fontSize: 11.5, color: colors.warningText),
                    ),
                  ),
                if (hasConflictForSelected)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'This staff member already has an overlapping shift.',
                      style: TextStyle(fontSize: 11.5, color: colors.danger),
                    ),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 20),
                PrimaryButton(
                  label: 'Add Shift',
                  onPressed: _staffId == null || !_end.isAfter(_start) ? null : _save,
                  loading: _saving,
                  color: colors.clinicianAccent,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

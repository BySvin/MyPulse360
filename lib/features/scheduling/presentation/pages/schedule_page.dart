import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../widgets/my_schedule_view.dart';
import '../widgets/team_schedule_view.dart';

/// Doctor's Schedule tab: a segmented [Team | My Shifts] switch, since a
/// doctor both manages the clinic's schedule and works their own shifts.
class SchedulePage extends ConsumerStatefulWidget {
  const SchedulePage({super.key});

  @override
  ConsumerState<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends ConsumerState<SchedulePage> {
  String _segment = 'Team';

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(title: const Text('Schedule'), centerTitle: false),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: CupertinoSlidingSegmentedControl<String>(
                groupValue: _segment,
                backgroundColor: colors.surfaceMuted,
                thumbColor: colors.clinicianAccent,
                children: {
                  'Team': Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      'Team',
                      style: TextStyle(
                        color: _segment == 'Team' ? Colors.white : colors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  'Mine': Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      'My Shifts',
                      style: TextStyle(
                        color: _segment == 'Mine' ? Colors.white : colors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                },
                onValueChanged: (value) {
                  if (value != null) setState(() => _segment = value);
                },
              ),
            ),
            Expanded(
              child: _segment == 'Team'
                  ? TeamScheduleView(clinicId: user.clinicId)
                  : MyScheduleView(staffId: user.id, accentColor: colors.clinicianAccent),
            ),
          ],
        ),
      ),
    );
  }
}

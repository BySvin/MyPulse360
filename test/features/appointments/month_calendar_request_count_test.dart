import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mypulse360/config/theme/app_theme.dart';
import 'package:mypulse360/features/appointments/domain/entities/appointment.dart';
import 'package:mypulse360/features/appointments/domain/entities/time_slot.dart';
import 'package:mypulse360/features/appointments/domain/repositories/appointments_repository.dart';
import 'package:mypulse360/features/appointments/presentation/providers/appointments_providers.dart';
import 'package:mypulse360/features/appointments/presentation/widgets/month_calendar.dart';

/// Task 1 of the appointments slice exists for exactly one reason: rendering a
/// month must cost **one** round trip, not one per day. Before
/// `month_availability`, drawing a calendar meant 31 `available_slots` calls.
///
/// The plan proposed proving this by counting requests in a browser network
/// panel. A number read off a panel once proves nothing the next time someone
/// changes this widget, so it is asserted here instead — and this is the only
/// place the guarantee is checked, since the saving is invisible from the UI.
class _CountingRepository implements AppointmentsRepository {
  int monthCalls = 0;
  int slotCalls = 0;
  final List<DateTime> monthsRequested = [];

  @override
  Future<List<({DateTime day, int openSlots, bool isOnLeave})>>
  getMonthAvailability({
    required String doctorId,
    required DateTime month,
  }) async {
    monthCalls++;
    monthsRequested.add(month);
    return const [];
  }

  @override
  Future<List<TimeSlot>> getAvailableSlots({
    required String doctorId,
    required DateTime date,
  }) async {
    slotCalls++;
    return const [];
  }

  @override
  Future<List<Appointment>> getForPatient(String patientId) async => const [];

  @override
  Future<List<Appointment>> getForDoctor(String doctorId) async => const [];

  @override
  Stream<Appointment?> watchNextUpcoming(String patientId) =>
      const Stream.empty();

  @override
  Stream<List<Appointment>> watchTodaysQueue(String doctorId) =>
      const Stream.empty();

  @override
  Future<Appointment> book({
    required String patientId,
    required String doctorId,
    required DateTime scheduledAt,
    required String appointmentType,
    String? reasonForVisit,
  }) async => throw UnimplementedError();

  @override
  Future<Appointment> updateStatus(
    String appointmentId,
    AppointmentStatus status,
  ) async => throw UnimplementedError();

  @override
  Future<Appointment> reschedule(String appointmentId, DateTime newTime) async =>
      throw UnimplementedError();
}

Future<void> _pumpCalendar(
  WidgetTester tester,
  _CountingRepository repository, {
  required DateTime selectedDate,
}) async {
  // The default 800x600 test surface is shorter than a full month grid, which
  // overflows the Column. In the app the calendar sits inside a scroll view;
  // this is a test-harness constraint, not a layout defect.
  tester.view.physicalSize = const Size(1000, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appointmentsRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        // `context.colors` reads a ThemeExtension, so the real theme is
        // required — a bare MaterialApp throws on the null check.
        theme: AppTheme.light(),
        home: Scaffold(
          body: MonthCalendar(
            doctorId: 'doctor-1',
            selectedDate: selectedDate,
            onSelected: (_) {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('rendering a month costs one request, not one per day', (
    tester,
  ) async {
    final repository = _CountingRepository();

    // A 31-day month, so a per-day implementation would be unmistakable.
    await _pumpCalendar(
      tester,
      repository,
      selectedDate: DateTime(2026, 8, 15),
    );

    expect(
      repository.monthCalls,
      1,
      reason: 'one month_availability call per rendered month',
    );
    expect(
      repository.slotCalls,
      0,
      reason:
          'the calendar must not fetch per-day slots — that is the 31-call '
          'path month_availability replaced',
    );
    expect(repository.monthsRequested.single, DateTime(2026, 8));
  });

  testWidgets('paging to the next month costs exactly one more request', (
    tester,
  ) async {
    final repository = _CountingRepository();
    await _pumpCalendar(
      tester,
      repository,
      selectedDate: DateTime(2026, 8, 15),
    );
    expect(repository.monthCalls, 1);

    // The forward chevron is the IconButton at the end of the header row.
    // (There is also a decorative chevron beside the month name, so match
    // the button specifically rather than the bare icon.)
    await tester.tap(
      find.widgetWithIcon(IconButton, Icons.chevron_right_rounded),
    );
    await tester.pumpAndSettle();

    expect(
      repository.monthCalls,
      2,
      reason: 'one additional call for the newly displayed month',
    );
    expect(repository.slotCalls, 0);
    expect(repository.monthsRequested.last, DateTime(2026, 9));
  });
}

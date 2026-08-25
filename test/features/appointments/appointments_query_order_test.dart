import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mypulse360/features/appointments/data/datasources/supabase_appointments_datasource.dart';

/// postgrest-dart's `order()` defaults to **descending** — the opposite of SQL
/// and of postgrest-js. So `.order('scheduled_at')` reads as ascending and is
/// not, and both tabs of the appointments list render backwards.
///
/// That is exactly what happened: a review correctly spotted the wrong order,
/// the "fix" dropped `ascending: false` and changed nothing, and it passed
/// review twice because the code *looked* right. Nothing caught it until the
/// datasource was run against the real database.
///
/// This asserts the query actually sent, which is the only place the mistake
/// is visible without a live server.
class _CapturingClient extends http.BaseClient {
  final List<Uri> requests = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request.url);
    return http.StreamedResponse(
      Stream.value(utf8.encode('[]')),
      200,
      headers: {'content-type': 'application/json'},
      request: request,
    );
  }
}

void main() {
  late _CapturingClient httpClient;
  late SupabaseAppointmentsDataSource dataSource;

  setUp(() {
    httpClient = _CapturingClient();
    dataSource = SupabaseAppointmentsDataSource(
      SupabaseClient('https://example.supabase.co', 'test-key',
          httpClient: httpClient),
    );
  });

  test('getForPatient asks the server for oldest-first', () async {
    await dataSource.getForPatient('patient-1');

    expect(httpClient.requests, hasLength(1));
    final query = Uri.decodeFull(httpClient.requests.single.query);
    expect(
      query,
      contains('order=scheduled_at.asc'),
      reason: 'appointments_list_page reverses only the past bucket, which is '
          'correct only if the server returns ascending',
    );
    expect(query, isNot(contains('scheduled_at.desc')));
  });

  test('getForDoctor asks the server for oldest-first', () async {
    await dataSource.getForDoctor('doctor-1');

    final query = Uri.decodeFull(httpClient.requests.single.query);
    expect(query, contains('order=scheduled_at.asc'));
    expect(query, isNot(contains('scheduled_at.desc')));
  });
}

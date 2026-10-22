import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:librarysystemapp/models/dashboard_summary.dart';
import 'package:librarysystemapp/providers/dashboard_provider.dart';
import 'package:librarysystemapp/services/dashboard_service.dart';

import 'auth_test.dart' show setupAuth, testToken;

Map<String, dynamic> summaryResponse() => {
  'activeCount': 17,
  'pendingCount': 4,
  'overdueCount': 3,
  'recent': [
    {
      'book': {'title': 'A Student Guide'},
      'status': 'borrowed',
      'displayStatus': 'overdue',
      'borrowedAt': '2026-10-22T16:30:00.000Z',
      'dueDate': '2099-12-31T00:00:00.000Z',
    },
    {
      'book': {'title': 'Pending Reading'},
      'status': 'pending',
      'displayStatus': 'pending',
      'requestedAt': '2026-10-21T10:00:00.000Z',
    },
  ],
};

void main() {
  test(
    'summary uses server totals rather than recent sample or local due dates',
    () {
      final summary = DashboardSummary.fromJson(summaryResponse());
      expect(summary.active, 17);
      expect(summary.pending, 4);
      expect(summary.overdue, 3);
      expect(summary.recent!.first.status, 'Overdue');
      expect(
        summary.recent!.first.formattedDate,
        'Borrowed Oct 23, 2026 · Manila',
      );
    },
  );

  test('missing or invalid counts and recent are unavailable, not zero', () {
    final summary = DashboardSummary.fromJson({
      'activeCount': -1,
      'pendingCount': '4',
      'overdueCount': 1.5,
    });
    expect(summary.active, isNull);
    expect(summary.pending, isNull);
    expect(summary.overdue, isNull);
    expect(summary.recent, isNull);
    expect(() => DashboardSummary.fromJson([]), throwsFormatException);
  });

  test(
    'empty data is valid and missing records do not invent titles or statuses',
    () {
      expect(DashboardSummary.fromJson({'recent': []}).recent, isEmpty);
      final activity = RecentActivity.fromJson({
        'book': null,
        'status': 'borrowed',
        'dueDate': '2000-01-01',
      });
      expect(activity.title, 'Book title unavailable');
      expect(activity.status, 'Status unavailable');
      expect(activity.formattedDate, 'Date not recorded');
      final returned = RecentActivity.fromJson({
        'displayStatus': 'returned',
        'returnedAt': '2026-10-23T10:00:00Z',
        'createdAt': '2026-10-20T00:00:00Z',
      });
      expect(returned.formattedDate, 'Returned Oct 23, 2026 · Manila');
    },
  );

  test(
    'summary reads use scoped Bearer token and deduplicate concurrent refresh',
    () async {
      final fixture = setupAuth();
      fixture.store.value = testToken;
      await fixture.auth.restore();
      final pending = Completer<void>();
      fixture.adapter.summaryWait = pending.future;
      fixture.adapter.summaryData = summaryResponse();
      final dashboard = DashboardProvider(
        DashboardService(fixture.auth.authenticatedGet),
      );
      addTearDown(dashboard.dispose);
      final first = dashboard.refresh();
      final second = dashboard.refresh();
      expect(dashboard.loading, isTrue);
      pending.complete();
      await Future.wait([first, second]);
      expect(dashboard.summary!.active, 17);
      final requests = fixture.adapter.requests
          .where((r) => r.path == '/borrowings/summary')
          .toList();
      expect(requests.length, 1);
      expect(requests.single.headers['Authorization'], 'Bearer $testToken');
      expect(requests.single.method, 'GET');
      expect(dashboard.loading, isFalse);
    },
  );

  test('network errors preserve previous totals and can be retried', () async {
    final fixture = setupAuth();
    fixture.store.value = testToken;
    await fixture.auth.restore();
    fixture.adapter.summaryData = summaryResponse();
    final dashboard = DashboardProvider(
      DashboardService(fixture.auth.authenticatedGet),
    );
    addTearDown(dashboard.dispose);
    await dashboard.refresh();
    fixture.adapter.offline = true;
    await dashboard.refresh();
    expect(dashboard.summary!.active, 17);
    expect(dashboard.error, contains('Cannot reach'));
    expect(fixture.auth.student, isNotNull);
    fixture.adapter.offline = false;
    await dashboard.refresh();
    expect(dashboard.error, isNull);
  });

  test('401 from summary clears the existing student session', () async {
    final fixture = setupAuth();
    fixture.store.value = testToken;
    await fixture.auth.restore();
    fixture.adapter.summaryStatus = 401;
    fixture.adapter.summaryData = {
      'message': 'Session expired. Please log in again.',
    };
    final dashboard = DashboardProvider(
      DashboardService(fixture.auth.authenticatedGet),
    );
    addTearDown(dashboard.dispose);
    await dashboard.refresh();
    expect(fixture.auth.student, isNull);
    expect(fixture.store.value, isNull);
    expect(dashboard.summary, isNull);
  });

  test('summary completion after logout is not accepted', () async {
    final fixture = setupAuth();
    fixture.store.value = testToken;
    await fixture.auth.restore();
    final gate = Completer<void>();
    fixture.adapter.summaryWait = gate.future;
    final dashboard = DashboardProvider(
      DashboardService(fixture.auth.authenticatedGet),
    );
    addTearDown(dashboard.dispose);
    final request = dashboard.refresh();
    await fixture.auth.logout();
    gate.complete();
    await request;
    expect(dashboard.summary, isNull);
  });

  test('disposed dashboard ignores in-flight completion', () async {
    final gate = Completer<dynamic>();
    final dashboard = DashboardProvider(DashboardService((_) => gate.future));
    var notifications = 0;
    dashboard.addListener(() => notifications++);
    final request = dashboard.refresh();
    dashboard.dispose();
    gate.complete(summaryResponse());
    await request;
    expect(notifications, 1);
    expect(dashboard.summary, isNull);
  });
}

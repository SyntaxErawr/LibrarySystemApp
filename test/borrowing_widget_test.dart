import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:librarysystemapp/main.dart';
import 'package:librarysystemapp/providers/auth_provider.dart';
import 'package:librarysystemapp/services/auth_service.dart';
import 'package:librarysystemapp/services/api_service.dart';
import 'package:librarysystemapp/config/api_config.dart';

import 'auth_test.dart' show MemoryStore, testToken;
import 'borrowing_test.dart' show CirculationAdapter, loan;

void main() {
  Future<void> launch(WidgetTester tester, CirculationAdapter adapter) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final dio = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl))
      ..httpClientAdapter = adapter;
    addTearDown(() => dio.close(force: true));
    await tester.pumpWidget(
      LibrarySystemApp(
        auth: AuthProvider(
          AuthService(ApiService(dio: dio)),
          MemoryStore()..value = testToken,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> section(WidgetTester tester, String name) async {
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(name).last);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'request confirmation, loading lock, own pending cancel and dashboard refresh',
    (tester) async {
      final gate = Completer<void>();
      final adapter = CirculationAdapter()..writeWait = gate.future;
      await launch(tester, adapter);
      await tester.tap(find.text('Books'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Book title'));
      await tester.tap(find.text('Book title'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Request Book'));
      await tester.tap(find.text('Request Book'));
      await tester.pumpAndSettle();
      expect(adapter.writes, 0);
      expect(find.text('Request Book?'), findsOneWidget);
      await tester.tap(find.text('Submit Request'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(adapter.writes, 1);
      expect(find.text('Submitting...'), findsOneWidget);
      gate.complete();
      await tester.pumpAndSettle();
      expect(adapter.records.single['status'], 'pending');
      expect(find.textContaining('You already have this book'), findsOneWidget);
      expect(
        adapter.requests
            .where((r) => r.uri.path == '/api/borrowings/summary')
            .length,
        2,
      );
      final stockReads = adapter.requests
          .where((r) => r.uri.path == '/api/books')
          .length;
      expect(stockReads, greaterThanOrEqualTo(2));
      await tester.tap(find.text('My Books').last);
      await tester.pumpAndSettle();
      await section(tester, 'Pending Requests');
      expect(find.text('Pending'), findsOneWidget);
      expect(find.textContaining('Oct 23, 2026'), findsOneWidget);
      await tester.ensureVisible(find.text('Cancel Request'));
      await tester.tap(find.text('Cancel Request'));
      await tester.pumpAndSettle();
      expect(adapter.writes, 1);
      await tester.tap(find.widgetWithText(FilledButton, 'Cancel Request'));
      await tester.pumpAndSettle();
      expect(adapter.writes, 2);
      expect(adapter.records.single['status'], 'cancelled');
      await section(tester, 'Borrowing History');
      expect(find.text('Cancelled'), findsOneWidget);
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      expect(
        adapter.requests
            .where((r) => r.uri.path == '/api/borrowings/summary')
            .length,
        3,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'server overdue, returned and rejected history fit small screen',
    (tester) async {
      final adapter = CirculationAdapter()
        ..records = [
          {
            ...loan('borrowed'),
            'displayStatus': 'overdue',
            'daysRemaining': -1,
          },
          loan('returned', id: 'r2'),
          loan('rejected', id: 'r3'),
        ];
      await launch(tester, adapter);
      await tester.tap(find.text('My Books').last);
      await tester.pumpAndSettle();
      expect(find.text('Overdue'), findsOneWidget);
      expect(find.text('1 days overdue'), findsOneWidget);
      await section(tester, 'Borrowing History');
      expect(find.text('Returned'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Reason: Reference only'), 150);
      expect(find.text('Reason: Reference only'), findsOneWidget);
      expect(find.text('Cancel Request'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('empty current records and unavailable request action', (
    tester,
  ) async {
    await launch(tester, CirculationAdapter());
    await tester.tap(find.text('My Books').last);
    await tester.pumpAndSettle();
    expect(find.text('No records in this section.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('unavailable stock disables requesting without a write', (
    tester,
  ) async {
    final adapter = CirculationAdapter()..availableCopies = 0;
    await launch(tester, adapter);
    await tester.tap(find.text('Books'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Book title'));
    await tester.tap(find.text('Book title'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Request Book'));
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Request Book'),
          )
          .onPressed,
      isNull,
    );
    expect(find.text('This book is currently unavailable.'), findsOneWidget);
    expect(adapter.writes, 0);
  });
  testWidgets(
    'stale cancellation conflict preserves server error and refreshes records',
    (tester) async {
      final adapter = CirculationAdapter()
        ..records = [loan('pending')]
        ..writeStatus = 409
        ..writeError = 'Only pending requests can be changed.';
      await launch(tester, adapter);
      await tester.tap(find.text('My Books').last);
      await tester.pumpAndSettle();
      await section(tester, 'Pending Requests');
      await tester.ensureVisible(find.text('Cancel Request'));
      await tester.tap(find.text('Cancel Request'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Cancel Request'));
      await tester.pumpAndSettle();
      expect(adapter.writes, 1);
      expect(
        find.text('Only pending requests can be changed.'),
        findsOneWidget,
      );
    },
  );
}

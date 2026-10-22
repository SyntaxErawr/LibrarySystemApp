import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:librarysystemapp/config/api_config.dart';
import 'package:librarysystemapp/main.dart';
import 'package:librarysystemapp/providers/auth_provider.dart';
import 'package:librarysystemapp/services/api_service.dart';
import 'package:librarysystemapp/services/auth_service.dart';

import 'auth_test.dart' show AuthAdapter, MemoryStore, testToken, user;
import 'dashboard_test.dart' show summaryResponse;

void main() {
  Future<MemoryStore> launch(
    WidgetTester tester,
    AuthAdapter adapter, {
    bool settle = true,
    double width = 360,
  }) async {
    tester.view.physicalSize = Size(width, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final dio = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl))
      ..httpClientAdapter = adapter;
    addTearDown(() => dio.close(force: true));
    final store = MemoryStore()..value = testToken;
    await tester.pumpWidget(
      LibrarySystemApp(
        auth: AuthProvider(AuthService(ApiService(dio: dio)), store),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump();
    }
    return store;
  }

  testWidgets(
    'dashboard shows server counts and recent activity on small phone',
    (tester) async {
      await launch(
        tester,
        AuthAdapter()..summaryData = summaryResponse(),
        width: 320,
      );
      expect(find.text('Welcome, Test Student!'), findsOneWidget);
      for (final count in ['17', '4', '3']) {
        expect(find.text(count), findsOneWidget);
      }
      expect(find.text('A Student Guide'), findsOneWidget);
      expect(find.text('Overdue'), findsOneWidget);
      expect(find.text('Borrowed Oct 23, 2026 \u00b7 Manila'), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('empty state and unavailable fields are distinguished', (
    tester,
  ) async {
    await launch(
      tester,
      AuthAdapter()
        ..summaryData = {'activeCount': 0, 'pendingCount': 0, 'recent': []},
    );
    expect(find.text('0'), findsNWidgets(2));
    expect(find.text('Unavailable'), findsOneWidget);
    expect(find.text('No borrowing or request activity yet.'), findsOneWidget);
  });

  testWidgets('loading and server error offer a working refresh', (
    tester,
  ) async {
    final gate = Completer<void>();
    final adapter = AuthAdapter()
      ..summaryWait = gate.future
      ..summaryStatus = 503;
    await launch(tester, adapter, settle: false);
    for (
      var frame = 0;
      frame < 20 && find.byType(LinearProgressIndicator).evaluate().isEmpty;
      frame++
    ) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    gate.complete();
    await tester.pumpAndSettle();
    expect(
      find.text('The server is temporarily unavailable. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('Unavailable'), findsNWidgets(3));
    adapter.summaryStatus = 200;
    await tester.tap(find.text('Refresh activity'));
    await tester.pumpAndSettle();
    expect(find.text('0'), findsNWidgets(3));
    expect(
      find.text('The server is temporarily unavailable. Please try again.'),
      findsNothing,
    );
  });

  testWidgets('profile shows verified fields, refreshes once, and logs out', (
    tester,
  ) async {
    final adapter = AuthAdapter();
    final store = await launch(tester, adapter);
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    for (final value in [
      'student@example.test',
      'TEST-1',
      'BSIT',
      '1st Year',
      'Student',
      'Active',
    ]) {
      expect(find.text(value), findsOneWidget);
    }
    expect(adapter.requests.where((r) => r.path == '/auth/me').length, 1);
    adapter.meUser = {...user(), 'name': 'Updated Student', 'course': 'BSCS'};
    await tester.ensureVisible(find.text('Refresh profile'));
    await tester.tap(find.text('Refresh profile'));
    await tester.pumpAndSettle();
    expect(find.text('Updated Student'), findsNWidgets(2));
    expect(find.text('BSCS'), findsOneWidget);
    expect(adapter.requests.where((r) => r.path == '/auth/me').length, 2);
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome, Updated Student!'), findsOneWidget);
    expect(
      adapter.requests.where((r) => r.path == '/borrowings/summary').length,
      1,
    );
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Log out'));
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    expect(find.text('Log in'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(store.value, isNull);
  });

  testWidgets(
    'legacy fields show Not provided without overflow at larger text size',
    (tester) async {
      final legacy = user()
        ..remove('studentId')
        ..remove('course')
        ..remove('yearLevel');
      await launch(tester, AuthAdapter()..meUser = legacy, width: 320);
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      expect(find.text('Not provided'), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('bottom navigation opens each module without quick actions', (
    tester,
  ) async {
    final adapter = AuthAdapter();
    await launch(tester, adapter);
    expect(find.text('Quick actions'), findsNothing);
    expect(find.text('Browse Books'), findsNothing);
    await tester.tap(find.text('Books'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      1,
    );
    expect(find.text('Explore Books'), findsOneWidget);
    await tester.tap(find.text('My Books').last);
    await tester.pumpAndSettle();
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      2,
    );
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      3,
    );
    expect(find.text('Account Role'), findsOneWidget);
    expect(
      adapter.requests.where((r) => r.path == '/borrowings/summary').length,
      1,
    );
  });

  testWidgets(
    '401 on dashboard returns to Login and nonstudents cannot enter',
    (tester) async {
      final adapter = AuthAdapter()
        ..summaryStatus = 401
        ..summaryData = {'message': 'Session expired. Please log in again.'};
      final store = await launch(tester, adapter);
      expect(find.text('Log in'), findsOneWidget);
      expect(store.value, isNull);
      expect(find.byType(NavigationBar), findsNothing);
    },
  );

  for (final role in ['admin', 'librarian']) {
    testWidgets('$role cannot access dashboard or profile', (tester) async {
      final adapter = AuthAdapter()..role = role;
      await launch(tester, adapter);
      expect(find.text('Log in'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(
        adapter.requests.where((r) => r.path == '/borrowings/summary'),
        isEmpty,
      );
    });
  }
}

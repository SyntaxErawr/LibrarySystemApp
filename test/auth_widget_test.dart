import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:librarysystemapp/config/api_config.dart';
import 'package:librarysystemapp/main.dart';
import 'package:librarysystemapp/providers/auth_provider.dart';
import 'package:librarysystemapp/services/api_service.dart';
import 'package:librarysystemapp/services/auth_service.dart';

import 'auth_test.dart' show AuthAdapter, MemoryStore, testToken;

void main() {
  Future<({AuthAdapter adapter, MemoryStore store})> launch(
    WidgetTester tester, {
    String role = 'student',
    bool saved = false,
    String? storedToken,
  }) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final adapter = AuthAdapter()..role = role;
    final dio = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl))
      ..httpClientAdapter = adapter;
    addTearDown(() => dio.close(force: true));
    final store = MemoryStore();
    if (saved) store.value = storedToken ?? testToken;
    await tester.pumpWidget(
      LibrarySystemApp(
        auth: AuthProvider(AuthService(ApiService(dio: dio)), store),
      ),
    );
    await tester.pumpAndSettle();
    return (adapter: adapter, store: store);
  }

  testWidgets('login validates, signs in, shows student, and logs out', (
    tester,
  ) async {
    final fixture = await launch(tester);
    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(fixture.adapter.requests, isEmpty);
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'student@example.test',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'TestPass1!');
    await tester.ensureVisible(find.text('Log in'));
    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome, Test Student!'), findsOneWidget);
    expect(fixture.store.value, testToken);
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Log out'));
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    expect(find.text('Log in'), findsOneWidget);
    expect(fixture.store.value, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('nonstudent session never reaches dashboard', (tester) async {
    final fixture = await launch(tester, role: 'admin', saved: true);
    expect(find.text('Log in'), findsOneWidget);
    expect(find.textContaining('students only'), findsOneWidget);
    expect(find.textContaining('Welcome,'), findsNothing);
    expect(fixture.store.value, isNull);
  });

  testWidgets(
    'registration scrolls with keyboard, validates, and returns to login',
    (tester) async {
      final fixture = await launch(tester);
      await tester.ensureVisible(find.text('New student? Create an account'));
      await tester.tap(find.text('New student? Create an account'));
      await tester.pumpAndSettle();
      expect(find.text('Create student account'), findsOneWidget);
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Create account'));
      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();
      expect(find.text('Full name is required.'), findsOneWidget);
      expect(
        find.text('Passwords must match and cannot be empty.'),
        findsOneWidget,
      );
      expect(fixture.adapter.requests, isEmpty);
      expect(tester.takeException(), isNull);
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Already registered? Log in'));
      await tester.tap(find.text('Already registered? Log in'));
      await tester.pumpAndSettle();
      expect(find.text('Log in'), findsOneWidget);
    },
  );

  testWidgets('restored student opens dashboard directly', (tester) async {
    await launch(tester, saved: true);
    expect(find.text('Welcome, Test Student!'), findsOneWidget);
    expect(find.text('Log in'), findsNothing);
  });

  testWidgets('JWT expiry returns an open dashboard to login', (tester) async {
    final expiry =
        DateTime.now().add(const Duration(seconds: 5)).millisecondsSinceEpoch ~/
        1000;
    final payload = base64Url.encode(utf8.encode(jsonEncode({'exp': expiry})));
    final fixture = await launch(
      tester,
      saved: true,
      storedToken: 'test.$payload.signature',
    );
    expect(find.text('Welcome, Test Student!'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(find.text('Log in'), findsOneWidget);
    expect(fixture.store.value, isNull);
    expect(find.textContaining('Session expired'), findsOneWidget);
  });

  testWidgets('complete registration submits once and returns to login', (
    tester,
  ) async {
    final fixture = await launch(tester);
    await tester.ensureVisible(find.text('New student? Create an account'));
    await tester.tap(find.text('New student? Create an account'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    final values = [
      'Test Student',
      'TEST-1',
      'student@example.test',
      'TestPass1!',
      'TestPass1!',
    ];
    for (var index = 0; index < values.length; index++) {
      await tester.ensureVisible(fields.at(index));
      await tester.enterText(fields.at(index), values[index]);
    }
    final dropdowns = find.byType(DropdownButtonFormField<String>);
    await tester.ensureVisible(dropdowns.at(0));
    await tester.pumpAndSettle();
    await tester.tap(dropdowns.at(0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('BSIT').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(dropdowns.at(1));
    await tester.pumpAndSettle();
    await tester.tap(dropdowns.at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1st Year').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Create account'));
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();
    expect(find.text('Log in'), findsOneWidget);
    expect(
      find.text('Student account created. You can now log in.'),
      findsOneWidget,
    );
    expect(fixture.adapter.requests.single.path, '/auth/register');
    expect(fixture.store.value, isNull);
    expect(tester.takeException(), isNull);
  });
}

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:librarysystemapp/screens/auth/login_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:librarysystemapp/config/api_config.dart';
import 'package:librarysystemapp/main.dart';
import 'package:librarysystemapp/providers/auth_provider.dart';
import 'package:librarysystemapp/providers/book_provider.dart';
import 'package:librarysystemapp/providers/dashboard_provider.dart';
import 'package:librarysystemapp/screens/books/book_catalog_screen.dart';
import 'package:librarysystemapp/screens/books/book_details_screen.dart';
import 'package:librarysystemapp/services/api_service.dart';
import 'package:librarysystemapp/services/auth_service.dart';
import 'package:librarysystemapp/services/book_service.dart';
import 'package:librarysystemapp/services/dashboard_service.dart';

import 'auth_test.dart' show AuthAdapter, MemoryStore, testToken, setupAuth;
import 'book_test.dart' show response, book;
import 'dashboard_test.dart' show summaryResponse;
import 'borrowing_test.dart' show CirculationAdapter;

class TimeoutAdapter extends AuthAdapter {
  TimeoutAdapter(this.type);
  final DioExceptionType type;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) async {
    if (options.uri.path.endsWith('/summary')) {
      throw DioException(requestOptions: options, type: type);
    }
    return super.fetch(options, stream, cancelFuture);
  }
}

void main() {
  test(
    'access denial on restoration retains token without opening the shell',
    () async {
      final fixture = setupAuth();
      fixture.store.value = testToken;
      fixture.adapter.meStatus = 403;
      await fixture.auth.restore();
      expect(fixture.auth.student, isNull);
      expect(fixture.store.value, testToken);
    },
  );
  test(
    'access denial on profile refresh does not revoke a verified session',
    () async {
      final fixture = setupAuth();
      fixture.store.value = testToken;
      await fixture.auth.restore();
      fixture.adapter.meStatus = 403;
      await fixture.auth.refreshStudent();
      expect(fixture.auth.student, isNotNull);
      expect(fixture.store.value, testToken);
      expect(fixture.auth.error, 'You do not have access to this action.');
    },
  );
  test('inactive account response is rejected during restoration', () async {
    final fixture = setupAuth();
    fixture.store.value = testToken;
    fixture.adapter.meUser = {
      '_id': 'test',
      'role': 'student',
      'isActive': false,
      'name': 'Inactive',
      'email': 'test@example.test',
    };
    await fixture.auth.restore();
    expect(fixture.auth.student, isNull);
    expect(fixture.store.value, isNull);
  });
  for (final status in [400, 401, 403, 404, 409, 422, 429, 500, 502, 503]) {
    test(
      'HTTP $status has safe feedback and only 401 invalidates session',
      () async {
        final fixture = setupAuth();
        fixture.store.value = testToken;
        await fixture.auth.restore();
        fixture.adapter.summaryStatus = status;
        fixture.adapter.summaryData = {'message': 'Public request failed.'};
        await expectLater(
          fixture.auth.authenticatedGet('/borrowings/summary'),
          throwsA(
            isA<AuthFailure>()
                .having((e) => e.status, 'status', status)
                .having(
                  (e) => e.message,
                  'message',
                  isNot(contains('Cannot reach')),
                ),
          ),
        );
        expect(fixture.auth.student == null, status == 401);
        expect(fixture.store.value == null, status == 401);
      },
    );
  }
  for (final type in [
    DioExceptionType.connectionTimeout,
    DioExceptionType.receiveTimeout,
    DioExceptionType.sendTimeout,
  ]) {
    test('$type retains secure credentials and explains delay', () async {
      final dio = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl))
        ..httpClientAdapter = TimeoutAdapter(type);
      final store = MemoryStore()..value = testToken;
      final auth = AuthProvider(AuthService(ApiService(dio: dio)), store);
      await auth.restore();
      await expectLater(
        auth.authenticatedGet('/borrowings/summary'),
        throwsA(
          isA<AuthFailure>().having(
            (e) => e.message,
            'message',
            contains('too long'),
          ),
        ),
      );
      expect(auth.student, isNotNull);
      expect(store.value, testToken);
      auth.dispose();
      dio.close();
    });
  }
  test('post-action catalog refresh supersedes pre-action request', () async {
    final old = Completer<dynamic>(), fresh = Completer<dynamic>();
    var calls = 0;
    final catalog = BookProvider(
      BookService((_) => ++calls == 1 ? old.future : fresh.future),
    );
    final before = catalog.refresh();
    final after = catalog.refresh(force: true);
    fresh.complete(response('updated'));
    await after;
    old.complete(response('stale'));
    await before;
    expect(catalog.books.single.id, 'updated');
    catalog.dispose();
    await catalog.refresh();
    expect(calls, 2);
  });
  test('post-action dashboard refresh supersedes pre-action counts', () async {
    final old = Completer<dynamic>(), fresh = Completer<dynamic>();
    var calls = 0;
    final dashboard = DashboardProvider(
      DashboardService((_) => ++calls == 1 ? old.future : fresh.future),
    );
    final before = dashboard.refresh();
    final after = dashboard.refresh(force: true);
    fresh.complete({...summaryResponse(), 'pendingCount': 1});
    await after;
    old.complete({...summaryResponse(), 'pendingCount': 0});
    await before;
    expect(dashboard.summary!.pending, 1);
    dashboard.dispose();
  });
  testWidgets(
    'detail refresh deduplicates concurrent reads and ignores disposed completion',
    (tester) async {
      var calls = 0;
      final gate = Completer<dynamic>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BookDetailsScreen(
              id: 'id',
              service: BookService((_) {
                calls++;
                return gate.future;
              }),
              onBack: () {},
            ),
          ),
        ),
      );
      final refresh = tester.widget<RefreshIndicator>(
        find.byType(RefreshIndicator),
      );
      final first = refresh.onRefresh(), second = refresh.onRefresh();
      expect(calls, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      gate.complete({'book': book('id')});
      await Future.wait([first, second]);
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  Future<AuthProvider> launch(
    WidgetTester tester,
    CirculationAdapter adapter, {
    String token = testToken,
  }) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final dio = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl))
      ..httpClientAdapter = adapter;
    addTearDown(() => dio.close(force: true));
    final auth = AuthProvider(
      AuthService(ApiService(dio: dio)),
      MemoryStore()..value = token,
    );
    await tester.pumpWidget(LibrarySystemApp(auth: auth));
    await tester.pumpAndSettle();
    return auth;
  }

  Future<void> details(WidgetTester tester) async {
    await tester.tap(find.text('Books'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Book title'));
    await tester.tap(find.text('Book title'));
    await tester.pumpAndSettle();
  }

  testWidgets('hidden catalog details do not intercept Back on Profile', (
    tester,
  ) async {
    await launch(tester, CirculationAdapter());
    await details(tester);
    final route = ModalRoute.of(
      tester.element(find.byType(BookCatalogScreen)),
    )!;
    expect(route.popDisposition, RoutePopDisposition.doNotPop);
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(route.popDisposition, RoutePopDisposition.bubble);
    await tester.tap(find.text('Books'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Explore Books'), findsOneWidget);
  });
  testWidgets(
    'JWT timer expiry removes confirmation overlay and authenticated content',
    (tester) async {
      final payload = base64Url
          .encode(
            utf8.encode(
              jsonEncode({
                'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 60,
              }),
            ),
          )
          .replaceAll('=', '');
      final adapter = CirculationAdapter();
      final auth = await launch(
        tester,
        adapter,
        token: 'test.$payload.signature',
      );
      await details(tester);
      await tester.ensureVisible(find.text('Request Book'));
      await tester.tap(find.text('Request Book'));
      await tester.pumpAndSettle();
      expect(find.text('Request Book?'), findsOneWidget);
      await tester.pump(const Duration(seconds: 90));
      await tester.pumpAndSettle();
      expect(auth.student, isNull);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Log in'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(adapter.writes, 0);
    },
  );
  testWidgets(
    'Login sets dark status-bar icons after returning from registration',
    (tester) async {
      final dio = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl))
        ..httpClientAdapter = AuthAdapter();
      addTearDown(() => dio.close(force: true));
      await tester.pumpWidget(
        LibrarySystemApp(
          auth: AuthProvider(AuthService(ApiService(dio: dio)), MemoryStore()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('New student? Create an account'));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      final overlays = find.descendant(
        of: find.byType(LoginScreen),
        matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
      );
      expect(
        tester
            .widget<AnnotatedRegion<SystemUiOverlayStyle>>(overlays.first)
            .value
            .statusBarIconBrightness,
        Brightness.dark,
      );
    },
  );
}

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:librarysystemapp/config/api_config.dart';
import 'package:librarysystemapp/providers/auth_provider.dart';
import 'package:librarysystemapp/services/api_service.dart';
import 'package:librarysystemapp/services/auth_service.dart';
import 'package:librarysystemapp/services/token_store.dart';
import 'package:librarysystemapp/utils/auth_validation.dart';

const testToken = 'test-session-value';
Map<String, dynamic> user([String role = 'student']) => {
  '_id': '012345678901234567890123',
  'name': 'Test Student',
  'email': 'student@example.test',
  'role': role,
  'isActive': true,
  'studentId': 'TEST-1',
  'course': 'BSIT',
  'yearLevel': '1st Year',
};

class MemoryStore implements TokenStore {
  String? value;
  bool failWrite = false;
  int deletes = 0;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String token) async {
    if (failWrite) throw StateError('storage unavailable');
    value = token;
  }

  @override
  Future<void> delete() async {
    value = null;
    deletes++;
  }
}

class AuthAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  String role = 'student';
  String? meRole;
  int loginStatus = 200,
      meStatus = 200,
      registerStatus = 201,
      logoutStatus = 200;
  Object? loginData;
  Map<String, dynamic>? meUser;
  Object summaryData = {
    'activeCount': 0,
    'pendingCount': 0,
    'overdueCount': 0,
    'recent': [],
    'upcoming': [],
  };
  int summaryStatus = 200;
  Future<void>? summaryWait;
  bool offline = false;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (offline) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      );
    }
    final path = options.uri.path;
    if (path == '/api/borrowings/summary') await summaryWait;
    final (status, data) = switch (path) {
      '/api/auth/login' => (
        loginStatus,
        loginData ??
            (loginStatus == 200
                ? {'token': testToken, 'user': user(role)}
                : {'message': 'Invalid email or password.'}),
      ),
      '/api/auth/me' => (
        meStatus,
        meStatus == 200
            ? {'user': meUser ?? user(meRole ?? role)}
            : {'message': 'Session expired. Please log in again.'},
      ),
      '/api/auth/register' => (
        registerStatus,
        registerStatus == 201
            ? {'message': 'Student account created. You can now log in.'}
            : {
                'message': 'This email is already registered.',
                'fields': {'email': 'This email is already registered.'},
              },
      ),
      '/api/auth/logout' => (logoutStatus, {'message': 'Logged out.'}),
      '/api/borrowings/summary' => (summaryStatus, summaryData),
      _ => (404, {'message': 'API route not found.'}),
    };
    return ResponseBody.fromString(
      jsonEncode(data),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

({AuthProvider auth, MemoryStore store, AuthAdapter adapter}) setupAuth() {
  final adapter = AuthAdapter();
  final dio = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl))
    ..httpClientAdapter = adapter;
  final store = MemoryStore();
  final auth = AuthProvider(AuthService(ApiService(dio: dio)), store);
  addTearDown(auth.dispose);
  addTearDown(() => dio.close(force: true));
  return (auth: auth, store: store, adapter: adapter);
}

Map<String, String> validRegistration() => {
  'name': 'Test Student',
  'studentId': 'TEST-1',
  'email': 'student@example.test',
  'course': 'BSIT',
  'yearLevel': '1st Year',
  'password': 'TestPass1!',
  'confirmPassword': 'TestPass1!',
};

void main() {
  test(
    'student login verifies me before saving token and sends Bearer',
    () async {
      final fixture = setupAuth();
      await fixture.auth.restore();
      expect(
        await fixture.auth.login(' Student@example.test ', 'TestPass1!'),
        isTrue,
      );
      expect(fixture.auth.student!.name, 'Test Student');
      expect(fixture.store.value, testToken);
      expect(fixture.adapter.requests.map((r) => r.path), [
        '/auth/login',
        '/auth/me',
      ]);
      expect(
        fixture.adapter.requests.first.data['email'],
        'student@example.test',
      );
      expect(
        fixture.adapter.requests.last.headers['Authorization'],
        'Bearer $testToken',
      );
      expect(
        fixture.adapter.requests.first.headers.containsKey('Authorization'),
        isFalse,
      );
    },
  );

  for (final role in ['admin', 'librarian', 'Student', 'unknown']) {
    test('rejects $role and clears saved session', () async {
      final fixture = setupAuth();
      await fixture.auth.restore();
      fixture.store.value = 'old-session';
      fixture.adapter.role = role;
      expect(
        await fixture.auth.login('student@example.test', 'TestPass1!'),
        isFalse,
      );
      expect(fixture.auth.student, isNull);
      expect(fixture.store.value, isNull);
      expect(fixture.auth.error, contains('students only'));
    });
  }

  test('me role overrides an apparently student login response', () async {
    final fixture = setupAuth();
    await fixture.auth.restore();
    fixture.adapter.meRole = 'admin';
    expect(
      await fixture.auth.login('student@example.test', 'TestPass1!'),
      isFalse,
    );
    expect(fixture.store.value, isNull);
  });

  for (final data in [
    <String, dynamic>{},
    {'token': '', 'user': user()},
    {'token': testToken},
    'invalid',
  ]) {
    test('rejects malformed login response ${data.runtimeType}', () async {
      final fixture = setupAuth();
      await fixture.auth.restore();
      fixture.adapter.loginData = data;
      expect(
        await fixture.auth.login('student@example.test', 'TestPass1!'),
        isFalse,
      );
      expect(fixture.store.value, isNull);
      expect(fixture.auth.student, isNull);
    });
  }

  test(
    'invalid credentials fail once without retry or token storage',
    () async {
      final fixture = setupAuth();
      await fixture.auth.restore();
      fixture.adapter.loginStatus = 401;
      expect(
        await fixture.auth.login('student@example.test', 'wrong'),
        isFalse,
      );
      expect(fixture.adapter.requests.length, 1);
      expect(fixture.auth.error, 'Invalid email or password.');
      expect(fixture.store.value, isNull);
    },
  );

  test('restores a valid student using the saved token', () async {
    final fixture = setupAuth();
    fixture.store.value = testToken;
    await fixture.auth.restore();
    expect(fixture.auth.restoring, isFalse);
    expect(fixture.auth.student!.studentId, 'TEST-1');
    expect(fixture.adapter.requests.single.path, '/auth/me');
  });

  for (final role in ['admin', 'librarian']) {
    test('restoration rejects $role and deletes token', () async {
      final fixture = setupAuth();
      fixture.store.value = testToken;
      fixture.adapter.role = role;
      await fixture.auth.restore();
      expect(fixture.auth.student, isNull);
      expect(fixture.store.value, isNull);
    });
  }

  test('expired session clears storage', () async {
    final fixture = setupAuth();
    fixture.store.value = testToken;
    fixture.adapter.meStatus = 401;
    await fixture.auth.restore();
    expect(fixture.auth.student, isNull);
    expect(fixture.store.value, isNull);
    expect(fixture.auth.error, contains('Session expired'));
  });

  test(
    'offline restore fails closed but keeps token for a later attempt',
    () async {
      final fixture = setupAuth();
      fixture.store.value = testToken;
      fixture.adapter.offline = true;
      await fixture.auth.restore();
      expect(fixture.auth.student, isNull);
      expect(fixture.store.value, testToken);
      expect(fixture.auth.restoring, isFalse);
    },
  );

  test('secure write failure does not open dashboard', () async {
    final fixture = setupAuth();
    await fixture.auth.restore();
    fixture.store.failWrite = true;
    expect(
      await fixture.auth.login('student@example.test', 'TestPass1!'),
      isFalse,
    );
    expect(fixture.auth.student, isNull);
  });

  test('refresh rejects invalidated tokens while signed in', () async {
    final fixture = setupAuth();
    fixture.store.value = testToken;
    await fixture.auth.restore();
    fixture.adapter.meStatus = 401;
    await fixture.auth.refreshStudent();
    expect(fixture.auth.student, isNull);
    expect(fixture.store.value, isNull);
    expect(fixture.auth.error, contains('Session expired'));
  });

  test('refresh rejects a changed role', () async {
    final fixture = setupAuth();
    fixture.store.value = testToken;
    await fixture.auth.restore();
    fixture.adapter.role = 'librarian';
    await fixture.auth.refreshStudent();
    expect(fixture.auth.student, isNull);
    expect(fixture.store.value, isNull);
  });

  test('invalid registration is blocked before a request', () async {
    final fixture = setupAuth();
    await fixture.auth.restore();
    expect(await fixture.auth.register({}), isFalse);
    expect(fixture.adapter.requests, isEmpty);
    expect(fixture.auth.fieldErrors['email'], isNotNull);
  });

  test(
    'registration excludes privileged fields and does not sign in',
    () async {
      final fixture = setupAuth();
      await fixture.auth.restore();
      expect(
        await fixture.auth.register({
          ...validRegistration(),
          'role': 'admin',
          'isActive': 'true',
        }),
        isTrue,
      );
      final body = fixture.adapter.requests.single.data as Map;
      expect(body.containsKey('role'), isFalse);
      expect(body.containsKey('isActive'), isFalse);
      expect(fixture.store.value, isNull);
      expect(fixture.auth.student, isNull);
      expect(fixture.auth.notice, contains('created'));
    },
  );

  test('duplicate registration exposes field error without retry', () async {
    final fixture = setupAuth();
    await fixture.auth.restore();
    fixture.adapter.registerStatus = 409;
    expect(await fixture.auth.register(validRegistration()), isFalse);
    expect(
      fixture.auth.fieldErrors['email'],
      'This email is already registered.',
    );
    expect(fixture.adapter.requests.length, 1);
  });

  for (final offline in [false, true]) {
    test(
      'logout removes token and student even when offline=$offline',
      () async {
        final fixture = setupAuth();
        fixture.store.value = testToken;
        await fixture.auth.restore();
        fixture.adapter.offline = offline;
        await fixture.auth.logout();
        expect(fixture.store.value, isNull);
        expect(fixture.auth.student, isNull);
        expect(fixture.auth.busy, isFalse);
        expect(fixture.adapter.requests.last.path, '/auth/logout');
      },
    );
  }

  test('registration matches required fields and Other program rules', () {
    expect(AuthValidation.registration(validRegistration()), isEmpty);
    expect(
      AuthValidation.registration({}).keys,
      containsAll([
        'name',
        'studentId',
        'email',
        'course',
        'yearLevel',
        'password',
        'confirmPassword',
      ]),
    );
    expect(
      AuthValidation.registration({
        ...validRegistration(),
        'course': 'Other',
      })['otherProgram'],
      isNotNull,
    );
    expect(
      AuthValidation.registration({
        ...validRegistration(),
        'course': 'Other',
        'otherProgram': 'Custom program',
      }),
      isEmpty,
    );
    expect(
      AuthValidation.registration({
        ...validRegistration(),
        'confirmPassword': 'different',
      })['confirmPassword'],
      isNotNull,
    );
    expect(
      AuthValidation.registration({
        ...validRegistration(),
        'yearLevel': '5th Year',
      })['yearLevel'],
      isNotNull,
    );
  });

  test('password complexity and UTF-8 byte limits match shared validation', () {
    for (final password in [
      'short',
      'testpass1!',
      'TESTPASS1!',
      'TestPass!!',
      'TestPass11',
      '${'é' * 35}Ab1!',
    ]) {
      expect(
        AuthValidation.registration({
          ...validRegistration(),
          'password': password,
          'confirmPassword': password,
        })['password'],
        isNotNull,
      );
    }
    expect(
      AuthValidation.passwordChecks('TestPass1é')['One special character'],
      isFalse,
    );
    expect(
      AuthValidation.passwordChecks('TestPass1😀')['One special character'],
      isTrue,
    );
    expect(AuthValidation.loginPassword('legacy'), isNull);
  });
}

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/student.dart';
import '../services/auth_service.dart';
import '../services/token_store.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider(this.service, this.store);
  final AuthService service;
  final TokenStore store;
  Student? student;
  String? _token;
  bool restoring = true;
  bool busy = false;
  String? error;
  String? notice;
  Map<String, String> fieldErrors = {};
  bool _disposed = false;
  Timer? _expiryTimer;

  // Keep tokens private and route protected reads through existing revocation handling.
  Future<dynamic> authenticatedGet(String path) =>
      _authenticated((token) => service.authenticatedGet(path, token));

  Future<dynamic> authenticatedWrite(
    String method,
    String path,
    Map<String, dynamic> body,
  ) => _authenticated(
    (token) => service.authenticatedWrite(method, path, body, token),
  );

  Future<dynamic> _authenticated(
    Future<dynamic> Function(String) action,
  ) async {
    final token = _token;
    if (token == null || student == null) {
      throw const AuthFailure('Please log in again.', status: 401);
    }
    try {
      final data = await action(token);
      if (_disposed || _token != token) {
        throw const AuthFailure(
          'The session has changed. Please log in again.',
          status: 401,
        );
      }
      return data;
    } on AuthFailure catch (failure) {
      if (_token == token &&
          (failure.status == 401 || failure.discardSession)) {
        error = failure.message;
        await _clear();
        _emit();
      }
      rethrow;
    }
  }

  void clearFeedback() {
    error = null;
    notice = null;
    fieldErrors = {};
    _emit();
  }

  void _scheduleExpiry(String token) {
    _expiryTimer?.cancel();
    if (_disposed) return;
    // This only schedules UI expiry. Account/role acceptance always uses /me.
    try {
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(token.split('.')[1]))),
      );
      if (payload is! Map || payload['exp'] is! num) return;
      final expires = DateTime.fromMillisecondsSinceEpoch(
        ((payload['exp'] as num) * 1000).toInt(),
      );
      final delay = expires.difference(DateTime.now());
      _expiryTimer = Timer(delay.isNegative ? Duration.zero : delay, () async {
        if (_disposed) return;
        error = 'Session expired. Please log in again.';
        await _clear();
        _emit();
      });
    } catch (_) {
      // Do not infer token validity from local decoding.
    }
  }

  Future<void> refreshStudent() async {
    final token = _token;
    if (token == null || busy || restoring) return;
    await _run(() async {
      try {
        final currentStudent = await service.me(token);
        if (_token == token) student = currentStudent;
      } on AuthFailure catch (failure) {
        if (failure.status == 401 || failure.discardSession) {
          await _clear();
        }
        rethrow;
      }
    });
  }

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  Future<void> restore() async {
    try {
      final token = await store.read();
      if (token != null && token.isNotEmpty) {
        student = await service.me(token);
        _token = token;
        _scheduleExpiry(token);
      }
    } on AuthFailure catch (failure) {
      error = failure.message;
      // Retain credentials on transient network/server failures for a later
      // restart, but never show a dashboard without /me verification.
      if (failure.status == 401 || failure.discardSession) {
        await _clear();
      }
    } catch (_) {
      error = 'Secure session storage is unavailable. Please sign in again.';
      await _clear();
    } finally {
      restoring = false;
      _emit();
    }
  }

  Future<bool> login(String email, String password) => _run(() async {
    // A failed/rejected sign-in must not leave an old token behind.
    await store.delete();
    _token = null;
    student = null;
    try {
      final session = await service.login(email, password);
      await store.write(session.token);
      _token = session.token;
      student = session.student;
      _scheduleExpiry(session.token);
    } catch (_) {
      await _clear();
      rethrow;
    }
  });

  Future<bool> register(Map<String, String> values) => _run(() async {
    await service.register(values);
    notice = 'Student account created. You can now log in.';
  });

  Future<void> logout() async {
    if (busy) return;
    busy = true;
    error = null;
    _emit();
    final token = _token;
    try {
      if (token != null) await service.logout(token);
      notice = 'You have been logged out.';
    } catch (_) {
      notice = 'Signed out on this device. Server logout could not be confirmed; other sessions may remain active.';
    } finally {
      await _clear();
      busy = false;
      _emit();
    }
  }

  Future<void> _clear() async {
    _expiryTimer?.cancel();
    student = null;
    _token = null;
    try {
      await store.delete();
    } catch (_) {
      error = 'Could not remove the saved session. Clear app storage before using a shared device.';
    }
  }

  Future<bool> _run(Future<void> Function() action) async {
    if (busy || restoring) return false;
    busy = true;
    error = null;
    notice = null;
    fieldErrors = {};
    _emit();
    try {
      await action();
      return true;
    } on AuthFailure catch (failure) {
      error = failure.message;
      fieldErrors = failure.fields;
      return false;
    } catch (_) {
      error = 'Unable to save or access your secure session. Please try again.';
      return false;
    } finally {
      busy = false;
      _emit();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _expiryTimer?.cancel();
    super.dispose();
  }
}

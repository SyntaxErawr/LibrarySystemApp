import 'package:dio/dio.dart';

import '../models/student.dart';
import '../utils/auth_validation.dart';
import 'api_service.dart';

class AuthFailure implements Exception {
  const AuthFailure(
    this.message, {
    this.fields = const {},
    this.status,
    this.discardSession = false,
  });
  final String message;
  final Map<String, String> fields;
  final int? status;
  final bool discardSession;
}

class LoginSession {
  const LoginSession(this.token, this.student);
  final String token;
  final Student student;
}

class AuthService {
  AuthService(this.api);
  final ApiService api;

  Future<dynamic> authenticatedWrite(
    String method,
    String path,
    Map<String, dynamic> body,
    String token,
  ) => _guard(() async {
    final response = method == 'POST'
        ? await api.post(path, body, token: token)
        : await api.patch(path, body, token: token);
    return response.data;
  });

  Future<dynamic> authenticatedGet(String path, String token) =>
      _guard(() async {
        final response = await api.get(path, token: token);
        return response.data;
      });

  Future<LoginSession> login(String email, String password) => _guard(() async {
    final response = await api.post('/auth/login', {
      'email': email.trim().toLowerCase(),
      'password': password,
    });
    final data = response.data;
    if (data is! Map ||
        data['token'] is! String ||
        (data['token'] as String).isEmpty) {
      throw const AuthFailure('The server returned an invalid login response.');
    }
    // /me verifies token validity and loads authoritative current account data.
    // Do not persist anything until both role checks have passed.
    Student.fromTrustedUser(data['user']);
    final token = data['token'] as String;
    return LoginSession(token, await me(token));
  });

  Future<Student> me(String token) => _guard(() async {
    final response = await api.get('/auth/me', token: token);
    final data = response.data;
    if (data is! Map) throw const FormatException();
    return Student.fromTrustedUser(data['user']);
  });

  Future<void> register(Map<String, String> values) => _guard(() async {
    final errors = AuthValidation.registration(values);
    if (errors.isNotEmpty) {
      throw AuthFailure('Please check the highlighted fields.', fields: errors);
    }
    // Never accept a caller-supplied role or privileged attributes.
    final body = <String, dynamic>{
      for (final key in [
        'name',
        'studentId',
        'email',
        'course',
        'otherProgram',
        'yearLevel',
        'password',
        'confirmPassword',
      ])
        if (values.containsKey(key)) key: values[key],
    };
    final response = await api.post('/auth/register', body);
    if (response.statusCode != 201) {
      throw const AuthFailure('The server did not confirm account creation.');
    }
  });

  Future<void> logout(String token) => _guard(() async {
    await api.post('/auth/logout', {}, token: token);
  });

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on StudentOnlyException {
      throw const AuthFailure(
        'This app is for students only. Admin and Librarian accounts cannot sign in.',
        discardSession: true,
      );
    } on FormatException {
      throw const AuthFailure(
        'The server returned invalid account data. Please try again.',
        discardSession: true,
      );
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      final data = error.response?.data;
      final fields = <String, String>{};
      if (data is Map && data['fields'] is Map) {
        for (final key in [
          'name',
          'studentId',
          'email',
          'course',
          'otherProgram',
          'yearLevel',
          'password',
          'confirmPassword',
        ]) {
          final value = (data['fields'] as Map)[key];
          if (value is String && value.length <= 250) fields[key] = value;
        }
      }
      // Display only expected public validation/auth responses, never raw errors.
      final message = data is Map ? data['message'] : null;
      final safeMessage =
          [400, 401, 409, 429].contains(status) &&
              message is String &&
              message.length <= 250
          ? message
          : null;
      throw AuthFailure(
        safeMessage ??
            switch (status) {
              403 => 'You do not have access to this action.',
              404 => 'The requested resource was not found. Please refresh.',
              422 => 'The submitted information could not be accepted. Please check it and try again.',
              429 => 'Too many requests. Please wait and try again.',
              int code when code >= 500 =>
                'The server is temporarily unavailable. Please try again.',
              _
                  when error.type == DioExceptionType.connectionTimeout ||
                      error.type == DioExceptionType.receiveTimeout ||
                      error.type == DioExceptionType.sendTimeout =>
                'The server took too long to respond. It may be starting. Please try again.',
              _ =>
                'Cannot reach the server. Check your connection and try again.',
            },
        fields: fields,
        status: status,
      );
    }
  }
}

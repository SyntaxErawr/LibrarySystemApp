import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:librarysystemapp/models/borrowing.dart';
import 'package:librarysystemapp/providers/borrowing_provider.dart';
import 'package:librarysystemapp/providers/auth_provider.dart';
import 'package:librarysystemapp/services/borrowing_service.dart';
import 'package:librarysystemapp/services/auth_service.dart';
import 'package:librarysystemapp/services/api_service.dart';
import 'package:librarysystemapp/config/api_config.dart';

import 'auth_test.dart' show AuthAdapter, MemoryStore, testToken;

Map<String, dynamic> loan(
  String status, {
  String id = 'r1',
  String bookId = 'b1',
}) => {
  '_id': id,
  'book': {'_id': bookId, 'title': 'Book title', 'author': 'Author'},
  'status': status,
  'displayStatus': status,
  'requestedAt': '2026-10-22T16:30:00Z',
  if (['borrowed', 'overdue', 'returned'].contains(status)) ...{
    'borrowedAt': '2026-10-20T16:00:00Z',
    'dueDate': '2026-10-23T15:59:59.999Z',
  },
  if (status == 'returned') 'returnedAt': '2026-10-23T01:00:00Z',
  if (status == 'rejected') 'rejectionReason': 'Reference only',
};
Map<String, dynamic> borrowingPage(
  List<dynamic> records, {
  int page = 1,
  int pages = 1,
}) => {
  'borrowings': records,
  'total': records.length,
  'page': page,
  'pages': pages,
};

class CirculationAdapter extends AuthAdapter {
  List<Map<String, dynamic>> records = [];
  int writeStatus = 201;
  String writeError = 'This book is currently unavailable.';
  Future<void>? writeWait;
  int writes = 0;
  int availableCopies = 2;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path;
    if (path.startsWith('/api/borrowings/') &&
            path != '/api/borrowings/summary' ||
        path.startsWith('/api/books')) {
      requests.add(options);
      dynamic data;
      var status = 200;
      if (options.method != 'GET') {
        writes++;
        await writeWait;
        status = writeStatus;
        if (status < 300) {
          if (options.method == 'POST') {
            records.add(loan('pending'));
          } else {
            records = records
                .map(
                  (r) => {
                    ...r,
                    'status': 'cancelled',
                    'displayStatus': 'cancelled',
                  },
                )
                .toList();
          }
          summaryData = {
            'activeCount': 0,
            'pendingCount': records
                .where((r) => r['status'] == 'pending')
                .length,
            'overdueCount': 0,
            'recent': [],
          };
          data = options.method == 'POST'
              ? {'borrowing': loan('pending'), 'message': 'Request submitted.'}
              : {'message': 'Request cancelled.'};
        } else {
          data = {'message': writeError};
        }
      } else if (path.startsWith('/api/books')) {
        final book = {
          '_id': 'b1',
          'title': 'Book title',
          'author': 'Author',
          'isActive': true,
          'availableCopies': availableCopies,
          'totalCopies': 3,
        };
        data = path == '/api/books'
            ? {
                'books': [book],
                'categories': [],
                'page': 1,
                'pages': 1,
                'total': 1,
              }
            : {'book': book};
      } else {
        final filter = options.uri.queryParameters['status'];
        data = borrowingPage(
          records
              .where(
                (r) => filter == 'open'
                    ? ['pending', 'borrowed', 'overdue'].contains(r['status'])
                    : filter == 'active'
                    ? ['borrowed', 'overdue'].contains(r['status'])
                    : filter == 'history'
                    ? [
                        'returned',
                        'rejected',
                        'cancelled',
                      ].contains(r['status'])
                    : filter == 'pending'
                    ? r['status'] == 'pending'
                    : true,
              )
              .toList(),
        );
      }
      return ResponseBody.fromString(
        jsonEncode(data),
        status,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }
    return super.fetch(options, stream, cancelFuture);
  }
}

void main() {
  for (final status in [
    'pending',
    'borrowed',
    'overdue',
    'returned',
    'cancelled',
    'rejected',
  ]) {
    test('parses $status and populated book', () {
      final record = Borrowing.fromJson(loan(status));
      expect(record.status, status);
      expect(record.label, Borrowing.labels[status]);
      expect(record.bookId, 'b1');
      expect(record.pending, status == 'pending');
    });
  }
  test('legacy and missing data, Manila boundary, server overdue', () {
    final record = Borrowing.fromJson({
      '_id': 'x',
      'book': 'book-id',
      'status': 'borrowed',
      'displayStatus': 'overdue',
      'daysRemaining': -2,
      'dueAt': '2026-10-22T16:30:00Z',
    });
    expect(record.bookId, 'book-id');
    expect(record.author, 'Author unavailable');
    expect(Borrowing.date(record.dueDate), 'Oct 23, 2026 (Manila)');
    expect(record.label, 'Overdue');
    expect(record.daysRemaining, -2);
    expect(Borrowing.date(null), 'Not recorded');
    expect(() => Borrowing.fromJson({}), throwsFormatException);
  });
  test(
    'service uses own records and exact write contract without retries',
    () async {
      final calls = <Object>[];
      final service = BorrowingService(
        (path) async {
          calls.add(path);
          return borrowingPage([]);
        },
        (method, path, body) async {
          calls.add([method, path, body]);
          return {};
        },
      );
      expect((await service.list(status: 'history')).records, isEmpty);
      await service.request('b1');
      await service.cancel(Borrowing.fromJson(loan('pending')));
      expect(Uri.parse(calls[0] as String).path, '/borrowings/my');
      expect(calls[1], [
        'POST',
        '/borrowings/requests',
        {'book': 'b1'},
      ]);
      expect(calls[2], ['PATCH', '/borrowings/r1/cancel', {}]);
      await expectLater(
        service.cancel(Borrowing.fromJson(loan('borrowed'))),
        throwsA(isA<AuthFailure>()),
      );
      expect(calls.length, 3);
    },
  );
  test('open records block duplicates and combined three-item limit', () async {
    var records = [loan('pending')];
    final provider = BorrowingProvider(
      BorrowingService(
        (_) async => borrowingPage(records),
        (_, path, body) async => {},
      ),
      onChanged: () async {},
    );
    expect(provider.blocked('b1'), isNotNull);
    await provider.checkOpen();
    expect(provider.blocked('b1'), contains('Pending'));
    expect(provider.blocked('other'), isNull);
    records = [
      loan('pending'),
      loan('borrowed', id: '2', bookId: 'b2'),
      loan('overdue', id: '3', bookId: 'b3'),
    ];
    await provider.checkOpen();
    expect(provider.blocked('other'), contains('3 combined'));
    provider.dispose();
  });
  test(
    'write lock, post-action refresh, stock failure and no automatic retry',
    () async {
      final gate = Completer<void>();
      var writes = 0, updates = 0;
      final provider = BorrowingProvider(
        BorrowingService((_) async => borrowingPage([]), (_, path, body) async {
          writes++;
          await gate.future;
        }),
        onChanged: () async {
          updates++;
        },
      );
      final first = provider.request('b1');
      expect(await provider.request('b1'), false);
      expect(writes, 1);
      gate.complete();
      expect(await first, true);
      expect(updates, 1);
      expect(provider.notice, contains('not reserved'));
      provider.dispose();
      for (final message in [
        'You already have 3 combined pending requests and active loans.',
        'This book is currently unavailable.',
        'You already have a pending request or active loan for this book.',
        'Only pending requests can be changed.',
      ]) {
        var attempts = 0;
        final failed = BorrowingProvider(
          BorrowingService((_) async => borrowingPage([]), (
            _,
            path,
            body,
          ) async {
            attempts++;
            throw AuthFailure(message, status: 409);
          }),
          onChanged: () async {},
        );
        expect(await failed.request('b1'), false);
        expect(failed.actionError, message);
        expect(attempts, 1);
        failed.dispose();
      }
    },
  );
  for (final method in ['POST', 'PATCH']) {
    test('$method authenticates and clears expired session', () async {
      final adapter = CirculationAdapter()
        ..writeStatus = 401
        ..writeError = 'Session expired. Please log in again.';
      final dio = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl))
        ..httpClientAdapter = adapter;
      final store = MemoryStore()..value = testToken;
      final auth = AuthProvider(AuthService(ApiService(dio: dio)), store);
      await auth.restore();
      await expectLater(
        auth.authenticatedWrite(
          method,
          method == 'POST' ? '/borrowings/requests' : '/borrowings/r1/cancel',
          method == 'POST' ? {'book': 'b1'} : {},
        ),
        throwsA(isA<AuthFailure>()),
      );
      expect(
        adapter.requests.last.headers['Authorization'],
        'Bearer $testToken',
      );
      expect(auth.student, isNull);
      expect(store.value, isNull);
      expect(adapter.writes, 1);
      auth.dispose();
      dio.close();
    });
  }
}

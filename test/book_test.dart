import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:librarysystemapp/models/book.dart';
import 'package:librarysystemapp/providers/book_provider.dart';
import 'package:librarysystemapp/services/book_service.dart';

Map<String, dynamic> book(String id, {bool active = true}) => {
  '_id': id,
  'title': id,
  'author': 'Author',
  'isActive': active,
  'availableCopies': 2,
  'totalCopies': 5,
};
Map<String, dynamic> response(String id) => {
  'books': [book(id), book('archived', active: false)],
  'categories': ['Science'],
  'page': 1,
  'pages': 1,
  'total': 1,
};
void main() {
  test('preserves server stock and handles missing metadata safely', () {
    final b = Book.fromJson(book('id'));
    expect(b.availableCopies, 2);
    expect(b.totalCopies, 5);
    expect(b.description, 'No description provided.');
    expect(
      Book.fromJson({'_id': 'id'}).availability,
      'Availability not provided',
    );
    expect(() => Book.fromJson({}), throwsFormatException);
  });
  test('encodes supported filters and excludes archived results', () async {
    late Uri request;
    final service = BookService((path) async {
      request = Uri.parse(path);
      return response('active');
    });
    final result = await service.list(
      search: 'A & B',
      category: 'Science',
      available: true,
      page: 2,
    );
    expect(request.path, '/books');
    expect(request.queryParameters, {
      'search': 'A & B',
      'category': 'Science',
      'availability': 'available',
      'page': '2',
      'limit': '20',
    });
    expect(result.books.single.id, 'active');
  });
  test('newer request wins and identical refresh is deduplicated', () async {
    final first = Completer<dynamic>(), second = Completer<dynamic>();
    var calls = 0;
    final provider = BookProvider(
      BookService((_) => ++calls == 1 ? first.future : second.future),
    );
    final old = provider.refresh();
    final duplicate = provider.refresh();
    expect(calls, 1);
    provider.category = 'Science';
    final current = provider.refresh();
    second.complete(response('new'));
    await current;
    first.complete(response('old'));
    await Future.wait([old, duplicate]);
    expect(provider.books.single.id, 'new');
    provider.dispose();
  });
  test('invalid payload produces retryable error', () async {
    final provider = BookProvider(BookService((_) async => {}));
    await provider.refresh();
    expect(provider.error, isNotNull);
    expect(provider.loading, false);
    provider.dispose();
  });
}

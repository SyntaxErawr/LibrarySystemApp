import '../models/book.dart';
import 'auth_service.dart';

class BookPage {
  BookPage(this.books, this.categories, this.total, this.page, this.pages);
  final List<Book> books;
  final List<String> categories;
  final int total, page, pages;
}

class BookService {
  BookService(this.get);
  final Future<dynamic> Function(String path) get;
  Future<BookPage> list({
    String search = '',
    String category = '',
    bool available = false,
    int page = 1,
  }) async {
    final path = Uri(
      path: '/books',
      queryParameters: {
        'search': search,
        'category': category,
        'availability': available ? 'available' : '',
        'page': '$page',
        'limit': '20',
      },
    ).toString();
    final data = await get(path);
    if (data is! Map ||
        data['books'] is! List ||
        data['categories'] is! List ||
        data['total'] is! int ||
        data['page'] is! int ||
        data['pages'] is! int ||
        data['total'] < 0 ||
        data['page'] < 1 ||
        data['pages'] < 1) {
      throw const FormatException('Invalid catalog response.');
    }
    return BookPage(
      (data['books'] as List)
          .map(Book.fromJson)
          .where((b) => b.isActive)
          .toList(),
      (data['categories'] as List)
          .whereType<String>()
          .where((s) => s.trim().isNotEmpty)
          .toSet()
          .toList()
        ..sort(),
      data['total'],
      data['page'],
      data['pages'],
    );
  }

  Future<Book> details(String id) async {
    try {
      final data = await get('/books/${Uri.encodeComponent(id)}');
      if (data is! Map) throw const FormatException();
      final book = Book.fromJson(data['book']);
      if (!book.isActive) {
        throw const AuthFailure(
          'This book is no longer available in the catalog.',
        );
      }
      return book;
    } on AuthFailure catch (e) {
      if (e.status == 404) {
        throw const AuthFailure(
          'This book is no longer available in the catalog.',
        );
      }
      rethrow;
    }
  }
}

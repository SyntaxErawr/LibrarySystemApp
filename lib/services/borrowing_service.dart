import '../models/borrowing.dart';
import 'auth_service.dart';

class BorrowingPage {
  BorrowingPage(this.records, this.page, this.pages, this.total);
  final List<Borrowing> records;
  final int page, pages, total;
}

class BorrowingService {
  BorrowingService(this.get, this.write);
  final Future<dynamic> Function(String) get;
  final Future<dynamic> Function(String, String, Map<String, dynamic>) write;
  Future<BorrowingPage> list({String status = '', int page = 1}) async {
    final data = await get(
      Uri(
        path: '/borrowings/my',
        queryParameters: {'status': status, 'page': '$page', 'limit': '20'},
      ).toString(),
    );
    if (data is! Map ||
        data['borrowings'] is! List ||
        data['page'] is! int ||
        data['pages'] is! int ||
        data['total'] is! int ||
        data['page'] < 1 ||
        data['pages'] < 1 ||
        data['total'] < 0) {
      throw const FormatException('Invalid borrowing page.');
    }
    return BorrowingPage(
      (data['borrowings'] as List).map(Borrowing.fromJson).toList(),
      data['page'],
      data['pages'],
      data['total'],
    );
  }

  // The open list has at most three records under the verified backend rule.
  Future<List<Borrowing>> open() async => (await list(status: 'open')).records;
  Future<void> request(String bookId) async {
    await write('POST', '/borrowings/requests', {'book': bookId});
  }

  Future<void> cancel(Borrowing record) async {
    if (!record.pending) {
      throw const AuthFailure('Only pending requests can be changed.');
    }
    try {
      await write(
        'PATCH',
        '/borrowings/${Uri.encodeComponent(record.id)}/cancel',
        {},
      );
    } on AuthFailure catch (failure) {
      if (failure.status == 404) {
        throw const AuthFailure(
          'This request was not found. Refresh your records.',
          status: 404,
        );
      }
      rethrow;
    }
  }
}

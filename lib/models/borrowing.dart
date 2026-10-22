import 'package:intl/intl.dart';

class Borrowing {
  Borrowing.fromJson(dynamic data) {
    if (data is! Map ||
        data['_id'] is! String ||
        (data['_id'] as String).isEmpty) {
      throw const FormatException('Invalid borrowing record.');
    }
    id = data['_id'];
    final book = data['book'];
    bookId = book is String
        ? book
        : book is Map && book['_id'] is String
        ? book['_id']
        : '';
    title = book is Map && book['title'] is String
        ? book['title']
        : 'Book title unavailable';
    author = book is Map && book['author'] is String
        ? book['author']
        : 'Author unavailable';
    status = data['status'] is String ? data['status'] : '';
    displayStatus = data['displayStatus'] is String
        ? data['displayStatus']
        : status;
    requestedAt = parse(data['requestedAt']);
    borrowedAt = parse(data['borrowedAt']);
    dueDate = parse(data['dueDate']) ?? parse(data['dueAt']);
    returnedAt = parse(data['returnedAt']);
    rejectionReason = data['rejectionReason'] is String
        ? data['rejectionReason']
        : '';
    daysRemaining = data['daysRemaining'] is int ? data['daysRemaining'] : null;
  }
  late final String id,
      bookId,
      title,
      author,
      status,
      displayStatus,
      rejectionReason;
  late final DateTime? requestedAt, borrowedAt, dueDate, returnedAt;
  late final int? daysRemaining;
  bool get pending => status == 'pending';
  bool get open =>
      returnedAt == null && ['pending', 'borrowed', 'overdue'].contains(status);
  String get label => labels[displayStatus] ?? 'Status unavailable';
  static const labels = {
    'pending': 'Pending',
    'borrowed': 'Borrowed',
    'overdue': 'Overdue',
    'returned': 'Returned',
    'cancelled': 'Cancelled',
    'rejected': 'Rejected',
  };
  static DateTime? parse(dynamic value) =>
      value is String ? DateTime.tryParse(value) : null;
  static String date(DateTime? value) => value == null
      ? 'Not recorded'
      : '${DateFormat('MMM d, yyyy').format(value.toUtc().add(const Duration(hours: 8)))} (Manila)';
}

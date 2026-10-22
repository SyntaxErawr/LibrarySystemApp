import 'package:intl/intl.dart';

class DashboardSummary {
  const DashboardSummary({
    this.active,
    this.pending,
    this.overdue,
    this.recent,
  });
  final int? active, pending, overdue;
  final List<RecentActivity>? recent;

  factory DashboardSummary.fromJson(dynamic data) {
    if (data is! Map) throw const FormatException('Invalid summary.');
    int? count(String key) {
      final value = data[key];
      return value is int && value >= 0 ? value : null;
    }

    final records = data['recent'];
    return DashboardSummary(
      active: count('activeCount'),
      pending: count('pendingCount'),
      overdue: count('overdueCount'),
      recent: records is List && records.every((item) => item is Map)
          ? List.unmodifiable(
              records.map((item) => RecentActivity.fromJson(item as Map)),
            )
          : null,
    );
  }
}

class RecentActivity {
  const RecentActivity(this.title, this.status, this.date, this.dateLabel);
  final String title, status, dateLabel;
  final DateTime? date;
  static const statuses = {
    'pending': 'Pending',
    'borrowed': 'Borrowed',
    'overdue': 'Overdue',
    'returned': 'Returned',
    'rejected': 'Rejected',
    'cancelled': 'Cancelled',
  };

  factory RecentActivity.fromJson(Map data) {
    final book = data['book'];
    final title = book is Map ? book['title'] : null;
    // displayStatus is computed by the server in Asia/Manila. Never infer it
    // from the device clock, due date, or stored status.
    final status = data['displayStatus'];
    final (field, label) = switch (status) {
      'returned' => ('returnedAt', 'Returned'),
      'rejected' => ('reviewedAt', 'Reviewed'),
      'cancelled' => ('cancelledAt', 'Cancelled'),
      'borrowed' || 'overdue' => ('borrowedAt', 'Borrowed'),
      'pending' => ('requestedAt', 'Requested'),
      _ => ('createdAt', 'Created'),
    };
    DateTime? parse(dynamic value) =>
        value is String ? DateTime.tryParse(value) : null;
    final relevant = parse(data[field]);
    return RecentActivity(
      title is String && title.trim().isNotEmpty
          ? title
          : 'Book title unavailable',
      statuses[status] ?? 'Status unavailable',
      relevant ?? parse(data['createdAt']),
      relevant == null ? 'Created' : label,
    );
  }

  String get formattedDate => date == null
      ? 'Date not recorded'
      : '$dateLabel ${DateFormat('MMM d, yyyy').format(date!.toUtc().add(const Duration(hours: 8)))} · Manila';
}

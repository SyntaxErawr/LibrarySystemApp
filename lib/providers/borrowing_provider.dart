import 'package:flutter/foundation.dart';

import '../models/borrowing.dart';
import '../services/borrowing_service.dart';
import '../services/auth_service.dart';

class BorrowingProvider extends ChangeNotifier {
  BorrowingProvider(this.service, {required this.onChanged});
  final BorrowingService service;
  final Future<void> Function() onChanged;
  List<Borrowing> records = [], openRecords = [];
  bool loading = false, checking = false, writing = false, openKnown = false;
  String? error, actionError, notice;
  String filter = 'active';
  int page = 1, pages = 1;
  bool _disposed = false;
  int _generation = 0;
  Future<void>? _read, _check;
  void _emit() {
    if (!_disposed) notifyListeners();
  }

  String? blocked(String bookId) {
    if (!openKnown) return 'Refresh borrowing status before requesting.';
    for (final record in openRecords) {
      if (record.bookId == bookId && record.open) {
        return 'You already have this book: ${record.label}.';
      }
    }
    if (openRecords.where((r) => r.open).length >= 3) {
      return 'You already have 3 combined pending requests and active loans.';
    }
    return null;
  }

  Future<void> checkOpen() =>
      _disposed ? Future.value() : _check ??= _checkOpen();
  Future<void> _checkOpen() async {
    checking = true;
    _emit();
    try {
      final result = await service.open();
      if (!_disposed) {
        openRecords = result;
        openKnown = true;
      }
    } catch (_) {
      if (!_disposed) openKnown = false;
    } finally {
      _check = null;
      checking = false;
      _emit();
    }
  }

  Future<void> select(String value) {
    filter = value;
    _generation++;
    _read = null;
    return refresh();
  }

  Future<void> refresh() => _disposed ? Future.value() : _read ??= _load(1);
  Future<void> more() =>
      loading || page >= pages ? Future.value() : _read ??= _load(page + 1);
  Future<void> _load(int target) async {
    final generation = ++_generation;
    loading = true;
    error = null;
    if (target == 1) records = [];
    _emit();
    try {
      final result = await service.list(status: filter, page: target);
      if (!_disposed && generation == _generation) {
        records = target == 1
            ? result.records
            : [
                ...records,
                ...result.records.where(
                  (r) => !records.any((old) => old.id == r.id),
                ),
              ];
        page = result.page;
        pages = result.pages;
      }
    } catch (e) {
      if (!_disposed && generation == _generation) {
        error = e is AuthFailure
            ? e.message
            : 'Could not load borrowing records. Please try again.';
      }
    } finally {
      if (generation == _generation) {
        loading = false;
        _read = null;
        _emit();
      }
    }
  }

  Future<bool> request(String bookId) => _mutate(
    () => service.request(bookId),
    'Request submitted. Wait for staff approval; copies are not reserved.',
  );
  Future<bool> cancel(Borrowing record) => _mutate(
    () => service.cancel(record),
    'Request cancelled. Stock is unchanged.',
  );
  Future<bool> _mutate(Future<void> Function() action, String success) async {
    if (writing || _disposed) return false;
    writing = true;
    actionError = null;
    notice = null;
    _emit();
    bool succeeded = false;
    try {
      await action();
      succeeded = true;
      if (!_disposed) notice = success;
    } catch (e) {
      if (!_disposed) actionError = e is AuthFailure ? e.message : 'The action could not be confirmed. Refresh your records before trying again.';
    }
    if (!_disposed) {
      // Read after success or failure: a timed-out write may have committed.
      await _check;
      await checkOpen();
      _generation++;
      _read = null;
      await refresh();
      try {
        if (!_disposed) await onChanged();
      } catch (_) {
        /* Each read provider exposes its own refresh error. */
      }
    }
    writing = false;
    _emit();
    return succeeded;
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}

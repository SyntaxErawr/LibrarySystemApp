import 'package:flutter/foundation.dart';

import '../models/dashboard_summary.dart';
import '../services/auth_service.dart';
import '../services/dashboard_service.dart';

class DashboardProvider extends ChangeNotifier {
  DashboardProvider(this.service);
  final DashboardService service;
  DashboardSummary? summary;
  bool loading = false;
  String? error;
  bool _disposed = false;
  Future<void>? _request;
  int _generation = 0;

  Future<void> refresh({bool force = false}) {
    if (_disposed) return Future.value();
    if (force) _request = null;
    return _request ??= _load();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final result = await service.load();
      if (!_disposed && generation == _generation) summary = result;
    } on AuthFailure catch (failure) {
      if (!_disposed && generation == _generation) error = failure.message;
    } catch (_) {
      if (!_disposed && generation == _generation) {
        error = 'Library activity is unavailable. Please try again.';
      }
    } finally {
      if (!_disposed && generation == _generation) {
        _request = null;
        loading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

import '../models/dashboard_summary.dart';

class DashboardService {
  DashboardService(this.get);
  final Future<dynamic> Function(String path) get;

  Future<DashboardSummary> load() async =>
      DashboardSummary.fromJson(await get('/borrowings/summary'));
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.onSelectTab});
  final ValueChanged<int> onSelectTab;

  @override
  Widget build(BuildContext context) {
    final student = context.watch<AuthProvider>().student;
    final dashboard = context.watch<DashboardProvider>();
    final summary = dashboard.summary;
    if (student == null) return const SizedBox.shrink();
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: dashboard.refresh,
        child: SingleChildScrollView(
          key: const PageStorageKey('dashboard'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'LIBRARY MANAGEMENT SYSTEM',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.forest,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Welcome, ${student.name}!',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.deep,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('Your library activity, all in one place.'),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      onPressed: dashboard.loading ? null : dashboard.refresh,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh activity'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (dashboard.loading) ...[
                    const LinearProgressIndicator(
                      semanticsLabel: 'Loading library activity',
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (dashboard.error != null) ...[
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        dashboard.error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                    if (summary != null)
                      const Text(
                        'Showing previously loaded activity. Refresh to try again.',
                      ),
                    const SizedBox(height: 12),
                  ],
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 550 ? 3 : 1;
                      final width =
                          (constraints.maxWidth - (columns - 1) * 12) / columns;
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _SummaryCard(
                            label: 'Active borrowed books',
                            value: summary?.active,
                            icon: Icons.menu_book,
                            width: width,
                          ),
                          _SummaryCard(
                            label: 'Pending borrow requests',
                            value: summary?.pending,
                            icon: Icons.schedule,
                            width: width,
                          ),
                          _SummaryCard(
                            label: 'Overdue books',
                            value: summary?.overdue,
                            icon: Icons.event_busy,
                            width: width,
                            amber: true,
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Recent activity',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  if (summary?.recent == null)
                    Text(
                      dashboard.loading
                          ? 'Loading recent activity...'
                          : 'Recent activity is unavailable.',
                    )
                  else if (summary!.recent!.isEmpty)
                    const Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('No borrowing or request activity yet.'),
                      ),
                    )
                  else
                    ...summary.recent!.map(
                      (activity) => Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        color: AppTheme.sand,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                activity.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.deep,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(activity.status),
                              const SizedBox(height: 4),
                              Text(
                                activity.formattedDate,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.width,
    this.amber = false,
  });
  final String label;
  final int? value;
  final IconData icon;
  final double width;
  final bool amber;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Semantics(
      label: '$label: ${value ?? 'Unavailable'}',
      excludeSemantics: true,
      child: Card(
        margin: EdgeInsets.zero,
        color: AppTheme.sand,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: amber ? AppTheme.amber : AppTheme.sage,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Icon(icon, color: AppTheme.deep),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value?.toString() ?? 'Unavailable',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.deep,
                      ),
                    ),
                    Text(label),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

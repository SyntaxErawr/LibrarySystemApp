import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/borrowing.dart';
import '../../providers/borrowing_provider.dart';
import '../../config/app_theme.dart';

Future<bool> confirmBorrowing(
  BuildContext context,
  String title,
  String message,
  String action,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Go back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    ) ??
    false;

class BorrowRequestsScreen extends StatelessWidget {
  const BorrowRequestsScreen({super.key});
  @override
  Widget build(BuildContext context) => const BorrowingList();
}

class BorrowingList extends StatelessWidget {
  const BorrowingList({super.key});
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BorrowingProvider>();
    return RefreshIndicator(
      onRefresh: () async {
        await provider.refresh();
        await provider.checkOpen();
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          if (provider.loading)
            const LinearProgressIndicator(
              semanticsLabel: 'Loading borrowing records',
            ),
          if (provider.notice != null)
            Text(provider.notice!, semanticsLabel: provider.notice),
          if (provider.actionError != null)
            Text(
              provider.actionError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (provider.error != null) ...[
            Text(provider.error!),
            OutlinedButton(
              onPressed: provider.loading
                  ? null
                  : () => provider.records.isEmpty
                        ? provider.refresh()
                        : provider.more(),
              child: const Text('Retry'),
            ),
          ],
          if (!provider.loading &&
              provider.error == null &&
              provider.records.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No records in this section.'),
            ),
          for (final record in provider.records)
            Card(
              color: AppTheme.sand,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      record.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(record.author),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Chip(
                        label: Text(record.label),
                        backgroundColor: record.displayStatus == 'overdue'
                            ? AppTheme.amber
                            : null,
                      ),
                    ),
                    if (record.requestedAt != null)
                      Text('Requested: ${Borrowing.date(record.requestedAt)}'),
                    if (record.borrowedAt != null)
                      Text('Borrowed: ${Borrowing.date(record.borrowedAt)}'),
                    if ([
                      'borrowed',
                      'overdue',
                      'returned',
                    ].contains(record.displayStatus))
                      Text('Due: ${Borrowing.date(record.dueDate)}'),
                    if (record.daysRemaining case final days?)
                      Text(
                        days < 0
                            ? '${-days} days overdue'
                            : days == 0
                            ? 'Due today'
                            : '$days days remaining',
                      ),
                    if (record.returnedAt != null)
                      Text('Returned: ${Borrowing.date(record.returnedAt)}'),
                    if (record.rejectionReason.isNotEmpty)
                      Text('Reason: ${record.rejectionReason}'),
                    if (record.pending)
                      OutlinedButton(
                        onPressed: provider.writing
                            ? null
                            : () async {
                                if (await confirmBorrowing(
                                  context,
                                  'Cancel Request?',
                                  'Cancel your request for ${record.title}?',
                                  'Cancel Request',
                                )) {
                                  if (!context.mounted) return;
                                  await provider.cancel(record);
                                }
                              },
                        child: Text(
                          provider.writing
                              ? 'Please wait...'
                              : 'Cancel Request',
                        ),
                      ),
                  ],
                ),
              ),
            ),
          if (provider.records.isNotEmpty && provider.page < provider.pages)
            OutlinedButton(
              onPressed: provider.loading ? null : provider.more,
              child: const Text('Load more'),
            ),
        ],
      ),
    );
  }
}

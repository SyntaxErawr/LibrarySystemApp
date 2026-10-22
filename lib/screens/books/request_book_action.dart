import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/book.dart';
import '../../providers/borrowing_provider.dart';
import '../borrowings/borrow_requests_screen.dart';

class RequestBookAction extends StatefulWidget {
  const RequestBookAction({
    super.key,
    required this.book,
    required this.refreshBook,
  });
  final Book book;
  final Future<void> Function() refreshBook;
  @override
  State<RequestBookAction> createState() => _RequestBookActionState();
}

class _RequestBookActionState extends State<RequestBookAction> {
  bool confirming = false;
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) context.read<BorrowingProvider?>()?.checkOpen();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BorrowingProvider?>();
    if (provider == null) return const SizedBox.shrink();
    final unavailable =
        !widget.book.isActive || (widget.book.availableCopies ?? 0) < 1;
    final blocked = provider.blocked(widget.book.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (blocked != null) Text(blocked),
        if (unavailable) const Text('This book is currently unavailable.'),
        if (!provider.openKnown)
          OutlinedButton(
            onPressed: provider.checking ? null : provider.checkOpen,
            child: const Text('Refresh borrowing status'),
          ),
        FilledButton(
          onPressed:
              unavailable ||
                  blocked != null ||
                  provider.writing ||
                  confirming ||
                  provider.checking
              ? null
              : () async {
                  setState(() => confirming = true);
                  final confirmed = await confirmBorrowing(
                    context,
                    'Request Book?',
                    'Request ${widget.book.title}? Staff approval is required. Pending requests do not reserve copies.',
                    'Submit Request',
                  );
                  if (!mounted) return;
                  setState(() => confirming = false);
                  if (confirmed) {
                    await provider.request(widget.book.id);
                    if (mounted) await widget.refreshBook();
                  }
                },
          child: Text(provider.writing ? 'Submitting...' : 'Request Book'),
        ),
        if (provider.notice != null)
          Text(provider.notice!, semanticsLabel: provider.notice),
        if (provider.actionError != null)
          Text(
            provider.actionError!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        const Text('Review requests in My Books > Pending Requests.'),
        const SizedBox(height: 16),
      ],
    );
  }
}

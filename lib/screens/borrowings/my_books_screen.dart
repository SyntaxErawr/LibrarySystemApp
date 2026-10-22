import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/borrowing_provider.dart';
import 'borrow_requests_screen.dart';

class MyBooksScreen extends StatefulWidget {
  const MyBooksScreen({super.key});
  @override
  State<MyBooksScreen> createState() => _MyBooksScreenState();
}

class _MyBooksScreenState extends State<MyBooksScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) {
        context.read<BorrowingProvider>().refresh();
        context.read<BorrowingProvider>().checkOpen();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BorrowingProvider>();
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: DropdownButtonFormField<String>(
              initialValue: provider.filter,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'My Books'),
              items: const [
                DropdownMenuItem(
                  value: 'active',
                  child: Text('Currently Borrowed'),
                ),
                DropdownMenuItem(
                  value: 'pending',
                  child: Text('Pending Requests'),
                ),
                DropdownMenuItem(
                  value: 'history',
                  child: Text('Borrowing History'),
                ),
              ],
              onChanged: provider.writing
                  ? null
                  : (value) {
                      if (value != null) provider.select(value);
                    },
            ),
          ),
          Expanded(
            child: provider.filter == 'pending'
                ? const BorrowRequestsScreen()
                : const BorrowingList(),
          ),
        ],
      ),
    );
  }
}

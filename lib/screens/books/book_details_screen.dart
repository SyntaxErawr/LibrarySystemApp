import 'package:flutter/material.dart';

import '../../models/book.dart';
import '../../services/book_service.dart';
import '../../services/auth_service.dart';
import 'request_book_action.dart';

class BookDetailsScreen extends StatefulWidget {
  const BookDetailsScreen({
    super.key,
    required this.id,
    required this.service,
    required this.onBack,
  });
  final String id;
  final BookService service;
  final VoidCallback onBack;
  @override
  State<BookDetailsScreen> createState() => _BookDetailsScreenState();
}

class _BookDetailsScreenState extends State<BookDetailsScreen> {
  Book? book;
  String? error;
  bool loading = true;
  Future<void>? _request;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() => _request ??= _fetch();

  Future<void> _fetch() async {
    setState(() {
      loading = true;
      error = null;
      book = null;
    });
    try {
      final result = await widget.service.details(widget.id);
      if (mounted) setState(() => book = result);
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is AuthFailure
              ? e.message
              : 'Could not load book details. Please try again.',
        );
      }
    } finally {
      _request = null;
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: _load,
    child: ListView(
      padding: const EdgeInsets.all(20),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: widget.onBack,
            icon: const Icon(Icons.arrow_back),
            label: const Text('Back to books'),
          ),
        ),
        if (loading) const Center(child: CircularProgressIndicator()),
        if (error != null) ...[
          Text(error!),
          OutlinedButton(onPressed: _load, child: const Text('Retry')),
        ],
        if (book case final b?) ...[
          BookCover(book: b, size: 120),
          const SizedBox(height: 20),
          Text(b.title, style: Theme.of(context).textTheme.headlineSmall),
          Text(b.author, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          Text(b.stock),
          const SizedBox(height: 16),
          RequestBookAction(book: b, refreshBook: _load),
          for (final field in {
            'ISBN': b.isbn,
            'Category': b.category,
            'Publisher': b.publisher,
            'Publication year': b.publicationYear?.toString() ?? 'Not provided',
            'Shelf location': b.shelfLocation,
            'Description': b.description,
          }.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    field.key,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(field.value),
                ],
              ),
            ),
        ],
      ],
    ),
  );
}

class BookCover extends StatelessWidget {
  const BookCover({super.key, required this.book, this.size = 56});
  final Book book;
  final double size;
  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(book.coverImageUrl);
    final placeholder = Icon(
      Icons.menu_book_outlined,
      size: size,
      color: Theme.of(context).colorScheme.primary,
    );
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      return placeholder;
    }
    return Image.network(
      uri.toString(),
      width: size,
      height: size * 1.3,
      fit: BoxFit.contain,
      errorBuilder: (_, error, stack) => placeholder,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/book_provider.dart';
import 'book_details_screen.dart';

class BookCatalogScreen extends StatefulWidget {
  const BookCatalogScreen({super.key, this.active = true});
  final bool active;
  @override
  State<BookCatalogScreen> createState() => _BookCatalogScreenState();
}

class _BookCatalogScreenState extends State<BookCatalogScreen> {
  String? selected;
  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<BookProvider>();
    if (selected != null) {
      return PopScope(
        canPop: !widget.active,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop && widget.active) setState(() => selected = null);
        },
        child: BookDetailsScreen(
          key: ValueKey(selected),
          id: selected!,
          service: catalog.service,
          onBack: () => setState(() => selected = null),
        ),
      );
    }
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: catalog.refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Explore Books',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: catalog.search,
                    maxLength: 120,
                    onChanged: catalog.searchChanged,
                    decoration: const InputDecoration(
                      labelText: 'Search title, author, or ISBN',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: catalog.category,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('All categories'),
                      ),
                      for (final category in {
                        ...catalog.categories,
                        if (catalog.category.isNotEmpty) catalog.category,
                      })
                        DropdownMenuItem(
                          value: category,
                          child: Text(
                            category,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (value) => catalog.filter(category: value),
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('All Books'),
                        selected: !catalog.available,
                        onSelected: (_) => catalog.filter(available: false),
                      ),
                      ChoiceChip(
                        label: const Text('Available Books'),
                        selected: catalog.available,
                        onSelected: (_) => catalog.filter(available: true),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            if (catalog.loading)
              const LinearProgressIndicator(semanticsLabel: 'Loading books'),
            if (catalog.error != null) ...[
              Text(catalog.error!, semanticsLabel: catalog.error),
              OutlinedButton(
                onPressed: catalog.loading
                    ? null
                    : () => catalog.books.isEmpty
                          ? catalog.refresh()
                          : catalog.nextPage(),
                child: const Text('Retry'),
              ),
            ],
            if (!catalog.loading &&
                catalog.error == null &&
                catalog.books.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('No books found. Try another search or filter.'),
              ),
            for (final book in catalog.books)
              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  leading: BookCover(book: book, size: 40),
                  title: Text(book.title),
                  subtitle: Text(
                    '${book.author}\n${book.category}\n${book.stock}',
                  ),
                  isThreeLine: true,
                  onTap: () => setState(() => selected = book.id),
                ),
              ),
            if (catalog.books.isNotEmpty)
              Text('${catalog.books.length} of ${catalog.total} books'),
            if (catalog.books.isNotEmpty && catalog.page < catalog.pages)
              OutlinedButton(
                onPressed: catalog.loading ? null : catalog.nextPage,
                child: const Text('Load more'),
              ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:librarysystemapp/providers/book_provider.dart';
import 'package:librarysystemapp/services/book_service.dart';
import 'package:librarysystemapp/screens/books/book_catalog_screen.dart';

import 'book_test.dart' show book, response;

void main() {
  testWidgets(
    'small phone catalog searches, opens fresh details and fits keyboard',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final requests = <String>[];
      final provider = BookProvider(
        BookService((path) async {
          requests.add(path);
          return path.startsWith('/books/')
              ? {'book': book('Catalog title')}
              : response('Catalog title');
        }),
      );
      await provider.refresh();
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: const MaterialApp(home: Scaffold(body: BookCatalogScreen())),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Catalog title'));
      await tester.pumpAndSettle();
      expect(requests.last, '/books/Catalog%20title');
      await tester.scrollUntilVisible(
        find.text('No description provided.'),
        200,
      );
      expect(find.text('No description provided.'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Back to books'), -200);
      await tester.tap(find.text('Back to books'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'new search');
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(Uri.parse(requests.last).queryParameters['search'], 'new search');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      provider.dispose();
    },
  );
}

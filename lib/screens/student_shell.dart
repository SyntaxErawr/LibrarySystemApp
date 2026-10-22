import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/dashboard_provider.dart';
import '../services/dashboard_service.dart';
import '../services/book_service.dart';
import '../providers/book_provider.dart';
import 'books/book_catalog_screen.dart';
import 'dashboard/dashboard_screen.dart';
import 'profile/profile_screen.dart';
import '../providers/borrowing_provider.dart';
import '../services/borrowing_service.dart';
import 'borrowings/my_books_screen.dart';

class StudentShell extends StatefulWidget {
  const StudentShell({super.key});
  @override
  State<StudentShell> createState() => _StudentShellState();
}

class _StudentShellState extends State<StudentShell> {
  int _index = 0;
  bool _catalogOpened = false;
  bool _myBooksOpened = false;
  void _select(int index) => setState(() {
    _index = index;
    if (index == 1) _catalogOpened = true;
    if (index == 2) _myBooksOpened = true;
  });

  @override
  Widget build(BuildContext context) => MultiProvider(
    providers: [
      ChangeNotifierProvider(
        create: (_) => BookProvider(
          BookService(context.read<AuthProvider>().authenticatedGet),
        )..refresh(),
      ),
      ChangeNotifierProvider(
        create: (_) => DashboardProvider(
          DashboardService(context.read<AuthProvider>().authenticatedGet),
        )..refresh(),
      ),
      ChangeNotifierProvider(
        create: (scope) => BorrowingProvider(
          BorrowingService(
            context.read<AuthProvider>().authenticatedGet,
            context.read<AuthProvider>().authenticatedWrite,
          ),
          onChanged: () async {
            await Future.wait([
              scope.read<DashboardProvider>().refresh(force: true),
              scope.read<BookProvider>().refresh(force: true),
            ]);
          },
        ),
      ),
    ],
    child: Scaffold(
      appBar: AppBar(
        title: Text(['By the Book', 'Books', 'My Books', 'My Profile'][_index]),
      ),
      body: IndexedStack(
        index: _index,
        children: [
          DashboardScreen(onSelectTab: _select),
          _index == 1 || _catalogOpened
              ? BookCatalogScreen(active: _index == 1)
              : const SizedBox.shrink(),
          _myBooksOpened ? const MyBooksScreen() : const SizedBox.shrink(),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _select,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            label: 'Books',
          ),
          NavigationDestination(
            icon: Icon(Icons.bookmark_border),
            label: 'My Books',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    ),
  );
}

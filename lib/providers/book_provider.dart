import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/book.dart';
import '../services/book_service.dart';
import '../services/auth_service.dart';

class BookProvider extends ChangeNotifier {
  BookProvider(this.service);
  final BookService service;
  List<Book> books = [];
  List<String> categories = [];
  String search = '', category = '';
  bool available = false, loading = false;
  String? error;
  int page = 1, pages = 1, total = 0;
  int _generation = 0;
  bool _disposed = false;
  Timer? _debounce;
  Future<void>? _request;
  void searchChanged(String value) {
    search = value;
    _generation++;
    _request = null;
    _debounce?.cancel();
    books = [];
    loading = true;
    error = null;
    notifyListeners();
    _debounce = Timer(const Duration(milliseconds: 350), refresh);
  }

  void filter({String? category, bool? available}) {
    this.category = category ?? this.category;
    this.available = available ?? this.available;
    refresh();
  }

  Future<void> refresh({bool force = false}) {
    if (_disposed) return Future.value();
    _debounce?.cancel();
    if (force) _request = null;
    return _load(1);
  }

  Future<void> nextPage() =>
      loading || page >= pages ? Future.value() : _load(page + 1);
  Future<void> _load(int requestedPage) {
    if (_disposed) return Future.value();
    final key = '$search|$category|$available|$requestedPage';
    if (_request != null && key == _key) return _request!;
    _key = key;
    final generation = ++_generation;
    loading = true;
    error = null;
    if (requestedPage == 1) books = [];
    notifyListeners();
    return _request = _fetch(generation, requestedPage);
  }

  String? _key;
  Future<void> _fetch(int generation, int requestedPage) async {
    try {
      final result = await service.list(
        search: search,
        category: category,
        available: available,
        page: requestedPage,
      );
      if (_disposed || generation != _generation) return;
      books = requestedPage == 1
          ? result.books
          : [
              ...books,
              ...result.books.where((b) => !books.any((old) => old.id == b.id)),
            ];
      categories = result.categories;
      page = result.page;
      pages = result.pages;
      total = result.total;
    } catch (e) {
      if (!_disposed && generation == _generation) {
        error = e is AuthFailure
            ? e.message
            : 'Could not load books. Please try again.';
      }
    } finally {
      if (!_disposed && generation == _generation) {
        loading = false;
        _request = null;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    super.dispose();
  }
}

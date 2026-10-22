class Book {
  Book.fromJson(dynamic data) {
    if (data is! Map ||
        data['_id'] is! String ||
        (data['_id'] as String).isEmpty) {
      throw const FormatException('Invalid book data.');
    }
    id = data['_id'];
    String text(String key, String fallback) =>
        data[key] is String && (data[key] as String).trim().isNotEmpty
        ? data[key]
        : fallback;
    title = text('title', 'Title not provided');
    author = text('author', 'Author not provided');
    isbn = text('isbn', 'Not provided');
    category = text('category', 'Not provided');
    description = text('description', 'No description provided.');
    publisher = text('publisher', 'Not provided');
    shelfLocation = text('shelfLocation', 'Not provided');
    coverImageUrl = text('coverImageUrl', '');
    publicationYear = quantity(data['publicationYear']);
    totalCopies = quantity(data['totalCopies']);
    availableCopies = quantity(data['availableCopies']);
    isActive = data['isActive'] == true;
  }
  late final String id,
      title,
      author,
      isbn,
      category,
      description,
      publisher,
      shelfLocation,
      coverImageUrl;
  late final int? totalCopies, availableCopies, publicationYear;
  late final bool isActive;
  static int? quantity(dynamic value) =>
      value is num &&
          value.isFinite &&
          value >= 0 &&
          value == value.roundToDouble()
      ? value.toInt()
      : null;
  String get availability => availableCopies == null
      ? 'Availability not provided'
      : availableCopies! > 0
      ? 'Available'
      : 'Unavailable';
  String get stock =>
      '$availability · ${availableCopies ?? "?"} of ${totalCopies ?? "?"} copies available';
}

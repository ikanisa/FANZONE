// Convenience extensions used across the app.

extension StringX on String {
  /// Capitalises the first letter.
  String get capitalised =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';

  /// Sanitises a search term for safe use in ILIKE queries.
  String get sanitisedForSearch => trim()
      .replaceAll(RegExp(r'''[,%()'"\\\;_\-]'''), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

extension NullableStringX on String? {
  /// Returns the value or a fallback.
  String orDefault([String fallback = '']) => this ?? fallback;
}

extension ListX<T> on List<T> {
  /// Safe indexing — returns null if out of bounds.
  T? getOrNull(int index) =>
      (index >= 0 && index < length) ? this[index] : null;
}

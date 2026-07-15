/// Formats TMDB-style ratings consistently for display and persistence.
///
/// Existing databases may contain values such as `8.381`; the UI should show
/// a stable one-decimal score (`8.4`) without requiring a data migration.
String? formatRating(Object? value) {
  if (value == null) return null;
  final raw = value.toString().trim();
  if (raw.isEmpty) return null;
  final number = double.tryParse(raw);
  if (number == null || !number.isFinite) return raw;
  return number.toStringAsFixed(1);
}

import 'library_shelf.dart';
import 'media.dart';

/// Sort options shared by library browsing and search surfaces.
enum MediaSort {
  title,
  recentlyAdded,
  year,
  rating;

  String get label => switch (this) {
    MediaSort.title => '标题 A-Z',
    MediaSort.recentlyAdded => '最近添加',
    MediaSort.year => '年份',
    MediaSort.rating => '评分',
  };
}

/// Query parameters for a library browse request.
///
/// Prefer [shelf] for sidebar sections (互斥分类). [type] remains for legacy
/// unmatched / type-only views. At least one of [shelf] or [type] should be set.
class MediaLibraryQuery {
  const MediaLibraryQuery({
    this.type,
    this.shelf,
    this.searchTerm = '',
    this.sort = MediaSort.title,
    this.genreTerms = const [],
  }) : assert(
         type != null || shelf != null,
         'MediaLibraryQuery requires type and/or shelf',
       );

  final MediaType? type;
  final LibraryShelf? shelf;
  final String searchTerm;
  final MediaSort sort;
  final List<String> genreTerms;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MediaLibraryQuery &&
        other.type == type &&
        other.shelf == shelf &&
        other.searchTerm == searchTerm &&
        other.sort == sort &&
        _listEquals(other.genreTerms, genreTerms);
  }

  @override
  int get hashCode =>
      Object.hash(type, shelf, searchTerm, sort, Object.hashAll(genreTerms));
}

bool _listEquals(List<String> left, List<String> right) {
  if (left.length != right.length) return false;
  for (var i = 0; i < left.length; i++) {
    if (left[i] != right[i]) return false;
  }
  return true;
}

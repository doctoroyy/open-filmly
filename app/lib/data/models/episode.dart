/// Domain model for a single episode within a TV show.
class Episode {
  const Episode({
    required this.id,
    required this.showId,
    required this.seasonNumber,
    required this.episodeNumber,
    this.title = '',
    required this.path,
    this.fullPath,
    this.dateAdded = '',
  });

  final String id;
  final String showId;
  final int seasonNumber;
  final int episodeNumber;
  final String title;
  final String path;
  final String? fullPath;
  final String dateAdded;

  Episode copyWith({
    String? id,
    String? showId,
    int? seasonNumber,
    int? episodeNumber,
    String? title,
    String? path,
    String? fullPath,
    String? dateAdded,
  }) {
    return Episode(
      id: id ?? this.id,
      showId: showId ?? this.showId,
      seasonNumber: seasonNumber ?? this.seasonNumber,
      episodeNumber: episodeNumber ?? this.episodeNumber,
      title: title ?? this.title,
      path: path ?? this.path,
      fullPath: fullPath ?? this.fullPath,
      dateAdded: dateAdded ?? this.dateAdded,
    );
  }

  /// Display label for this episode, e.g. "S01E03 - The One".
  String get displayLabel {
    final code =
        'S${seasonNumber.toString().padLeft(2, '0')}E${episodeNumber.toString().padLeft(2, '0')}';
    return title.isEmpty ? code : '$code - $title';
  }
}

/// A season grouping — just a convenience container, not persisted.
class Season {
  const Season({required this.number, required this.episodes});

  final int number;
  final List<Episode> episodes;

  String get label => 'Season $number';
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/library_shelf.dart';
import '../../widgets/filmly_design.dart';

/// Mobile "我的" tab — short list, no ActionSheet.
/// Secondary shelves (动漫/综艺/…) live here as full-page navigations.
class MePage extends StatelessWidget {
  const MePage({super.key});

  static const _browse = <({LibraryShelf shelf, IconData icon})>[
    (shelf: LibraryShelf.anime, icon: Icons.animation_rounded),
    (shelf: LibraryShelf.variety, icon: Icons.live_tv_rounded),
    (shelf: LibraryShelf.concert, icon: Icons.music_note_rounded),
    (shelf: LibraryShelf.documentary, icon: Icons.menu_book_rounded),
    (shelf: LibraryShelf.other, icon: Icons.more_horiz_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
        children: [
          const Text(
            '我的',
            style: TextStyle(
              color: FilmlyPalette.textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 20),
          _section(
            children: [
              _tile(
                context,
                icon: Icons.favorite_rounded,
                label: '收藏',
                onTap: () => context.push('/favorites'),
              ),
              _tile(
                context,
                icon: Icons.settings_rounded,
                label: '设置',
                onTap: () => context.push('/config'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              '浏览分类',
              style: TextStyle(
                color: FilmlyPalette.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          _section(
            children: [
              for (final item in _browse)
                _tile(
                  context,
                  icon: item.icon,
                  label: item.shelf.label,
                  onTap: () => context.push(_pathFor(item.shelf)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static String _pathFor(LibraryShelf shelf) => switch (shelf) {
    LibraryShelf.movie => '/movies',
    LibraryShelf.tv => '/tv',
    LibraryShelf.anime => '/anime',
    LibraryShelf.variety => '/variety',
    LibraryShelf.concert => '/concert',
    LibraryShelf.documentary => '/documentary',
    LibraryShelf.other => '/other',
  };

  Widget _section({required List<Widget> children}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: FilmlyPalette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: FilmlyPalette.divider),
      ),
      child: Column(children: children),
    );
  }

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: FilmlyPalette.accent, size: 22),
      title: Text(
        label,
        style: const TextStyle(
          color: FilmlyPalette.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: FilmlyPalette.textMuted,
      ),
      onTap: onTap,
    );
  }
}

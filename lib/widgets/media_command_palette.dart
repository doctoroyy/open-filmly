import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/platform/open_player.dart';
import '../core/router/app_router.dart';
import '../data/models/media.dart';
import '../features/player/player_page.dart';
import '../providers/data_providers.dart';
import '../providers/intelligence_providers.dart';
import '../services/intelligence/semantic_search_service.dart';
import 'filmly_design.dart';

/// Desktop-first command palette. Search opens library destinations directly;
/// only an explicit handoff starts a durable Filmly conversation.
class MediaCommandPalette {
  const MediaCommandPalette._();

  static Future<void> show(BuildContext context) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Search your library',
      barrierColor: Colors.black.withValues(alpha: 0.34),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (_, _, _) => _MediaCommandPaletteSheet(appContext: context),
      transitionBuilder: (context, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.985, end: 1).animate(curved),
            alignment: Alignment.topCenter,
            child: child,
          ),
        );
      },
    );
  }
}

enum _PaletteAction { openResult, askAll, continueConversation }

class _PaletteEntry {
  const _PaletteEntry.result(this.result)
    : action = _PaletteAction.openResult;

  const _PaletteEntry.action(this.action) : result = null;

  final _PaletteAction action;
  final AskFilmlyResult? result;

  bool get isResult => action == _PaletteAction.openResult && result != null;
}

class _MediaCommandPaletteSheet extends ConsumerStatefulWidget {
  const _MediaCommandPaletteSheet({required this.appContext});

  /// The shell context that opened this dialog. Dialog contexts cannot be
  /// trusted for subsequent GoRouter navigation once the dialog is dismissed.
  final BuildContext appContext;

  @override
  ConsumerState<_MediaCommandPaletteSheet> createState() =>
      _MediaCommandPaletteSheetState();
}

class _MediaCommandPaletteSheetState
    extends ConsumerState<_MediaCommandPaletteSheet> {
  static const _canvas = Color(0xFFF6F5F2);
  static const _elevated = Color(0xFFFFFDFC);
  static const _rule = Color(0xFFE5E2DC);
  static const _warmFocus = Color(0xFFEAF1FF);
  static const _filmlyBlue = Color(0xFF246BDE);

  final _controller = TextEditingController();
  late final _focusNode = FocusNode(onKeyEvent: _handleFieldKeyEvent);
  String _query = '';
  int _selectedIndex = 0;
  List<_PaletteEntry> _entries = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _close() {
    // GoRouter's ShellRoute keeps an inner navigator for content pages while
    // showGeneralDialog uses the root one. Clear only popup routes there so a
    // destination push cannot leave this modal barrier on top of the page.
    final rootNavigator = Navigator.of(widget.appContext, rootNavigator: true);
    rootNavigator.popUntil((route) => route is! PopupRoute);
  }

  Future<void> _dismissForNavigation() async {
    _close();
    // A GoRouter transition issued in the same frame can retain a
    // showGeneralDialog route above the new destination on desktop. Let the
    // palette's own exit transition settle before changing the shell route.
    await Future<void>.delayed(const Duration(milliseconds: 190));
  }

  Future<void> _openResult(AskFilmlyResult result) async {
    await _dismissForNavigation();
    if (!widget.appContext.mounted) return;
    if (result.isScene && result.uri != null && result.startMs != null) {
      await openPlayer(
        widget.appContext,
        PlayerArgs(
          uri: result.uri!,
          title: result.title,
          mediaId: result.mediaId,
          startAt: Duration(milliseconds: result.startMs!),
        ),
      );
      return;
    }
    final id = result.mediaId;
    if (id != null && widget.appContext.mounted) {
      widget.appContext.push(mediaDetailLocation(id));
    }
  }

  Future<void> _openAgent() async {
    final prompt = _query.trim();
    await _dismissForNavigation();
    if (!widget.appContext.mounted) return;
    final location = prompt.isEmpty
        ? '/agent'
        : '/agent?prompt=${Uri.encodeQueryComponent(prompt)}';
    widget.appContext.push(location);
  }

  Future<void> _openAskFilmly() async {
    final query = _query.trim();
    await _dismissForNavigation();
    if (!widget.appContext.mounted) return;
    final location = query.isEmpty
        ? '/ask'
        : '/ask?q=${Uri.encodeQueryComponent(query)}';
    widget.appContext.push(location);
  }

  void _updateQuery(String value) {
    setState(() {
      _query = value;
      _selectedIndex = 0;
      _entries = const [];
    });
  }

  int _effectiveSelectedIndex(List<_PaletteEntry> items) {
    if (items.isEmpty) return 0;
    return _selectedIndex.clamp(0, items.length - 1);
  }

  Future<void> _activateSelectedEntry() async {
    final items = _entries;
    if (items.isEmpty) {
      if (_query.trim().isEmpty) {
        await _openAgent();
      } else {
        await _openAskFilmly();
      }
      return;
    }
    final entry = items[_effectiveSelectedIndex(items)];
    switch (entry.action) {
      case _PaletteAction.openResult:
        final result = entry.result;
        if (result != null) await _openResult(result);
      case _PaletteAction.askAll:
        await _openAskFilmly();
      case _PaletteAction.continueConversation:
        await _openAgent();
    }
  }

  KeyEventResult _handleFieldKeyEvent(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape ||
        (key == LogicalKeyboardKey.keyK &&
            (HardwareKeyboard.instance.isMetaPressed ||
                HardwareKeyboard.instance.isControlPressed))) {
      _close();
      return KeyEventResult.handled;
    }

    final items = _entries;
    if (items.isNotEmpty && key == LogicalKeyboardKey.arrowDown) {
      setState(() {
        _selectedIndex = (_effectiveSelectedIndex(items) + 1) % items.length;
      });
      return KeyEventResult.handled;
    }
    if (items.isNotEmpty && key == LogicalKeyboardKey.arrowUp) {
      setState(() {
        _selectedIndex =
            (_effectiveSelectedIndex(items) - 1 + items.length) % items.length;
      });
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      if (HardwareKeyboard.instance.isShiftPressed) {
        _openAgent();
        return KeyEventResult.handled;
      }
      _activateSelectedEntry();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  List<_PaletteEntry> _buildEntries(List<AskFilmlyResult> items) {
    if (items.isEmpty) {
      return const [
        _PaletteEntry.action(_PaletteAction.askAll),
        _PaletteEntry.action(_PaletteAction.continueConversation),
      ];
    }
    final media = items.where((item) => !item.isScene).take(5).toList();
    final moments = items.where((item) => item.isScene).take(5).toList();
    return [
      ...media.map(_PaletteEntry.result),
      ...moments.map(_PaletteEntry.result),
      const _PaletteEntry.action(_PaletteAction.continueConversation),
    ];
  }

  /// Prefer recently watched titles, then recently added, capped at three
  /// local destinations for the empty palette state.
  List<AskFilmlyResult> _recentDestinations() {
    final watched =
        ref.watch(recentlyWatchedMediaProvider).asData?.value ??
        const <Media>[];
    final recent =
        ref.watch(recentMediaProvider).asData?.value ?? const <Media>[];
    final seen = <String>{};
    final destinations = <AskFilmlyResult>[];
    for (final media in [...watched, ...recent]) {
      if (!seen.add(media.id)) continue;
      destinations.add(
        AskFilmlyResult(
          title: media.title,
          year: media.year.isEmpty ? null : media.year,
          mediaId: media.id,
          snippet: media.overview?.trim().isNotEmpty == true
              ? media.overview!.trim()
              : (media.type == MediaType.tv ? 'TV series' : 'Movie'),
          reason: 'Recent destination',
          score: 1,
        ),
      );
      if (destinations.length >= 3) break;
    }
    return destinations;
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim();
    final results = query.isEmpty
        ? const AsyncData<List<AskFilmlyResult>>([])
        : ref.watch(askFilmlyProvider(query));

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): _close,
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): _close,
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): _close,
      },
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            MediaQuery.sizeOf(context).height * 0.12,
            20,
            24,
          ),
          child: Material(
            key: const Key('media_command_palette'),
            color: Colors.transparent,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720, maxHeight: 640),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: _elevated,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _rule),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 40,
                      offset: Offset(0, 18),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _inputBar(),
                    const Divider(height: 1, color: _rule),
                    Flexible(child: _body(query, results)),
                    const Divider(height: 1, color: _rule),
                    _footer(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _inputBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 14, 15),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, size: 20, color: FilmlyPalette.textMuted),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              key: const Key('media_command_palette_field'),
              controller: _controller,
              focusNode: _focusNode,
              autofocus: true,
              onChanged: _updateQuery,
              onSubmitted: (_) => _activateSelectedEntry(),
              style: const TextStyle(
                color: FilmlyPalette.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.2,
              ),
              decoration: const InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: 'Search your library',
                hintStyle: TextStyle(
                  color: FilmlyPalette.textMuted,
                  fontSize: 17,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
          if (_query.isNotEmpty)
            IconButton(
              tooltip: 'Clear',
              onPressed: () {
                _controller.clear();
                _updateQuery('');
                _focusNode.requestFocus();
              },
              icon: const Icon(Icons.close_rounded, size: 19),
            )
          else
            const _KeyHint(label: 'ESC'),
        ],
      ),
    );
  }

  Widget _body(String query, AsyncValue<List<AskFilmlyResult>> results) {
    if (query.isEmpty) {
      final recent = _recentDestinations();
      _entries = [
        ...recent.map(_PaletteEntry.result),
        const _PaletteEntry.action(_PaletteAction.continueConversation),
      ];
      return _emptyState(recent);
    }
    return results.when(
      loading: () {
        _entries = const [];
        return const SizedBox(
          height: 230,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        );
      },
      error: (error, _) {
        _entries = const [
          _PaletteEntry.action(_PaletteAction.continueConversation),
        ];
        return _notice(
          icon: Icons.cloud_off_rounded,
          title: 'Search is temporarily unavailable',
          detail: '$error',
        );
      },
      data: (items) => _results(items),
    );
  }

  Widget _emptyState(List<AskFilmlyResult> recent) {
    final selectedIndex = _effectiveSelectedIndex(_entries);
    final children = <Widget>[
      const _SectionLabel('SEARCH YOUR LIBRARY'),
      const SizedBox(height: 9),
      const Text(
        'Type a title, a person, a line, or the moment you remember.',
        style: TextStyle(
          color: FilmlyPalette.textSecondary,
          fontSize: 13,
          height: 1.45,
        ),
      ),
      const SizedBox(height: 10),
      Text(
        'e.g. 唐朝诡事录 · 雨夜 长安 · 宫崎骏',
        style: TextStyle(
          color: FilmlyPalette.textMuted.withValues(alpha: 0.9),
          fontSize: 12,
        ),
      ),
    ];

    if (recent.isNotEmpty) {
      children.add(const SizedBox(height: 16));
      children.add(const _SectionLabel('RECENT'));
      children.add(const SizedBox(height: 6));
      for (var i = 0; i < recent.length; i++) {
        children.add(
          _resultRow(
            recent[i],
            resultIndex: i,
            selected: i == selectedIndex,
          ),
        );
      }
    }

    children.add(const SizedBox(height: 12));
    children.add(
      _commandRow(
        key: const Key('media_command_palette_continue_conversation'),
        icon: Icons.arrow_outward_rounded,
        title: 'Continue in Filmly',
        subtitle: 'Use a durable conversation for a question or a safe plan',
        outcome: 'Ask',
        selected: recent.length == selectedIndex,
        onTap: _openAgent,
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _results(List<AskFilmlyResult> items) {
    final entries = _buildEntries(items);
    _entries = entries;
    final selectedIndex = _effectiveSelectedIndex(entries);

    if (items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
        children: [
          const _SectionLabel('NO LOCAL MATCHES'),
          const SizedBox(height: 10),
          const Text(
            'Try a title, a person, or describe a moment you remember.',
            style: TextStyle(
              color: FilmlyPalette.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          const _SectionLabel('ASK'),
          const SizedBox(height: 6),
          _commandRow(
            key: const Key('media_command_palette_ask_all'),
            icon: Icons.travel_explore_rounded,
            title: 'Search all in Ask Filmly',
            subtitle: 'Open the full search workspace with this query',
            outcome: 'Open',
            selected: selectedIndex == 0,
            onTap: _openAskFilmly,
          ),
          _commandRow(
            key: const Key('media_command_palette_continue_conversation'),
            icon: Icons.forum_outlined,
            title: 'Continue in Filmly',
            subtitle: 'Ask a follow-up or prepare a safe plan',
            outcome: 'Ask',
            selected: selectedIndex == 1,
            onTap: _openAgent,
          ),
        ],
      );
    }

    final media = items.where((item) => !item.isScene).take(5).toList();
    final moments = items.where((item) => item.isScene).take(5).toList();
    final children = <Widget>[];
    var entryIndex = 0;
    var resultIndex = 0;

    if (media.isNotEmpty) {
      children.add(
        const Padding(
          padding: EdgeInsets.only(bottom: 6),
          child: _SectionLabel('BEST MATCH'),
        ),
      );
      for (final result in media) {
        final index = entryIndex;
        children.add(
          _resultRow(
            result,
            resultIndex: resultIndex,
            selected: index == selectedIndex,
          ),
        );
        entryIndex += 1;
        resultIndex += 1;
      }
    }

    if (moments.isNotEmpty) {
      children.add(
        Padding(
          padding: EdgeInsets.only(top: media.isEmpty ? 0 : 10, bottom: 6),
          child: const _SectionLabel('MOMENTS'),
        ),
      );
      for (final result in moments) {
        final index = entryIndex;
        children.add(
          _resultRow(
            result,
            resultIndex: resultIndex,
            selected: index == selectedIndex,
          ),
        );
        entryIndex += 1;
        resultIndex += 1;
      }
    }

    children.add(
      const Padding(
        padding: EdgeInsets.only(top: 10, bottom: 6),
        child: _SectionLabel('ASK'),
      ),
    );
    children.add(
      _commandRow(
        key: const Key('media_command_palette_continue_conversation'),
        icon: Icons.forum_outlined,
        title: 'Continue in Filmly',
        subtitle: 'Ask a follow-up or prepare a safe plan',
        outcome: 'Ask',
        selected: entryIndex == selectedIndex,
        onTap: _openAgent,
      ),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
      children: children,
    );
  }

  Widget _resultRow(
    AskFilmlyResult result, {
    required int resultIndex,
    required bool selected,
  }) {
    final time = result.startMs == null
        ? null
        : _formatTimestamp(Duration(milliseconds: result.startMs!));
    final outcome = result.isScene
        ? (time == null ? 'Play' : 'Play $time')
        : 'Open';
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        key: Key('media_command_result_$resultIndex'),
        onTap: () => _openResult(result),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          key: selected
              ? Key('media_command_result_${resultIndex}_selected')
              : null,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: selected ? _warmFocus : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border(
              left: BorderSide(
                color: selected ? _filmlyBlue : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: result.isScene
                        ? _filmlyBlue.withValues(alpha: 0.11)
                        : _canvas,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    result.isScene
                        ? Icons.play_arrow_rounded
                        : Icons.movie_outlined,
                    color: result.isScene
                        ? _filmlyBlue
                        : FilmlyPalette.textSecondary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              result.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: FilmlyPalette.textPrimary,
                              ),
                            ),
                          ),
                          if (result.year?.isNotEmpty == true) ...[
                            const SizedBox(width: 6),
                            Text(
                              result.year!,
                              style: const TextStyle(
                                color: FilmlyPalette.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (result.snippet.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            result.snippet,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: FilmlyPalette.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      const SizedBox(height: 5),
                      Text(
                        result.reason,
                        style: const TextStyle(
                          color: FilmlyPalette.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  outcome,
                  style: TextStyle(
                    color: result.isScene
                        ? _filmlyBlue
                        : FilmlyPalette.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _commandRow({
    Key? key,
    required IconData icon,
    required String title,
    required String subtitle,
    required String outcome,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: selected ? _warmFocus : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border(
            left: BorderSide(
              color: selected ? _filmlyBlue : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
          child: Row(
            children: [
              Icon(icon, size: 20, color: FilmlyPalette.textSecondary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: FilmlyPalette.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: FilmlyPalette.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                outcome,
                style: const TextStyle(
                  color: FilmlyPalette.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _notice({
    required IconData icon,
    required String title,
    required String detail,
  }) {
    return SizedBox(
      height: 220,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 42),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 28, color: FilmlyPalette.textMuted),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: FilmlyPalette.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                detail,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: FilmlyPalette.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _footer() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      child: Row(
        children: [
          _KeyHint(label: '↑↓ Navigate'),
          SizedBox(width: 8),
          _KeyHint(label: '↵ Open'),
          SizedBox(width: 8),
          _KeyHint(label: '⇧↵ Continue'),
          Spacer(),
          _KeyHint(label: 'Esc'),
        ],
      ),
    );
  }

  String _formatTimestamp(Duration value) {
    String two(int number) => number.toString().padLeft(2, '0');
    if (value.inHours > 0) {
      return '${two(value.inHours)}:${two(value.inMinutes.remainder(60))}:${two(value.inSeconds.remainder(60))}';
    }
    return '${two(value.inMinutes)}:${two(value.inSeconds.remainder(60))}';
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: const TextStyle(
      color: FilmlyPalette.textMuted,
      fontSize: 10,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.05,
    ),
  );
}

class _KeyHint extends StatelessWidget {
  const _KeyHint({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: const Color(0xFFEAEAF0),
      borderRadius: BorderRadius.circular(5),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: FilmlyPalette.textSecondary,
        fontSize: 10,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/platform/open_player.dart';
import '../core/router/app_router.dart';
import '../features/player/player_page.dart';
import '../providers/intelligence_providers.dart';
import '../services/intelligence/semantic_search_service.dart';
import 'filmly_design.dart';

/// Desktop-first command palette for the parts of a media library that are
/// hard to reach through a traditional title search: scenes, dialogue and
/// natural-language intent. The full Agent remains available as a route for
/// multi-step conversations and confirmations.
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
  final _controller = TextEditingController();
  late final _focusNode = FocusNode(onKeyEvent: _handleFieldKeyEvent);
  String _query = '';
  int _selectedResultIndex = 0;
  List<AskFilmlyResult> _visibleResults = const [];

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

  List<AskFilmlyResult> _activeResults() {
    return _visibleResults;
  }

  void _updateQuery(String value) {
    setState(() {
      _query = value;
      _selectedResultIndex = 0;
      _visibleResults = const [];
    });
  }

  int _effectiveSelectedIndex(List<AskFilmlyResult> items) {
    if (items.isEmpty) return 0;
    return _selectedResultIndex.clamp(0, items.length - 1);
  }

  Future<void> _activateSelectedResult() async {
    final items = _activeResults();
    if (items.isEmpty) {
      await _openAskFilmly();
      return;
    }
    await _openResult(items[_effectiveSelectedIndex(items)]);
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

    final items = _activeResults();
    if (items.isNotEmpty && key == LogicalKeyboardKey.arrowDown) {
      setState(() {
        _selectedResultIndex =
            (_effectiveSelectedIndex(items) + 1) % items.length;
      });
      return KeyEventResult.handled;
    }
    if (items.isNotEmpty && key == LogicalKeyboardKey.arrowUp) {
      setState(() {
        _selectedResultIndex =
            (_effectiveSelectedIndex(items) - 1 + items.length) % items.length;
      });
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      _activateSelectedResult();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
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
          padding: const EdgeInsets.fromLTRB(20, 92, 20, 24),
          child: Material(
            key: const Key('media_command_palette'),
            color: Colors.transparent,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720, maxHeight: 640),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFFF9F9FB),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE0E0E7)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x40000000),
                      blurRadius: 52,
                      offset: Offset(0, 22),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _inputBar(),
                    const Divider(height: 1, color: FilmlyPalette.divider),
                    Flexible(child: _body(query, results)),
                    const Divider(height: 1, color: FilmlyPalette.divider),
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
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: FilmlyPalette.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              size: 18,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              key: const Key('media_command_palette_field'),
              controller: _controller,
              focusNode: _focusNode,
              autofocus: true,
              onChanged: _updateQuery,
              onSubmitted: (_) => _activateSelectedResult(),
              style: const TextStyle(
                color: FilmlyPalette.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.2,
              ),
              decoration: const InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: 'Search scenes, dialogue, people, or a feeling…',
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
      _visibleResults = const [];
      return _emptyState();
    }
    return results.when(
      loading: () {
        _visibleResults = const [];
        return const SizedBox(
          height: 230,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        );
      },
      error: (error, _) {
        _visibleResults = const [];
        return _notice(
          icon: Icons.cloud_off_rounded,
          title: 'Search is temporarily unavailable',
          detail: '$error',
        );
      },
      data: (items) => _results(items),
    );
  }

  Widget _emptyState() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel('START HERE'),
          const SizedBox(height: 8),
          _commandRow(
            icon: Icons.manage_search_rounded,
            title: 'Search your library',
            subtitle: 'Find films, dialogue, scenes, and themes',
            onTap: () => _focusNode.requestFocus(),
          ),
          _commandRow(
            key: const Key('media_command_palette_open_agent'),
            icon: Icons.forum_outlined,
            title: 'Open Media Agent',
            subtitle: 'Plan library work and carry on a conversation',
            onTap: _openAgent,
          ),
          _commandRow(
            icon: Icons.travel_explore_rounded,
            title: 'Browse Ask Filmly',
            subtitle: 'Use the full search workspace',
            onTap: _openAskFilmly,
          ),
        ],
      ),
    );
  }

  Widget _results(List<AskFilmlyResult> items) {
    if (items.isEmpty) {
      return _notice(
        icon: Icons.search_off_rounded,
        title: 'No library matches yet',
        detail: 'Try a title, a person, or describe a moment you remember.',
      );
    }
    final visibleItems = items.take(8).toList(growable: false);
    _visibleResults = visibleItems;
    final selectedIndex = _effectiveSelectedIndex(visibleItems);
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
      itemCount: visibleItems.length + 2,
      itemBuilder: (context, index) {
        if (index == 0) {
          return const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: _SectionLabel('RESULTS FROM YOUR LIBRARY'),
          );
        }
        if (index == visibleItems.length + 1) {
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _commandRow(
              icon: Icons.forum_outlined,
              title: 'Continue in Media Agent',
              subtitle: 'Ask a follow-up or prepare a safe action plan',
              onTap: _openAgent,
            ),
          );
        }
        return _resultRow(
          visibleItems[index - 1],
          index: index - 1,
          selected: index - 1 == selectedIndex,
        );
      },
    );
  }

  Widget _resultRow(
    AskFilmlyResult result, {
    required int index,
    required bool selected,
  }) {
    final time = result.startMs == null
        ? null
        : _formatTimestamp(Duration(milliseconds: result.startMs!));
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        key: Key('media_command_result_$index'),
        onTap: () => _openResult(result),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          key: selected ? Key('media_command_result_${index}_selected') : null,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: selected
                ? FilmlyPalette.accent.withValues(alpha: 0.10)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: result.isScene
                        ? FilmlyPalette.accent.withValues(alpha: 0.11)
                        : FilmlyPalette.surface,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    result.isScene
                        ? Icons.play_arrow_rounded
                        : Icons.movie_outlined,
                    color: result.isScene
                        ? FilmlyPalette.accent
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
                      Wrap(
                        spacing: 7,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            result.reason,
                            style: const TextStyle(
                              color: FilmlyPalette.textMuted,
                              fontSize: 11,
                            ),
                          ),
                          if (time != null)
                            Text(
                              time,
                              style: const TextStyle(
                                color: FilmlyPalette.accent,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  result.isScene
                      ? Icons.play_circle_fill_rounded
                      : Icons.arrow_outward_rounded,
                  size: 19,
                  color: result.isScene
                      ? FilmlyPalette.accent
                      : FilmlyPalette.textMuted,
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
    required VoidCallback onTap,
  }) {
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
            const Icon(
              Icons.arrow_forward_rounded,
              size: 17,
              color: FilmlyPalette.textMuted,
            ),
          ],
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
          Text(
            'ASK FILMLY',
            style: TextStyle(
              color: FilmlyPalette.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          Spacer(),
          _KeyHint(label: '↵  Open'),
          SizedBox(width: 8),
          _KeyHint(label: '⌘K  Toggle'),
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

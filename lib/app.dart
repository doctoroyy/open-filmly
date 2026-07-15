import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'core/platform/platform_capabilities.dart';
import 'core/router/app_router.dart';
import 'widgets/filmly_design.dart';

/// Root application widget.
///
/// Keeps MaterialApp.router for go_router while applying a Filmly-inspired
/// desktop theme with softened dark tones and no Material chrome.
class OpenFilmlyApp extends StatelessWidget {
  const OpenFilmlyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Open Filmly',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const _FilmlyScrollBehavior(),
      theme: ThemeData(
        brightness: Brightness.light,
        useMaterial3: true,
        scaffoldBackgroundColor: FilmlyPalette.background,
        colorScheme: const ColorScheme.light(
          primary: FilmlyPalette.primary,
          secondary: FilmlyPalette.accent,
          surface: FilmlyPalette.background,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: FilmlyPalette.textPrimary,
          error: Color(0xFFE5484D),
          onError: Colors.white,
        ),
        splashFactory: NoSplash.splashFactory,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.black.withValues(alpha: 0.04),
        focusColor: FilmlyPalette.accent.withValues(alpha: 0.12),
        visualDensity: PlatformCapabilities.isDesktop
            ? VisualDensity.compact
            : VisualDensity.standard,
        dividerColor: FilmlyPalette.divider,
        shadowColor: Colors.black.withValues(alpha: 0.10),
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: FilmlyPalette.accent,
          selectionColor: Color(0x332F6BFF),
          selectionHandleColor: FilmlyPalette.accent,
        ),
        cupertinoOverrideTheme: const CupertinoThemeData(
          brightness: Brightness.light,
          primaryColor: FilmlyPalette.accent,
          scaffoldBackgroundColor: FilmlyPalette.background,
          barBackgroundColor: FilmlyPalette.background,
          textTheme: CupertinoTextThemeData(
            textStyle: TextStyle(
              color: FilmlyPalette.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
            navTitleTextStyle: TextStyle(
              color: FilmlyPalette.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            color: FilmlyPalette.textPrimary,
            fontSize: 34,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.7,
          ),
          headlineMedium: TextStyle(
            color: FilmlyPalette.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
          titleLarge: TextStyle(
            color: FilmlyPalette.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
          ),
          bodyLarge: TextStyle(
            color: FilmlyPalette.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
          bodyMedium: TextStyle(
            color: FilmlyPalette.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w400,
          ),
          labelLarge: TextStyle(
            color: FilmlyPalette.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
        ),
      ),
      routerConfig: appRouter,
    );
  }
}

class _FilmlyScrollBehavior extends MaterialScrollBehavior {
  const _FilmlyScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return PlatformCapabilities.isDesktop
        ? const ClampingScrollPhysics()
        : const BouncingScrollPhysics();
  }
}

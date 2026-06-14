import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_skill/flutter_skill.dart';

import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (kDebugMode) {
    FlutterSkillBinding.ensureInitialized();
  }
  runApp(const ProviderScope(child: OpenFilmlyApp()));
}

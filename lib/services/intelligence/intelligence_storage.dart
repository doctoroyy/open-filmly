import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Returns the private, disposable AI cache root. It is intentionally kept
/// outside user media folders so subtitle generation never changes library
/// contents or requires write access to a NAS/WebDAV source.
Future<Directory> defaultIntelligenceDirectory() async {
  final support = await getApplicationSupportDirectory();
  final root = p.basename(support.path).toLowerCase() == 'open filmly'
      ? support
      : Platform.isMacOS
      ? Directory(p.join(support.parent.path, 'Open Filmly'))
      : Directory(p.join(support.path, 'Open Filmly'));
  return Directory(p.join(root.path, 'intelligence'));
}

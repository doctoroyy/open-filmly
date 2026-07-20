import 'package:flutter_test/flutter_test.dart';
import 'package:open_filmly/data/models/app_config.dart';

void main() {
  test('keeps legacy config compatible and round-trips AI settings', () {
    final legacy = AppConfig.fromJson({
      'tmdbApiKey': 'tmdb',
      'selectedFolders': ['/Movies'],
    });
    expect(legacy.aiExecutionMode, 'local');
    expect(legacy.aiTargetLanguage, 'zh-CN');
    expect(legacy.aiMemoryEnabled, isTrue);

    final configured = legacy.copyWith(
      aiWorkerPath: '/usr/local/bin/open-filmly-ai-worker',
      aiModelDirectory: '/Models',
      aiModel: 'medium',
      aiAllowRemoteText: true,
      aiMemoryEnabled: false,
    );
    final restored = AppConfig.fromJson(configured.toJson());

    expect(restored.aiWorkerPath, configured.aiWorkerPath);
    expect(restored.aiModelDirectory, configured.aiModelDirectory);
    expect(restored.aiModel, 'medium');
    expect(restored.aiAllowRemoteText, isTrue);
    expect(restored.aiMemoryEnabled, isFalse);
    expect(restored.selectedFolders, ['/Movies']);
  });
}

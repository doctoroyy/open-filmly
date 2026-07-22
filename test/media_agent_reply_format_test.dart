import 'package:flutter_test/flutter_test.dart';
import 'package:open_filmly/features/intelligence/media_agent_page.dart';

void main() {
  test('normalizes simple model Markdown before displaying an Agent reply', () {
    expect(
      normalizeAgentReply('**操作：** 建立智能合集\n\n## 下一步\n- 先审核'),
      '操作： 建立智能合集\n\n下一步\n- 先审核',
    );
  });
}

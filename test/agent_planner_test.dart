import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:open_filmly/data/intelligence/agent_models.dart';
import 'package:open_filmly/services/intelligence/agent_planner.dart';

void main() {
  test('parses Gemini JSON into a safe media operation', () async {
    final client = _FakeClient(
      _geminiResponse({
        'operation': 'smartCollection',
        'query': '科幻 太空',
        'collectionName': '太空科幻',
        'reasoning': '用户要求建立一个科幻合集',
      }),
    );
    final planner = GeminiAgentPlanner(
      apiKey: 'gemini-test-key',
      client: client,
    );

    final intent = await planner.plan('把太空科幻电影整理成合集');

    expect(intent.operation, MediaAgentOperation.smartCollection);
    expect(intent.query, '科幻 太空');
    expect(intent.collectionName, '太空科幻');
    expect(client.lastHeaders?['x-goog-api-key'], 'gemini-test-key');
    expect(client.lastBody, contains('把太空科幻电影整理成合集'));
    expect(client.lastBody, isNot(contains('gemini-test-key')));
  });

  test('rejects operations outside the safe agent allowlist', () async {
    final planner = GeminiAgentPlanner(
      apiKey: 'gemini-test-key',
      client: _FakeClient(_geminiResponse({'operation': 'deleteFiles'})),
    );

    expect(() => planner.plan('删除重复文件'), throwsA(isA<AgentPlannerException>()));
  });

  test('requires a configured Gemini key', () async {
    final planner = GeminiAgentPlanner(
      apiKey: '',
      client: _FakeClient(_geminiResponse({'operation': 'listUnwatched'})),
    );

    expect(
      () => planner.plan('找出很久没看的电影'),
      throwsA(isA<AgentPlannerException>()),
    );
  });
}

String _geminiResponse(Map<String, dynamic> value) => jsonEncode({
  'candidates': [
    {
      'content': {
        'parts': [
          {'text': '```json\n${jsonEncode(value)}\n```'},
        ],
      },
    },
  ],
});

class _FakeClient extends http.BaseClient {
  _FakeClient(this.body);

  final String body;
  Map<String, String>? lastHeaders;
  String? lastBody;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    lastHeaders = request.headers;
    if (request is http.Request) lastBody = request.body;
    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(body)),
      200,
      headers: const {'content-type': 'application/json'},
    );
  }
}

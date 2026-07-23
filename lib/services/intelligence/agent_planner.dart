import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../data/intelligence/agent_models.dart';
import 'local_rule_agent_planner.dart';

class AgentIntent {
  const AgentIntent({
    required this.operation,
    this.query = '',
    this.collectionName,
    this.reasoning = '',
  });

  final MediaAgentOperation operation;
  final String query;
  final String? collectionName;
  final String reasoning;
}

abstract interface class MediaAgentPlanner {
  Future<AgentIntent> plan(String request);
}

/// Prefer offline rules for common library jobs; escalate free-form NL to a
/// remote planner when configured.
class CompositeMediaAgentPlanner implements MediaAgentPlanner {
  CompositeMediaAgentPlanner({
    required this.local,
    this.remote,
  });

  final LocalRuleAgentPlanner local;
  final MediaAgentPlanner? remote;

  @override
  Future<AgentIntent> plan(String request) async {
    final matched = local.tryMatch(request);
    if (matched != null) return matched;
    final cloud = remote;
    if (cloud != null) return cloud.plan(request);
    return local.plan(request);
  }
}

class AgentPlannerException implements Exception {
  const AgentPlannerException(this.message);

  final String message;

  @override
  String toString() => 'AgentPlannerException: $message';
}

/// Converts a natural-language request into the small, safe operation
/// allowlist supported by [MediaAgentService]. Gemini never receives media
/// files or paths and never executes an operation directly.
class GeminiAgentPlanner implements MediaAgentPlanner {
  GeminiAgentPlanner({
    required this.apiKey,
    this.model = 'gemini-2.5-flash',
    this.client,
  });

  final String apiKey;
  final String model;
  final http.Client? client;

  @override
  Future<AgentIntent> plan(String request) async {
    final normalized = request.trim();
    if (apiKey.trim().isEmpty) {
      throw const AgentPlannerException('尚未配置 Gemini API Key');
    }
    if (normalized.isEmpty) {
      throw const AgentPlannerException('请输入希望 Agent 执行的任务');
    }

    final requestClient = client ?? http.Client();
    try {
      final endpoint = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent',
      );
      final response = await requestClient
          .post(
            endpoint,
            headers: {
              'Content-Type': 'application/json',
              'x-goog-api-key': apiKey.trim(),
            },
            body: jsonEncode({
              'contents': [
                {
                  'role': 'user',
                  'parts': [
                    {'text': _prompt(normalized)},
                  ],
                },
              ],
              'generationConfig': {
                'temperature': 0,
                'maxOutputTokens': 512,
                'responseMimeType': 'application/json',
                'responseSchema': {
                  'type': 'object',
                  'properties': {
                    'operation': {
                      'type': 'string',
                      'enum': [
                        for (final value in MediaAgentOperation.values)
                          value.name,
                      ],
                    },
                    'query': {'type': 'string'},
                    'collectionName': {'type': 'string'},
                    'reasoning': {'type': 'string'},
                  },
                  'required': ['operation'],
                  'propertyOrdering': [
                    'operation',
                    'query',
                    'collectionName',
                    'reasoning',
                  ],
                },
              },
            }),
          )
          .timeout(const Duration(seconds: 45));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw AgentPlannerException(
          'Gemini 请求失败（HTTP ${response.statusCode}）：${_errorSummary(response.body)}',
        );
      }
      return _parseResponse(response.body);
    } on AgentPlannerException {
      rethrow;
    } catch (error) {
      throw AgentPlannerException('Gemini Agent 规划失败：$error');
    } finally {
      if (client == null) requestClient.close();
    }
  }

  AgentIntent _parseResponse(String body) {
    try {
      final decoded = jsonDecode(body);
      Map<String, dynamic>? candidate;
      if (decoded is Map && decoded['candidates'] is List) {
        final candidates = decoded['candidates'] as List;
        if (candidates.isNotEmpty && candidates.first is Map) {
          candidate = Map<String, dynamic>.from(candidates.first as Map);
        }
      }
      final content = candidate?['content'];
      final parts = content is Map ? content['parts'] : null;
      String? rawText;
      if (parts is List && parts.isNotEmpty && parts.first is Map) {
        rawText = (parts.first as Map)['text']?.toString();
      }
      if (rawText == null || rawText.trim().isEmpty) {
        throw const AgentPlannerException('Gemini 没有返回 Agent 规划');
      }
      final jsonText = _stripJsonEnvelope(rawText);
      final value = jsonDecode(jsonText);
      if (value is! Map) {
        throw const AgentPlannerException('Gemini 返回的规划不是 JSON 对象');
      }
      final operationName = value['operation']?.toString().trim() ?? '';
      final operation = MediaAgentOperation.values.firstWhere(
        (item) => item.name == operationName,
        orElse: () => throw AgentPlannerException(
          'Gemini 返回了不允许的 Agent 操作：$operationName',
        ),
      );
      return AgentIntent(
        operation: operation,
        query: value['query']?.toString().trim() ?? '',
        collectionName: value['collectionName']?.toString().trim(),
        reasoning: value['reasoning']?.toString().trim() ?? '',
      );
    } on AgentPlannerException {
      rethrow;
    } catch (error) {
      throw AgentPlannerException('无法解析 Gemini Agent 规划：$error');
    }
  }

  String _stripJsonEnvelope(String value) {
    var result = value.trim();
    result = result
        .replaceFirst(RegExp(r'^```(?:json)?\s*'), '')
        .replaceFirst(RegExp(r'\s*```$'), '')
        .trim();
    final start = result.indexOf('{');
    final end = result.lastIndexOf('}');
    if (start >= 0 && end > start) {
      result = result.substring(start, end + 1);
    }
    return result;
  }

  String _errorSummary(String body) {
    try {
      final value = jsonDecode(body);
      if (value is Map) {
        final error = value['error'];
        if (error is Map) {
          final message = error['message']?.toString().trim();
          if (message != null && message.isNotEmpty) {
            return message.length > 240
                ? '${message.substring(0, 240)}…'
                : message;
          }
        }
      }
    } catch (_) {
      // Use the generic status below when the provider returned non-JSON text.
    }
    return '服务未返回可用错误说明';
  }

  String _prompt(String request) =>
      '''
你是 Open Filmly 的私人影视库 Agent 规划器。你的工作只是把用户请求转换成一个安全的结构化计划，不执行任何操作。

用户请求：$request

只允许返回以下 operation 之一：
- batchSubtitles：批量生成字幕
- findDuplicates：查找重复媒体，只生成报告
- inspectLowQuality：检查低画质文件，只生成报告
- smartCollection：建立智能合集
- listUnwatched：列出长期未观看内容
- customFilter：按照复合条件筛选报告
- libraryReport：影视库全盘统计与健康度分析

规则：
1. 删除、移动、重命名、覆盖文件等请求不得映射到任何破坏性操作；请选择最接近的只读报告操作，或返回 listUnwatched。
2. 如果用户要求合集，填写 query 和 collectionName。
3. 如果用户没有提供合集名称，collectionName 留空。
4. 只返回 JSON，不要 markdown，不要额外解释。
''';
}

import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../data/intelligence/agent_models.dart';
import '../../data/repositories/media_repository.dart';
import '../../data/repositories/playback_progress_repository.dart';
import 'agent_planner.dart';
import 'agent_tools.dart';
import 'media_agent_service.dart';

class ConversationalTurnResult {
  const ConversationalTurnResult({
    required this.replyText,
    this.plan,
    this.toolsUsed = const [],
  });

  final String replyText;
  final MediaAgentPlan? plan;
  final List<String> toolsUsed;
}

class ConversationalAgentEngine {
  ConversationalAgentEngine({
    required this.apiKey,
    required this.mediaRepository,
    required this.progressRepository,
    required this.agentService,
    this.model = 'gemini-2.5-flash',
    this.client,
  });

  final String apiKey;
  final MediaRepository mediaRepository;
  final PlaybackProgressRepository progressRepository;
  final MediaAgentService agentService;
  final String model;
  final http.Client? client;

  final List<Map<String, dynamic>> _history = [];

  List<Map<String, dynamic>> get history => List.unmodifiable(_history);

  void clearHistory() => _history.clear();

  Future<ConversationalTurnResult> sendUserMessage(String userPrompt) async {
    if (apiKey.trim().isEmpty) {
      throw const AgentPlannerException('尚未配置 Gemini API Key');
    }
    final input = userPrompt.trim();
    if (input.isEmpty) {
      throw const AgentPlannerException('请输入有效的对话内容');
    }

    _history.add({
      'role': 'user',
      'parts': [
        {'text': input},
      ],
    });

    final requestClient = client ?? http.Client();
    final toolsUsed = <String>[];
    MediaAgentPlan? generatedPlan;
    String finalReply = '';

    try {
      final endpoint = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent',
      );

      var loopCount = 0;
      while (loopCount < 5) {
        loopCount++;

        final requestBody = jsonEncode({
          'systemInstruction': {
            'parts': [
              {
                'text': '''
你是 Open Filmly 的高级影视库 AI Copilot。你拥有影视库的多维度工具可供调阅。

指导原则：
1. 始终亲切、专业地解答用户问题。
2. 尽可能利用工具（如 search_media, get_library_stats, analyze_viewing_habits 等）获取真实影视数据后再做推演和推荐。
3. 如果用户的请求涉及生成计划（如“建合集”、“批量生成字幕”、“筛选低画质文件”等），在回复中清晰说明，并选出对应的操作。
''',
              },
            ],
          },
          'contents': _history,
          'tools': [
            {
              'functionDeclarations': AgentTools.declarations,
            },
          ],
          'generationConfig': {
            'temperature': 0.2,
            'maxOutputTokens': 1024,
          },
        });

        final response = await requestClient
            .post(
              endpoint,
              headers: {
                'Content-Type': 'application/json',
                'x-goog-api-key': apiKey.trim(),
              },
              body: requestBody,
            )
            .timeout(const Duration(seconds: 45));

        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw AgentPlannerException(
            'Gemini 对话失败（HTTP ${response.statusCode}）',
          );
        }

        final responseData = jsonDecode(response.body);
        final candidate = (responseData['candidates'] as List?)?.firstOrNull;
        final content = candidate?['content'];
        final parts = (content?['parts'] as List?) ?? [];

        Map<String, dynamic>? functionCall;
        String textPart = '';

        for (final p in parts) {
          if (p is Map) {
            if (p.containsKey('functionCall')) {
              functionCall = Map<String, dynamic>.from(p['functionCall']);
            }
            if (p.containsKey('text')) {
              textPart += p['text'].toString();
            }
          }
        }

        if (functionCall != null) {
          final toolName = functionCall['name']?.toString() ?? '';
          final toolArgs = Map<String, dynamic>.from(
            functionCall['args'] as Map? ?? {},
          );
          toolsUsed.add(toolName);

          _history.add({
            'role': 'model',
            'parts': [
              {
                'functionCall': {
                  'name': toolName,
                  'args': toolArgs,
                },
              },
            ],
          });

          final toolResult = await AgentTools.execute(
            name: toolName,
            arguments: toolArgs,
            mediaRepository: mediaRepository,
            progressRepository: progressRepository,
          );

          if (toolName == 'create_smart_collection') {
            generatedPlan = await agentService.plan(
              MediaAgentOperation.smartCollection,
              query: toolArgs['query']?.toString() ?? '',
              collectionName: toolArgs['collectionName']?.toString(),
            );
          } else if (toolName == 'batch_generate_subtitles') {
            generatedPlan = await agentService.plan(
              MediaAgentOperation.batchSubtitles,
              query: toolArgs['filterQuery']?.toString() ?? '',
            );
          }

          _history.add({
            'role': 'user',
            'parts': [
              {
                'functionResponse': {
                  'name': toolName,
                  'response': toolResult,
                },
              },
            ],
          });
          continue;
        }

        finalReply = textPart.trim();
        _history.add({
          'role': 'model',
          'parts': [
            {'text': finalReply},
          ],
        });
        break;
      }

      if (generatedPlan == null && _isPlanSuggested(input)) {
        try {
          generatedPlan = await agentService.planFromRequest(input);
        } catch (_) {}
      }

      return ConversationalTurnResult(
        replyText: finalReply.isEmpty
            ? (generatedPlan != null ? '已为你生成对应操作计划。' : '好的，处理完成。')
            : finalReply,
        plan: generatedPlan,
        toolsUsed: toolsUsed,
      );
    } catch (error) {
      throw AgentPlannerException('Agent 思考失败：$error');
    } finally {
      if (client == null) requestClient.close();
    }
  }

  bool _isPlanSuggested(String input) {
    final lower = input.toLowerCase();
    return lower.contains('合集') ||
        lower.contains('字幕') ||
        lower.contains('重复') ||
        lower.contains('低画质') ||
        lower.contains('未看');
  }
}

import 'dart:convert';

import 'package:http/http.dart' as http;

/// Result of AI-based media name recognition.
class MediaNameRecognition {
  const MediaNameRecognition({
    required this.cleanTitle,
    required this.mediaType,
    this.year,
    required this.confidence,
  });

  final String cleanTitle;
  final String mediaType; // 'movie' | 'tv' | 'unknown'
  final String? year;
  final double confidence;
}

/// Uses Gemini AI to intelligently parse media file/folder names into
/// clean searchable titles — the same approach as the Electron version's
/// IntelligentNameRecognizer.
class IntelligentNameRecognizer {
  IntelligentNameRecognizer(this._client);

  final http.Client _client;

  static const _geminiEndpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';

  /// Recognize a media title from a filename and optional file path.
  /// Returns null if recognition fails or API key is missing.
  Future<MediaNameRecognition?> recognize(
    String filename, {
    String? filePath,
    required String geminiApiKey,
  }) async {
    if (geminiApiKey.isEmpty) return null;

    final prompt =
        '''
你是一个专业的电影和电视剧识别专家。请分析以下信息并识别真实的媒体内容：

原始文件名：$filename
${filePath != null ? '文件路径：$filePath' : ''}

任务：
1. 识别文件名/路径中的真实电影或电视剧名称
2. 判断是电影（movie）还是电视剧（tv）
3. 提取发行年份（如果有）
4. 提供用于 TMDB 搜索的最佳标题（优先英文原名）

判断规则：
- 包含 S01E01、Season、Episode、季、集 等格式通常是电视剧
- 只有年份但无季集信息通常是电影
- 如果能识别出这是某部知名影视作品，直接给出其官方标题

请以JSON格式回复（不要包含markdown代码块标记）：
{
  "cleanTitle": "用于TMDB搜索的标题（优先英文原名，如 Stranger Things）",
  "mediaType": "movie|tv|unknown",
  "year": "首播/上映年份（可选，字符串）",
  "confidence": 0.85
}

重要：
- 移除技术信息：720p、1080p、4K、x264、x265、HEVC、DTS、AAC、BluRay、WEB-DL等
- 移除发布组信息
- "怪奇物语" = "Stranger Things"，优先返回英文原名以提高 TMDB 搜索准确度
- 保持标题完整性，不要截断
''';

    try {
      final uri = Uri.parse('$_geminiEndpoint?key=$geminiApiKey');
      final response = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt},
              ],
            },
          ],
          'generationConfig': {'temperature': 0.1, 'maxOutputTokens': 256},
        }),
      );

      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(response.body);
      final text =
          decoded['candidates']?[0]?['content']?['parts']?[0]?['text']
              as String?;
      if (text == null || text.isEmpty) return null;

      // Parse JSON from response (strip markdown code blocks if present)
      var cleanText = text
          .replaceAll(RegExp(r'```json\s*'), '')
          .replaceAll(RegExp(r'```\s*'), '')
          .trim();

      final parsed = jsonDecode(cleanText) as Map<String, dynamic>;

      return MediaNameRecognition(
        cleanTitle: (parsed['cleanTitle'] as String?)?.trim() ?? filename,
        mediaType: parsed['mediaType'] as String? ?? 'unknown',
        year: parsed['year'] as String?,
        confidence: (parsed['confidence'] as num?)?.toDouble() ?? 0.5,
      );
    } catch (e) {
      // AI recognition is best-effort; fall through to regex-based parsing
      return null;
    }
  }
}

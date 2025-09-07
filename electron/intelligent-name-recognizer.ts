import { GoogleGenerativeAI } from '@google/generative-ai';
import axios from 'axios';

export interface MediaNameRecognitionResult {
  originalTitle: string;
  cleanTitle: string;
  mediaType: 'movie' | 'tv' | 'unknown';
  year?: string;
  confidence: number;
  enrichedContext?: string;
  alternativeNames?: string[];
}

export interface JinaSearchResult {
  title: string;
  snippet: string;
  url: string;
  relevance: number;
}

export class IntelligentNameRecognizer {
  private genAI: GoogleGenerativeAI;
  private model: any;
  private geminiApiKey: string;

  constructor(geminiApiKey: string) {
    this.geminiApiKey = geminiApiKey;
    this.genAI = new GoogleGenerativeAI(geminiApiKey);
    this.model = this.genAI.getGenerativeModel({ model: 'gemini-2.0-flash-exp' });
    
    console.log('[IntelligentNameRecognizer] Initialized with Gemini API');
  }

  /**
   * 使用 Jina AI 搜索相关信息以增强识别准确性
   */
  private async searchWithJina(query: string): Promise<JinaSearchResult[]> {
    try {
      // 使用 Jina Reader API 搜索相关信息
      const searchUrl = `https://r.jina.ai/${encodeURIComponent(query + ' movie tv show imdb')}`;
      
      const response = await axios.get(searchUrl, {
        headers: {
          'Accept': 'text/plain',
          'User-Agent': 'Mozilla/5.0 (compatible; OpenFilmly/1.0)'
        },
        timeout: 10000
      });

      // 解析搜索结果
      const results: JinaSearchResult[] = [];
      if (response.data && typeof response.data === 'string') {
        // 从文本中提取相关信息
        const text = response.data.substring(0, 1000); // 取前1000字符
        if (text.toLowerCase().includes('movie') || text.toLowerCase().includes('film') || text.toLowerCase().includes('tv')) {
          results.push({
            title: query,
            snippet: text,
            url: searchUrl,
            relevance: 0.7
          });
        }
      }

      console.log(`[Jina] Found ${results.length} search results for "${query}"`);
      return results;
    } catch (error) {
      console.error(`[Jina] Error searching for "${query}":`, error);
      return [];
    }
  }

  /**
   * 使用 Gemini 结合 Jina 搜索结果进行智能识别
   */
  async recognizeMediaName(filename: string, filePath?: string): Promise<MediaNameRecognitionResult> {
    try {
      // 第一步：基本清理获取初步搜索词
      const preliminaryTitle = this.basicCleanTitle(filename);
      
      // 第二步：使用 Jina 搜索相关信息
      const searchResults = await this.searchWithJina(preliminaryTitle);
      
      // 第三步：使用 Gemini 结合搜索结果进行智能分析
      const enrichedContext = searchResults.map(result => 
        `${result.title}: ${result.snippet}`
      ).join('\n');

      const prompt = `
你是一个专业的电影和电视剧识别专家。请分析以下信息并识别真实的媒体内容：

原始文件名：${filename}
${filePath ? `文件路径：${filePath}` : ''}

搜索引擎结果（用于增强识别准确性）：
${enrichedContext || '无相关搜索结果'}

任务：
1. 识别文件名中的真实电影或电视剧名称
2. 判断是电影（movie）还是电视剧（tv）
3. 提取发行年份（如果有）
4. 清理技术信息（分辨率、编码等）
5. 提供置信度评分 (0.0-1.0)

判断规则：
- 包含 S01E01、Season、Episode、季、集、第X季 等格式通常是电视剧
- 包含电视剧、连续剧、剧集等关键词的是电视剧
- 只有年份但无季集信息通常是电影
- 文件路径中包含 TV、Series、电视剧 等文件夹名称暗示电视剧
- 结合搜索结果判断真实性和准确性

重要清理规则：
- 移除技术信息：720p、1080p、4K、x264、x265、HEVC、HDR、DTS、AAC、BluRay、WEB-DL、BDRip等
- 移除发布组信息（方括号、大括号、【】等包围的内容）
- 移除语言标识：中英、双语、CHS、ENG等
- 移除版本信息：导演剪辑版、未删减版、Extended等
- 保持电影/电视剧原始名称的完整性
- 中文标题优先保持中文，英文标题保持英文

常见中文电视剧识别：
- "权力的游戏"、"绝命毒师"、"西部世界"、"黑镜"、"怪奇物语" 等都是电视剧
- 如果文件名包含明确的集数信息，通常是电视剧

请以JSON格式回复：
{
  "originalTitle": "识别的原始标题（清理后但保持原始性）",
  "cleanTitle": "最终清理的标题（用于搜索）",
  "mediaType": "movie|tv|unknown",
  "year": "发行年份（如果能确定）",
  "confidence": 0.85,
  "reasoningSteps": ["识别步骤1", "识别步骤2"],
  "alternativeNames": ["可能的其他名称"]
}

示例：
输入：Black.Mirror.S04E06.Black.Museum.1080p.NetFlix.WEB-DL.DD5.1.x264
输出：{
  "originalTitle": "Black Mirror",
  "cleanTitle": "Black Mirror",
  "mediaType": "tv",
  "year": null,
  "confidence": 0.95,
  "reasoningSteps": ["识别到S04E06季集格式，确定为电视剧", "Black Mirror是知名电视剧"],
  "alternativeNames": ["黑镜"]
}

重要：
- 置信度应该基于识别的确定性
- 如果搜索结果能验证识别结果，提高置信度
- 对于中文内容，尽量识别准确的中文标题
- 不要遗漏重要的标题信息
`;

      const result = await this.model.generateContent(prompt);
      const response = await result.response;
      const text = response.text();
      
      console.log(`[Gemini] Raw response for "${filename}":`, text);

      // 解析 JSON 响应
      try {
        // 清理响应文本，移除markdown代码块标记
        let cleanText = text.replace(/```json\s*/g, '').replace(/```\s*/g, '').trim();
        const parsed = JSON.parse(cleanText);
        
        // 验证和修正响应格式
        const recognitionResult: MediaNameRecognitionResult = {
          originalTitle: parsed.originalTitle || filename,
          cleanTitle: parsed.cleanTitle || this.basicCleanTitle(filename),
          mediaType: ['movie', 'tv'].includes(parsed.mediaType) ? parsed.mediaType : 'unknown',
          year: parsed.year,
          confidence: Math.max(0, Math.min(1, parsed.confidence || 0.5)),
          enrichedContext: enrichedContext || undefined,
          alternativeNames: Array.isArray(parsed.alternativeNames) ? parsed.alternativeNames : []
        };

        // 如果有搜索结果，提高置信度
        if (searchResults.length > 0) {
          recognitionResult.confidence = Math.min(1, recognitionResult.confidence + 0.1);
        }

        // 如果有推理步骤，添加到enrichedContext
        if (parsed.reasoningSteps && Array.isArray(parsed.reasoningSteps)) {
          const reasoningText = parsed.reasoningSteps.join('; ');
          recognitionResult.enrichedContext = enrichedContext ? 
            `${enrichedContext}\n推理步骤: ${reasoningText}` : 
            `推理步骤: ${reasoningText}`;
        }

        console.log(`[IntelligentNameRecognizer] Recognition result for "${filename}":`, recognitionResult);
        return recognitionResult;

      } catch (parseError) {
        console.error(`[Gemini] Failed to parse JSON response for "${filename}":`, parseError);
        console.log(`[Gemini] Raw text causing parse error:`, text);
        return this.createFallbackResult(filename, searchResults);
      }

    } catch (error) {
      console.error(`[IntelligentNameRecognizer] Error recognizing "${filename}":`, error);
      return this.createFallbackResult(filename, []);
    }
  }

  /**
   * 创建后备识别结果
   */
  private createFallbackResult(filename: string, searchResults: JinaSearchResult[]): MediaNameRecognitionResult {
    const cleanTitle = this.basicCleanTitle(filename);
    const hasSeasonEpisode = /s\d+e\d+|season|episode|第\d+[季集]/i.test(filename);
    
    return {
      originalTitle: filename,
      cleanTitle,
      mediaType: hasSeasonEpisode ? 'tv' : 'unknown',
      confidence: searchResults.length > 0 ? 0.3 : 0.1,
      enrichedContext: searchResults.length > 0 ? 'Based on search results' : undefined,
      alternativeNames: []
    };
  }

  /**
   * 基本的标题清理方法 - 增强版
   */
  private basicCleanTitle(title: string): string {
    return title
      // 移除文件扩展名
      .replace(/\.(mp4|mkv|avi|mov|wmv|m4v|flv|webm|ts|m2ts|mts|rmvb|rm)$/i, '')
      // 移除常见的发布组标识
      .replace(/\[([\w\-\.\s]+)\]/g, '')
      .replace(/\{([\w\-\.\s]+)\}/g, '')
      .replace(/【([^】]+)】/g, '')
      .replace(/（([^）]+)）/g, '')
      // 移除年份括号 (但保留中文括号中的其他内容)
      .replace(/\((\d{4})\)/g, ' $1 ')
      .replace(/（(\d{4})）/g, ' $1 ')
      // 移除季集信息
      .replace(/[Ss]\d+[Ee]\d+/g, '')
      .replace(/第\s*\d+\s*[季集]/g, '')
      .replace(/Season\s*\d+/gi, '')
      .replace(/Episode\s*\d+/gi, '')
      // 移除分辨率信息
      .replace(/\b(720p|1080p|4k|uhd|hd|sd|2160p|1440p|480p|360p)\b/gi, '')
      // 移除编码信息
      .replace(/\b(x264|x265|h264|h265|hevc|avc|vp9|av1|xvid|divx)\b/gi, '')
      // 移除音频信息
      .replace(/\b(aac|ac3|dts|mp3|flac|dolby|atmos|dd5\.?1|dd7\.?1|truehd)\b/gi, '')
      // 移除视频源信息
      .replace(/\b(bluray|blu-ray|bdrip|dvdrip|web-dl|webrip|hdtv|hdcam|cam|ts|tc|r5|screener|brrip|dvdscr)\b/gi, '')
      // 移除HDR和其他视频技术信息
      .replace(/\b(hdr|hdr10|dolby\.?vision|dv|10bit|8bit)\b/gi, '')
      // 移除语言信息
      .replace(/\b(dual|multi|eng|chs|cht|jpn|kor|rus|fra|ger|spa|ita|中英|国英|粤英)\b/gi, '')
      // 移除字幕信息
      .replace(/\b(sub|subs|subtitle|subtitles|字幕|内封|外挂)\b/gi, '')
      // 移除其他技术信息
      .replace(/\b(complete|uncut|extended|director['\s]?s?\.?cut|remastered|internal|proper|repack|real)\b/gi, '')
      // 移除多余的点、横线、下划线
      .replace(/[._-]+/g, ' ')
      // 清理特殊字符
      .replace(/[【】〈〉《》「」]/g, '')
      // 移除多余的空格
      .replace(/\s+/g, ' ')
      .trim();
  }

  /**
   * 批量识别多个文件名
   */
  async recognizeMultipleMediaNames(
    filenames: string[], 
    filePaths?: string[]
  ): Promise<MediaNameRecognitionResult[]> {
    const results: MediaNameRecognitionResult[] = [];
    
    for (let i = 0; i < filenames.length; i++) {
      const filename = filenames[i];
      const filePath = filePaths ? filePaths[i] : undefined;
      
      try {
        const result = await this.recognizeMediaName(filename, filePath);
        results.push(result);
        
        // 添加延迟以避免API限制
        await new Promise(resolve => setTimeout(resolve, 200));
      } catch (error) {
        console.error(`[IntelligentNameRecognizer] Error processing file ${filename}:`, error);
        results.push(this.createFallbackResult(filename, []));
      }
    }
    
    return results;
  }

  /**
   * 验证识别结果的准确性
   */
  async verifyRecognition(result: MediaNameRecognitionResult): Promise<MediaNameRecognitionResult> {
    if (result.confidence < 0.7) {
      // 对低置信度结果进行二次验证
      const verificationResults = await this.searchWithJina(result.cleanTitle);
      
      if (verificationResults.length > 0) {
        // 基于搜索结果调整置信度
        result.confidence = Math.min(0.9, result.confidence + 0.2);
        result.enrichedContext = verificationResults.map(r => r.snippet).join(' ');
      }
    }
    
    return result;
  }
}
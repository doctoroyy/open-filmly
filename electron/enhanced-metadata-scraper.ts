import * as path from "path"
import * as fs from "fs"
import * as os from "os"
import axios from "axios"
import { MovieDb } from "moviedb-promise"
import type { MediaDatabase } from "./media-database"
import { IntelligentNameRecognizer } from "./intelligent-name-recognizer"
import { EventEmitter } from 'events'

interface ScrapeTask {
  mediaId: string
  mediaItem: any
  retries: number
  maxRetries: number
  priority: 'high' | 'medium' | 'low'
}

interface ScrapeResult {
  mediaId: string
  success: boolean
  metadata?: any
  confidence?: number
  method?: 'tmdb_exact' | 'tmdb_fuzzy' | 'ai_enhanced' | 'web_search' | 'failed'
  error?: string
  processingTime?: number
}

interface MatchingScore {
  titleSimilarity: number
  yearMatch: number
  typeMatch: number
  totalScore: number
  confidence: number
}

export class EnhancedMetadataScraper extends EventEmitter {
  private mediaDatabase: MediaDatabase
  private posterCacheDir: string
  private tmdbApiKey: string | null = null
  private movieDb: MovieDb | null = null
  private intelligentRecognizer: IntelligentNameRecognizer | null = null
  private geminiApiKey: string
  
  // 增强的批量处理配置
  private maxConcurrency: number = 3 // 降低并发数以提高质量
  private batchQueue: ScrapeTask[] = []
  private runningTasks: Set<string> = new Set()
  private isProcessing: boolean = false
  private processingStats = {
    totalProcessed: 0,
    successful: 0,
    failed: 0,
    averageProcessingTime: 0
  }

  // 智能匹配配置
  private readonly MIN_CONFIDENCE_THRESHOLD = 0.85 // 提高置信度阈值
  private readonly FUZZY_SEARCH_THRESHOLD = 0.6
  private readonly TITLE_SIMILARITY_THRESHOLD = 0.8
  
  constructor(
    mediaDatabase: MediaDatabase, 
    tmdbApiKey?: string, 
    geminiApiKey?: string
  ) {
    super()
    this.mediaDatabase = mediaDatabase
    this.tmdbApiKey = tmdbApiKey || process.env.TMDB_API_KEY || null
    this.geminiApiKey = geminiApiKey || process.env.GEMINI_API_KEY || ''

    // 初始化 MovieDb 实例
    if (this.tmdbApiKey) {
      console.log(`[EnhancedMetadataScraper] Initializing MovieDb with API key`)
      this.movieDb = new MovieDb(this.tmdbApiKey)
    } else {
      console.warn("[EnhancedMetadataScraper] No TMDB API key provided.")
    }

    // 初始化智能识别器
    if (this.geminiApiKey) {
      console.log(`[EnhancedMetadataScraper] Initializing IntelligentNameRecognizer`)
      this.intelligentRecognizer = new IntelligentNameRecognizer(this.geminiApiKey)
    } else {
      console.warn("[EnhancedMetadataScraper] No Gemini API key provided.")
    }

    // 创建海报缓存目录
    this.posterCacheDir = path.join(os.homedir(), ".open-filmly", "posters")
    if (!fs.existsSync(this.posterCacheDir)) {
      fs.mkdirSync(this.posterCacheDir, { recursive: true })
    }
  }

  /**
   * 智能批量刮削元数据 - 增强版
   */
  public async batchScrapeMetadata(mediaIds: string[]): Promise<ScrapeResult[]> {
    const startTime = Date.now()
    console.log(`[EnhancedMetadataScraper] Starting enhanced batch scrape for ${mediaIds.length} items`)
    
    // 重置状态
    this.batchQueue = []
    this.runningTasks.clear()
    this.processingStats = { totalProcessed: 0, successful: 0, failed: 0, averageProcessingTime: 0 }
    
    // 创建优先级任务队列
    const prioritizedTasks = await this.createPrioritizedTaskQueue(mediaIds)
    this.batchQueue = prioritizedTasks
    
    this.isProcessing = true
    const results: ScrapeResult[] = []
    
    // 发出增强的开始事件
    this.emit('batch:started', {
      total: this.batchQueue.length,
      completed: 0,
      failed: 0,
      estimatedTime: this.batchQueue.length * 3000 // 估计每个任务3秒
    })

    // 智能并发处理
    const promises: Promise<ScrapeResult>[] = []
    while (this.batchQueue.length > 0 && this.runningTasks.size < this.maxConcurrency) {
      const task = this.batchQueue.shift()!
      promises.push(this.processEnhancedScrapeTask(task))
    }

    // 等待所有任务完成并处理剩余队列
    while (promises.length > 0 || this.batchQueue.length > 0) {
      const completedResults = await Promise.allSettled(promises)
      
      for (const result of completedResults) {
        if (result.status === 'fulfilled') {
          results.push(result.value)
          this.updateProcessingStats(result.value)
        } else {
          console.error('[EnhancedMetadataScraper] Task failed:', result.reason)
          results.push({
            mediaId: 'unknown',
            success: false,
            error: result.reason.message,
            method: 'failed',
            processingTime: 0
          })
        }
      }

      // 启动下一批任务
      promises.length = 0
      while (this.batchQueue.length > 0 && this.runningTasks.size < this.maxConcurrency) {
        const task = this.batchQueue.shift()!
        promises.push(this.processEnhancedScrapeTask(task))
      }
    }

    this.isProcessing = false
    const totalTime = Date.now() - startTime
    
    // 发出完成事件
    this.emit('batch:completed', {
      total: results.length,
      completed: results.filter(r => r.success).length,
      failed: results.filter(r => !r.success).length,
      totalTime,
      averageTime: totalTime / results.length,
      stats: this.processingStats
    })

    console.log(`[EnhancedMetadataScraper] Enhanced batch scrape completed: ${results.filter(r => r.success).length}/${results.length} successful in ${totalTime}ms`)
    
    return results
  }

  /**
   * 创建优先级任务队列
   */
  private async createPrioritizedTaskQueue(mediaIds: string[]): Promise<ScrapeTask[]> {
    const tasks: ScrapeTask[] = []
    
    for (const mediaId of mediaIds) {
      const media = await this.mediaDatabase.getMediaById(mediaId)
      if (media) {
        // 根据文件大小、类型等因素确定优先级
        let priority: 'high' | 'medium' | 'low' = 'medium'
        
        if (media.type === 'movie') {
          priority = 'high' // 电影优先处理
        } else if (media.type === 'tv') {
          priority = 'medium'
        } else {
          priority = 'low'
        }

        // 文件大小较大的优先处理
        if (media.fileSize > 1024 * 1024 * 1024 * 2) { // 2GB以上
          priority = priority === 'low' ? 'medium' : 'high'
        }

        tasks.push({
          mediaId,
          mediaItem: media,
          retries: 0,
          maxRetries: 3, // 增加重试次数
          priority
        })
      }
    }

    // 按优先级排序
    return tasks.sort((a, b) => {
      const priorityOrder = { high: 3, medium: 2, low: 1 }
      return priorityOrder[b.priority] - priorityOrder[a.priority]
    })
  }

  /**
   * 处理增强版刮削任务
   */
  private async processEnhancedScrapeTask(task: ScrapeTask): Promise<ScrapeResult> {
    const startTime = Date.now()
    this.runningTasks.add(task.mediaId)
    
    try {
      console.log(`[EnhancedMetadataScraper] Processing ${task.mediaItem.title} (Priority: ${task.priority})`)
      
      this.emit('item:started', {
        mediaId: task.mediaId,
        title: task.mediaItem.title,
        priority: task.priority
      })

      // 多层级智能搜索策略
      let result = await this.tryExactTmdbSearch(task.mediaItem)
      
      if (!result || result.confidence < this.MIN_CONFIDENCE_THRESHOLD) {
        console.log(`[EnhancedMetadataScraper] Exact search failed, trying fuzzy search...`)
        result = await this.tryFuzzyTmdbSearch(task.mediaItem)
      }
      
      if (!result || result.confidence < this.FUZZY_SEARCH_THRESHOLD) {
        console.log(`[EnhancedMetadataScraper] Fuzzy search failed, trying AI-enhanced analysis...`)
        result = await this.tryAiEnhancedAnalysis(task.mediaItem)
      }
      
      if (!result || result.confidence < 0.4) {
        console.log(`[EnhancedMetadataScraper] AI analysis failed, trying web search...`)
        result = await this.tryWebSearch(task.mediaItem)
      }

      const processingTime = Date.now() - startTime

      if (result && result.metadata && result.confidence >= 0.4) {
        // 下载海报
        if (result.metadata.posterPath) {
          try {
            const posterFileName = `${task.mediaId}.jpg`
            const posterPath = path.join(this.posterCacheDir, posterFileName)
            await this.downloadPoster(result.metadata.posterPath, posterPath)
            result.metadata.posterPath = posterPath
          } catch (error) {
            console.warn(`[EnhancedMetadataScraper] Failed to download poster for ${task.mediaId}:`, error)
          }
        }

        // 更新数据库
        await this.updateMediaWithMetadata(task.mediaId, result.metadata)
        
        this.emit('item:completed', {
          mediaId: task.mediaId,
          title: task.mediaItem.title,
          success: true,
          method: result.method,
          confidence: result.confidence,
          processingTime
        })

        return {
          mediaId: task.mediaId,
          success: true,
          metadata: result.metadata,
          confidence: result.confidence,
          method: result.method,
          processingTime
        }
      } else {
        this.emit('item:failed', {
          mediaId: task.mediaId,
          title: task.mediaItem.title,
          error: 'All search methods failed to meet confidence threshold'
        })

        return {
          mediaId: task.mediaId,
          success: false,
          error: 'All search methods failed to meet confidence threshold',
          method: 'failed',
          processingTime
        }
      }
    } catch (error: any) {
      const processingTime = Date.now() - startTime
      console.error(`[EnhancedMetadataScraper] Error processing ${task.mediaId}:`, error)
      
      this.emit('item:failed', {
        mediaId: task.mediaId,
        title: task.mediaItem.title,
        error: error.message
      })

      return {
        mediaId: task.mediaId,
        success: false,
        error: error.message,
        method: 'failed',
        processingTime
      }
    } finally {
      this.runningTasks.delete(task.mediaId)
    }
  }

  /**
   * 精确TMDB搜索
   */
  private async tryExactTmdbSearch(mediaItem: any): Promise<{ metadata: any; confidence: number; method: 'tmdb_exact' } | null> {
    if (!this.movieDb) return null

    try {
      console.log(`[EnhancedMetadataScraper] Trying exact TMDB search for: ${mediaItem.title}`)
      
      const searchParams: any = {
        query: mediaItem.title,
        language: 'zh-CN'
      }

      if (mediaItem.year && mediaItem.year !== "未知") {
        const year = parseInt(mediaItem.year, 10)
        if (mediaItem.type === 'movie') {
          searchParams.year = year
        } else if (mediaItem.type === 'tv') {
          searchParams.first_air_date_year = year
        }
      }

      let searchResponse
      if (mediaItem.type === 'movie') {
        searchResponse = await this.movieDb.searchMovie(searchParams)
      } else if (mediaItem.type === 'tv') {
        searchResponse = await this.movieDb.searchTv(searchParams)
      } else {
        searchResponse = await this.movieDb.searchMulti(searchParams)
      }
      
      if (searchResponse.results && searchResponse.results.length > 0) {
        const bestMatch = await this.findBestMatch(mediaItem, searchResponse.results)
        
        if (bestMatch && bestMatch.matchingScore.confidence >= this.MIN_CONFIDENCE_THRESHOLD) {
          const details = await this.getDetailedInfo(bestMatch.result, bestMatch.result.media_type || mediaItem.type)
          
          if (details) {
            const metadata = this.mapTMDBToMedia(details, bestMatch.result.media_type || mediaItem.type)
            return {
              metadata,
              confidence: bestMatch.matchingScore.confidence,
              method: 'tmdb_exact'
            }
          }
        }
      }

      return null
    } catch (error: any) {
      console.error(`[EnhancedMetadataScraper] Exact TMDB search failed:`, error)
      return null
    }
  }

  /**
   * 模糊TMDB搜索
   */
  private async tryFuzzyTmdbSearch(mediaItem: any): Promise<{ metadata: any; confidence: number; method: 'tmdb_fuzzy' } | null> {
    if (!this.movieDb) return null

    try {
      console.log(`[EnhancedMetadataScraper] Trying fuzzy TMDB search for: ${mediaItem.title}`)
      
      // 使用智能识别器清理标题
      let cleanTitle = mediaItem.title
      if (this.intelligentRecognizer) {
        const recognition = await this.intelligentRecognizer.recognizeMediaName(
          mediaItem.title, 
          mediaItem.fullPath || mediaItem.path
        )
        if (recognition.confidence > 0.5) {
          cleanTitle = recognition.cleanTitle
        }
      }

      // 尝试多个搜索变体
      const searchVariants = [
        cleanTitle,
        cleanTitle.replace(/[^\w\s]/g, ''), // 移除特殊字符
        cleanTitle.split(' ').slice(0, -1).join(' '), // 移除最后一个词
        cleanTitle.split(' ').slice(0, 2).join(' ') // 只取前两个词
      ]

      for (const variant of searchVariants) {
        if (!variant.trim()) continue

        const searchParams = {
          query: variant,
          language: 'zh-CN'
        }

        const searchResponse = await this.movieDb.searchMulti(searchParams)
        
        if (searchResponse.results && searchResponse.results.length > 0) {
          const bestMatch = await this.findBestMatch(mediaItem, searchResponse.results)
          
          if (bestMatch && bestMatch.matchingScore.confidence >= this.FUZZY_SEARCH_THRESHOLD) {
            const details = await this.getDetailedInfo(bestMatch.result, bestMatch.result.media_type || mediaItem.type)
            
            if (details) {
              const metadata = this.mapTMDBToMedia(details, bestMatch.result.media_type || mediaItem.type)
              return {
                metadata,
                confidence: bestMatch.matchingScore.confidence,
                method: 'tmdb_fuzzy'
              }
            }
          }
        }
      }

      return null
    } catch (error: any) {
      console.error(`[EnhancedMetadataScraper] Fuzzy TMDB search failed:`, error)
      return null
    }
  }

  /**
   * AI增强分析
   */
  private async tryAiEnhancedAnalysis(mediaItem: any): Promise<{ metadata: any; confidence: number; method: 'ai_enhanced' } | null> {
    if (!this.intelligentRecognizer) return null

    try {
      console.log(`[EnhancedMetadataScraper] Trying AI-enhanced analysis for: ${mediaItem.title}`)
      
      const recognition = await this.intelligentRecognizer.recognizeMediaName(
        mediaItem.title, 
        mediaItem.fullPath || mediaItem.path
      )

      if (recognition.confidence > 0.5) {
        // 基于AI识别结果再次尝试TMDB搜索
        if (this.movieDb && recognition.cleanTitle !== mediaItem.title) {
          const searchParams = {
            query: recognition.cleanTitle,
            language: 'zh-CN'
          }

          if (recognition.year) {
            const year = parseInt(recognition.year, 10)
            if (recognition.mediaType === 'movie') {
              searchParams.year = year
            } else if (recognition.mediaType === 'tv') {
              searchParams.first_air_date_year = year
            }
          }

          const searchResponse = recognition.mediaType === 'movie' 
            ? await this.movieDb.searchMovie(searchParams)
            : recognition.mediaType === 'tv'
            ? await this.movieDb.searchTv(searchParams)
            : await this.movieDb.searchMulti(searchParams)

          if (searchResponse.results && searchResponse.results.length > 0) {
            const bestMatch = await this.findBestMatch(
              { ...mediaItem, title: recognition.cleanTitle, type: recognition.mediaType, year: recognition.year },
              searchResponse.results
            )
            
            if (bestMatch && bestMatch.matchingScore.confidence >= 0.6) {
              const details = await this.getDetailedInfo(bestMatch.result, recognition.mediaType)
              
              if (details) {
                const metadata = this.mapTMDBToMedia(details, recognition.mediaType)
                return {
                  metadata,
                  confidence: Math.min(0.9, bestMatch.matchingScore.confidence + 0.1), // AI加成
                  method: 'ai_enhanced'
                }
              }
            }
          }
        }

        // 如果TMDB搜索失败，返回AI生成的基础元数据
        const metadata = {
          id: `ai-${Date.now()}`,
          title: recognition.cleanTitle,
          originalTitle: mediaItem.title,
          year: recognition.year || mediaItem.year,
          type: recognition.mediaType !== 'unknown' ? recognition.mediaType : mediaItem.type,
          overview: recognition.enrichedContext || `AI识别的${recognition.mediaType === 'movie' ? '电影' : '电视剧'}`,
          posterPath: null,
          backdropPath: null,
          rating: 0,
          genres: [],
          releaseDate: recognition.year ? `${recognition.year}-01-01` : null
        }

        return {
          metadata,
          confidence: recognition.confidence,
          method: 'ai_enhanced'
        }
      }

      return null
    } catch (error: any) {
      console.error(`[EnhancedMetadataScraper] AI-enhanced analysis failed:`, error)
      return null
    }
  }

  /**
   * 网络搜索
   */
  private async tryWebSearch(mediaItem: any): Promise<{ metadata: any; confidence: number; method: 'web_search' } | null> {
    try {
      console.log(`[EnhancedMetadataScraper] Trying web search for: ${mediaItem.title}`)
      
      // 使用多个搜索引擎或API
      const searchQuery = `${mediaItem.title} ${mediaItem.year || ''} movie tv series imdb`
      
      // 这里可以集成更多的搜索API
      // 例如：DuckDuckGo API, Bing API等
      
      // 暂时返回null，可以在将来扩展
      return null
    } catch (error: any) {
      console.error(`[EnhancedMetadataScraper] Web search failed:`, error)
      return null
    }
  }

  /**
   * 查找最佳匹配
   */
  private async findBestMatch(mediaItem: any, searchResults: any[]): Promise<{ result: any; matchingScore: MatchingScore } | null> {
    let bestMatch = null
    let highestScore = 0

    for (const result of searchResults) {
      const score = this.calculateMatchingScore(mediaItem, result)
      
      if (score.totalScore > highestScore) {
        highestScore = score.totalScore
        bestMatch = { result, matchingScore: score }
      }
    }

    return bestMatch
  }

  /**
   * 计算匹配分数
   */
  private calculateMatchingScore(mediaItem: any, searchResult: any): MatchingScore {
    // 标题相似度
    const titleSimilarity = this.calculateTitleSimilarity(
      mediaItem.title.toLowerCase(),
      (searchResult.title || searchResult.name || '').toLowerCase()
    )

    // 年份匹配
    const itemYear = parseInt(mediaItem.year || '0', 10)
    const resultYear = parseInt(
      (searchResult.release_date || searchResult.first_air_date || '').substring(0, 4) || '0',
      10
    )
    const yearMatch = itemYear && resultYear ? 
      (Math.abs(itemYear - resultYear) <= 1 ? 1 : Math.max(0, 1 - Math.abs(itemYear - resultYear) / 10)) : 0.5

    // 类型匹配
    const typeMatch = this.calculateTypeMatch(mediaItem.type, searchResult.media_type)

    // 总分计算
    const totalScore = (titleSimilarity * 0.6) + (yearMatch * 0.3) + (typeMatch * 0.1)
    
    // 置信度计算
    const confidence = Math.min(1, totalScore * 1.2) // 稍微提升置信度

    return {
      titleSimilarity,
      yearMatch,
      typeMatch,
      totalScore,
      confidence
    }
  }

  /**
   * 计算标题相似度
   */
  private calculateTitleSimilarity(title1: string, title2: string): number {
    if (!title1 || !title2) return 0

    // 移除常见的停用词和字符
    const clean1 = title1.replace(/[^\w\s]/g, '').replace(/\b(the|a|an|and|or|but|in|on|at|to|for|of|with|by)\b/g, '').trim()
    const clean2 = title2.replace(/[^\w\s]/g, '').replace(/\b(the|a|an|and|or|but|in|on|at|to|for|of|with|by)\b/g, '').trim()

    // 如果完全匹配
    if (clean1 === clean2) return 1

    // 计算编辑距离
    const distance = this.levenshteinDistance(clean1, clean2)
    const maxLength = Math.max(clean1.length, clean2.length)
    
    if (maxLength === 0) return 0
    
    return Math.max(0, 1 - distance / maxLength)
  }

  /**
   * 计算编辑距离
   */
  private levenshteinDistance(str1: string, str2: string): number {
    const matrix = []

    for (let i = 0; i <= str2.length; i++) {
      matrix[i] = [i]
    }

    for (let j = 0; j <= str1.length; j++) {
      matrix[0][j] = j
    }

    for (let i = 1; i <= str2.length; i++) {
      for (let j = 1; j <= str1.length; j++) {
        if (str2.charAt(i - 1) === str1.charAt(j - 1)) {
          matrix[i][j] = matrix[i - 1][j - 1]
        } else {
          matrix[i][j] = Math.min(
            matrix[i - 1][j - 1] + 1,
            matrix[i][j - 1] + 1,
            matrix[i - 1][j] + 1
          )
        }
      }
    }

    return matrix[str2.length][str1.length]
  }

  /**
   * 计算类型匹配度
   */
  private calculateTypeMatch(itemType: string, resultType: string): number {
    if (!itemType || !resultType) return 0.5

    if (itemType === resultType) return 1
    if ((itemType === 'movie' && resultType === 'movie') || 
        (itemType === 'tv' && resultType === 'tv')) return 1
    
    return 0
  }

  /**
   * 获取详细信息
   */
  private async getDetailedInfo(result: any, type: string): Promise<any> {
    if (!this.movieDb) return null

    try {
      if (type === 'movie') {
        return await this.movieDb.movieInfo({
          id: result.id,
          language: 'zh-CN',
          append_to_response: 'credits,videos,similar'
        })
      } else if (type === 'tv') {
        return await this.movieDb.tvInfo({
          id: result.id,
          language: 'zh-CN',
          append_to_response: 'credits,videos,similar'
        })
      }
    } catch (error) {
      console.error('[EnhancedMetadataScraper] Error getting detailed info:', error)
    }

    return null
  }

  /**
   * 更新处理统计
   */
  private updateProcessingStats(result: ScrapeResult): void {
    this.processingStats.totalProcessed++
    if (result.success) {
      this.processingStats.successful++
    } else {
      this.processingStats.failed++
    }
    
    if (result.processingTime) {
      this.processingStats.averageProcessingTime = 
        (this.processingStats.averageProcessingTime * (this.processingStats.totalProcessed - 1) + result.processingTime) / 
        this.processingStats.totalProcessed
    }
  }

  /**
   * 映射TMDB数据到媒体对象
   */
  private mapTMDBToMedia(item: any, type: 'movie' | 'tv'): any {
    return {
      id: item.id.toString(),
      title: type === 'movie' ? item.title : item.name,
      originalTitle: type === 'movie' ? item.original_title : item.original_name,
      year: type === 'movie' 
        ? (item.release_date ? item.release_date.substring(0, 4) : '')
        : (item.first_air_date ? item.first_air_date.substring(0, 4) : ''),
      type,
      posterPath: item.poster_path ? `https://image.tmdb.org/t/p/w500${item.poster_path}` : null,
      backdropPath: item.backdrop_path ? `https://image.tmdb.org/t/p/original${item.backdrop_path}` : null,
      overview: item.overview,
      releaseDate: type === 'movie' ? item.release_date : item.first_air_date,
      genres: item.genres ? item.genres.map((g: any) => g.name) : [],
      rating: item.vote_average,
      credits: item.credits,
      videos: item.videos,
      similar: item.similar
    }
  }

  /**
   * 下载海报
   */
  private async downloadPoster(url: string, filePath: string): Promise<void> {
    try {
      const dirPath = path.dirname(filePath)
      if (!fs.existsSync(dirPath)) {
        fs.mkdirSync(dirPath, { recursive: true })
      }
      
      const response = await axios({
        method: "GET",
        url,
        responseType: "stream",
        headers: {
          "User-Agent": "Mozilla/5.0 (compatible; OpenFilmly/1.0)",
        },
        timeout: 30000,
      })

      const writer = fs.createWriteStream(filePath)

      return new Promise((resolve, reject) => {
        response.data.pipe(writer)
        writer.on("finish", resolve)
        writer.on("error", reject)
        response.data.on("error", reject)
      })
    } catch (error) {
      console.error(`[EnhancedMetadataScraper] Error downloading poster:`, error)
      throw error
    }
  }

  /**
   * 更新媒体项的元数据
   */
  private async updateMediaWithMetadata(mediaId: string, metadata: any): Promise<void> {
    try {
      // 更新媒体类型
      if (metadata.type) {
        await this.mediaDatabase.updateMediaType(mediaId, metadata.type)
      }

      // 更新详细信息
      await this.mediaDatabase.updateMediaDetails(mediaId, {
        overview: metadata.overview,
        backdropPath: metadata.backdropPath,
        rating: metadata.rating,
        releaseDate: metadata.releaseDate,
        genres: metadata.genres
      })

      // 更新海报路径
      if (metadata.posterPath) {
        await this.mediaDatabase.updateMediaPoster(mediaId, metadata.posterPath)
      }
    } catch (error) {
      console.error(`[EnhancedMetadataScraper] Error updating media metadata:`, error)
      throw error
    }
  }

  // API管理方法
  public setTmdbApiKey(apiKey: string): void {
    this.tmdbApiKey = apiKey
    this.movieDb = new MovieDb(apiKey)
  }

  public hasTmdbApiKey(): boolean {
    return !!this.tmdbApiKey
  }

  public getTmdbApiKey(): string | null {
    return this.tmdbApiKey
  }

  // 获取增强的批处理状态
  public getEnhancedBatchStatus(): {
    isProcessing: boolean
    queueLength: number
    runningTasks: number
    stats: typeof this.processingStats
  } {
    return {
      isProcessing: this.isProcessing,
      queueLength: this.batchQueue.length,
      runningTasks: this.runningTasks.size,
      stats: this.processingStats
    }
  }
}
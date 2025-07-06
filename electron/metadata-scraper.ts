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
}

interface ScrapeResult {
  mediaId: string
  success: boolean
  metadata?: any
  confidence?: number
  method?: 'tmdb' | 'ai' | 'jina' | 'failed'
  error?: string
}


export class MetadataScraper extends EventEmitter {
  private mediaDatabase: MediaDatabase
  private posterCacheDir: string
  private tmdbApiKey: string | null = null
  private movieDb: MovieDb | null = null
  private intelligentRecognizer: IntelligentNameRecognizer | null = null
  private geminiApiKey: string
  private jinaApiKey: string | null = null
  
  // 批量处理配置
  private maxConcurrency: number = 5
  private batchQueue: ScrapeTask[] = []
  private runningTasks: Set<string> = new Set()
  private isProcessing: boolean = false

  constructor(
    mediaDatabase: MediaDatabase, 
    tmdbApiKey?: string, 
    geminiApiKey?: string,
    jinaApiKey?: string
  ) {
    super()
    this.mediaDatabase = mediaDatabase
    this.tmdbApiKey = tmdbApiKey || process.env.TMDB_API_KEY || null
    this.geminiApiKey = geminiApiKey || process.env.GEMINI_API_KEY || ''
    this.jinaApiKey = jinaApiKey || null

    // 初始化 MovieDb 实例
    if (this.tmdbApiKey) {
      console.log(`[MetadataScraper] Initializing MovieDb with API key ${this.tmdbApiKey.substring(0, 5)}...`)
      this.movieDb = new MovieDb(this.tmdbApiKey)
    } else {
      console.log("[MetadataScraper] No TMDB API key provided. Will rely on AI fallback.")
    }

    // 初始化智能识别器
    if (this.geminiApiKey) {
      console.log(`[MetadataScraper] Initializing IntelligentNameRecognizer with Gemini API key ${this.geminiApiKey.substring(0, 5)}...`)
      this.intelligentRecognizer = new IntelligentNameRecognizer(this.geminiApiKey)
    } else {
      console.error("[MetadataScraper] No Gemini API key provided. AI recognition will be disabled.")
    }

    // 创建海报缓存目录
    this.posterCacheDir = path.join(os.homedir(), ".open-filmly", "posters")
    if (!fs.existsSync(this.posterCacheDir)) {
      fs.mkdirSync(this.posterCacheDir, { recursive: true })
    }
  }

  // 批量处理媒体项
  public async batchScrapeMetadata(mediaIds: string[]): Promise<ScrapeResult[]> {
    console.log(`[MetadataScraper] Starting batch scrape for ${mediaIds.length} items`)
    
    // 清空现有队列
    this.batchQueue = []
    this.runningTasks.clear()
    
    // 创建任务队列
    for (const mediaId of mediaIds) {
      const media = await this.mediaDatabase.getMediaById(mediaId)
      if (media) {
        this.batchQueue.push({
          mediaId,
          mediaItem: media,
          retries: 0,
          maxRetries: 2
        })
      }
    }

    // 开始处理
    this.isProcessing = true
    const results: ScrapeResult[] = []
    
    // 发出开始事件
    this.emit('batch:started', {
      total: this.batchQueue.length,
      completed: 0,
      failed: 0
    })

    // 并发处理任务
    const promises: Promise<ScrapeResult>[] = []
    while (this.batchQueue.length > 0 && this.runningTasks.size < this.maxConcurrency) {
      const task = this.batchQueue.shift()!
      promises.push(this.processScrapeTask(task))
    }

    // 等待所有任务完成
    const batchResults = await Promise.allSettled(promises)
    for (const result of batchResults) {
      if (result.status === 'fulfilled') {
        results.push(result.value)
      } else {
        console.error('[MetadataScraper] Task failed:', result.reason)
        results.push({
          mediaId: 'unknown',
          success: false,
          error: result.reason.message,
          method: 'failed'
        })
      }
    }

    this.isProcessing = false
    
    // 发出完成事件
    this.emit('batch:completed', {
      total: results.length,
      completed: results.filter(r => r.success).length,
      failed: results.filter(r => !r.success).length
    })

    console.log(`[MetadataScraper] Batch scrape completed: ${results.filter(r => r.success).length}/${results.length} successful`)
    
    return results
  }

  // 处理单个刮削任务
  private async processScrapeTask(task: ScrapeTask): Promise<ScrapeResult> {
    this.runningTasks.add(task.mediaId)
    
    try {
      console.log(`[MetadataScraper] Processing ${task.mediaItem.title}`)
      
      // 发出进度更新
      this.emit('item:started', {
        mediaId: task.mediaId,
        title: task.mediaItem.title
      })

      // 多级fallback策略
      let result = await this.tryTmdbSearch(task.mediaItem)
      
      if (!result || result.confidence < 0.7) {
        console.log(`[MetadataScraper] TMDB search failed/low confidence, trying AI analysis...`)
        result = await this.tryAiAnalysis(task.mediaItem)
      }
      
      if (!result || result.confidence < 0.5) {
        console.log(`[MetadataScraper] AI analysis failed/low confidence, trying Jina search...`)
        result = await this.tryJinaSearch(task.mediaItem)
      }

      if (result && result.metadata) {
        // 下载海报
        if (result.metadata.posterPath) {
          try {
            const posterFileName = `${task.mediaId}.jpg`
            const posterPath = path.join(this.posterCacheDir, posterFileName)
            await this.downloadPoster(result.metadata.posterPath, posterPath)
            result.metadata.posterPath = posterPath
          } catch (error) {
            console.error(`[MetadataScraper] Error downloading poster for ${task.mediaId}:`, error)
          }
        }

        // 更新数据库
        await this.updateMediaWithMetadata(task.mediaId, result.metadata)
        
        this.emit('item:completed', {
          mediaId: task.mediaId,
          title: task.mediaItem.title,
          success: true,
          method: result.method
        })

        return {
          mediaId: task.mediaId,
          success: true,
          metadata: result.metadata,
          confidence: result.confidence,
          method: result.method
        }
      } else {
        this.emit('item:failed', {
          mediaId: task.mediaId,
          title: task.mediaItem.title,
          error: 'All search methods failed'
        })

        return {
          mediaId: task.mediaId,
          success: false,
          error: 'All search methods failed',
          method: 'failed'
        }
      }
    } catch (error: any) {
      console.error(`[MetadataScraper] Error processing ${task.mediaId}:`, error)
      
      this.emit('item:failed', {
        mediaId: task.mediaId,
        title: task.mediaItem.title,
        error: error.message
      })

      return {
        mediaId: task.mediaId,
        success: false,
        error: error.message,
        method: 'failed'
      }
    } finally {
      this.runningTasks.delete(task.mediaId)
    }
  }

  // TMDB搜索
  private async tryTmdbSearch(mediaItem: any): Promise<{ metadata: any; confidence: number; method: 'tmdb' | 'ai' | 'jina' } | null> {
    if (!this.movieDb) {
      return null
    }

    try {
      console.log(`[MetadataScraper] Trying TMDB search for: ${mediaItem.title}`)
      
      // 使用智能识别器改进搜索
      let searchTitle = mediaItem.title
      let searchYear = mediaItem.year
      let detectedType = mediaItem.type

      if (this.intelligentRecognizer) {
        const recognition = await this.intelligentRecognizer.recognizeMediaName(
          mediaItem.title, 
          mediaItem.fullPath || mediaItem.path
        )
        
        if (recognition.confidence > 0.6) {
          searchTitle = recognition.cleanTitle
          searchYear = recognition.year || mediaItem.year
          detectedType = recognition.mediaType !== 'unknown' ? recognition.mediaType : mediaItem.type
        }
      }

      // 执行TMDB搜索
      const searchParams: any = {
        query: searchTitle,
        language: 'zh-CN'
      }

      if (searchYear && searchYear !== "未知") {
        if (detectedType === 'movie') {
          searchParams.year = parseInt(searchYear, 10)
        } else {
          searchParams.first_air_date_year = parseInt(searchYear, 10)
        }
      }

      let searchResponse
      if (detectedType === 'movie') {
        searchResponse = await this.movieDb.searchMovie(searchParams)
      } else if (detectedType === 'tv') {
        searchResponse = await this.movieDb.searchTv(searchParams)
      } else {
        searchResponse = await this.movieDb.searchMulti(searchParams)
      }
      
      if (searchResponse.results && searchResponse.results.length > 0) {
        const result = searchResponse.results[0]
        const itemId = result.id
        const type = result.media_type || detectedType

        let details
        if (type === "movie") {
          details = await this.movieDb.movieInfo({
            id: itemId as number,
            language: 'zh-CN',
            append_to_response: 'credits'
          })
        } else if (type === "tv") {
          details = await this.movieDb.tvInfo({
            id: itemId as number,
            language: 'zh-CN',
            append_to_response: 'credits'
          })
        }

        if (details && (type === 'movie' || type === 'tv')) {
          const metadata = this.mapTMDBToMedia(details, type as 'movie' | 'tv')
          return {
            metadata,
            confidence: 0.9, // TMDB搜索通常置信度较高
            method: 'tmdb'
          }
        }
      }

      return null
    } catch (error: any) {
      console.error(`[MetadataScraper] TMDB search failed:`, error)
      return null
    }
  }

  // AI分析（使用Gemini）
  private async tryAiAnalysis(mediaItem: any): Promise<{ metadata: any; confidence: number; method: 'tmdb' | 'ai' | 'jina' } | null> {
    if (!this.intelligentRecognizer) {
      return null
    }

    try {
      console.log(`[MetadataScraper] Trying AI analysis for: ${mediaItem.title}`)
      
      // 使用AI进行深度分析
      const recognition = await this.intelligentRecognizer.recognizeMediaName(
        mediaItem.title, 
        mediaItem.fullPath || mediaItem.path
      )

      if (recognition.confidence > 0.5) {
        // 基于AI识别结果创建基础元数据
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
          method: 'ai'
        }
      }

      return null
    } catch (error: any) {
      console.error(`[MetadataScraper] AI analysis failed:`, error)
      return null
    }
  }

  // Jina搜索（如果有API key）
  private async tryJinaSearch(mediaItem: any): Promise<{ metadata: any; confidence: number; method: 'tmdb' | 'ai' | 'jina' } | null> {
    if (!this.jinaApiKey) {
      console.log(`[MetadataScraper] No Jina API key available`)
      return null
    }

    try {
      console.log(`[MetadataScraper] Trying Jina search for: ${mediaItem.title}`)
      
      // 调用Jina搜索API
      const response = await axios.get('https://s.jina.ai/search', {
        params: {
          q: `${mediaItem.title} movie tv series ${mediaItem.year}`,
          count: 5
        },
        headers: {
          'Authorization': `Bearer ${this.jinaApiKey}`
        },
        timeout: 10000
      })

      if (response.data && response.data.results && response.data.results.length > 0) {
        const firstResult = response.data.results[0]
        
        // 解析搜索结果，提取有用信息
        const metadata = {
          id: `jina-${Date.now()}`,
          title: this.extractTitleFromJinaResult(firstResult),
          originalTitle: mediaItem.title,
          year: this.extractYearFromJinaResult(firstResult) || mediaItem.year,
          type: this.detectTypeFromJinaResult(firstResult) || mediaItem.type,
          overview: firstResult.snippet || firstResult.content || `通过Jina搜索找到的相关内容`,
          posterPath: null,
          backdropPath: null,
          rating: 0,
          genres: [],
          releaseDate: null
        }

        return {
          metadata,
          confidence: 0.6, // Jina搜索置信度中等
          method: 'jina'
        }
      }

      return null
    } catch (error: any) {
      console.error(`[MetadataScraper] Jina search failed:`, error)
      return null
    }
  }

  // 辅助方法：从Jina结果提取标题
  private extractTitleFromJinaResult(result: any): string {
    return result.title || result.content?.split('\n')[0] || 'Unknown Title'
  }

  // 辅助方法：从Jina结果提取年份
  private extractYearFromJinaResult(result: any): string | null {
    const text = (result.title + ' ' + result.snippet + ' ' + result.content).toLowerCase()
    const yearMatch = text.match(/\b(19|20)\d{2}\b/)
    return yearMatch ? yearMatch[0] : null
  }

  // 辅助方法：从Jina结果检测类型
  private detectTypeFromJinaResult(result: any): 'movie' | 'tv' | 'unknown' {
    const text = (result.title + ' ' + result.snippet + ' ' + result.content).toLowerCase()
    
    if (text.includes('tv series') || text.includes('television') || text.includes('episode')) {
      return 'tv'
    }
    if (text.includes('movie') || text.includes('film')) {
      return 'movie'
    }
    
    return 'unknown'
  }

  // 映射TMDB数据到媒体对象
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
      credits: item.credits
    }
  }

  // 下载海报
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
          "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
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
      console.error(`[MetadataScraper] Error downloading poster:`, error)
      throw error
    }
  }

  // 更新媒体项的元数据
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
      console.error(`[MetadataScraper] Error updating media metadata:`, error)
      throw error
    }
  }

  // 设置API keys
  public setTmdbApiKey(apiKey: string): void {
    this.tmdbApiKey = apiKey
    this.movieDb = new MovieDb(apiKey)
  }

  public setJinaApiKey(apiKey: string): void {
    this.jinaApiKey = apiKey
  }

  // 检查API可用性
  public hasTmdbApiKey(): boolean {
    return !!this.tmdbApiKey
  }

  public getTmdbApiKey(): string | null {
    return this.tmdbApiKey
  }

  public hasJinaApiKey(): boolean {
    return !!this.jinaApiKey
  }

  // 获取批处理状态
  public getBatchStatus(): {
    isProcessing: boolean
    queueLength: number
    runningTasks: number
  } {
    return {
      isProcessing: this.isProcessing,
      queueLength: this.batchQueue.length,
      runningTasks: this.runningTasks.size
    }
  }
}
import { EventEmitter } from 'events'
import type { NetworkStorageClient } from './network-storage-client'
import type { MediaDatabase } from './media-database'
import { MetadataScraper } from './metadata-scraper'
import { TaskQueueManager } from './task-queue-manager'
import type { HashService } from './hash-service'
import { parseFileName } from './file-parser'
import type { Media } from '../types/media'
import * as crypto from 'crypto'
import * as path from 'path'

export interface ScanProgress {
  phase: 'connecting' | 'discovering' | 'processing' | 'scraping' | 'completed' | 'error'
  current: number
  total: number
  currentItem?: string
  error?: string
  startTime: Date
  estimatedTimeRemaining?: number
}

export interface AutoScanStatus {
  isScanning: boolean
  isConnected: boolean
  scanProgress?: ScanProgress
  scrapeProgress?: ScanProgress
  currentPhase: string
  errors: string[]
}

export class AutoScanManager extends EventEmitter {
  private networkStorageClient: NetworkStorageClient
  private mediaDatabase: MediaDatabase
  private metadataScraper: MetadataScraper
  private hashService?: HashService
  private taskQueue: TaskQueueManager
  private status: AutoScanStatus
  private sharePath: string = ""
  private selectedFolders: string[] = []
  private abortController?: AbortController

  constructor(
    networkStorageClient: NetworkStorageClient, 
    mediaDatabase: MediaDatabase, 
    metadataScraper: MetadataScraper
  ) {
    super()
    this.networkStorageClient = networkStorageClient
    this.mediaDatabase = mediaDatabase
    this.metadataScraper = metadataScraper
    this.taskQueue = new TaskQueueManager(3) // 最多3个并发任务

    this.status = {
      isScanning: false,
      isConnected: false,
      currentPhase: 'idle',
      errors: []
    }

    this.setupTaskQueueListeners()
  }

  setSharePath(sharePath: string): void {
    this.sharePath = sharePath
  }

  setSelectedFolders(folders: string[]): void {
    this.selectedFolders = folders
  }


  setHashService(hashService: HashService): void {
    this.hashService = hashService
  }

  async startAutoScan(force: boolean = false): Promise<{ started: boolean; message?: string }> {
    if (this.status.isScanning && !force) {
      return { started: false, message: 'Scan already in progress' }
    }

    if (this.status.isScanning && force) {
      await this.stopAutoScan()
    }

    try {
      console.log('[AutoScan] Starting automatic scan...')
      
      this.status.isScanning = true
      this.status.currentPhase = 'connecting'
      this.status.errors = []
      this.abortController = new AbortController()

      // 重置任务队列
      this.taskQueue.clearAllTasks()
      this.taskQueue.start()

      // 开始扫描流程
      this.startScanProcess()

      this.emitStatusUpdate()
      return { started: true, message: 'Auto scan started successfully' }
    } catch (error: any) {
      this.status.isScanning = false
      this.status.currentPhase = 'error'
      this.status.errors.push(error.message)
      this.emitStatusUpdate()
      return { started: false, message: error.message }
    }
  }

  async stopAutoScan(): Promise<{ stopped: boolean }> {
    console.log('[AutoScan] Stopping automatic scan...')
    
    if (this.abortController) {
      this.abortController.abort()
    }

    this.taskQueue.stop()
    this.taskQueue.clearAllTasks()
    
    this.status.isScanning = false
    this.status.currentPhase = 'idle'
    this.emitStatusUpdate()

    return { stopped: true }
  }

  getStatus(): AutoScanStatus {
    return { ...this.status }
  }

  getMetadataScraper(): MetadataScraper {
    return this.metadataScraper
  }

  private async startScanProcess(): Promise<void> {
    try {
      // 阶段1：连接验证
      await this.verifyConnection()

      // 阶段2：文件发现
      const mediaFiles = await this.discoverMediaFiles()
      
      // 阶段3：文件处理
      const mediaItems = await this.processMediaFiles(mediaFiles)

      // 阶段4：元数据刮削
      if (mediaItems.length > 0) {
        await this.scheduleMetadataFetching(mediaItems)
      }

      // 完成
      this.completeScan()
    } catch (error: any) {
      this.handleScanError(error)
    }
  }

  private async verifyConnection(): Promise<void> {
    if (this.abortController?.signal.aborted) throw new Error('Scan aborted')

    this.updateScanProgress('connecting', 0, 1, 'Verifying SMB connection...')

    if (!this.sharePath) {
      throw new Error('Share path not configured')
    }

    // 这里可以添加连接测试逻辑
    this.status.isConnected = true
    this.updateScanProgress('connecting', 1, 1, 'Connection verified')
  }

  private async discoverMediaFiles(): Promise<any[]> {
    if (this.abortController?.signal.aborted) throw new Error('Scan aborted')

    this.updateScanProgress('discovering', 0, 1, 'Discovering media files...')

    const startPaths = this.selectedFolders && this.selectedFolders.length > 0 
      ? this.selectedFolders 
      : [""]

    let allMediaFiles: any[] = []
    
    for (let i = 0; i < startPaths.length; i++) {
      if (this.abortController?.signal.aborted) throw new Error('Scan aborted')
      
      const folder = startPaths[i]
      this.updateScanProgress('discovering', i, startPaths.length, `Scanning folder: ${folder || '/'}`)
      
      try {
        const mediaFiles = await this.networkStorageClient.scanMediaFiles(folder)
        allMediaFiles = [...allMediaFiles, ...mediaFiles]
      } catch (error: any) {
        console.error(`Error scanning folder ${folder}:`, error)
        this.status.errors.push(`Failed to scan folder ${folder}: ${error.message}`)
      }
    }

    this.updateScanProgress('discovering', startPaths.length, startPaths.length, 
      `Found ${allMediaFiles.length} media files`)
    
    return allMediaFiles
  }

  private async processMediaFiles(mediaFiles: any[]): Promise<Media[]> {
    if (this.abortController?.signal.aborted) throw new Error('Scan aborted')

    this.updateScanProgress('processing', 0, mediaFiles.length, 'Processing media files...')

    // 按类型分组：电影和电视剧分别处理
    const movieFiles = mediaFiles.filter(f => f.type === 'movie')
    const tvFiles = mediaFiles.filter(f => f.type === 'tv')
    
    const mediaItems: Media[] = []
    
    // 处理电影（每个文件一个媒体项）
    for (let i = 0; i < movieFiles.length; i++) {
      if (this.abortController?.signal.aborted) throw new Error('Scan aborted')
      
      const mediaFile = movieFiles[i]
      this.updateScanProgress('processing', i + 1, mediaFiles.length, 
        `Processing movie: ${path.basename(mediaFile.name)}`)

      try {
        const mediaItem = await this.createMediaItem(mediaFile)
        if (mediaItem) {
          await this.mediaDatabase.saveMedia(mediaItem)
          mediaItems.push(mediaItem)
        }
      } catch (error: any) {
        console.error(`Error processing movie ${mediaFile.name}:`, error)
        this.status.errors.push(`Failed to process ${mediaFile.name}: ${error.message}`)
      }
    }
    
    // 处理电视剧（按剧集名称分组）
    const tvShowGroups = this.groupTVFiles(tvFiles)
    let processedCount = movieFiles.length
    
    for (const [showTitle, episodes] of tvShowGroups.entries()) {
      if (this.abortController?.signal.aborted) throw new Error('Scan aborted')
      
      processedCount++
      this.updateScanProgress('processing', processedCount, mediaFiles.length, 
        `Processing TV show: ${showTitle}`)

      try {
        const tvShowItem = await this.createTVShowItem(showTitle, episodes)
        if (tvShowItem) {
          await this.mediaDatabase.saveMedia(tvShowItem)
          mediaItems.push(tvShowItem)
        }
      } catch (error: any) {
        console.error(`Error processing TV show ${showTitle}:`, error)
        this.status.errors.push(`Failed to process TV show ${showTitle}: ${error.message}`)
      }
    }

    return mediaItems
  }

  private async createMediaItem(mediaFile: any): Promise<Media | null> {
    try {
      const { title, year } = parseFileName(mediaFile.name)
      
      // 计算文件hash（如果需要）
      const fileHash = await this.calculateFileHash(mediaFile)

      const mediaId = this.generateMediaId(mediaFile)
      const mediaItem: Media = {
        id: mediaId,
        title: title || mediaFile.name,
        year: year || "未知",
        type: mediaFile.type || "unknown",
        path: mediaFile.path,
        fullPath: mediaFile.fullPath || mediaFile.path,
        posterPath: "",
        dateAdded: new Date().toISOString(),
        lastUpdated: new Date().toISOString(),
        fileHash
      }

      return mediaItem
    } catch (error: any) {
      console.error(`Error creating media item for ${mediaFile.name}:`, error)
      return null
    }
  }
  
  private groupTVFiles(tvFiles: any[]): Map<string, any[]> {
    const groups = new Map<string, any[]>()
    
    for (const file of tvFiles) {
      const { title, season, episode } = parseFileName(file.name)
      
      // 提取电视剧名称（去除季集信息）
      let showTitle = title
      
      // 尝试从路径中提取更好的剧集名称
      const pathParts = file.path.split(/[\\/]/)
      for (let i = pathParts.length - 2; i >= 0; i--) {
        const part = pathParts[i]
        // 如果这个目录不像是季节目录，就用它作为剧集名称
        if (!part.match(/[Ss](eason)?\s*\d+|第.*?季/i)) {
          showTitle = part.replace(/[._]/g, ' ').trim()
          break
        }
      }
      
      // 清理剧集名称
      showTitle = showTitle
        .replace(/[._]/g, ' ')
        .replace(/\[.*?\]/g, '')
        .replace(/【.*?】/g, '')
        .replace(/\(.*?\)/g, '')
        .replace(/\s+/g, ' ')
        .trim()
      
      if (!groups.has(showTitle)) {
        groups.set(showTitle, [])
      }
      
      groups.get(showTitle)!.push({
        ...file,
        season: season || 1,
        episode: episode || 1,
        episodeName: title
      })
    }
    
    return groups
  }
  
  private async createTVShowItem(showTitle: string, episodes: any[]): Promise<Media | null> {
    try {
      // 从第一集中获取基础信息
      const firstEpisode = episodes[0]
      const { year } = parseFileName(firstEpisode.name)
      
      // 计算总集数
      const episodeCount = episodes.length
      
      // 创建剧集列表
      const episodeList = episodes.map(ep => ({
        path: ep.path,
        name: ep.episodeName,
        season: ep.season,
        episode: ep.episode
      }))
      
      // 生成唯一ID（基于剧集名称）
      const showId = `tv-show-${Buffer.from(showTitle).toString('base64').slice(0, 12)}`
      
      const tvShowItem: Media = {
        id: showId,
        title: showTitle,
        year: year || "未知",
        type: "tv",
        path: firstEpisode.path, // 使用第一集的路径作为代表
        fullPath: firstEpisode.fullPath || firstEpisode.path,
        posterPath: "",
        dateAdded: new Date().toISOString(),
        lastUpdated: new Date().toISOString(),
        episodeCount,
        episodes: episodeList,
        fileHash: await this.calculateFileHash(firstEpisode)
      }

      return tvShowItem
    } catch (error: any) {
      console.error(`Error creating TV show item for ${showTitle}:`, error)
      return null
    }
  }

  private async calculateFileHash(mediaFile: any): Promise<string> {
    try {
      // 为了效率，我们可以基于文件路径和大小生成hash
      // 在实际应用中，可能需要读取文件内容的部分来计算真正的hash
      const hashInput = `${mediaFile.path}:${mediaFile.size || Date.now()}`
      return crypto.createHash('md5').update(hashInput).digest('hex')
    } catch (error) {
      console.error('Error calculating file hash:', error)
      return ''
    }
  }

  private generateMediaId(mediaFile: any): string {
    const type = mediaFile.type === 'tv' ? 'tv-series' : 'movie'
    const pathHash = Buffer.from(mediaFile.path).toString("base64").slice(0, 12)
    return `${type}-${pathHash}`
  }

  private async scheduleMetadataFetching(mediaItems: Media[]): Promise<void> {
    console.log(`[AutoScan] Scheduling enhanced metadata fetching for ${mediaItems.length} items`)
    
    if (!this.metadataScraper) {
      console.log('[AutoScan] Enhanced scraper not available, skipping metadata fetching')
      return
    }

    this.status.scrapeProgress = {
      phase: 'scraping',
      current: 0,
      total: mediaItems.length,
      startTime: new Date()
    }

    // 设置增强刮削器的事件监听
    this.setupEnhancedScraperListeners()

    // 批量处理媒体项
    const mediaIds = mediaItems.map(item => item.id)
    
    try {
      // 使用增强刮削器进行批量处理
      const results = await this.metadataScraper.batchScrapeMetadata(mediaIds)
      
      console.log(`[AutoScan] Enhanced scraping completed: ${results.filter(r => r.success).length}/${results.length} successful`)
      
      // 更新刮削进度
      if (this.status.scrapeProgress) {
        this.status.scrapeProgress.current = results.length
        this.status.scrapeProgress.phase = 'completed'
      }
      
      this.emitStatusUpdate()
    } catch (error) {
      console.error('[AutoScan] Enhanced scraping failed:', error)
      if (this.status.scrapeProgress) {
        this.status.scrapeProgress.phase = 'error'
      }
      this.emitStatusUpdate()
    }
  }

  private async completeScan(): Promise<void> {
    console.log('[AutoScan] Scan completed successfully')
    
    this.status.isScanning = false
    this.status.currentPhase = 'completed'
    
    if (this.status.scanProgress) {
      this.status.scanProgress.phase = 'completed'
    }

    // 触发hash处理（后台进行，不阻塞完成事件）
    if (this.hashService) {
      this.processHashMatching().catch(error => {
        console.error('[AutoScan] Hash processing failed:', error)
      })
    }

    this.emitStatusUpdate()
    this.emit('scan:completed', {
      totalProcessed: this.status.scanProgress?.total || 0,
      errors: this.status.errors
    })
  }

  private handleScanError(error: Error): void {
    console.error('[AutoScan] Scan failed:', error)
    
    this.status.isScanning = false
    this.status.currentPhase = 'error'
    this.status.errors.push(error.message)
    
    if (this.status.scanProgress) {
      this.status.scanProgress.phase = 'error'
      this.status.scanProgress.error = error.message
    }

    this.emitStatusUpdate()
    this.emit('scan:error', { error: error.message })
  }

  private updateScanProgress(
    phase: ScanProgress['phase'], 
    current: number, 
    total: number, 
    currentItem?: string
  ): void {
    if (!this.status.scanProgress) {
      this.status.scanProgress = {
        phase,
        current,
        total,
        startTime: new Date()
      }
    } else {
      this.status.scanProgress.phase = phase
      this.status.scanProgress.current = current
      this.status.scanProgress.total = total
    }

    if (currentItem) {
      this.status.scanProgress.currentItem = currentItem
    }

    // 计算估计剩余时间
    if (current > 0 && phase !== 'completed') {
      const elapsed = Date.now() - this.status.scanProgress.startTime.getTime()
      const avgTimePerItem = elapsed / current
      const remaining = (total - current) * avgTimePerItem
      this.status.scanProgress.estimatedTimeRemaining = remaining
    }

    this.emitStatusUpdate()
  }

  private setupTaskQueueListeners(): void {
    // TaskQueue currently not used for scraping since we use batch processing
    // Keeping this method for potential future use with other task types
    this.taskQueue.on('task:completed', (result: { taskId: string; result: any }) => {
      console.log(`[AutoScan] Task ${result.taskId} completed`)
    })

    this.taskQueue.on('task:failed', (error: { taskId: string; error: string }) => {
      console.error(`[AutoScan] Task ${error.taskId} failed:`, error.error)
      this.status.errors.push(`Task failed: ${error.error}`)
    })
  }

  private setupEnhancedScraperListeners(): void {
    if (!this.metadataScraper) return

    // 监听批量处理开始
    this.metadataScraper.on('batch:started', (progress: any) => {
      console.log(`[AutoScan] Enhanced scraping batch started: ${progress.total} items`)
      if (this.status.scrapeProgress) {
        this.status.scrapeProgress.total = progress.total
        this.status.scrapeProgress.current = 0
      }
      this.emitStatusUpdate()
    })

    // 监听单个项目开始
    this.metadataScraper.on('item:started', (data: any) => {
      console.log(`[AutoScan] Started scraping: ${data.title}`)
      if (this.status.scrapeProgress) {
        this.status.scrapeProgress.currentItem = data.title
      }
      this.emitStatusUpdate()
    })

    // 监听单个项目完成
    this.metadataScraper.on('item:completed', (data: any) => {
      console.log(`[AutoScan] Completed scraping: ${data.title} (method: ${data.method})`)
      if (this.status.scrapeProgress) {
        this.status.scrapeProgress.current++
      }
      this.emitStatusUpdate()
    })

    // 监听单个项目失败
    this.metadataScraper.on('item:failed', (data: any) => {
      console.log(`[AutoScan] Failed scraping: ${data.title} - ${data.error}`)
      if (this.status.scrapeProgress) {
        this.status.scrapeProgress.current++
      }
      this.status.errors.push(`Scraping failed for ${data.title}: ${data.error}`)
      this.emitStatusUpdate()
    })

    // 监听批量处理完成
    this.metadataScraper.on('batch:completed', (progress: any) => {
      console.log(`[AutoScan] Enhanced scraping batch completed: ${progress.completed}/${progress.total} successful`)
      if (this.status.scrapeProgress) {
        this.status.scrapeProgress.phase = 'completed'
        this.status.scrapeProgress.current = progress.total
      }
      this.emitStatusUpdate()
    })
  }

  private async processHashMatching(): Promise<void> {
    if (!this.hashService) return

    try {
      console.log('[AutoScan] Starting hash matching process...')
      
      // 获取所有媒体项
      const movies = await this.mediaDatabase.getMediaByType('movie')
      const tvShows = await this.mediaDatabase.getMediaByType('tv')
      const allMedia = [...movies, ...tvShows]

      if (allMedia.length === 0) {
        console.log('[AutoScan] No media found for hash processing')
        return
      }

      console.log(`[AutoScan] Processing hashes for ${allMedia.length} media items`)
      
      // 批量处理hash匹配
      const results = await this.hashService.batchProcessMediaHashes(allMedia)
      
      console.log(`[AutoScan] Hash processing completed:`, results)
      
      // 发出hash处理完成事件
      this.emit('hash:completed', results)
    } catch (error: any) {
      console.error('[AutoScan] Error in hash processing:', error)
      this.emit('hash:error', { error: error.message })
    }
  }

  private emitStatusUpdate(): void {
    this.emit('status:update', this.getStatus())
  }
}
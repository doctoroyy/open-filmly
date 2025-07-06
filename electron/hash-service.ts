import axios from 'axios'
import * as crypto from 'crypto'
import * as fs from 'fs'
import type { MediaDatabase } from './media-database'
import type { Media } from '../types/media'

interface HashMatchResult {
  fileHash: string
  mediaData?: {
    title: string
    year: string
    type: 'movie' | 'tv'
    tmdbId?: string
    overview?: string
    genres?: string[]
    rating?: number
    confidence: number
  }
  matched: boolean
  source: 'community' | 'tmdb' | 'local'
}

interface HashSubmissionData {
  fileHash: string
  mediaData: {
    title: string
    year: string
    type: 'movie' | 'tv'
    tmdbId?: string
    overview?: string
    genres?: string[]
    rating?: number
  }
  confidence: number
  userAgent: string
}

export class HashService {
  private mediaDatabase: MediaDatabase
  private apiBaseUrl: string
  private userAgent: string
  private cache: Map<string, HashMatchResult> = new Map()
  private cacheExpiry: number = 24 * 60 * 60 * 1000 // 24小时

  constructor(mediaDatabase: MediaDatabase) {
    this.mediaDatabase = mediaDatabase
    
    // 使用免费的API服务（可以部署在Cloudflare Workers上）
    this.apiBaseUrl = process.env.HASH_API_URL || 'https://filmly-hash-api.your-domain.workers.dev'
    
    // 生成用户代理标识
    this.userAgent = `open-filmly-${this.generateUserId()}`
  }

  /**
   * 计算文件的真实Hash值
   * 为了效率，可以只计算文件的部分内容
   */
  public async calculateRealFileHash(filePath: string): Promise<string> {
    try {
      // 如果是本地文件，直接计算
      if (fs.existsSync(filePath)) {
        return this.calculateLocalFileHash(filePath)
      }
      
      // 如果是网络文件（SMB等），使用文件信息计算伪hash
      const stats = await this.getFileStats(filePath)
      const hashInput = `${filePath}:${stats.size}:${stats.mtime}`
      return crypto.createHash('md5').update(hashInput).digest('hex')
    } catch (error) {
      console.error('Error calculating file hash:', error)
      // 降级到基于路径的hash
      return crypto.createHash('md5').update(filePath).digest('hex')
    }
  }

  /**
   * 查询文件Hash对应的媒体信息
   */
  public async queryHashMatch(fileHash: string): Promise<HashMatchResult> {
    try {
      // 检查缓存
      const cacheKey = `hash:${fileHash}`
      if (this.cache.has(cacheKey)) {
        const cached = this.cache.get(cacheKey)!
        console.log(`[HashService] Cache hit for hash: ${fileHash}`)
        return cached
      }

      // 首先查询本地数据库
      const localMatch = await this.queryLocalHash(fileHash)
      if (localMatch.matched) {
        this.cache.set(cacheKey, localMatch)
        return localMatch
      }

      // 查询云端数据库
      const cloudMatch = await this.queryCloudHash(fileHash)
      
      // 缓存结果
      this.cache.set(cacheKey, cloudMatch)
      
      return cloudMatch
    } catch (error) {
      console.error('[HashService] Error querying hash match:', error)
      return {
        fileHash,
        matched: false,
        source: 'local'
      }
    }
  }

  /**
   * 提交文件Hash和媒体信息到云端
   */
  public async submitHashData(
    fileHash: string, 
    mediaData: Media, 
    confidence: number = 0.8
  ): Promise<boolean> {
    try {
      // 只提交高置信度的数据
      if (confidence < 0.7) {
        console.log('[HashService] Confidence too low, skipping submission')
        return false
      }

      const submissionData: HashSubmissionData = {
        fileHash,
        mediaData: {
          title: mediaData.title,
          year: mediaData.year,
          type: mediaData.type as 'movie' | 'tv',
          tmdbId: this.extractTmdbId(mediaData),
          overview: this.extractOverview(mediaData),
          genres: this.extractGenres(mediaData),
          rating: this.extractRating(mediaData)
        },
        confidence,
        userAgent: this.userAgent
      }

      const response = await axios.post(`${this.apiBaseUrl}/api/submit-hash`, submissionData, {
        timeout: 10000,
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': this.userAgent
        }
      })

      if (response.status === 200) {
        console.log(`[HashService] Successfully submitted hash: ${fileHash}`)
        
        // 更新本地记录
        await this.recordHashSubmission(fileHash, mediaData)
        
        return true
      }

      return false
    } catch (error) {
      console.error('[HashService] Error submitting hash data:', error)
      return false
    }
  }

  /**
   * 批量处理媒体文件的Hash匹配
   */
  public async batchProcessMediaHashes(mediaItems: Media[]): Promise<{
    matched: number
    submitted: number
    total: number
  }> {
    let matched = 0
    let submitted = 0

    for (const media of mediaItems) {
      try {
        // 计算或获取文件hash
        let fileHash = media.fileHash
        if (!fileHash) {
          fileHash = await this.calculateRealFileHash(media.fullPath || media.path)
          
          // 更新数据库中的hash
          await this.mediaDatabase.updateMediaFileHash(media.id, fileHash)
        }

        // 查询hash匹配
        const matchResult = await this.queryHashMatch(fileHash)
        
        if (matchResult.matched) {
          matched++
          
          // 如果匹配到更好的数据，更新本地记录
          if (matchResult.source === 'community' && matchResult.mediaData) {
            await this.updateMediaWithHashData(media.id, matchResult.mediaData)
          }
        } else {
          // 如果本地有完整的媒体信息，提交到云端
          if (this.hasCompleteMetadata(media)) {
            const success = await this.submitHashData(fileHash, media, 0.8)
            if (success) {
              submitted++
            }
          }
        }
      } catch (error) {
        console.error(`[HashService] Error processing media ${media.id}:`, error)
      }
    }

    console.log(`[HashService] Batch processing completed: ${matched} matched, ${submitted} submitted, ${mediaItems.length} total`)
    
    return {
      matched,
      submitted,
      total: mediaItems.length
    }
  }

  // 私有辅助方法

  private async calculateLocalFileHash(filePath: string): Promise<string> {
    return new Promise((resolve, reject) => {
      const hash = crypto.createHash('md5')
      const stream = fs.createReadStream(filePath, { start: 0, end: 1024 * 1024 }) // 只读取前1MB
      
      stream.on('data', (data) => hash.update(data))
      stream.on('end', () => resolve(hash.digest('hex')))
      stream.on('error', reject)
    })
  }

  private async getFileStats(filePath: string): Promise<{ size: number; mtime: number }> {
    try {
      const stats = fs.statSync(filePath)
      return {
        size: stats.size,
        mtime: stats.mtime.getTime()
      }
    } catch (error) {
      // 返回默认值
      return {
        size: Date.now(),
        mtime: Date.now()
      }
    }
  }

  private async queryLocalHash(fileHash: string): Promise<HashMatchResult> {
    try {
      const media = await this.mediaDatabase.getMediaByFileHash(fileHash)
      
      if (media && this.hasCompleteMetadata(media)) {
        return {
          fileHash,
          mediaData: {
            title: media.title,
            year: media.year,
            type: media.type as 'movie' | 'tv',
            tmdbId: this.extractTmdbId(media),
            overview: this.extractOverview(media),
            genres: this.extractGenres(media),
            rating: this.extractRating(media),
            confidence: 0.9
          },
          matched: true,
          source: 'local'
        }
      }

      return {
        fileHash,
        matched: false,
        source: 'local'
      }
    } catch (error) {
      console.error('[HashService] Error querying local hash:', error)
      return {
        fileHash,
        matched: false,
        source: 'local'
      }
    }
  }

  private async queryCloudHash(fileHash: string): Promise<HashMatchResult> {
    try {
      const response = await axios.get(`${this.apiBaseUrl}/api/query-hash/${fileHash}`, {
        timeout: 5000,
        headers: {
          'User-Agent': this.userAgent
        }
      })

      if (response.status === 200 && response.data.matched) {
        console.log(`[HashService] Cloud match found for hash: ${fileHash}`)
        
        return {
          fileHash,
          mediaData: response.data.mediaData,
          matched: true,
          source: 'community'
        }
      }

      return {
        fileHash,
        matched: false,
        source: 'community'
      }
    } catch (error) {
      if (axios.isAxiosError(error) && error.response?.status === 404) {
        // 404是正常的（hash不存在）
        return {
          fileHash,
          matched: false,
          source: 'community'
        }
      }

      console.error('[HashService] Error querying cloud hash:', error)
      return {
        fileHash,
        matched: false,
        source: 'community'
      }
    }
  }

  private generateUserId(): string {
    // 生成一个匿名但稳定的用户ID
    const machineId = process.platform + process.arch + (process.env.USERNAME || process.env.USER || 'anonymous')
    return crypto.createHash('sha256').update(machineId).digest('hex').substring(0, 12)
  }

  private extractTmdbId(media: Media): string | undefined {
    try {
      if (media.details) {
        const details = JSON.parse(media.details)
        return details.tmdbId || details.id
      }
    } catch (error) {
      // 忽略解析错误
    }
    return undefined
  }

  private extractOverview(media: Media): string | undefined {
    try {
      if (media.details) {
        const details = JSON.parse(media.details)
        return details.overview
      }
    } catch (error) {
      // 忽略解析错误
    }
    return undefined
  }

  private extractGenres(media: Media): string[] | undefined {
    try {
      if (media.details) {
        const details = JSON.parse(media.details)
        return details.genres
      }
    } catch (error) {
      // 忽略解析错误
    }
    return undefined
  }

  private extractRating(media: Media): number | undefined {
    try {
      if (media.rating) {
        return parseFloat(media.rating)
      }
      if (media.details) {
        const details = JSON.parse(media.details)
        return details.rating
      }
    } catch (error) {
      // 忽略解析错误
    }
    return undefined
  }

  private hasCompleteMetadata(media: Media): boolean {
    // 检查是否有足够的元数据可以分享
    return !!(
      media.title &&
      media.year &&
      media.type &&
      (this.extractOverview(media) || this.extractTmdbId(media))
    )
  }

  private async updateMediaWithHashData(mediaId: string, hashData: any): Promise<void> {
    try {
      await this.mediaDatabase.updateMediaDetails(mediaId, {
        overview: hashData.overview,
        rating: hashData.rating,
        genres: hashData.genres
      })
      
      console.log(`[HashService] Updated media ${mediaId} with hash data`)
    } catch (error) {
      console.error(`[HashService] Error updating media with hash data:`, error)
    }
  }

  private async recordHashSubmission(fileHash: string, mediaData: Media): Promise<void> {
    try {
      // 可以在数据库中记录提交历史，用于避免重复提交
      const submissionRecord = {
        fileHash,
        mediaId: mediaData.id,
        submittedAt: new Date().toISOString()
      }
      
      // 这里可以创建一个submissions表来记录
      console.log(`[HashService] Recorded hash submission: ${fileHash}`)
    } catch (error) {
      console.error('[HashService] Error recording hash submission:', error)
    }
  }
}
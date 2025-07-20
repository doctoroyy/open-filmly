import { MovieDb } from "moviedb-promise"
import axios from "axios"

interface TMDBConfiguration {
  images: {
    base_url: string
    secure_base_url: string
    backdrop_sizes: string[]
    logo_sizes: string[]
    poster_sizes: string[]
    profile_sizes: string[]
    still_sizes: string[]
  }
  change_keys: string[]
}

interface SearchOptions {
  language?: string
  includeAdult?: boolean
  region?: string
  year?: number
  firstAirDateYear?: number
  page?: number
}

interface DetailedSearchResult {
  tmdbId: number
  title: string
  originalTitle: string
  overview: string
  posterPath: string | null
  backdropPath: string | null
  releaseDate: string | null
  genres: string[]
  rating: number
  type: 'movie' | 'tv'
  runtime?: number
  numberOfSeasons?: number
  numberOfEpisodes?: number
  credits?: any
  videos?: any
  similar?: any[]
  keywords?: any[]
  recommendations?: any[]
}

export class EnhancedTMDBClient {
  private movieDb: MovieDb
  private apiKey: string
  private configuration: TMDBConfiguration | null = null
  private configLastUpdated: number = 0
  private readonly CONFIG_CACHE_DURATION = 24 * 60 * 60 * 1000 // 24小时

  constructor(apiKey: string) {
    this.apiKey = apiKey
    this.movieDb = new MovieDb(apiKey)
    console.log('[EnhancedTMDBClient] Initialized with API key')
  }

  /**
   * 获取TMDB配置信息
   */
  private async getConfiguration(): Promise<TMDBConfiguration> {
    const now = Date.now()
    
    if (this.configuration && (now - this.configLastUpdated) < this.CONFIG_CACHE_DURATION) {
      return this.configuration
    }

    try {
      const config = await this.movieDb.configuration()
      this.configuration = config as TMDBConfiguration
      this.configLastUpdated = now
      console.log('[EnhancedTMDBClient] Configuration updated')
      return this.configuration
    } catch (error) {
      console.error('[EnhancedTMDBClient] Failed to get configuration:', error)
      // 返回默认配置
      return {
        images: {
          base_url: 'http://image.tmdb.org/t/p/',
          secure_base_url: 'https://image.tmdb.org/t/p/',
          backdrop_sizes: ['w300', 'w780', 'w1280', 'original'],
          logo_sizes: ['w45', 'w92', 'w154', 'w185', 'w300', 'w500', 'original'],
          poster_sizes: ['w92', 'w154', 'w185', 'w342', 'w500', 'w780', 'original'],
          profile_sizes: ['w45', 'w185', 'h632', 'original'],
          still_sizes: ['w92', 'w185', 'w300', 'original']
        },
        change_keys: []
      }
    }
  }

  /**
   * 构建图片URL
   */
  private async buildImageUrl(path: string | null, size: string = 'original', type: 'poster' | 'backdrop' | 'profile' = 'poster'): Promise<string | null> {
    if (!path) return null

    const config = await this.getConfiguration()
    return `${config.images.secure_base_url}${size}${path}`
  }

  /**
   * 增强的电影搜索
   */
  async searchMovies(query: string, options: SearchOptions = {}): Promise<any[]> {
    try {
      const searchParams = {
        query: query.trim(),
        language: options.language || 'zh-CN',
        include_adult: options.includeAdult || false,
        region: options.region || 'CN',
        page: options.page || 1,
        ...(options.year && { year: options.year })
      }

      console.log(`[EnhancedTMDBClient] Searching movies with params:`, searchParams)
      
      const response = await this.movieDb.searchMovie(searchParams)
      return response.results || []
    } catch (error) {
      console.error('[EnhancedTMDBClient] Movie search failed:', error)
      return []
    }
  }

  /**
   * 增强的电视剧搜索
   */
  async searchTVShows(query: string, options: SearchOptions = {}): Promise<any[]> {
    try {
      const searchParams = {
        query: query.trim(),
        language: options.language || 'zh-CN',
        include_adult: options.includeAdult || false,
        page: options.page || 1,
        ...(options.firstAirDateYear && { first_air_date_year: options.firstAirDateYear })
      }

      console.log(`[EnhancedTMDBClient] Searching TV shows with params:`, searchParams)
      
      const response = await this.movieDb.searchTv(searchParams)
      return response.results || []
    } catch (error) {
      console.error('[EnhancedTMDBClient] TV search failed:', error)
      return []
    }
  }

  /**
   * 多媒体搜索
   */
  async searchMulti(query: string, options: SearchOptions = {}): Promise<any[]> {
    try {
      const searchParams = {
        query: query.trim(),
        language: options.language || 'zh-CN',
        include_adult: options.includeAdult || false,
        page: options.page || 1
      }

      console.log(`[EnhancedTMDBClient] Multi-search with params:`, searchParams)
      
      const response = await this.movieDb.searchMulti(searchParams)
      return response.results || []
    } catch (error) {
      console.error('[EnhancedTMDBClient] Multi-search failed:', error)
      return []
    }
  }

  /**
   * 获取详细的电影信息
   */
  async getMovieDetails(movieId: number): Promise<DetailedSearchResult | null> {
    try {
      console.log(`[EnhancedTMDBClient] Getting movie details for ID: ${movieId}`)
      
      const movie = await this.movieDb.movieInfo({
        id: movieId,
        language: 'zh-CN',
        append_to_response: 'credits,videos,similar,keywords,recommendations'
      })

      const posterPath = await this.buildImageUrl(movie.poster_path, 'w500', 'poster')
      const backdropPath = await this.buildImageUrl(movie.backdrop_path, 'original', 'backdrop')

      return {
        tmdbId: movie.id,
        title: movie.title,
        originalTitle: movie.original_title,
        overview: movie.overview || '',
        posterPath,
        backdropPath,
        releaseDate: movie.release_date,
        genres: movie.genres ? movie.genres.map((g: any) => g.name) : [],
        rating: movie.vote_average || 0,
        type: 'movie',
        runtime: movie.runtime,
        credits: movie.credits,
        videos: movie.videos,
        similar: movie.similar?.results || [],
        keywords: movie.keywords?.keywords || [],
        recommendations: movie.recommendations?.results || []
      }
    } catch (error) {
      console.error(`[EnhancedTMDBClient] Failed to get movie details for ID ${movieId}:`, error)
      return null
    }
  }

  /**
   * 获取详细的电视剧信息
   */
  async getTVShowDetails(tvId: number): Promise<DetailedSearchResult | null> {
    try {
      console.log(`[EnhancedTMDBClient] Getting TV show details for ID: ${tvId}`)
      
      const tvShow = await this.movieDb.tvInfo({
        id: tvId,
        language: 'zh-CN',
        append_to_response: 'credits,videos,similar,keywords,recommendations'
      })

      const posterPath = await this.buildImageUrl(tvShow.poster_path, 'w500', 'poster')
      const backdropPath = await this.buildImageUrl(tvShow.backdrop_path, 'original', 'backdrop')

      return {
        tmdbId: tvShow.id,
        title: tvShow.name,
        originalTitle: tvShow.original_name,
        overview: tvShow.overview || '',
        posterPath,
        backdropPath,
        releaseDate: tvShow.first_air_date,
        genres: tvShow.genres ? tvShow.genres.map((g: any) => g.name) : [],
        rating: tvShow.vote_average || 0,
        type: 'tv',
        numberOfSeasons: tvShow.number_of_seasons,
        numberOfEpisodes: tvShow.number_of_episodes,
        credits: tvShow.credits,
        videos: tvShow.videos,
        similar: tvShow.similar?.results || [],
        keywords: tvShow.keywords?.results || [],
        recommendations: tvShow.recommendations?.results || []
      }
    } catch (error) {
      console.error(`[EnhancedTMDBClient] Failed to get TV show details for ID ${tvId}:`, error)
      return null
    }
  }

  /**
   * 智能搜索 - 结合多种搜索策略
   */
  async intelligentSearch(query: string, type?: 'movie' | 'tv', year?: number): Promise<DetailedSearchResult[]> {
    console.log(`[EnhancedTMDBClient] Intelligent search for: "${query}", type: ${type}, year: ${year}`)
    
    const results: DetailedSearchResult[] = []
    const seenIds = new Set<string>()

    try {
      // 搜索选项
      const searchOptions: SearchOptions = {
        language: 'zh-CN',
        includeAdult: false,
        year: type === 'movie' ? year : undefined,
        firstAirDateYear: type === 'tv' ? year : undefined
      }

      let searchResults: any[] = []

      // 根据类型进行搜索
      if (type === 'movie') {
        searchResults = await this.searchMovies(query, searchOptions)
      } else if (type === 'tv') {
        searchResults = await this.searchTVShows(query, searchOptions)
      } else {
        // 如果没有指定类型，使用多媒体搜索
        searchResults = await this.searchMulti(query, searchOptions)
      }

      // 获取详细信息
      for (const result of searchResults.slice(0, 10)) { // 限制为前10个结果
        const resultType = result.media_type || type || (result.title ? 'movie' : 'tv')
        const key = `${resultType}-${result.id}`
        
        if (seenIds.has(key)) continue
        seenIds.add(key)

        let detailedResult: DetailedSearchResult | null = null
        
        if (resultType === 'movie') {
          detailedResult = await this.getMovieDetails(result.id)
        } else if (resultType === 'tv') {
          detailedResult = await this.getTVShowDetails(result.id)
        }

        if (detailedResult) {
          results.push(detailedResult)
        }

        // 添加延迟以避免API限制
        await this.delay(100)
      }

      console.log(`[EnhancedTMDBClient] Intelligent search returned ${results.length} detailed results`)
      return results
    } catch (error) {
      console.error('[EnhancedTMDBClient] Intelligent search failed:', error)
      return []
    }
  }

  /**
   * 批量搜索
   */
  async batchSearch(queries: Array<{query: string, type?: 'movie' | 'tv', year?: number}>): Promise<DetailedSearchResult[]> {
    console.log(`[EnhancedTMDBClient] Starting batch search for ${queries.length} queries`)
    
    const allResults: DetailedSearchResult[] = []
    const batchSize = 5 // 每批处理5个查询
    
    for (let i = 0; i < queries.length; i += batchSize) {
      const batch = queries.slice(i, i + batchSize)
      console.log(`[EnhancedTMDBClient] Processing batch ${Math.floor(i / batchSize) + 1}/${Math.ceil(queries.length / batchSize)}`)
      
      const batchPromises = batch.map(async (item) => {
        try {
          return await this.intelligentSearch(item.query, item.type, item.year)
        } catch (error) {
          console.error(`[EnhancedTMDBClient] Batch search failed for query "${item.query}":`, error)
          return []
        }
      })

      const batchResults = await Promise.all(batchPromises)
      
      for (const results of batchResults) {
        allResults.push(...results)
      }

      // 批次间延迟
      if (i + batchSize < queries.length) {
        await this.delay(1000)
      }
    }

    console.log(`[EnhancedTMDBClient] Batch search completed, total results: ${allResults.length}`)
    return allResults
  }

  /**
   * 获取热门电影
   */
  async getTrendingMovies(timeWindow: 'day' | 'week' = 'week'): Promise<DetailedSearchResult[]> {
    try {
      console.log(`[EnhancedTMDBClient] Getting trending movies for ${timeWindow}`)
      
      const response = await this.movieDb.trending('movie', timeWindow, { language: 'zh-CN' })
      const results: DetailedSearchResult[] = []

      for (const movie of (response.results || []).slice(0, 20)) {
        const detailedResult = await this.getMovieDetails(movie.id)
        if (detailedResult) {
          results.push(detailedResult)
        }
        await this.delay(50)
      }

      return results
    } catch (error) {
      console.error('[EnhancedTMDBClient] Failed to get trending movies:', error)
      return []
    }
  }

  /**
   * 获取热门电视剧
   */
  async getTrendingTVShows(timeWindow: 'day' | 'week' = 'week'): Promise<DetailedSearchResult[]> {
    try {
      console.log(`[EnhancedTMDBClient] Getting trending TV shows for ${timeWindow}`)
      
      const response = await this.movieDb.trending('tv', timeWindow, { language: 'zh-CN' })
      const results: DetailedSearchResult[] = []

      for (const tvShow of (response.results || []).slice(0, 20)) {
        const detailedResult = await this.getTVShowDetails(tvShow.id)
        if (detailedResult) {
          results.push(detailedResult)
        }
        await this.delay(50)
      }

      return results
    } catch (error) {
      console.error('[EnhancedTMDBClient] Failed to get trending TV shows:', error)
      return []
    }
  }

  /**
   * 根据类型获取详细信息
   */
  async getDetailsByType(id: number, type: 'movie' | 'tv'): Promise<DetailedSearchResult | null> {
    if (type === 'movie') {
      return await this.getMovieDetails(id)
    } else {
      return await this.getTVShowDetails(id)
    }
  }

  /**
   * 验证API密钥
   */
  async validateApiKey(): Promise<boolean> {
    try {
      await this.movieDb.configuration()
      console.log('[EnhancedTMDBClient] API key validation successful')
      return true
    } catch (error) {
      console.error('[EnhancedTMDBClient] API key validation failed:', error)
      return false
    }
  }

  /**
   * 获取API使用统计
   */
  async getApiStatus(): Promise<{ valid: boolean, rateLimitRemaining?: number, rateLimitReset?: number }> {
    try {
      // TMDB没有直接的API来检查配额，所以我们通过一个简单的请求来验证
      const response = await axios.get(`https://api.themoviedb.org/3/configuration?api_key=${this.apiKey}`)
      
      return {
        valid: true,
        rateLimitRemaining: response.headers['x-ratelimit-remaining'] ? 
          parseInt(response.headers['x-ratelimit-remaining']) : undefined,
        rateLimitReset: response.headers['x-ratelimit-reset'] ? 
          parseInt(response.headers['x-ratelimit-reset']) : undefined
      }
    } catch (error) {
      console.error('[EnhancedTMDBClient] API status check failed:', error)
      return { valid: false }
    }
  }

  /**
   * 工具方法：延迟
   */
  private async delay(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms))
  }

  /**
   * 获取配置信息（公开方法）
   */
  async getImageConfiguration(): Promise<TMDBConfiguration['images'] | null> {
    try {
      const config = await this.getConfiguration()
      return config.images
    } catch (error) {
      console.error('[EnhancedTMDBClient] Failed to get image configuration:', error)
      return null
    }
  }

  /**
   * 清理配置缓存
   */
  clearConfigurationCache(): void {
    this.configuration = null
    this.configLastUpdated = 0
    console.log('[EnhancedTMDBClient] Configuration cache cleared')
  }
}
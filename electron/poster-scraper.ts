import * as path from "path"
import * as fs from "fs"
import * as os from "os"
import axios from "axios"
import type { MediaDatabase } from "./media-database"

export class PosterScraper {
  private mediaDatabase: MediaDatabase
  private posterCacheDir: string
  private tmdbApiKey: string | null = null

  constructor(mediaDatabase: MediaDatabase, tmdbApiKey?: string) {
    this.mediaDatabase = mediaDatabase
    this.tmdbApiKey = tmdbApiKey || process.env.TMDB_API_KEY || null

    // 创建海报缓存目录
    this.posterCacheDir = path.join(os.homedir(), ".nas-poster-wall", "posters")
    if (!fs.existsSync(this.posterCacheDir)) {
      fs.mkdirSync(this.posterCacheDir, { recursive: true })
    }
  }

  // 设置TMDB API Key
  public setTmdbApiKey(apiKey: string): void {
    this.tmdbApiKey = apiKey
  }

  // 为单个媒体项抓取海报
  public async fetchPoster(mediaId: string): Promise<string | null> {
    try {
      // 从数据库获取媒体项
      const media = await this.mediaDatabase.getMediaById(mediaId)
      if (!media) {
        throw new Error(`Media not found: ${mediaId}`)
      }

      // 如果已经有海报，直接返回
      if (media.posterPath && fs.existsSync(media.posterPath)) {
        return media.posterPath
      }

      // 构建缓存文件路径
      const posterFileName = `${mediaId}.jpg`
      const posterPath = path.join(this.posterCacheDir, posterFileName)
      
      let posterUrl = null

      // 尝试从TMDB抓取海报（如果有API Key）
      if (this.tmdbApiKey) {
        console.log(`Searching TMDB for poster for: ${media.title}`)
        posterUrl = await this.searchTmdbPoster(media.title, media.year, media.type as "movie" | "tv")
      }
      
      // 如果TMDB抓取失败，尝试从豆瓣抓取海报
      if (!posterUrl) {
        console.log(`Searching Douban for poster for: ${media.title}`)
        posterUrl = await this.searchDoubanPoster(media.title, media.year, media.type as "movie" | "tv")
      }

      if (posterUrl) {
        // 下载海报
        await this.downloadPoster(posterUrl, posterPath)

        // 更新数据库
        await this.mediaDatabase.updateMediaPoster(mediaId, posterPath)
        
        // 获取并更新详细信息
        if (this.tmdbApiKey) {
          try {
            await this.updateMediaDetails(mediaId, media.title, media.year, media.type as "movie" | "tv")
          } catch (error) {
            console.error(`Error updating details for ${mediaId}:`, error)
          }
        }

        return posterPath
      }

      return null
    } catch (error) {
      console.error(`Error fetching poster for ${mediaId}:`, error)
      return null
    }
  }

  // 为多个媒体项抓取海报
  public async fetchPosters(mediaIds: string[]): Promise<Record<string, string | null>> {
    const results: Record<string, string | null> = {}

    for (const mediaId of mediaIds) {
      results[mediaId] = await this.fetchPoster(mediaId)
    }

    return results
  }

  // 从TMDB搜索海报和详细信息
  private async searchTmdbPoster(title: string, year: string, type: "movie" | "tv"): Promise<string | null> {
    if (!this.tmdbApiKey) {
      console.log("TMDB API Key not configured, skipping TMDB search")
      return null
    }
    
    try {
      // 清理标题，移除可能影响搜索的内容
      const cleanTitle = title
        .replace(/[.[(（].*?[)）\].]?/g, "") // 移除括号内容
        .replace(/\d{4}/, "")               // 移除年份
        .replace(/1080[pi]|720[pi]|2160[pi]|4K|UHD|HD|超清/i, "") // 移除分辨率
        .replace(/BluRay|Blu-Ray|WEB-DL|HDTV|DVDRip|BDRip|HDRip|WEBRIP/i, "") // 移除来源
        .replace(/[Ss]\d{1,2}[Ee]\d{1,2}/, "") // 移除季集信息
        .replace(/第\d{1,2}[季集]/, "")     // 移除中文季集信息
        .replace(/\s+/g, " ")               // 合并空格
        .trim()

      console.log(`Searching TMDB for: "${cleanTitle}" (${year}) [${type}]`)
      
      // 构建查询参数
      const searchQuery = encodeURIComponent(cleanTitle)
      const endpoint = type === "movie" ? "movie" : "tv"
      const searchUrl = `https://api.themoviedb.org/3/search/${endpoint}?api_key=${this.tmdbApiKey}&query=${searchQuery}&language=zh-CN`
      
      // 如果有年份信息，添加年份过滤
      const fullUrl = year && year !== "未知" 
        ? `${searchUrl}&year=${year}`
        : searchUrl
      
      // 发送请求
      const response = await axios.get(fullUrl)
      
      // 检查是否有结果
      if (response.data.results && response.data.results.length > 0) {
        // 如果有多个结果，尝试找到最匹配的
        const results = response.data.results
        let bestMatch = results[0]
        
        if (results.length > 1 && year && year !== "未知") {
          // 尝试通过年份匹配
          const yearMatch = results.find((r: any) => {
            const releaseYear = type === "movie" 
              ? r.release_date?.substring(0, 4)
              : r.first_air_date?.substring(0, 4)
            return releaseYear === year
          })
          if (yearMatch) bestMatch = yearMatch
        }
        
        // 构建海报URL
        if (bestMatch.poster_path) {
          const posterUrl = `https://image.tmdb.org/t/p/original${bestMatch.poster_path}`
          console.log(`Found TMDB poster for: ${cleanTitle}`)
          return posterUrl
        }
      }
      
      console.log(`No TMDB results found for: ${cleanTitle}`)
      return null
    } catch (error) {
      console.error(`Error searching TMDB for ${title}:`, error)
      return null
    }
  }
  
  // 更新媒体详细信息
  private async updateMediaDetails(mediaId: string, title: string, year: string, type: "movie" | "tv"): Promise<void> {
    if (!this.tmdbApiKey) return
    
    try {
      // 先搜索媒体
      const searchQuery = encodeURIComponent(title)
      const endpoint = type === "movie" ? "movie" : "tv"
      const searchUrl = `https://api.themoviedb.org/3/search/${endpoint}?api_key=${this.tmdbApiKey}&query=${searchQuery}&language=zh-CN`
      
      // 如果有年份信息，添加年份过滤
      const fullUrl = year && year !== "未知" 
        ? `${searchUrl}&year=${year}`
        : searchUrl
      
      // 发送搜索请求
      const searchResponse = await axios.get(fullUrl)
      
      // 检查是否有结果
      if (searchResponse.data.results && searchResponse.data.results.length > 0) {
        const result = searchResponse.data.results[0]
        const itemId = result.id
        
        // 获取详细信息
        const detailsUrl = `https://api.themoviedb.org/3/${endpoint}/${itemId}?api_key=${this.tmdbApiKey}&language=zh-CN&append_to_response=credits`
        const detailsResponse = await axios.get(detailsUrl)
        
        if (detailsResponse.data) {
          const details = detailsResponse.data
          
          // 构建更新数据
          const updateData: any = {
            overview: details.overview,
            backdropPath: details.backdrop_path ? `https://image.tmdb.org/t/p/original${details.backdrop_path}` : undefined,
            rating: details.vote_average,
            releaseDate: type === "movie" ? details.release_date : details.first_air_date
          }
          
          // 更新数据库
          await this.mediaDatabase.updateMediaDetails(mediaId, updateData)
        }
      }
    } catch (error) {
      console.error(`Error updating details for ${mediaId}:`, error)
    }
  }

  // 从豆瓣搜索海报
  private async searchDoubanPoster(title: string, year: string, type: "movie" | "tv"): Promise<string | null> {
    try {
      // 清理标题
      const cleanTitle = title
        .replace(/[.[(（].*?[)）\].]?/g, "") // 移除括号内容
        .replace(/\d{4}/, "")               // 移除年份
        .replace(/1080[pi]|720[pi]|2160[pi]|4K|UHD|HD|超清/i, "") // 移除分辨率
        .replace(/BluRay|Blu-Ray|WEB-DL|HDTV|DVDRip|BDRip|HDRip|WEBRIP/i, "") // 移除来源
        .replace(/[Ss]\d{1,2}[Ee]\d{1,2}/, "") // 移除季集信息
        .replace(/第\d{1,2}[季集]/, "")     // 移除中文季集信息
        .replace(/\s+/g, " ")               // 合并空格
        .trim()

      console.log(`Searching Douban for: "${cleanTitle}" (${year}) [${type}]`)

      // 构建搜索URL
      const searchQuery = encodeURIComponent(`${cleanTitle} ${year}`)
      const searchUrl = `https://www.douban.com/search?cat=1002&q=${searchQuery}`

      // 发送请求
      const response = await axios.get(searchUrl, {
        headers: {
          "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36",
          "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
          "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
          "Referer": "https://www.douban.com"
        },
        timeout: 10000
      })

      // 解析HTML
      const html = response.data

      // 提取第一个结果的URL
      const resultUrlMatch = html.match(
        /<a href="(https:\/\/movie\.douban\.com\/subject\/\d+\/)" target="_blank" class="nbg">/,
      )
      if (!resultUrlMatch || !resultUrlMatch[1]) {
        console.log(`No Douban results found for: ${cleanTitle}`)
        return null
      }

      const movieUrl = resultUrlMatch[1]
      console.log(`Found Douban page: ${movieUrl}`)

      // 获取电影详情页
      const movieResponse = await axios.get(movieUrl, {
        headers: {
          "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36",
          "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
          "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
          "Referer": "https://www.douban.com"
        },
        timeout: 10000
      })

      // 提取海报URL
      const posterMatch = movieResponse.data.match(
        /<img src="(https:\/\/img\d+\.doubanio\.com\/view\/photo\/[^"]+)" title="点击看更多海报" rel="v:image" \/>/,
      )
      if (!posterMatch || !posterMatch[1]) {
        console.log(`No poster found on Douban page: ${movieUrl}`)
        return null
      }

      // 返回高质量海报URL
      const posterUrl = posterMatch[1].replace("/s_ratio_poster/", "/l_ratio_poster/")
      console.log(`Found Douban poster: ${posterUrl}`)
      return posterUrl
    } catch (error) {
      console.error(`Error searching Douban for ${title}:`, error)
      return null
    }
  }

  // 下载海报
  private async downloadPoster(url: string, filePath: string): Promise<void> {
    try {
      const response = await axios({
        method: "GET",
        url,
        responseType: "stream",
        headers: {
          "User-Agent":
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36",
        },
      })

      const writer = fs.createWriteStream(filePath)

      return new Promise((resolve, reject) => {
        response.data.pipe(writer)
        writer.on("finish", resolve)
        writer.on("error", reject)
      })
    } catch (error) {
      console.error(`Error downloading poster from ${url}:`, error)
      throw error
    }
  }
}


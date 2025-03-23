import * as path from "path"
import * as fs from "fs"
import * as os from "os"
import axios from "axios"
import { MovieDb, SearchMovieRequest, SearchTvRequest } from "moviedb-promise"
import type { MediaDatabase } from "./media-database"

export class PosterScraper {
  private mediaDatabase: MediaDatabase
  private posterCacheDir: string
  private tmdbApiKey: string | null = null
  private movieDb: MovieDb | null = null

  constructor(mediaDatabase: MediaDatabase, tmdbApiKey?: string) {
    this.mediaDatabase = mediaDatabase
    this.tmdbApiKey = tmdbApiKey || process.env.TMDB_API_KEY || null

    // 初始化 MovieDb 实例
    if (this.tmdbApiKey) {
      console.log(`Initializing MovieDb with API key ${this.tmdbApiKey.substring(0, 5)}...`)
      this.movieDb = new MovieDb(this.tmdbApiKey)
    } else {
      console.error("No TMDB API key provided. Poster search functionality will be limited.")
    }

    // 创建海报缓存目录
    this.posterCacheDir = path.join(os.homedir(), ".open-filmly", "posters")
    if (!fs.existsSync(this.posterCacheDir)) {
      fs.mkdirSync(this.posterCacheDir, { recursive: true })
    }
  }

  // 检查是否有TMDB API密钥
  public hasTmdbApiKey(): boolean {
    return !!this.tmdbApiKey;
  }

  // 设置TMDB API Key
  public setTmdbApiKey(apiKey: string): void {
    this.tmdbApiKey = apiKey
    console.log(`Setting new TMDB API key: ${apiKey.substring(0, 5)}...`)
    this.movieDb = new MovieDb(apiKey)
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
      if (this.movieDb) {
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

        // 记录下载的海报路径
        console.log(`Poster downloaded to: ${posterPath}`);

        // 更新数据库
        await this.mediaDatabase.updateMediaPoster(mediaId, posterPath)
        console.log(`Media database updated with poster path for ${mediaId}: ${posterPath}`);
        
        // 获取并更新详细信息
        if (this.movieDb) {
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

  // 搜索TMDB海报
  private async searchTmdbPoster(title: string, year: string, type: "movie" | "tv"): Promise<string | null> {
    if (!this.movieDb) {
      console.error("TMDB API not initialized. Cannot search for posters.")
      return null
    }
    
    try {
      // 使用 parse-torrent-name 库提取更干净的标题
      const ptn = require('parse-torrent-name');
      let cleanTitleInfo;
      
      try {
        // 尝试使用torrent解析器解析完整标题
        cleanTitleInfo = ptn(title);
        console.log(`PTN解析结果: `, JSON.stringify(cleanTitleInfo, null, 2));
      } catch (parseError: any) {
        console.error(`PTN解析失败: ${parseError.message}，将使用备用清理方法`);
        cleanTitleInfo = { title };
      }
      
      // 获取干净的标题
      let cleanTitle = cleanTitleInfo.title || title;
      
      // 备用清理：如果parse-torrent-name没有成功解析或结果不理想
      if (cleanTitle === title) {
        console.log(`使用备用标题清理方法`);
        cleanTitle = title
          .replace(/[.[(（].*?[)）\].]?/g, "") // 移除括号内容
          .replace(/\d{4}/, "")               // 移除年份
          .replace(/1080[pi]|720[pi]|2160[pi]|4K|UHD|HD|超清/i, "") // 移除分辨率
          .replace(/BluRay|Blu-Ray|WEB-DL|HDTV|DVDRip|BDRip|HDRip|WEBRIP/i, "") // 移除来源
          .replace(/[Ss]\d{1,2}[Ee]\d{1,2}/, "") // 移除季集信息
          .replace(/第\d{1,2}[季集]/, "")     // 移除中文季集信息
          .replace(/\bDTS\b|\bAC3\b|\bx264\b|\bx265\b|\bHEVC\b|\bH\.?264\b|\bAAC\b/i, "") // 移除编码信息
          .replace(/\bREMUX\b|\bPROPER\b|\bRERIP\b|\bREPACK\b|\bAMZN\b|\bNF\b/i, "") // 移除其他标签
          .replace(/\.\s*$/, "") // 移除结尾的点
          .replace(/\s+/g, " ")  // 合并空格
          .trim();
      }
      
      // 使用解析器获取的年份，如果有
      if (cleanTitleInfo.year && (!year || year === "未知")) {
        year = String(cleanTitleInfo.year);
        console.log(`使用PTN解析的年份: ${year}`);
      }
      
      console.log(`Searching TMDB for: "${cleanTitle}" (${year}) [${type}]`);
      
      // 搜索电影或电视剧
      let results: any;
      if (type === "movie") {
        const searchParams: SearchMovieRequest = {
          query: cleanTitle,
          language: 'zh-CN'
        }
        
        // 添加年份参数（如果有）
        if (year && year !== "未知") {
          searchParams.primary_release_year = parseInt(year, 10)
        }
        
        console.log("TMDB search params:", JSON.stringify(searchParams));
        results = await this.movieDb.searchMovie(searchParams)
      } else {
        const searchParams: SearchTvRequest = {
          query: cleanTitle,
          language: 'zh-CN'
        }
        
        // 添加年份参数（如果有）
        if (year && year !== "未知") {
          searchParams.first_air_date_year = parseInt(year, 10)
        }
        
        results = await this.movieDb.searchTv(searchParams)
      }
      
      // 检查是否有结果
      if (results.results && results.results.length > 0) {
        // 如果有多个结果，尝试找到最匹配的
        const searchResults = results.results
        let bestMatch = searchResults[0]
        
        if (searchResults.length > 1 && year && year !== "未知") {
          // 尝试通过年份匹配
          const yearMatch = searchResults.find((r: any) => {
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
    if (!this.movieDb) return
    
    try {
      // 先搜索媒体
      let searchResponse
      if (type === "movie") {
        const searchParams: SearchMovieRequest = {
          query: title,
          language: 'zh-CN'
        }
        
        // 添加年份参数（如果有）
        if (year && year !== "未知") {
          searchParams.primary_release_year = parseInt(year, 10)
        }
        
        searchResponse = await this.movieDb.searchMovie(searchParams)
      } else {
        const searchParams: SearchTvRequest = {
          query: title,
          language: 'zh-CN'
        }
        
        // 添加年份参数（如果有）
        if (year && year !== "未知") {
          searchParams.first_air_date_year = parseInt(year, 10)
        }
        
        searchResponse = await this.movieDb.searchTv(searchParams)
      }
      
      // 检查是否有结果
      if (searchResponse.results && searchResponse.results.length > 0) {
        const result = searchResponse.results[0]
        const itemId = result.id
        
        // 获取详细信息
        if (type === "movie") {
          const details = await this.movieDb.movieInfo({
            id: itemId as number,
            language: 'zh-CN',
            append_to_response: 'credits'
          })
          
          if (details) {
            // 构建更新数据
            const updateData: any = {
              overview: details.overview,
              backdropPath: details.backdrop_path ? `https://image.tmdb.org/t/p/original${details.backdrop_path}` : undefined,
              rating: details.vote_average,
              releaseDate: details.release_date
            }
            
            // 更新数据库
            await this.mediaDatabase.updateMediaDetails(mediaId, updateData)
          }
        } else {
          const details = await this.movieDb.tvInfo({
            id: itemId as number,
            language: 'zh-CN',
            append_to_response: 'credits'
          })
          
          if (details) {
            // 构建更新数据
            const updateData: any = {
              overview: details.overview,
              backdropPath: details.backdrop_path ? `https://image.tmdb.org/t/p/original${details.backdrop_path}` : undefined,
              rating: details.vote_average,
              releaseDate: details.first_air_date
            }
            
            // 更新数据库
            await this.mediaDatabase.updateMediaDetails(mediaId, updateData)
          }
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
      console.log(`Downloading poster from ${url} to ${filePath}`);
      
      // 确保目标目录存在
      const dirPath = path.dirname(filePath);
      if (!fs.existsSync(dirPath)) {
        console.log(`Creating poster directory: ${dirPath}`);
        fs.mkdirSync(dirPath, { recursive: true });
      }
      
      const response = await axios({
        method: "GET",
        url,
        responseType: "stream",
        headers: {
          "User-Agent":
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36",
        },
        timeout: 30000, // 30秒超时
      })

      console.log(`Poster download response status: ${response.status}`);
      
      const writer = fs.createWriteStream(filePath);

      return new Promise((resolve, reject) => {
        response.data.pipe(writer);
        
        // 处理结束事件
        writer.on("finish", () => {
          console.log(`Poster successfully written to ${filePath}`);
          writer.close();
          resolve();
        });
        
        // 处理错误事件
        writer.on("error", (err: Error) => {
          console.error(`Error writing poster to ${filePath}:`, err);
          fs.unlink(filePath, () => {}); // 删除可能部分写入的文件
          reject(err);
        });
        
        // 处理请求错误
        response.data.on("error", (err: Error) => {
          console.error(`Error in download stream for ${url}:`, err);
          writer.close();
          fs.unlink(filePath, () => {});
          reject(err);
        });
      });
    } catch (error) {
      console.error(`Error downloading poster from ${url}:`, error);
      throw error;
    }
  }

  // 尝试使用TMDB识别媒体类型（电影或电视剧）
  public async identifyMediaType(mediaIds: string[]): Promise<string[]> {
    if (!this.movieDb) {
      console.error("TMDB API not initialized. Cannot identify media types.");
      return [];
    }

    const identifiedIds: string[] = [];

    for (const mediaId of mediaIds) {
      try {
        // 从数据库获取媒体项
        const media = await this.mediaDatabase.getMediaById(mediaId);
        if (!media) {
          console.error(`Media not found: ${mediaId}`);
          continue;
        }

        console.log(`尝试识别媒体类型: ${media.title}`);
        
        // 清理标题以提高搜索准确度
        const cleanTitle = media.title
          .replace(/[.[(（].*?[)）\].]?/g, "") // 移除括号内容
          .replace(/\d{4}/, "")               // 移除年份
          .replace(/1080[pi]|720[pi]|2160[pi]|4K|UHD|HD|超清/i, "") // 移除分辨率
          .replace(/BluRay|Blu-Ray|WEB-DL|HDTV|DVDRip|BDRip|HDRip|WEBRIP/i, "") // 移除来源
          .replace(/[Ss]\d{1,2}[Ee]\d{1,2}/, "") // 移除季集信息
          .replace(/第\d{1,2}[季集]/, "")     // 移除中文季集信息
          .replace(/\s+/g, " ")               // 合并空格
          .trim();

        // 首先尝试作为电影搜索
        const movieResults = await this.movieDb.searchMovie({
          query: cleanTitle,
          language: 'zh-CN'
        });

        // 然后尝试作为电视剧搜索
        const tvResults = await this.movieDb.searchTv({
          query: cleanTitle,
          language: 'zh-CN'
        });

        // 确定可能的类型
        let detectedType: "movie" | "tv" | "unknown" = "unknown";
        let confidence = 0; // 用于判断哪个结果更可靠

        // 检查电影结果
        if (movieResults.results && movieResults.results.length > 0) {
          const movieConfidence = movieResults.results[0].popularity || 0;
          confidence = movieConfidence;
          detectedType = "movie";
        }

        // 检查电视剧结果，如果置信度更高则更新类型
        if (tvResults.results && tvResults.results.length > 0) {
          const tvConfidence = tvResults.results[0].popularity || 0;
          if (tvConfidence > confidence) {
            confidence = tvConfidence;
            detectedType = "tv";
          }
        }

        // 额外检查文件名和路径中的特征
        if (detectedType === "unknown" || confidence < 5) {
          // 检查文件路径和名称是否有电视剧特征
          const path = media.path.toLowerCase();
          const fileName = media.title.toLowerCase();
          
          if (
            path.includes('/tv/') || 
            path.includes('\\tv\\') ||
            path.includes('season') || 
            path.includes('episode') ||
            /s\d+e\d+/i.test(fileName) || 
            /season\s*\d+/i.test(fileName) || 
            /episode\s*\d+/i.test(fileName)
          ) {
            detectedType = "tv";
          }
          // 检查是否有电影特征
          else if (
            path.includes('/movies/') || 
            path.includes('\\movies\\') ||
            path.includes('/movie/') ||
            path.includes('\\movie\\')
          ) {
            detectedType = "movie";
          }
        }

        // 更新数据库中的媒体类型
        if (detectedType !== "unknown") {
          console.log(`识别出媒体类型: ${media.title} => ${detectedType}`);
          await this.mediaDatabase.updateMediaType(mediaId, detectedType);
          identifiedIds.push(mediaId);
        } else {
          console.log(`无法识别媒体类型: ${media.title}`);
        }
      } catch (error) {
        console.error(`Error identifying media type for ${mediaId}:`, error);
      }
    }

    return identifiedIds;
  }
}


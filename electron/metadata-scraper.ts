import * as path from "path"
import * as fs from "fs"
import * as os from "os"
import axios from "axios"
import { MovieDb, SearchMovieRequest, SearchTvRequest } from "moviedb-promise"
import type { MediaDatabase } from "./media-database"

// Define the mapTMDBToMedia function locally to avoid import issues
function mapTMDBToMedia(item: any, type: 'movie' | 'tv') {
  return {
    id: item.id.toString(),
    title: type === 'movie' ? item.title : item.name,
    originalTitle: type === 'movie' ? item.original_title : item.original_name,
    year: type === 'movie' 
      ? item.release_date ? item.release_date.substring(0, 4) : ''
      : item.first_air_date ? item.first_air_date.substring(0, 4) : '',
    type,
    posterPath: item.poster_path ? `https://image.tmdb.org/t/p/w500${item.poster_path}` : undefined,
    backdropPath: item.backdrop_path ? `https://image.tmdb.org/t/p/original${item.backdrop_path}` : undefined,
    overview: item.overview,
    releaseDate: type === 'movie' ? item.release_date : item.first_air_date,
    genres: item.genres ? item.genres.map((g: any) => g.name) : [],
    rating: item.vote_average,
    credits: item.credits
  };
}

export class MetadataScraper {
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
      console.error("No TMDB API key provided. Metadata fetching functionality will be limited.")
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

  // 获取TMDB API Key
  public getTmdbApiKey(): string | null {
    return this.tmdbApiKey;
  }

  // 设置TMDB API Key
  public setTmdbApiKey(apiKey: string): void {
    this.tmdbApiKey = apiKey
    console.log(`Setting new TMDB API key: ${apiKey.substring(0, 5)}...`)
    this.movieDb = new MovieDb(apiKey)
  }

  // 为单个媒体项获取元数据
  public async fetchMetadata(mediaId: string): Promise<any | null> {
    try {
      // 从数据库获取媒体项
      const media = await this.mediaDatabase.getMediaById(mediaId)
      if (!media) {
        throw new Error(`Media not found: ${mediaId}`)
      }

      // 尝试从TMDB获取元数据
      if (this.movieDb) {
        console.log(`Fetching metadata from TMDB for: ${media.title}`)
        const metadata = await this.fetchTmdbMetadata(media.title, media.year)
        
        if (metadata) {
          // 构建缓存文件路径（用于海报）
          const posterFileName = `${mediaId}.jpg`
          const posterPath = path.join(this.posterCacheDir, posterFileName)

          // 如果有海报URL，下载海报
          if (metadata.posterPath) {
            try {
              await this.downloadPoster(metadata.posterPath, posterPath)
              metadata.posterPath = posterPath // 更新为本地路径
            } catch (error) {
              console.error(`Error downloading poster for ${mediaId}:`, error)
            }
          }

          // 更新数据库中的媒体类型和详细信息
          console.log(`Updating media type to: ${metadata.type} for ${mediaId}`);
          await this.mediaDatabase.updateMediaType(mediaId, metadata.type)
          await this.mediaDatabase.updateMediaDetails(mediaId, {
            overview: metadata.overview,
            backdropPath: metadata.backdropPath,
            rating: metadata.rating,
            releaseDate: metadata.releaseDate,
            genres: metadata.genres
          })

          return metadata
        }
      }
      
      // 如果TMDB API未初始化或搜索失败，尝试从文件路径和文件名进一步判断媒体类型
      if (media.type === "unknown") {
        const detectedType = this.detectMediaTypeFromPath(media.path, media.fullPath || "");
        if (detectedType !== "unknown") {
          console.log(`Detected media type from path: ${detectedType} for ${mediaId}`);
          await this.mediaDatabase.updateMediaType(mediaId, detectedType);
        }
      }

      return null
    } catch (error) {
      console.error(`Error fetching metadata for ${mediaId}:`, error)
      return null
    }
  }

  /**
   * 从文件路径和文件名尝试判断媒体类型
   */
  private detectMediaTypeFromPath(filePath: string, fullPath: string): "movie" | "tv" | "unknown" {
    const lowerPath = (filePath + " " + fullPath).toLowerCase();
    const fileName = path.basename(filePath);
    const lowerName = fileName.toLowerCase();
    
    // 检查路径中是否包含明显的电视剧关键词
    if (lowerPath.includes('tv') || 
        lowerPath.includes('series') || 
        lowerPath.includes('season') || 
        lowerPath.includes('episode') ||
        lowerPath.includes('剧集') ||
        lowerPath.includes('电视剧')) {
      return 'tv';
    }
    
    // 检查路径中是否包含明显的电影关键词
    if (lowerPath.includes('movie') || 
        lowerPath.includes('film') ||
        lowerPath.includes('电影')) {
      return 'movie';
    }
    
    // 检查文件名模式：S01E01, s01e01 等格式
    if (/s\d+e\d+/i.test(lowerName) || 
        /season\s*\d+/i.test(lowerName) || 
        /episode\s*\d+/i.test(lowerName) ||
        /第\s*\d+\s*[季集]/i.test(lowerName) ||
        /\d+x\d+/i.test(lowerName)) {
      return 'tv';
    }
    
    // 如果文件名包含年份格式 (2020) 但没有季集号标识，可能是电影
    if (/\(\d{4}\)/i.test(lowerName) && !(/\d+x\d+/i.test(lowerName))) {
      return 'movie';
    }
    
    // 无法确定的情况
    return 'unknown';
  }

  // 为多个媒体项获取元数据
  public async fetchAllMetadata(mediaIds: string[]): Promise<Record<string, any | null>> {
    const results: Record<string, any | null> = {}

    for (const mediaId of mediaIds) {
      results[mediaId] = await this.fetchMetadata(mediaId)
    }

    return results
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
        
        writer.on("finish", () => {
          console.log(`Poster successfully written to ${filePath}`);
          writer.close();
          resolve();
        });
        
        writer.on("error", (err: Error) => {
          console.error(`Error writing poster to ${filePath}:`, err);
          fs.unlink(filePath, () => {}); // 删除可能部分写入的文件
          reject(err);
        });
        
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

  // Fetch metadata from TMDB using multi-search
  private async fetchTmdbMetadata(title: string, year: string): Promise<any | null> {
    if (!this.movieDb) {
      console.error("TMDB API not initialized. Cannot fetch metadata.");
      return null;
    }

    try {
      const searchParams: any = {
        query: title,
        language: 'zh-CN'
      };

      if (year && year !== "未知") {
        searchParams.year = parseInt(year, 10);
      }

      console.log(`[TMDB Search] Starting search with params:`, JSON.stringify(searchParams));

      // Use multi-search to find the media
      const searchResponse = await this.movieDb.searchMulti(searchParams);
      
      console.log(`[TMDB Search] Found ${searchResponse.results?.length || 0} results for "${title}"`);
      
      if (searchResponse.results && searchResponse.results.length > 0) {
        // Log summary of first few results
        searchResponse.results.slice(0, 3).forEach((result: any, index: number) => {
          console.log(`[TMDB Search] Result #${index + 1}: ${result.media_type} - ${result.media_type === 'movie' ? result.title : result.name} (ID: ${result.id})`);
        });
        
        const result = searchResponse.results[0];
        const itemId = result.id;
        const type = result.media_type;
        
        console.log(`[TMDB Search] Selected result: ${type} - ${type === 'movie' ? result.title : result.name} (ID: ${itemId})`);

        let details;
        if (type === "movie") {
          console.log(`[TMDB Search] Fetching movie details for ID: ${itemId}`);
          details = await this.movieDb.movieInfo({
            id: itemId as number,
            language: 'zh-CN',
            append_to_response: 'credits'
          });
          console.log(`[TMDB Search] Retrieved movie details: ${details.title} (${details.release_date})`);
        } else if (type === "tv") {
          console.log(`[TMDB Search] Fetching TV show details for ID: ${itemId}`);
          details = await this.movieDb.tvInfo({
            id: itemId as number,
            language: 'zh-CN',
            append_to_response: 'credits'
          });
          console.log(`[TMDB Search] Retrieved TV details: ${details.name} (${details.first_air_date})`);
        } else {
          console.log(`[TMDB Search] Unsupported media type: ${type}`);
          return null;
        }

        if (details) {
          console.log(`[TMDB Search] Successfully mapped details to media object`);
          return mapTMDBToMedia(details, type);
        }
      }

      console.log(`[TMDB Search] No metadata found for: ${title}`);
      return null;
    } catch (error) {
      console.error(`[TMDB Search] Error fetching TMDB metadata for ${title}:`, error);
      return null;
    }
  }
} 
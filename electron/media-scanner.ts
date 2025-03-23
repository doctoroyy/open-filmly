import * as path from "path"
import type { SambaClient } from "./smb-client"
import type { MediaDatabase } from "./media-database"
import { parseFileName } from "./file-parser"
import type { Media, MediaEpisode } from "../types/media"
import type { MetadataScraper } from "./metadata-scraper"

export class MediaScanner {
  private sambaClient: SambaClient
  private mediaDatabase: MediaDatabase
  private metadataScraper?: MetadataScraper
  private sharePath: string = ""
  private selectedFolders: string[] = []

  constructor(sambaClient: SambaClient, mediaDatabase: MediaDatabase, metadataScraper?: MetadataScraper) {
    this.sambaClient = sambaClient
    this.mediaDatabase = mediaDatabase
    this.metadataScraper = metadataScraper
  }

  // 设置共享路径
  public setSharePath(sharePath: string): void {
    this.sharePath = sharePath
  }

  // 设置选定的文件夹列表
  public setSelectedFolders(folders: string[]): void {
    this.selectedFolders = folders
  }

  // 设置元数据抓取器
  public setMetadataScraper(metadataScraper: MetadataScraper): void {
    this.metadataScraper = metadataScraper
  }

  /**
   * 扫描所有媒体
   * 统一的入口方法，会根据参数决定扫描电影或电视剧或两者
   */
  public async scanAllMedia(type?: "movie" | "tv"): Promise<{
    movies: Media[];
    tvShows: Media[];
    total: number;
  }> {
    try {
      if (!this.sharePath) {
        throw new Error("共享路径未设置，请先配置共享路径")
      }

      console.log(`开始扫描共享 ${this.sharePath} 中的媒体文件...`)
      
      // 检查是否有选定的文件夹
      const startPaths = this.selectedFolders && this.selectedFolders.length > 0 
        ? this.selectedFolders // 使用选定的文件夹
        : [""];                // 默认使用根目录
      
      // 1. 收集所有媒体文件
      const allMediaFiles = await this.collectMediaFiles(startPaths);
      
      console.log(`扫描完成，找到 ${allMediaFiles.length} 个媒体文件`);
      
      // 2. 对媒体文件进行分类和处理
      const { mediaItems, mediaIds } = await this.processMediaFiles(allMediaFiles, type);
      
      // 3. 获取元数据
      if (this.metadataScraper && mediaIds.length > 0) {
        console.log(`正在获取 ${mediaIds.length} 个媒体项的元数据...`);
        try {
          await this.metadataScraper.fetchAllMetadata(mediaIds);
        } catch (error) {
          console.error("获取元数据时出错:", error);
        }
      }
      
      // 4. 获取最新的分类结果
      const movies = await this.mediaDatabase.getMediaByType("movie");
      const tvShows = await this.mediaDatabase.getMediaByType("tv");
      
      return {
        movies,
        tvShows,
        total: mediaItems.length
      };
    } catch (error) {
      console.error("扫描媒体文件时出错:", error);
      throw error;
    }
  }

  /**
   * 收集所有媒体文件
   * 遍历所有选定的路径，收集所有媒体文件
   */
  private async collectMediaFiles(startPaths: string[]): Promise<any[]> {
    let allMediaFiles: any[] = [];
    
    try {
      for (const folder of startPaths) {
        console.log(`扫描文件夹: ${folder || '/'}`);
        
        try {
          const mediaFiles = await this.sambaClient.scanMediaFiles(folder);
          allMediaFiles = [...allMediaFiles, ...mediaFiles];
        } catch (error: any) {
          if (error.code === 'STATUS_OBJECT_NAME_NOT_FOUND') {
            console.error(`找不到文件夹 "${folder}"，跳过`);
          } else {
            console.error(`扫描文件夹 ${folder} 时出错:`, error);
          }
          // 继续处理其他文件夹
        }
      }
      
      return allMediaFiles;
    } catch (error) {
      console.error("收集媒体文件时出错:", error);
      throw error;
    }
  }

  /**
   * 处理所有媒体文件
   * 将媒体文件分类为电影和电视剧，并保存到数据库
   */
  private async processMediaFiles(
    mediaFiles: any[], 
    type?: "movie" | "tv"
  ): Promise<{ mediaItems: Media[]; mediaIds: string[] }> {
    const mediaItems: Media[] = [];
    const mediaIds: string[] = [];
    
    // 将文件按类型分组
    const movieFiles = mediaFiles.filter(file => file.type === "movie");
    const tvFiles = mediaFiles.filter(file => file.type === "tv");
    const unknownFiles = mediaFiles.filter(file => file.type === "unknown");
    
    console.log(`分类结果: ${movieFiles.length} 部电影, ${tvFiles.length} 部电视剧, ${unknownFiles.length} 个未识别媒体`);
    
    // 处理电影
    if (!type || type === "movie") {
      await this.processMovies(movieFiles, mediaItems, mediaIds);
      // 处理未知类型的文件，先当作电影处理
      await this.processMovies(unknownFiles, mediaItems, mediaIds);
    }
    
    // 处理电视剧
    if (!type || type === "tv") {
      await this.processTVShows(tvFiles, mediaItems, mediaIds);
    }
    
    return { mediaItems, mediaIds };
  }

  /**
   * 处理电影文件
   */
  private async processMovies(
    movieFiles: any[], 
    mediaItems: Media[], 
    mediaIds: string[]
  ): Promise<void> {
    console.log(`处理 ${movieFiles.length} 个电影文件...`);
    
    let processedCount = 0;
    let errorCount = 0;
    
    for (const mediaFile of movieFiles) {
      try {
        // 解析文件名
        const { title, year } = parseFileName(mediaFile.name);
        
        // 创建媒体项
        const mediaId = `movie-${Buffer.from(mediaFile.path).toString("base64").slice(0, 12)}`;
        const mediaItem: Media = {
          id: mediaId,
          title: title || mediaFile.name,
          year: year || "未知",
          type: "movie",
          path: mediaFile.path,
          fullPath: mediaFile.fullPath || mediaFile.path, // 使用完整路径，如果可用
          posterPath: "",
          dateAdded: new Date().toISOString(),
          lastUpdated: new Date().toISOString(),
        }
        
        // 添加到列表
        mediaItems.push(mediaItem);
        mediaIds.push(mediaId);
        
        // 保存到数据库
        await this.mediaDatabase.saveMedia(mediaItem);
        processedCount++;
      } catch (error) {
        errorCount++;
        console.error(`处理媒体文件 ${mediaFile.path} 时出错:`, error);
      }
    }
    
    console.log(`电影处理完成: 成功 ${processedCount} 个, 失败 ${errorCount} 个`);
  }

  /**
   * 处理电视剧文件
   */
  private async processTVShows(
    tvFiles: any[], 
    mediaItems: Media[], 
    mediaIds: string[]
  ): Promise<void> {
    console.log(`处理 ${tvFiles.length} 个电视剧文件...`);
    
    // 将电视剧按系列分组
    const seriesMap = this.groupTvShowsBySeries(tvFiles);
    console.log(`共有 ${Object.keys(seriesMap).length} 个电视剧系列`);
    
    let processedCount = 0;
    let errorCount = 0;
    
    for (const [seriesName, episodes] of Object.entries(seriesMap)) {
      try {
        const seriesId = `tv-series-${Buffer.from(seriesName).toString("base64").slice(0, 12)}`;
        const firstEpisode = episodes[0];
        const parsedInfo = parseFileName(firstEpisode.name);
        
        // 获取父目录作为系列路径
        const seriesPath = path.dirname(firstEpisode.path);
        
        // 创建系列媒体记录
        const seriesItem: Media = {
          id: seriesId,
          title: seriesName,
          type: "tv",
          path: seriesPath,
          fullPath: firstEpisode.fullPath ? 
            path.dirname(firstEpisode.fullPath) : 
            path.dirname(firstEpisode.path),
          year: parsedInfo.year || "未知",
          posterPath: "",
          episodeCount: episodes.length,
          episodes: episodes.map(ep => this.createEpisodeRecord(ep)),
          dateAdded: new Date().toISOString(),
          lastUpdated: new Date().toISOString(),
        };
        
        // 添加到列表
        mediaItems.push(seriesItem);
        mediaIds.push(seriesId);
        
        // 保存到数据库
        await this.mediaDatabase.saveMedia(seriesItem);
        processedCount++;
      } catch (error) {
        errorCount++;
        console.error(`处理电视剧系列 ${seriesName} 时出错:`, error);
      }
    }
    
    console.log(`电视剧处理完成: 成功 ${processedCount} 个系列, 失败 ${errorCount} 个系列`);
  }

  /**
   * 创建剧集记录
   */
  private createEpisodeRecord(episode: any): MediaEpisode {
    return {
      path: episode.path,
      name: episode.name,
      season: this.extractSeasonNumber(episode.name),
      episode: this.extractEpisodeNumber(episode.name)
    };
  }
  
  /**
   * 根据系列名称将电视剧分组
   */
  private groupTvShowsBySeries(tvFiles: any[]): Record<string, any[]> {
    const seriesMap: Record<string, any[]> = {};
    
    for (const file of tvFiles) {
      // 解析文件名
      const seriesName = this.extractSeriesName(file.name);
      
      if (!seriesMap[seriesName]) {
        seriesMap[seriesName] = [];
      }
      
      seriesMap[seriesName].push(file);
    }
    
    return seriesMap;
  }
  
  /**
   * 从文件名提取电视剧系列名称
   */
  private extractSeriesName(fileName: string): string {
    // 尝试移除季、集信息，获取系列名称
    let seriesName = parseFileName(fileName).title;
    
    // 移除季、集信息
    seriesName = seriesName.replace(/\s*S\d+\s*E\d+\s*/i, ' ');
    seriesName = seriesName.replace(/\s*Season\s*\d+\s*Episode\s*\d+\s*/i, ' ');
    seriesName = seriesName.replace(/\s*第\s*\d+\s*[季集部]\s*/i, ' ');
    
    return seriesName.trim();
  }
  
  /**
   * 从文件名提取季信息
   */
  private extractSeasonNumber(fileName: string): number {
    // 尝试匹配季号
    const seasonMatch = fileName.match(/S(\d+)E\d+/i) || 
                       fileName.match(/Season\s*(\d+)/i) ||
                       fileName.match(/第\s*(\d+)\s*季/i);
    
    return seasonMatch ? parseInt(seasonMatch[1], 10) : 1;
  }
  
  /**
   * 从文件名提取集信息
   */
  private extractEpisodeNumber(fileName: string): number {
    // 尝试匹配集号
    const episodeMatch = fileName.match(/S\d+E(\d+)/i) ||
                        fileName.match(/Episode\s*(\d+)/i) ||
                        fileName.match(/第\s*(\d+)\s*[集部]/i) ||
                        fileName.match(/E(\d+)/i);
    
    return episodeMatch ? parseInt(episodeMatch[1], 10) : 1;
  }
}


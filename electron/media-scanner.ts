import * as path from "path"
import type { SambaClient } from "./smb-client"
import type { MediaDatabase } from "./media-database"
import { parseFileName } from "./file-parser"
import type { Media, MediaEpisode } from "../types/media"
import type { PosterScraper } from "./poster-scraper"

export class MediaScanner {
  private sambaClient: SambaClient
  private mediaDatabase: MediaDatabase
  private posterScraper?: PosterScraper
  private sharePath: string = ""
  private selectedFolders: string[] = []

  constructor(sambaClient: SambaClient, mediaDatabase: MediaDatabase, posterScraper?: PosterScraper) {
    this.sambaClient = sambaClient
    this.mediaDatabase = mediaDatabase
    this.posterScraper = posterScraper
  }

  // 设置共享路径
  public setSharePath(sharePath: string): void {
    this.sharePath = sharePath
  }

  // 设置选定的文件夹列表
  public setSelectedFolders(folders: string[]): void {
    this.selectedFolders = folders
  }

  // 设置海报抓取器
  public setPosterScraper(posterScraper: PosterScraper): void {
    this.posterScraper = posterScraper
  }

  // 从选定的文件夹扫描指定类型的媒体文件
  public async scanSelectedFolders(type: "movie" | "tv"): Promise<number> {
    if (!this.sambaClient || !this.sharePath) {
      throw new Error("Samba client or share path not configured")
    }

    let mediaFiles: any[] = []

    // 检查是否有选定的文件夹
    if (this.selectedFolders && this.selectedFolders.length > 0) {
      // 有选定的文件夹，遍历每个文件夹进行扫描
      for (const folder of this.selectedFolders) {
        try {
          console.log(`Scanning for ${type} in folder: ${folder}`)
          // 获取指定文件夹中的媒体文件
          const filesInFolder = await this.sambaClient.getMediaByType(folder, type)
          mediaFiles = [...mediaFiles, ...filesInFolder]
        } catch (error) {
          console.error(`Error scanning folder ${folder}:`, error)
          // 继续处理其他文件夹
        }
      }
    } else {
      // 没有选定的文件夹，使用共享根目录
      console.log(`Scanning for ${type} in share: ${this.sharePath}`)
      mediaFiles = await this.sambaClient.getMediaByType("/", type)
    }

    console.log(`Found ${mediaFiles.length} ${type} files`)

    // 处理找到的媒体文件
    const addedMediaIds: string[] = [];

    if (type === "tv") {
      // 处理电视剧时，按系列分组
      const seriesMap = this.groupTvShowsBySeries(mediaFiles);
      
      // 处理每个系列
      for (const [seriesName, episodes] of Object.entries(seriesMap)) {
        try {
          // 创建系列记录
          const seriesId = `tv-series-${Buffer.from(seriesName).toString("base64").slice(0, 12)}`;
          const firstEpisode = episodes[0];
          const parsedInfo = parseFileName(firstEpisode.name);
          
          // 创建系列媒体记录
          const seriesRecord: Media = {
            id: seriesId,
            title: seriesName,
            type: "tv",
            path: path.dirname(firstEpisode.path), // 使用第一集所在的目录
            year: parsedInfo.year || "未知",
            posterPath: "",
            episodeCount: episodes.length,
            episodes: episodes.map(ep => ({
              path: ep.path,
              name: ep.name,
              season: this.extractSeasonNumber(ep.name),
              episode: this.extractEpisodeNumber(ep.name)
            })),
            dateAdded: new Date().toISOString(),
            lastUpdated: new Date().toISOString(),
          };
          
          // 保存到数据库
          await this.mediaDatabase.saveMedia(seriesRecord);
          addedMediaIds.push(seriesId);
        } catch (error) {
          console.error(`Error processing TV series ${seriesName}:`, error);
        }
      }
    } else {
      // 处理电影
      for (const file of mediaFiles) {
        try {
          // 解析文件名提取元数据
          const parsedInfo = parseFileName(file.name);
          
          // 创建媒体记录
          const mediaId = `${type}-${Buffer.from(file.path).toString("base64").slice(0, 12)}`;
          const mediaRecord: Media = {
            id: mediaId,
            title: parsedInfo.title || file.name,
            type,
            path: file.path,
            year: parsedInfo.year || "未知",
            posterPath: "",
            dateAdded: new Date().toISOString(),
            lastUpdated: new Date().toISOString(),
          };
          
          // 保存到数据库
          await this.mediaDatabase.saveMedia(mediaRecord);
          addedMediaIds.push(mediaId);
        } catch (error) {
          console.error(`Error processing media file ${file.path}:`, error);
        }
      }
    }

    // 抓取海报和详细信息
    if (this.posterScraper && addedMediaIds.length > 0) {
      console.log(`Fetching posters for ${addedMediaIds.length} items...`);
      try {
        await this.posterScraper.fetchPosters(addedMediaIds);
      } catch (error) {
        console.error("Error fetching posters:", error);
      }
    }

    return mediaFiles.length;
  }

  // 自动扫描并分类媒体文件
  public async scanMedia(type?: "movie" | "tv"): Promise<Media[]> {
    try {
      if (!this.sharePath) {
        throw new Error("共享路径未设置，请先配置共享路径")
      }

      console.log(`开始扫描共享 ${this.sharePath} 中的媒体文件...`)
      
      // 检查是否有选定的文件夹
      const startPath = this.selectedFolders && this.selectedFolders.length > 0 
        ? this.selectedFolders // 使用选定的文件夹
        : [""];                // 默认使用根目录
      
      const mediaItems: Media[] = [];
      const addedMediaIds: string[] = [];
      
      try {
        let totalMediaFiles: any[] = [];
        
        // 遍历所有选定的文件夹
        for (const folder of startPath) {
          console.log(`扫描文件夹: ${folder || '/'}`);
          
          // 扫描所有媒体文件
          const mediaFiles = await this.sambaClient.scanMediaFiles(folder);
          totalMediaFiles = [...totalMediaFiles, ...mediaFiles];
        }
        
        console.log(`扫描完成，找到 ${totalMediaFiles.length} 个媒体文件`)
        
        // 处理每个文件
        let processedCount = 0;
        let errorCount = 0;

        // 将电视剧分组处理
        const tvFiles = totalMediaFiles.filter(file => file.type === "tv");
        const movieFiles = totalMediaFiles.filter(file => file.type === "movie");

        // 处理电影
        if (!type || type === "movie") {
          for (const mediaFile of movieFiles) {
            try {
              // 解析文件名
              const { title, year } = parseFileName(mediaFile.name);

              // 创建媒体项
              const mediaId = `${mediaFile.type}-${Buffer.from(mediaFile.path).toString("base64").slice(0, 12)}`;
              const mediaItem: Media = {
                id: mediaId,
                title: title || mediaFile.name,
                year: year || "未知",
                type: mediaFile.type,
                path: mediaFile.path,
                posterPath: "",
                dateAdded: new Date().toISOString(),
                lastUpdated: new Date().toISOString(),
              }

              // 添加到列表
              mediaItems.push(mediaItem);
              addedMediaIds.push(mediaId);

              // 保存到数据库
              await this.mediaDatabase.saveMedia(mediaItem);
              processedCount++;
            } catch (itemError) {
              errorCount++;
              console.error(`处理媒体文件 ${mediaFile.path} 时出错:`, itemError);
            }
          }
        }

        // 处理电视剧
        if (!type || type === "tv") {
          const seriesMap = this.groupTvShowsBySeries(tvFiles);
          
          for (const [seriesName, episodes] of Object.entries(seriesMap)) {
            try {
              const seriesId = `tv-series-${Buffer.from(seriesName).toString("base64").slice(0, 12)}`;
              const firstEpisode = episodes[0];
              const parsedInfo = parseFileName(firstEpisode.name);
              
              // 创建系列媒体记录
              const seriesItem: Media = {
                id: seriesId,
                title: seriesName,
                type: "tv",
                path: path.dirname(firstEpisode.path), // 使用第一集所在的目录
                year: parsedInfo.year || "未知",
                posterPath: "",
                episodeCount: episodes.length,
                episodes: episodes.map(ep => ({
                  path: ep.path,
                  name: ep.name,
                  season: this.extractSeasonNumber(ep.name),
                  episode: this.extractEpisodeNumber(ep.name)
                })),
                dateAdded: new Date().toISOString(),
                lastUpdated: new Date().toISOString(),
              };
              
              // 添加到列表
              mediaItems.push(seriesItem);
              addedMediaIds.push(seriesId);
              
              // 保存到数据库
              await this.mediaDatabase.saveMedia(seriesItem);
              processedCount++;
            } catch (itemError) {
              errorCount++;
              console.error(`处理电视剧系列 ${seriesName} 时出错:`, itemError);
            }
          }
        }

        console.log(`媒体扫描完成: 成功处理 ${processedCount} 个文件, 失败 ${errorCount} 个文件`);
        
        // 抓取海报和详细信息
        if (this.posterScraper && addedMediaIds.length > 0) {
          console.log(`Fetching posters for ${addedMediaIds.length} items...`);
          try {
            await this.posterScraper.fetchPosters(addedMediaIds);
          } catch (error) {
            console.error("Error fetching posters:", error);
          }
        }
        
        return mediaItems;
      } catch (scanError: any) {
        if (scanError.code === 'STATUS_OBJECT_NAME_NOT_FOUND') {
          throw new Error(`找不到共享 "${this.sharePath}" 或目录不存在，请检查配置`);
        } else {
          throw scanError;
        }
      }
    } catch (error) {
      console.error(`扫描媒体文件时出错:`, error);
      throw error;
    }
  }

  // 扫描所有媒体
  public async scanAllMedia() {
    try {
      // 直接使用scanMedia方法扫描所有媒体
      console.log("扫描所有媒体文件...")
      const allMedia = await this.scanMedia();
      
      // 从扫描结果中分离电影和电视剧
      const movies = allMedia.filter(item => item.type === "movie");
      const tvShows = allMedia.filter(item => item.type === "tv");
      const unknownMedia = allMedia.filter(item => item.type === "unknown");
      
      console.log(`扫描结果: ${movies.length} 部电影, ${tvShows.length} 部电视剧, ${unknownMedia.length} 个未识别媒体`);
      
      // 如果有未识别的媒体，尝试使用TMDB API来确定它们的类型
      if (unknownMedia.length > 0 && this.posterScraper) {
        console.log(`尝试使用TMDB识别 ${unknownMedia.length} 个未分类的媒体文件...`);
        const identifiedMediaIds = await this.posterScraper.identifyMediaType(unknownMedia.map(m => m.id));
        console.log(`TMDB识别完成，成功识别 ${identifiedMediaIds.length} 个媒体`);
      }
      
      // 重新获取最新的分类结果
      const updatedMovies = await this.mediaDatabase.getMediaByType("movie");
      const updatedTVShows = await this.mediaDatabase.getMediaByType("tv");
      
      return {
        movies: updatedMovies,
        tvShows: updatedTVShows
      };
    } catch (error) {
      console.error("扫描所有媒体失败:", error);
      throw error;
    }
  }
  
  // 根据系列名称将电视剧分组
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
  
  // 从文件名提取电视剧系列名称
  private extractSeriesName(fileName: string): string {
    // 尝试移除季、集信息，获取系列名称
    // 常见模式: "系列名 S01E01", "系列名.S01.E01", "[系列名][S01][E01]"
    
    let seriesName = parseFileName(fileName).title;
    
    // 移除季、集信息
    seriesName = seriesName.replace(/\s*S\d+\s*E\d+\s*/i, ' ');
    seriesName = seriesName.replace(/\s*Season\s*\d+\s*Episode\s*\d+\s*/i, ' ');
    seriesName = seriesName.replace(/\s*第\s*\d+\s*[季集部]\s*/i, ' ');
    
    return seriesName.trim();
  }
  
  // 从文件名提取季信息
  private extractSeasonNumber(fileName: string): number {
    // 尝试匹配季号
    const seasonMatch = fileName.match(/S(\d+)E\d+/i) || 
                       fileName.match(/Season\s*(\d+)/i) ||
                       fileName.match(/第\s*(\d+)\s*季/i);
    
    return seasonMatch ? parseInt(seasonMatch[1], 10) : 1;
  }
  
  // 从文件名提取集信息
  private extractEpisodeNumber(fileName: string): number {
    // 尝试匹配集号
    const episodeMatch = fileName.match(/S\d+E(\d+)/i) ||
                        fileName.match(/Episode\s*(\d+)/i) ||
                        fileName.match(/第\s*(\d+)\s*[集部]/i) ||
                        fileName.match(/E(\d+)/i);
    
    return episodeMatch ? parseInt(episodeMatch[1], 10) : 1;
  }
}


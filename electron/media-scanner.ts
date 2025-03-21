import * as path from "path"
import type { SambaClient } from "./samba-client"
import type { MediaDatabase } from "./media-database"
import { parseFileName } from "./file-parser"
import type { Media } from "../types/media"

export class MediaScanner {
  private sambaClient: SambaClient
  private mediaDatabase: MediaDatabase

  constructor(sambaClient: SambaClient, mediaDatabase: MediaDatabase) {
    this.sambaClient = sambaClient
    this.mediaDatabase = mediaDatabase
  }

  // 扫描媒体文件
  public async scanMedia(type: "movie" | "tv"): Promise<Media[]> {
    try {
      // 获取目录路径
      const directoryPath = type === "movie" ? this.sambaClient.getMoviePath() : this.sambaClient.getTvPath()

      // 列出目录中的文件
      const files = await this.sambaClient.listFiles(directoryPath)

      // 处理每个文件
      const mediaItems: Media[] = []

      for (const file of files) {
        // 跳过隐藏文件
        if (file.startsWith(".")) continue

        // 解析文件名
        const { title, year } = parseFileName(file)

        // 创建媒体项
        const mediaItem: Media = {
          id: `${type}-${Buffer.from(file).toString("base64").slice(0, 12)}`,
          title: title || file,
          year: year || "未知",
          type,
          path: path.join(directoryPath, file),
          posterPath: "",
          dateAdded: new Date().toISOString(),
          lastUpdated: new Date().toISOString(),
        }

        // 添加到列表
        mediaItems.push(mediaItem)

        // 保存到数据库
        await this.mediaDatabase.saveMedia(mediaItem)
      }

      return mediaItems
    } catch (error) {
      console.error(`Error scanning ${type} media:`, error)
      throw error
    }
  }

  // 扫描所有媒体
  public async scanAllMedia(): Promise<{ movies: Media[]; tvShows: Media[] }> {
    const movies = await this.scanMedia("movie")
    const tvShows = await this.scanMedia("tv")

    return { movies, tvShows }
  }
}


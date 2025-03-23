import * as path from "path"
import type { SambaClient } from "./samba-client"
import type { MediaDatabase } from "./media-database"
import { parseFileName } from "./file-parser"
import type { Media } from "../types/media"

export class MediaScanner {
  private sambaClient: SambaClient
  private mediaDatabase: MediaDatabase
  private sharePath: string = ""

  constructor(sambaClient: SambaClient, mediaDatabase: MediaDatabase) {
    this.sambaClient = sambaClient
    this.mediaDatabase = mediaDatabase
  }

  // 设置共享路径
  public setSharePath(sharePath: string): void {
    this.sharePath = sharePath
  }

  // 扫描媒体文件
  public async scanMedia(type: "movie" | "tv"): Promise<Media[]> {
    try {
      if (!this.sharePath) {
        throw new Error("共享路径未设置，请先配置共享路径")
      }

      // 使用新的方法获取媒体文件
      const mediaFiles = await this.sambaClient.getMediaByType(this.sharePath, type)
      
      // 处理每个文件
      const mediaItems: Media[] = []

      for (const mediaFile of mediaFiles) {
        // 解析文件名
        const { title, year } = parseFileName(mediaFile.name)

        // 创建媒体项
        const mediaItem: Media = {
          id: `${type}-${Buffer.from(mediaFile.path).toString("base64").slice(0, 12)}`,
          title: title || mediaFile.name,
          year: year || "未知",
          type,
          path: mediaFile.path,
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


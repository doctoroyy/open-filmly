import * as path from "path"
import * as fs from "fs"
import * as sqlite3 from "sqlite3"
import { open, type Database } from "sqlite"
import type { Media } from "../types/media"

export class MediaDatabase {
  private dbPath: string
  private db: Database | null = null

  constructor(dbPath: string) {
    this.dbPath = dbPath

    // 确保数据库目录存在
    const dbDir = path.dirname(dbPath)
    if (!fs.existsSync(dbDir)) {
      fs.mkdirSync(dbDir, { recursive: true })
    }
  }

  // 初始化数据库
  public async initialize(): Promise<void> {
    try {
      // 打开数据库连接
      this.db = await open({
        filename: this.dbPath,
        driver: sqlite3.Database,
      })

      // 创建媒体表
      await this.db.exec(`
        CREATE TABLE IF NOT EXISTS media (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          year TEXT,
          type TEXT NOT NULL,
          path TEXT NOT NULL,
          posterPath TEXT,
          rating TEXT,
          dateAdded TEXT NOT NULL,
          lastUpdated TEXT NOT NULL
        )
      `)

      // 创建配置表
      await this.db.exec(`
        CREATE TABLE IF NOT EXISTS config (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        )
      `)

      console.log("Database initialized")
    } catch (error) {
      console.error("Failed to initialize database:", error)
      throw error
    }
  }

  // 保存媒体项
  public async saveMedia(media: Media): Promise<void> {
    if (!this.db) {
      throw new Error("Database not initialized")
    }

    try {
      // 检查媒体项是否已存在
      const existing = await this.db.get("SELECT id FROM media WHERE id = ?", media.id)

      if (existing) {
        // 更新现有媒体项
        await this.db.run(
          `
          UPDATE media
          SET title = ?, year = ?, type = ?, path = ?, lastUpdated = ?
          WHERE id = ?
        `,
          [media.title, media.year, media.type, media.path, new Date().toISOString(), media.id],
        )
      } else {
        // 插入新媒体项
        await this.db.run(
          `
          INSERT INTO media (id, title, year, type, path, posterPath, dateAdded, lastUpdated)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        `,
          [
            media.id,
            media.title,
            media.year,
            media.type,
            media.path,
            media.posterPath || "",
            media.dateAdded,
            media.lastUpdated,
          ],
        )
      }
    } catch (error) {
      console.error(`Failed to save media ${media.id}:`, error)
      throw error
    }
  }

  // 更新媒体海报
  public async updateMediaPoster(mediaId: string, posterPath: string): Promise<void> {
    if (!this.db) {
      throw new Error("Database not initialized")
    }

    try {
      await this.db.run(
        `
        UPDATE media
        SET posterPath = ?, lastUpdated = ?
        WHERE id = ?
      `,
        [posterPath, new Date().toISOString(), mediaId],
      )
    } catch (error) {
      console.error(`Failed to update poster for ${mediaId}:`, error)
      throw error
    }
  }

  // 更新媒体评分
  public async updateMediaRating(mediaId: string, rating: string): Promise<void> {
    if (!this.db) {
      throw new Error("Database not initialized")
    }

    try {
      await this.db.run(
        `
        UPDATE media
        SET rating = ?, lastUpdated = ?
        WHERE id = ?
      `,
        [rating, new Date().toISOString(), mediaId],
      )
    } catch (error) {
      console.error(`Failed to update rating for ${mediaId}:`, error)
      throw error
    }
  }

  // 获取媒体项
  public async getMediaById(id: string): Promise<Media | null> {
    if (!this.db) {
      throw new Error("Database not initialized")
    }

    try {
      const media = await this.db.get("SELECT * FROM media WHERE id = ?", id)
      return media || null
    } catch (error) {
      console.error(`Failed to get media ${id}:`, error)
      throw error
    }
  }

  // 获取指定类型的所有媒体
  public async getMediaByType(type: "movie" | "tv"): Promise<Media[]> {
    if (!this.db) {
      throw new Error("Database not initialized")
    }

    try {
      const media = await this.db.all("SELECT * FROM media WHERE type = ? ORDER BY title", type)
      return media || []
    } catch (error) {
      console.error(`Failed to get ${type} media:`, error)
      throw error
    }
  }

  // 保存配置
  public async saveConfig(config: any): Promise<void> {
    if (!this.db) {
      throw new Error("Database not initialized")
    }

    try {
      // 将配置转换为JSON字符串
      const configJson = JSON.stringify(config)

      // 检查配置是否已存在
      const existing = await this.db.get("SELECT key FROM config WHERE key = ?", "app_config")

      if (existing) {
        // 更新现有配置
        await this.db.run("UPDATE config SET value = ? WHERE key = ?", [configJson, "app_config"])
      } else {
        // 插入新配置
        await this.db.run("INSERT INTO config (key, value) VALUES (?, ?)", ["app_config", configJson])
      }
    } catch (error) {
      console.error("Failed to save config:", error)
      throw error
    }
  }

  // 获取配置
  public async getConfig(): Promise<any | null> {
    if (!this.db) {
      throw new Error("Database not initialized")
    }

    try {
      const config = await this.db.get("SELECT value FROM config WHERE key = ?", "app_config")

      if (config && config.value) {
        return JSON.parse(config.value)
      }

      return null
    } catch (error) {
      console.error("Failed to get config:", error)
      throw error
    }
  }
}


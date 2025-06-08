import * as path from "path"
import * as fs from "fs"
import Database from "better-sqlite3"
import type { Media } from "../types/media"

export class MediaDatabase {
  private dbPath: string
  private db: Database.Database | null = null

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
      this.db = new Database(this.dbPath)

      // 创建媒体表
      this.db.exec(`
        CREATE TABLE IF NOT EXISTS media (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          year TEXT,
          type TEXT NOT NULL,
          path TEXT NOT NULL,
          fullPath TEXT,
          posterPath TEXT,
          rating TEXT,
          details TEXT,
          dateAdded TEXT NOT NULL,
          lastUpdated TEXT NOT NULL
        )
      `)

      // 检查并添加可能缺少的列
      try {
        // 尝试获取表信息
        const tableInfo = this.db.prepare("PRAGMA table_info(media)").all() as any[];
        const hasDetailsColumn = tableInfo.some(col => col.name === 'details');
        
        // 如果缺少details列，添加它
        if (!hasDetailsColumn) {
          console.log("Adding missing 'details' column to media table...");
          this.db.exec("ALTER TABLE media ADD COLUMN details TEXT");
          console.log("Successfully added 'details' column to media table");
        }
      } catch (alterError) {
        console.error("Error checking or adding columns:", alterError);
        // 继续初始化过程，不要让这个错误中断应用启动
      }

      // 创建配置表
      this.db.exec(`
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
      const existing = this.db.prepare("SELECT id FROM media WHERE id = ?").get(media.id)

      if (existing) {
        // 更新现有媒体项
        this.db.prepare(`
          UPDATE media
          SET title = ?, year = ?, type = ?, path = ?, fullPath = ?, rating = ?, details = ?, lastUpdated = ?
          WHERE id = ?
        `).run(
          media.title, 
          media.year || "", 
          media.type, 
          media.path, 
          media.fullPath || "", 
          media.rating || "",
          media.details || "",
          new Date().toISOString(), 
          media.id
        )
      } else {
        // 插入新媒体项
        this.db.prepare(`
          INSERT INTO media (id, title, year, type, path, fullPath, posterPath, rating, details, dateAdded, lastUpdated)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        `).run(
          media.id,
          media.title,
          media.year || "",
          media.type,
          media.path,
          media.fullPath || "",
          media.posterPath || "",
          media.rating || "",
          media.details || "",
          media.dateAdded || new Date().toISOString(),
          media.lastUpdated || new Date().toISOString()
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
      console.log(`更新媒体 ${mediaId} 的海报路径为: ${posterPath}`);
      
      // 首先检查媒体是否存在
      const existingMedia = this.db.prepare("SELECT * FROM media WHERE id = ?").get(mediaId);
      if (!existingMedia) {
        console.error(`无法更新海报: 未找到ID为 ${mediaId} 的媒体`);
        throw new Error(`Media with ID ${mediaId} not found`);
      }
      
      // 更新海报路径
      this.db.prepare(`
        UPDATE media
        SET posterPath = ?, lastUpdated = ?
        WHERE id = ?
      `).run(posterPath, new Date().toISOString(), mediaId);
      
      console.log(`成功更新媒体 ${mediaId} 的海报路径`);
    } catch (error) {
      console.error(`更新媒体 ${mediaId} 的海报路径失败:`, error);
      throw error;
    }
  }

  // 更新媒体评分
  public async updateMediaRating(mediaId: string, rating: string): Promise<void> {
    if (!this.db) {
      throw new Error("Database not initialized")
    }

    try {
      this.db.prepare(`
        UPDATE media
        SET rating = ?, lastUpdated = ?
        WHERE id = ?
      `).run(rating, new Date().toISOString(), mediaId)
    } catch (error) {
      console.error(`Failed to update rating for ${mediaId}:`, error)
      throw error
    }
  }

  // 通过ID获取媒体
  public async getMediaById(id: string): Promise<any> {
    if (!this.db) {
      throw new Error("Database not initialized")
    }

    try {
      console.log(`从数据库获取媒体ID: ${id}`);
      
      const media = this.db.prepare(`
        SELECT * FROM media WHERE id = ?
      `).get(id) as any;
      
      if (!media) {
        console.log(`数据库中未找到ID为 ${id} 的媒体`);
        return null;
      }
      
      // 检查媒体的海报路径是否存在
      if (media.posterPath) {
        const posterExists = require('fs').existsSync(media.posterPath);
        console.log(`媒体 ${id} 的海报路径 ${media.posterPath} ${posterExists ? '存在' : '不存在'}`);
        
        if (!posterExists) {
          console.log(`警告: 媒体 ${id} 的海报文件不存在，但路径已记录在数据库中`);
        }
      } else {
        console.log(`媒体 ${id} 没有海报路径`);
      }
      
      console.log(`成功获取媒体 ${id}: ${media.title}`);
      return media;
    } catch (error) {
      console.error(`获取媒体 ${id} 失败:`, error);
      throw error;
    }
  }

  // 获取指定类型的所有媒体
  public async getMediaByType(type: "movie" | "tv" | "unknown"): Promise<Media[]> {
    if (!this.db) {
      throw new Error("Database not initialized")
    }

    try {
      const media = this.db.prepare("SELECT * FROM media WHERE type = ? ORDER BY title").all(type) as Media[]
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
      const existing = this.db.prepare("SELECT key FROM config WHERE key = ?").get("app_config")

      if (existing) {
        // 更新现有配置
        this.db.prepare("UPDATE config SET value = ? WHERE key = ?").run(configJson, "app_config")
      } else {
        // 插入新配置
        this.db.prepare("INSERT INTO config (key, value) VALUES (?, ?)").run("app_config", configJson)
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
      const config = this.db.prepare("SELECT value FROM config WHERE key = ?").get("app_config") as { value: string } | undefined

      if (config && config.value) {
        return JSON.parse(config.value)
      }

      return null
    } catch (error) {
      console.error("Failed to get config:", error)
      throw error
    }
  }

  // 更新媒体类型
  public async updateMediaType(mediaId: string, type: "movie" | "tv" | "unknown"): Promise<void> {
    if (!this.db) {
      throw new Error("Database not initialized")
    }

    try {
      console.log(`更新媒体 ${mediaId} 的类型为: ${type}`);
      
      // 首先检查媒体是否存在
      const existingMedia = this.db.prepare("SELECT * FROM media WHERE id = ?").get(mediaId);
      if (!existingMedia) {
        console.error(`无法更新类型: 未找到ID为 ${mediaId} 的媒体`);
        throw new Error(`Media with ID ${mediaId} not found`);
      }
      
      // 更新媒体类型
      this.db.prepare(`
        UPDATE media
        SET type = ?, lastUpdated = ?
        WHERE id = ?
      `).run(type, new Date().toISOString(), mediaId);
      
      console.log(`成功更新媒体 ${mediaId} 的类型`);
    } catch (error) {
      console.error(`更新媒体 ${mediaId} 的类型失败:`, error);
      throw error;
    }
  }

  // 更新媒体详细信息
  public async updateMediaDetails(mediaId: string, details: {
    overview?: string;
    backdropPath?: string;
    rating?: number;
    releaseDate?: string;
    genres?: string[];
  }): Promise<void> {
    if (!this.db) {
      throw new Error("Database not initialized")
    }

    try {
      // 首先获取当前媒体项
      const media = await this.getMediaById(mediaId)
      if (!media) {
        throw new Error(`Media not found: ${mediaId}`)
      }
      
      // 创建一个用于存储额外详细信息的JSON字段
      const existingDetails = media.details ? JSON.parse(media.details) : {}
      const updatedDetails = {
        ...existingDetails,
        ...(details.overview !== undefined && { overview: details.overview }),
        ...(details.backdropPath !== undefined && { backdropPath: details.backdropPath }),
        ...(details.releaseDate !== undefined && { releaseDate: details.releaseDate }),
        ...(details.genres !== undefined && { genres: details.genres }),
      }
      
      try {
        // 更新数据库
        const queries = []
        const params = []
        
        // 构建UPDATE语句的SET部分
        let updateSql = `UPDATE media SET lastUpdated = ?`
        params.push(new Date().toISOString())
        
        // 添加rating字段更新（如果有）
        if (details.rating !== undefined) {
          updateSql += `, rating = ?`
          params.push(details.rating.toString())
        }
        
        // 为其他详细信息创建一个JSON字段
        updateSql += `, details = ?`
        params.push(JSON.stringify(updatedDetails))
        
        // 添加WHERE子句
        updateSql += ` WHERE id = ?`
        params.push(mediaId)
        
        // 执行更新
        this.db.prepare(updateSql).run(...params)
        
        console.log(`Updated details for media ${mediaId}`)
      } catch (error: any) {
        // 检查是否是'details列不存在'的错误
        if (error && error.code === 'SQLITE_ERROR' && error.message && error.message.includes('no such column: details')) {
          console.log(`'details' column not found, attempting to add it...`);
          
          try {
            // 添加details列
            this.db.exec(`ALTER TABLE media ADD COLUMN details TEXT`);
            console.log(`Successfully added 'details' column, retrying update...`);
            
            // 重试更新，但这次只设置details字段
            this.db.prepare(`
              UPDATE media 
              SET details = ?, lastUpdated = ? 
              WHERE id = ?
            `).run(
              JSON.stringify(updatedDetails),
              new Date().toISOString(),
              mediaId
            );
            
            console.log(`Successfully updated details for media ${mediaId} after adding column`);
          } catch (alterError) {
            console.error(`Failed to add 'details' column:`, alterError);
            throw alterError;
          }
        } else {
          // 如果是其他错误，直接抛出
          throw error;
        }
      }
    } catch (error) {
      console.error(`Failed to update details for ${mediaId}:`, error)
      throw error
    }
  }

  // 清空媒体缓存
  public async clearMediaCache(): Promise<void> {
    if (!this.db) {
      throw new Error("Database not initialized")
    }

    try {
      // 删除所有媒体记录
      this.db.prepare("DELETE FROM media").run();
      console.log("Media cache cleared");
      return;
    } catch (error) {
      console.error("Failed to clear media cache:", error);
      throw error;
    }
  }

  // 通过路径搜索媒体
  public async searchMediaByPath(searchTerm: string): Promise<Media[]> {
    if (!this.db) {
      throw new Error("Database not initialized")
    }

    try {
      console.log(`搜索路径包含 "${searchTerm}" 的媒体`);
      
      const media = this.db.prepare(`
        SELECT * FROM media 
        WHERE path LIKE ? OR fullPath LIKE ?
        ORDER BY title
      `).all(`%${searchTerm}%`, `%${searchTerm}%`) as Media[];
      
      console.log(`找到 ${media.length} 个匹配的媒体项`);
      return media;
    } catch (error) {
      console.error(`通过路径搜索媒体时出错:`, error);
      throw error;
    }
  }

  // 综合搜索媒体（标题、路径和完整路径）
  public async searchMedia(searchTerm: string): Promise<Media[]> {
    if (!this.db) {
      throw new Error("Database not initialized")
    }

    try {
      console.log(`综合搜索媒体: "${searchTerm}"`);
      
      const media = this.db.prepare(`
        SELECT * FROM media 
        WHERE title LIKE ? OR path LIKE ? OR fullPath LIKE ?
        ORDER BY title
      `).all(`%${searchTerm}%`, `%${searchTerm}%`, `%${searchTerm}%`) as Media[];
      
      console.log(`找到 ${media.length} 个匹配的媒体项`);
      return media;
    } catch (error) {
      console.error(`综合搜索媒体时出错:`, error);
      throw error;
    }
  }

  /**
   * 全面搜索媒体 - 搜索多个字段
   * 搜索标题、路径、完整路径等多个字段
   */
  public async comprehensiveSearch(searchTerm: string): Promise<Media[]> {
    if (!this.db) {
      throw new Error("Database not initialized")
    }

    try {
      console.log(`全面搜索包含 "${searchTerm}" 的媒体`);
      
      // 将搜索词拆分为多个关键词，以支持多关键词搜索
      const keywords = searchTerm.trim().split(/\s+/).filter(k => k.length > 0);
      
      if (keywords.length === 0) {
        return [];
      }
      
      // 构建 SQL 查询
      let sql = `SELECT * FROM media WHERE`;
      const params: string[] = [];
      
      // 为每个关键词构建条件
      for (let i = 0; i < keywords.length; i++) {
        const keyword = keywords[i];
        
        if (i > 0) {
          sql += ` AND`;
        }
        
        // 搜索多个字段
        sql += ` (
          title LIKE ? OR 
          path LIKE ? OR 
          fullPath LIKE ? OR
          year LIKE ?
        )`;
        
        // 添加参数
        params.push(`%${keyword}%`, `%${keyword}%`, `%${keyword}%`, `%${keyword}%`);
      }
      
      sql += ` ORDER BY title`;
      
      const media = this.db.prepare(sql).all(...params) as Media[];
      
      console.log(`全面搜索找到 ${media.length} 个匹配的媒体项`);
      return media;
    } catch (error) {
      console.error(`全面搜索媒体时出错:`, error);
      throw error;
    }
  }
}


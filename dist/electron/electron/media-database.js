"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.MediaDatabase = void 0;
const path = __importStar(require("path"));
const fs = __importStar(require("fs"));
const sqlite3 = __importStar(require("sqlite3"));
const sqlite_1 = require("sqlite");
class MediaDatabase {
    constructor(dbPath) {
        this.db = null;
        this.dbPath = dbPath;
        // 确保数据库目录存在
        const dbDir = path.dirname(dbPath);
        if (!fs.existsSync(dbDir)) {
            fs.mkdirSync(dbDir, { recursive: true });
        }
    }
    // 初始化数据库
    async initialize() {
        try {
            // 打开数据库连接
            this.db = await (0, sqlite_1.open)({
                filename: this.dbPath,
                driver: sqlite3.Database,
            });
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
      `);
            // 创建配置表
            await this.db.exec(`
        CREATE TABLE IF NOT EXISTS config (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        )
      `);
            console.log("Database initialized");
        }
        catch (error) {
            console.error("Failed to initialize database:", error);
            throw error;
        }
    }
    // 保存媒体项
    async saveMedia(media) {
        if (!this.db) {
            throw new Error("Database not initialized");
        }
        try {
            // 检查媒体项是否已存在
            const existing = await this.db.get("SELECT id FROM media WHERE id = ?", media.id);
            if (existing) {
                // 更新现有媒体项
                await this.db.run(`
          UPDATE media
          SET title = ?, year = ?, type = ?, path = ?, lastUpdated = ?
          WHERE id = ?
        `, [media.title, media.year, media.type, media.path, new Date().toISOString(), media.id]);
            }
            else {
                // 插入新媒体项
                await this.db.run(`
          INSERT INTO media (id, title, year, type, path, posterPath, dateAdded, lastUpdated)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        `, [
                    media.id,
                    media.title,
                    media.year,
                    media.type,
                    media.path,
                    media.posterPath || "",
                    media.dateAdded,
                    media.lastUpdated,
                ]);
            }
        }
        catch (error) {
            console.error(`Failed to save media ${media.id}:`, error);
            throw error;
        }
    }
    // 更新媒体海报
    async updateMediaPoster(mediaId, posterPath) {
        if (!this.db) {
            throw new Error("Database not initialized");
        }
        try {
            await this.db.run(`
        UPDATE media
        SET posterPath = ?, lastUpdated = ?
        WHERE id = ?
      `, [posterPath, new Date().toISOString(), mediaId]);
        }
        catch (error) {
            console.error(`Failed to update poster for ${mediaId}:`, error);
            throw error;
        }
    }
    // 更新媒体评分
    async updateMediaRating(mediaId, rating) {
        if (!this.db) {
            throw new Error("Database not initialized");
        }
        try {
            await this.db.run(`
        UPDATE media
        SET rating = ?, lastUpdated = ?
        WHERE id = ?
      `, [rating, new Date().toISOString(), mediaId]);
        }
        catch (error) {
            console.error(`Failed to update rating for ${mediaId}:`, error);
            throw error;
        }
    }
    // 获取媒体项
    async getMediaById(id) {
        if (!this.db) {
            throw new Error("Database not initialized");
        }
        try {
            const media = await this.db.get("SELECT * FROM media WHERE id = ?", id);
            return media || null;
        }
        catch (error) {
            console.error(`Failed to get media ${id}:`, error);
            throw error;
        }
    }
    // 获取指定类型的所有媒体
    async getMediaByType(type) {
        if (!this.db) {
            throw new Error("Database not initialized");
        }
        try {
            const media = await this.db.all("SELECT * FROM media WHERE type = ? ORDER BY title", type);
            return media || [];
        }
        catch (error) {
            console.error(`Failed to get ${type} media:`, error);
            throw error;
        }
    }
    // 保存配置
    async saveConfig(config) {
        if (!this.db) {
            throw new Error("Database not initialized");
        }
        try {
            // 将配置转换为JSON字符串
            const configJson = JSON.stringify(config);
            // 检查配置是否已存在
            const existing = await this.db.get("SELECT key FROM config WHERE key = ?", "app_config");
            if (existing) {
                // 更新现有配置
                await this.db.run("UPDATE config SET value = ? WHERE key = ?", [configJson, "app_config"]);
            }
            else {
                // 插入新配置
                await this.db.run("INSERT INTO config (key, value) VALUES (?, ?)", ["app_config", configJson]);
            }
        }
        catch (error) {
            console.error("Failed to save config:", error);
            throw error;
        }
    }
    // 获取配置
    async getConfig() {
        if (!this.db) {
            throw new Error("Database not initialized");
        }
        try {
            const config = await this.db.get("SELECT value FROM config WHERE key = ?", "app_config");
            if (config && config.value) {
                return JSON.parse(config.value);
            }
            return null;
        }
        catch (error) {
            console.error("Failed to get config:", error);
            throw error;
        }
    }
}
exports.MediaDatabase = MediaDatabase;
//# sourceMappingURL=media-database.js.map
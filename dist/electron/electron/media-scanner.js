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
exports.MediaScanner = void 0;
const path = __importStar(require("path"));
const file_parser_1 = require("./file-parser");
class MediaScanner {
    constructor(sambaClient, mediaDatabase) {
        this.sambaClient = sambaClient;
        this.mediaDatabase = mediaDatabase;
    }
    // 扫描媒体文件
    async scanMedia(type) {
        try {
            // 获取目录路径
            const directoryPath = type === "movie" ? this.sambaClient.getMoviePath() : this.sambaClient.getTvPath();
            // 列出目录中的文件
            const files = await this.sambaClient.listFiles(directoryPath);
            // 处理每个文件
            const mediaItems = [];
            for (const file of files) {
                // 跳过隐藏文件
                if (file.startsWith("."))
                    continue;
                // 解析文件名
                const { title, year } = (0, file_parser_1.parseFileName)(file);
                // 创建媒体项
                const mediaItem = {
                    id: `${type}-${Buffer.from(file).toString("base64").slice(0, 12)}`,
                    title: title || file,
                    year: year || "未知",
                    type,
                    path: path.join(directoryPath, file),
                    posterPath: "",
                    dateAdded: new Date().toISOString(),
                    lastUpdated: new Date().toISOString(),
                };
                // 添加到列表
                mediaItems.push(mediaItem);
                // 保存到数据库
                await this.mediaDatabase.saveMedia(mediaItem);
            }
            return mediaItems;
        }
        catch (error) {
            console.error(`Error scanning ${type} media:`, error);
            throw error;
        }
    }
    // 扫描所有媒体
    async scanAllMedia() {
        const movies = await this.scanMedia("movie");
        const tvShows = await this.scanMedia("tv");
        return { movies, tvShows };
    }
}
exports.MediaScanner = MediaScanner;
//# sourceMappingURL=media-scanner.js.map
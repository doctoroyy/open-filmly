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
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.PosterScraper = void 0;
const path = __importStar(require("path"));
const fs = __importStar(require("fs"));
const os = __importStar(require("os"));
const axios_1 = __importDefault(require("axios"));
class PosterScraper {
    constructor(mediaDatabase) {
        this.mediaDatabase = mediaDatabase;
        // 创建海报缓存目录
        this.posterCacheDir = path.join(os.homedir(), ".nas-poster-wall", "posters");
        if (!fs.existsSync(this.posterCacheDir)) {
            fs.mkdirSync(this.posterCacheDir, { recursive: true });
        }
    }
    // 为单个媒体项抓取海报
    async fetchPoster(mediaId) {
        try {
            // 从数据库获取媒体项
            const media = await this.mediaDatabase.getMediaById(mediaId);
            if (!media) {
                throw new Error(`Media not found: ${mediaId}`);
            }
            // 如果已经有海报，直接返回
            if (media.posterPath && fs.existsSync(media.posterPath)) {
                return media.posterPath;
            }
            // 构建缓存文件路径
            const posterFileName = `${mediaId}.jpg`;
            const posterPath = path.join(this.posterCacheDir, posterFileName);
            // 尝试从豆瓣抓取海报
            const posterUrl = await this.searchDoubanPoster(media.title, media.year, media.type);
            if (posterUrl) {
                // 下载海报
                await this.downloadPoster(posterUrl, posterPath);
                // 更新数据库
                await this.mediaDatabase.updateMediaPoster(mediaId, posterPath);
                return posterPath;
            }
            return null;
        }
        catch (error) {
            console.error(`Error fetching poster for ${mediaId}:`, error);
            return null;
        }
    }
    // 为多个媒体项抓取海报
    async fetchPosters(mediaIds) {
        const results = {};
        for (const mediaId of mediaIds) {
            results[mediaId] = await this.fetchPoster(mediaId);
        }
        return results;
    }
    // 从豆瓣搜索海报
    async searchDoubanPoster(title, year, type) {
        try {
            // 构建搜索URL
            const searchQuery = encodeURIComponent(`${title} ${year}`);
            const searchUrl = `https://www.douban.com/search?cat=1002&q=${searchQuery}`;
            // 发送请求
            const response = await axios_1.default.get(searchUrl, {
                headers: {
                    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36",
                },
            });
            // 解析HTML
            const html = response.data;
            // 提取第一个结果的URL
            const resultUrlMatch = html.match(/<a href="(https:\/\/movie\.douban\.com\/subject\/\d+\/)" target="_blank" class="nbg">/);
            if (!resultUrlMatch || !resultUrlMatch[1]) {
                return null;
            }
            const movieUrl = resultUrlMatch[1];
            // 获取电影详情页
            const movieResponse = await axios_1.default.get(movieUrl, {
                headers: {
                    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36",
                },
            });
            // 提取海报URL
            const posterMatch = movieResponse.data.match(/<img src="(https:\/\/img\d+\.doubanio\.com\/view\/photo\/s_ratio_poster\/public\/[^"]+)" title="点击看更多海报" rel="v:image" \/>/);
            if (!posterMatch || !posterMatch[1]) {
                return null;
            }
            // 返回高质量海报URL
            return posterMatch[1].replace("/s_ratio_poster/", "/l_ratio_poster/");
        }
        catch (error) {
            console.error(`Error searching Douban for ${title}:`, error);
            return null;
        }
    }
    // 下载海报
    async downloadPoster(url, filePath) {
        try {
            const response = await (0, axios_1.default)({
                method: "GET",
                url,
                responseType: "stream",
                headers: {
                    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36",
                },
            });
            const writer = fs.createWriteStream(filePath);
            return new Promise((resolve, reject) => {
                response.data.pipe(writer);
                writer.on("finish", resolve);
                writer.on("error", reject);
            });
        }
        catch (error) {
            console.error(`Error downloading poster from ${url}:`, error);
            throw error;
        }
    }
}
exports.PosterScraper = PosterScraper;
//# sourceMappingURL=poster-scraper.js.map
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
exports.SambaClient = void 0;
const samba = __importStar(require("samba-client"));
const path = __importStar(require("path"));
const fs = __importStar(require("fs"));
const os = __importStar(require("os"));
class SambaClient {
    constructor() {
        this.config = null;
        this.client = null;
        // 默认配置
        this.config = {
            ip: "192.168.31.100",
            port: 445,
            username: "",
            password: "",
            moviePath: "movies",
            tvPath: "tv",
        };
    }
    // 配置Samba客户端
    configure(config) {
        this.config = {
            ...this.config,
            ...config,
        };
        // 重置客户端，下次使用时会重新创建
        this.client = null;
    }
    // 获取Samba客户端实例
    getClient() {
        if (!this.client && this.config) {
            const { ip, username, password, domain } = this.config;
            // 创建Samba客户端
            this.client = new samba.Client({
                address: `//${ip}`,
                username: username || "guest",
                password: password || "",
                domain: domain || "",
                maxProtocol: "SMB3",
                autoCloseTimeout: 5000,
            });
        }
        return this.client;
    }
    // 列出目录中的文件
    async listFiles(directory) {
        if (!this.config) {
            throw new Error("Samba client not configured");
        }
        try {
            const client = this.getClient();
            const files = await client.listFiles(directory);
            return files;
        }
        catch (error) {
            console.error(`Error listing files in ${directory}:`, error);
            throw error;
        }
    }
    // 获取文件内容
    async readFile(filePath) {
        if (!this.config) {
            throw new Error("Samba client not configured");
        }
        try {
            const client = this.getClient();
            const content = await client.readFile(filePath);
            return content;
        }
        catch (error) {
            console.error(`Error reading file ${filePath}:`, error);
            throw error;
        }
    }
    // 将文件下载到本地临时目录
    async downloadFile(remotePath) {
        if (!this.config) {
            throw new Error("Samba client not configured");
        }
        try {
            const client = this.getClient();
            const content = await client.readFile(remotePath);
            // 创建临时文件
            const tempDir = path.join(os.tmpdir(), "nas-poster-wall");
            if (!fs.existsSync(tempDir)) {
                fs.mkdirSync(tempDir, { recursive: true });
            }
            const fileName = path.basename(remotePath);
            const localPath = path.join(tempDir, fileName);
            // 写入文件
            fs.writeFileSync(localPath, content);
            return localPath;
        }
        catch (error) {
            console.error(`Error downloading file ${remotePath}:`, error);
            throw error;
        }
    }
    // 获取电影目录
    getMoviePath() {
        return this.config?.moviePath || "movies";
    }
    // 获取电视剧目录
    getTvPath() {
        return this.config?.tvPath || "tv";
    }
}
exports.SambaClient = SambaClient;
//# sourceMappingURL=samba-client.js.map
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
const electron_1 = require("electron");
const path = __importStar(require("path"));
const samba_client_1 = require("./samba-client");
const media_scanner_1 = require("./media-scanner");
const poster_scraper_1 = require("./poster-scraper");
const media_database_1 = require("./media-database");
const media_player_1 = require("./media-player");
// 全局变量
let mainWindow = null;
let sambaClient;
let mediaScanner;
let posterScraper;
let mediaDatabase;
let mediaPlayer;
// 创建主窗口
function createWindow() {
    mainWindow = new electron_1.BrowserWindow({
        width: 1280,
        height: 800,
        webPreferences: {
            preload: path.join(__dirname, "preload.js"),
            contextIsolation: true,
            nodeIntegration: false,
        },
        // 设置窗口图标
        icon: path.join(__dirname, "../public/icon.png"),
    });
    // 在开发模式下加载本地服务器
    if (process.env.NODE_ENV === "development") {
        mainWindow.loadURL("http://localhost:3000");
        mainWindow.webContents.openDevTools();
    }
    else {
        // 在生产模式下加载打包后的应用
        mainWindow.loadFile(path.join(__dirname, "../renderer/index.html"));
    }
    // 窗口关闭时清除引用
    mainWindow.on("closed", () => {
        mainWindow = null;
    });
}
// 初始化应用
async function initializeApp() {
    try {
        // 初始化数据库
        mediaDatabase = new media_database_1.MediaDatabase(path.join(electron_1.app.getPath("userData"), "media.db"));
        await mediaDatabase.initialize();
        // 初始化Samba客户端
        sambaClient = new samba_client_1.SambaClient();
        // 初始化媒体扫描器
        mediaScanner = new media_scanner_1.MediaScanner(sambaClient, mediaDatabase);
        // 初始化海报抓取器
        posterScraper = new poster_scraper_1.PosterScraper(mediaDatabase);
        // 初始化媒体播放器
        mediaPlayer = new media_player_1.MediaPlayer();
        // 从数据库加载配置
        const config = await mediaDatabase.getConfig();
        if (config) {
            sambaClient.configure(config);
        }
    }
    catch (error) {
        console.error("Failed to initialize app:", error);
    }
}
// 应用准备就绪时创建窗口
electron_1.app.whenReady().then(() => {
    createWindow();
    initializeApp();
    electron_1.app.on("activate", () => {
        if (electron_1.BrowserWindow.getAllWindows().length === 0) {
            createWindow();
        }
    });
});
// 所有窗口关闭时退出应用（macOS除外）
electron_1.app.on("window-all-closed", () => {
    if (process.platform !== "darwin") {
        electron_1.app.quit();
    }
});
// IPC通信处理
// 获取配置
electron_1.ipcMain.handle("get-config", async () => {
    return await mediaDatabase.getConfig();
});
// 保存配置
electron_1.ipcMain.handle("save-config", async (_, config) => {
    try {
        await mediaDatabase.saveConfig(config);
        sambaClient.configure(config);
        return { success: true };
    }
    catch (error) {
        console.error("Failed to save config:", error);
        return { success: false, error: error.message };
    }
});
// 扫描媒体
electron_1.ipcMain.handle("scan-media", async (_, type) => {
    try {
        const results = await mediaScanner.scanMedia(type);
        return { success: true, count: results.length };
    }
    catch (error) {
        console.error("Failed to scan media:", error);
        return { success: false, error: error.message };
    }
});
// 获取媒体列表
electron_1.ipcMain.handle("get-media", async (_, type) => {
    try {
        const media = await mediaDatabase.getMediaByType(type);
        return media;
    }
    catch (error) {
        console.error("Failed to get media:", error);
        return [];
    }
});
// 播放媒体
electron_1.ipcMain.handle("play-media", async (_, mediaId) => {
    try {
        const media = await mediaDatabase.getMediaById(mediaId);
        if (!media) {
            throw new Error("Media not found");
        }
        await mediaPlayer.play(media.path);
        return { success: true };
    }
    catch (error) {
        console.error("Failed to play media:", error);
        return { success: false, error: error.message };
    }
});
// 抓取海报
electron_1.ipcMain.handle("fetch-posters", async (_, mediaIds) => {
    try {
        const results = await posterScraper.fetchPosters(mediaIds);
        return { success: true, results };
    }
    catch (error) {
        console.error("Failed to fetch posters:", error);
        return { success: false, error: error.message };
    }
});
// 选择本地媒体文件夹
electron_1.ipcMain.handle("select-folder", async () => {
    if (!mainWindow)
        return { canceled: true };
    const result = await electron_1.dialog.showOpenDialog(mainWindow, {
        properties: ["openDirectory"],
    });
    return result;
});
//# sourceMappingURL=main.js.map
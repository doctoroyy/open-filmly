import { app, BrowserWindow, ipcMain, dialog } from "electron"
import * as path from "path"
import { SambaClient } from "./samba-client"
import { MediaScanner } from "./media-scanner"
import { PosterScraper } from "./poster-scraper"
import { MediaDatabase } from "./media-database"
import { MediaPlayer } from "./media-player"

// 全局变量
let mainWindow: BrowserWindow | null = null
let sambaClient: SambaClient
let mediaScanner: MediaScanner
let posterScraper: PosterScraper
let mediaDatabase: MediaDatabase
let mediaPlayer: MediaPlayer

// 创建主窗口
function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1280,
    height: 800,
    webPreferences: {
      preload: path.join(__dirname, "preload.js"),
      contextIsolation: true,
      nodeIntegration: false,
    },
    // 设置窗口图标
    icon: path.join(__dirname, "../public/icon.png"),
  })

  // 在开发模式下加载本地服务器
  const isDev = process.env.NODE_ENV === "development"
  console.log(`Running in ${isDev ? "development" : "production"} mode`)
  
  if (isDev) {
    const serverUrl = "http://localhost:3000"
    console.log(`Loading from development server: ${serverUrl}`)
    mainWindow.loadURL(serverUrl)
    mainWindow.webContents.openDevTools()
  } else {
    // 在生产模式下加载打包后的应用
    const filePath = path.join(__dirname, "../.next/server/app/page.html")
    console.log(`Loading file from: ${filePath}`)
    mainWindow.loadFile(filePath)
  }

  // 窗口关闭时清除引用
  mainWindow.on("closed", () => {
    mainWindow = null
  })
}

// 初始化应用
async function initializeApp() {
  try {
    // 初始化数据库
    mediaDatabase = new MediaDatabase(path.join(app.getPath("userData"), "media.db"))
    await mediaDatabase.initialize()

    // 初始化Samba客户端
    sambaClient = new SambaClient()

    // 初始化媒体扫描器
    mediaScanner = new MediaScanner(sambaClient, mediaDatabase)

    // 初始化海报抓取器
    posterScraper = new PosterScraper(mediaDatabase)

    // 初始化媒体播放器
    mediaPlayer = new MediaPlayer()

    // 从数据库加载配置
    const config = await mediaDatabase.getConfig()
    if (config) {
      sambaClient.configure(config)
    }
  } catch (error: unknown) {
    console.error("Failed to initialize app:", error)
  }
}

// 应用准备就绪时创建窗口
app.whenReady().then(() => {
  createWindow()
  initializeApp()

  app.on("activate", () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      createWindow()
    }
  })
})

// 所有窗口关闭时退出应用（macOS除外）
app.on("window-all-closed", () => {
  if (process.platform !== "darwin") {
    app.quit()
  }
})

// IPC通信处理
// 获取配置
ipcMain.handle("get-config", async () => {
  return await mediaDatabase.getConfig()
})

// 保存配置
ipcMain.handle("save-config", async (_, config) => {
  try {
    await mediaDatabase.saveConfig(config)
    sambaClient.configure(config)
    return { success: true }
  } catch (error: unknown) {
    console.error("Failed to save config:", error)
    return { success: false, error: error instanceof Error ? error.message : String(error) }
  }
})

// 扫描媒体
ipcMain.handle("scan-media", async (_, type) => {
  try {
    const results = await mediaScanner.scanMedia(type)
    return { success: true, count: results.length }
  } catch (error: unknown) {
    console.error("Failed to scan media:", error)
    return { success: false, error: error instanceof Error ? error.message : String(error) }
  }
})

// 获取媒体列表
ipcMain.handle("get-media", async (_, type) => {
  try {
    const media = await mediaDatabase.getMediaByType(type)
    return media
  } catch (error: unknown) {
    console.error("Failed to get media:", error)
    return []
  }
})

// 播放媒体
ipcMain.handle("play-media", async (_, mediaId) => {
  try {
    const media = await mediaDatabase.getMediaById(mediaId)
    if (!media) {
      throw new Error("Media not found")
    }

    await mediaPlayer.play(media.path)
    return { success: true }
  } catch (error: unknown) {
    console.error("Failed to play media:", error)
    return { success: false, error: error instanceof Error ? error.message : String(error) }
  }
})

// 抓取海报
ipcMain.handle("fetch-posters", async (_, mediaIds) => {
  try {
    const results = await posterScraper.fetchPosters(mediaIds)
    return { success: true, results }
  } catch (error: unknown) {
    console.error("Failed to fetch posters:", error)
    return { success: false, error: error instanceof Error ? error.message : String(error) }
  }
})

// 选择本地媒体文件夹
ipcMain.handle("select-folder", async () => {
  if (!mainWindow) return { canceled: true }

  const result = await dialog.showOpenDialog(mainWindow, {
    properties: ["openDirectory"],
  })

  return result
})


import path from "path"
import { app, BrowserWindow, ipcMain, dialog, protocol, net } from "electron"
import { connect, createConnection } from "net"
import { MediaDatabase } from "./media-database"
import { MediaScanner } from "./media-scanner"
import { MediaPlayer } from "./media-player"
import { MetadataScraper } from "./metadata-scraper"
import * as fs from "fs"
import { SambaClient } from "./smb-client"
import { createProductionServer } from "./server"

// 抑制 macOS 上的 IMK 相关警告
if (process.platform === 'darwin') {
  process.env.IMK_DISABLE_WAKEUP_RELIABLE = '1'
  // 禁用硬件加速可以解决某些macOS上的渲染问题
  if (process.platform === 'darwin') {
    app.disableHardwareAcceleration()
  }
}

// 全局变量
let mainWindow: BrowserWindow | null = null
let sambaClient: SambaClient
let mediaScanner: MediaScanner
let metadataScraper: MetadataScraper
let mediaDatabase: MediaDatabase
let mediaPlayer: MediaPlayer
let productionServer: any = null

// 创建主窗口
function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1200,
    height: 800,
    webPreferences: {
      nodeIntegration: false,
      contextIsolation: true,
      preload: path.join(__dirname, 'preload.js'),
      webSecurity: false, // 允许加载本地文件
    },
    // 设置窗口图标 - 根据平台使用正确的图标路径
    icon: process.platform === 'darwin' 
      ? path.join(__dirname, "../public/app-icons/mac/icon.icns") 
      : process.platform === 'win32'
        ? path.join(__dirname, "../public/app-icons/win/icon.ico")
        : path.join(__dirname, "../public/app-icons/linux/512x512.png"),
  })

  // 窗口准备好后再显示，避免闪烁
  mainWindow.once('ready-to-show', () => {
    mainWindow?.show()
  })

  // 在开发模式下加载本地服务器
  const isDev = process.env.NODE_ENV === "development"
  console.log(`Running in ${isDev ? "development" : "production"} mode`)
  
  if (isDev) {
    const serverUrl = "http://localhost:5173"
    console.log(`Loading from development server: ${serverUrl}`)
    mainWindow.loadURL(serverUrl)
    mainWindow.webContents.openDevTools()
  } else {
    // 在生产模式下启动 Hono 服务器
    try {
      const server = createProductionServer(3000)
      productionServer = server.start()
      const serverUrl = "http://localhost:3000"
      console.log(`Started production server at: ${serverUrl}`)
      mainWindow.loadURL(serverUrl)
      // 在生产模式下也打开开发工具，方便调试
      // mainWindow.webContents.openDevTools()
    } catch (error) {
      console.error('Failed to start production server:', error)
      // 回退到文件协议
      const filePath = path.join(__dirname, "../renderer/index.html")
      console.log(`Fallback to file protocol: ${filePath}`)
      const fileUrl = `file://${filePath}`
      mainWindow.loadURL(fileUrl)
      mainWindow.webContents.openDevTools()
    }
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

    // 初始化海报抓取器，使用TMDB API密钥
    // 获取TMDB API密钥（从.env.local文件读取）
    let tmdbApiKey
    try {
      const envPath = path.join(process.cwd(), '.env.local')
      if (fs.existsSync(envPath)) {
        const envContent = fs.readFileSync(envPath, 'utf8')
        const matches = envContent.match(/VITE_TMDB_API_KEY=(.+)/)
        if (matches && matches[1]) {
          tmdbApiKey = matches[1].trim()
          console.log(`Found TMDB API key in .env.local: ${tmdbApiKey.substring(0, 5)}...`)
        } else {
          console.error('TMDB API key not found in .env.local')
        }
      } else {
        console.error('.env.local file not found')
      }
    } catch (error) {
      console.error('Error reading TMDB API key:', error)
    }

    // 尝试从环境变量获取
    if (!tmdbApiKey) {
      tmdbApiKey = process.env.VITE_TMDB_API_KEY || process.env.TMDB_API_KEY
      console.log(`Using TMDB API key from environment: ${tmdbApiKey ? 'found' : 'not found'}`)
    }

    metadataScraper = new MetadataScraper(mediaDatabase, tmdbApiKey)
    
    // 初始化媒体扫描器，并传入海报抓取器
    mediaScanner = new MediaScanner(sambaClient, mediaDatabase, metadataScraper)

    // 初始化媒体播放器
    mediaPlayer = new MediaPlayer()

    // 从数据库加载配置
    const config = await mediaDatabase.getConfig()
    if (config) {
      // 检查配置是否完整
      if (config.ip && config.ip.trim() !== "" && config.sharePath && config.sharePath.trim() !== "") {
        console.log("Configuration loaded, applying to Samba client")
        sambaClient.configure(config)
        // 设置媒体扫描器的共享路径
        if (config.sharePath) {
          mediaScanner.setSharePath(config.sharePath)
        }
      } else {
        console.log("Incomplete configuration found, waiting for user to configure")
      }
    } else {
      console.log("No configuration found, waiting for user to configure")
    }
  } catch (error: unknown) {
    console.error("Failed to initialize app:", error)
  }
}

// 应用准备就绪时创建窗口
app.whenReady().then(() => {
  // 注册file协议处理器
  protocol.handle('file', (request) => {
    try {
      const url = request.url.substring('file://'.length)
      let filePath = decodeURIComponent(url)
      console.log(`Protocol handler: loading file from ${filePath}`)
      
      // 检查文件是否存在
      if (fs.existsSync(filePath)) {
        // 获取文件MIME类型
        const mimeType = getMimeType(filePath)
        const fileContent = fs.readFileSync(filePath)
        return new Response(fileContent, {
          headers: {
            'Content-Type': mimeType,
            'Access-Control-Allow-Origin': '*'
          }
        })
      } else {
        console.error(`File not found: ${filePath}`)
        return new Response('File not found', { status: 404 })
      }
    } catch (error) {
      console.error('Error in file protocol handler:', error)
      return new Response('Error loading file', { status: 500 })
    }
  })

  createWindow()
  initializeApp()

  app.on("activate", () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      createWindow()
    }
  })
})

// 获取文件的MIME类型
function getMimeType(filePath: string): string {
  const ext = path.extname(filePath).toLowerCase()
  const mimeTypes: Record<string, string> = {
    '.html': 'text/html',
    '.js': 'text/javascript',
    '.css': 'text/css',
    '.json': 'application/json',
    '.png': 'image/png',
    '.jpg': 'image/jpeg',
    '.jpeg': 'image/jpeg',
    '.gif': 'image/gif',
    '.svg': 'image/svg+xml',
    '.ico': 'image/x-icon',
  }
  return mimeTypes[ext] || 'application/octet-stream'
}

// 所有窗口关闭时退出应用（macOS除外）
app.on("window-all-closed", () => {
  if (process.platform !== "darwin") {
    app.quit()
  }
})

// 应用退出时清理资源
app.on("before-quit", () => {
  if (productionServer) {
    try {
      productionServer.close()
      console.log("Production server closed")
    } catch (error) {
      console.error("Error closing production server:", error)
    }
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
    
    // 设置媒体扫描器的共享路径
    if (config.sharePath) {
      mediaScanner.setSharePath(config.sharePath)
    }
    
    // 设置选定的文件夹列表（如果有）
    if (config.selectedFolders && config.selectedFolders.length > 0) {
      mediaScanner.setSelectedFolders(config.selectedFolders)
    }
    
    return { success: true }
  } catch (error: unknown) {
    console.error("Failed to save config:", error)
    return { success: false, error: error instanceof Error ? error.message : String(error) }
  }
})

// 连接到Samba服务器
ipcMain.handle("connect-server", async (_, serverConfig) => {
  try {
    // 验证必要的配置
    if (!serverConfig.ip || serverConfig.ip.trim() === "") {
      return { 
        success: false, 
        error: "服务器IP必须指定",
        errorType: "invalid_config" 
      };
    }
    
    console.log(`连接到SMB服务器 ${serverConfig.ip}`);
    
    // 配置Samba客户端
    sambaClient.configure(serverConfig);
    
    try {
      // 尝试获取服务器上的所有共享
      console.log("尝试获取服务器上的所有共享...");
      const availableShares = await sambaClient.listShares();
      
      if (availableShares && availableShares.length > 0) {
        console.log(`发现可用共享: ${availableShares.join(', ')}`);
        
        // 返回发现的共享列表，让用户选择
        return { 
          success: true, 
          needShareSelection: true,
          shares: availableShares
        };
      } else {
        return {
          success: false,
          error: "无法在服务器上发现共享",
          errorType: "no_shares_found"
        };
      }
    } catch (error: any) {
      console.error("获取共享列表失败:", error);
      
      // 对特定的SMB错误进行更友好的提示
      if (error.code === 'STATUS_BAD_NETWORK_NAME') {
        return { 
          success: false, 
          error: `找不到指定的共享，请检查共享名称是否正确`,
          errorType: "share_not_found" 
        };
      } else if (error.code === 'STATUS_LOGON_FAILURE') {
        return { 
          success: false, 
          error: `认证失败，请检查用户名和密码`,
          errorType: "auth_failed" 
        };
      } else {
        return { 
          success: false, 
          error: error instanceof Error ? error.message : String(error),
          errorType: error.code || "unknown_error"
        };
      }
    }
  } catch (error: any) {
    console.error("连接服务器失败:", error);
    
    // 处理一些常见连接错误
    if (error.code === 'ETIMEDOUT' || error.code === 'EHOSTUNREACH' || error.code === 'ECONNREFUSED') {
      return { 
        success: false, 
        error: `无法连接到服务器 ${serverConfig.ip}，请检查IP地址是否正确且服务器是否在线`,
        errorType: "connection_failed" 
      };
    }
    
    return { 
      success: false, 
      error: error instanceof Error ? error.message : String(error),
      errorType: error.code || "unknown_error"
    };
  }
})

// 列出可用的共享
ipcMain.handle("list-shares", async () => {
  try {
    const shares = await sambaClient.listShares()
    return { success: true, shares }
  } catch (error: unknown) {
    console.error("Failed to list shares:", error)
    return { success: false, error: error instanceof Error ? error.message : String(error) }
  }
})

// 列出共享中的文件夹
ipcMain.handle("list-folders", async (_, shareName) => {
  try {
    // 确保共享名称格式正确
    const formattedShareName = shareName === "/" ? "" : shareName.replace(/^\/+/, '');
    console.log(`Listing folders in: "${formattedShareName}"`);
    
    const files = await sambaClient.listFiles(formattedShareName);
    // 过滤只返回文件夹
    const folders = [];
    
    for (const file of files) {
      if (file.startsWith('.')) continue;
      
      try {
        // 构建子路径，保持一致的格式
        const subPath = formattedShareName 
          ? `${formattedShareName}\\${file}` 
          : file;
          
        console.log(`Checking if is directory: "${subPath}"`);
        
        // 尝试列出文件，如果成功，则是文件夹
        await sambaClient.listFiles(subPath);
        folders.push(file);
      } catch (error) {
        // 忽略错误，表示不是文件夹或无权限
        console.log(`Not a directory or no permission: ${file}`);
      }
    }
    
    return { success: true, folders };
  } catch (error: unknown) {
    console.error(`Failed to list folders in ${shareName}:`, error);
    return { 
      success: false, 
      error: error instanceof Error ? error.message : String(error),
      errorType: error instanceof Error && 'code' in error ? (error as any).code : 'unknown'
    };
  }
})

// 获取目录内容（文件和文件夹）
ipcMain.handle("get-dir-contents", async (_, dirPath) => {
  try {
    // 确保目录路径格式正确
    const formattedPath = dirPath === "/" ? "" : dirPath.replace(/^\/+/, '');
    console.log(`Getting directory contents for: "${formattedPath}"`);
    
    // 使用新方法获取目录内容
    const items = await sambaClient.getDirContents(formattedPath);
    
    return { 
      success: true, 
      items
    };
  } catch (error: unknown) {
    console.error(`Failed to get contents of directory ${dirPath}:`, error);
    return { 
      success: false, 
      error: error instanceof Error ? error.message : String(error),
      errorType: error instanceof Error && 'code' in error ? (error as any).code : 'unknown'
    };
  }
})

// 扫描媒体
ipcMain.handle("scan-media", async (_, type, useCached = true) => {
  try {
    if (!sambaClient) {
      return { 
        success: false, 
        error: "Samba client is not initialized" 
      }
    }
    
    console.log(`Starting to scan ${type || "all"} media... (useCached: ${useCached})`)
    
    const config = await mediaDatabase.getConfig()
    if (!config || !config.sharePath) {
      return { 
        success: false, 
        error: "Samba server not configured" 
      }
    }
    
    // 确认共享路径和选定文件夹的设置已更新到mediaSanner
    mediaScanner.setSharePath(config.sharePath)
    if (config.selectedFolders && config.selectedFolders.length > 0) {
      mediaScanner.setSelectedFolders(config.selectedFolders)
    }
    
    let result = { count: 0, movies: 0, tvShows: 0 };
    
    // 如果使用缓存，先检查数据库中是否有指定类型的媒体
    if (useCached) {
      if (type === "movie") {
        const cachedMovies = await mediaDatabase.getMediaByType("movie");
        if (cachedMovies && cachedMovies.length > 0) {
          console.log(`Using cached data: ${cachedMovies.length} movies`);
          return { 
            success: true, 
            count: cachedMovies.length,
            movieCount: cachedMovies.length 
          };
        }
      } else if (type === "tv") {
        const cachedTvShows = await mediaDatabase.getMediaByType("tv");
        if (cachedTvShows && cachedTvShows.length > 0) {
          console.log(`Using cached data: ${cachedTvShows.length} TV shows`);
          return { 
            success: true, 
            count: cachedTvShows.length,
            tvCount: cachedTvShows.length 
          };
        }
      } else if (!type || type === "all") {
        const cachedMovies = await mediaDatabase.getMediaByType("movie");
        const cachedTvShows = await mediaDatabase.getMediaByType("tv");
        
        if ((cachedMovies && cachedMovies.length > 0) || 
            (cachedTvShows && cachedTvShows.length > 0)) {
          console.log(`Using cached data: ${cachedMovies.length} movies, ${cachedTvShows.length} TV shows`);
          return { 
            success: true, 
            count: cachedMovies.length + cachedTvShows.length,
            movieCount: cachedMovies.length,
            tvCount: cachedTvShows.length 
          };
        }
      }
      
      console.log("No cached data found, performing full scan");
    } else {
      console.log("Cache disabled, performing full scan");
    }
    
    if (type === "movie" || type === "tv") {
      // 扫描指定类型的媒体
      const { movies, tvShows, total } = await mediaScanner.scanAllMedia(type as "movie" | "tv");
      result = { 
        count: total, 
        movies: movies.length, 
        tvShows: tvShows.length 
      };
    } else {
      // 扫描所有媒体
      const { movies, tvShows, total } = await mediaScanner.scanAllMedia();
      result = { 
        count: total,
        movies: movies.length,
        tvShows: tvShows.length
      };
    }
    
    // 完成后重新返回所有媒体数据，以便更新UI
    return { 
      success: true,
      ...result
    }
  } catch (error: unknown) {
    console.error("Failed to scan media:", error)
    return { 
      success: false, 
      error: error instanceof Error ? error.message : String(error),
      count: 0
    }
  }
})

// 获取媒体
ipcMain.handle("get-media", async (_, type) => {
  try {
    if (type === "all") {
      const movies = await mediaDatabase.getMediaByType("movie");
      const tvShows = await mediaDatabase.getMediaByType("tv");
      const unknown = await mediaDatabase.getMediaByType("unknown");
      const allMedia = [...movies, ...tvShows, ...unknown];
      console.log(`Retrieved ${allMedia.length} total media items (${movies.length} movies, ${tvShows.length} TV shows, ${unknown.length} unknown)`);
      return allMedia;
    } else {
      const media = await mediaDatabase.getMediaByType(type);
      console.log(`Retrieved ${media.length} ${type} media items`);
      return media;
    }
  } catch (error) {
    console.error(`Error getting ${type} media:`, error);
    return [];
  }
})

// 通过ID获取媒体
ipcMain.handle("get-media-by-id", async (_, id) => {
  try {
    console.log(`获取媒体ID: ${id} 的详细信息`);
    const media = await mediaDatabase.getMediaById(id);
    if (media) {
      console.log(`成功获取媒体: ${media.title}, 海报路径: ${media.posterPath || '无'}`);
    } else {
      console.log(`未找到ID为 ${id} 的媒体`);
    }
    return media;
  } catch (error) {
    console.error(`Error getting media with ID ${id}:`, error);
    return null;
  }
})

// 获取最近观看
ipcMain.handle("get-recently-viewed", async () => {
  try {
    // 这里我们可以获取最近观看的媒体（可以按最后观看时间排序）
    // 如果数据库中没有专门的"最近观看"表，可以从现有数据中获取最近修改的项目
    const movies = await mediaDatabase.getMediaByType("movie")
    const tvShows = await mediaDatabase.getMediaByType("tv")
    
    // 合并电影和电视剧，按lastUpdated排序取最近的5个
    const allMedia = [...movies, ...tvShows]
    const recentlyViewed = allMedia
      .sort((a, b) => new Date(b.lastUpdated).getTime() - new Date(a.lastUpdated).getTime())
      .slice(0, 5)
    
    return recentlyViewed
  } catch (error) {
    console.error("Error getting recently viewed media:", error)
    return []
  }
})

// 播放媒体
ipcMain.handle("play-media", async (_, mediaId, filePath) => {
  try {
    // 如果提供了文件路径，直接播放该文件
    if (filePath) {
      console.log(`Playing media with direct path: ${filePath}`);
      await mediaPlayer.play(filePath);
      return { success: true };
    }
    
    // 否则，从数据库获取媒体项
    const media = await mediaDatabase.getMediaById(mediaId);
    if (!media) {
      throw new Error("Media not found");
    }

    console.log(`Playing media with ID ${mediaId}: ${media.path}`);
    await mediaPlayer.play(media.path);
    return { success: true };
  } catch (error: unknown) {
    console.error("Failed to play media:", error);
    return { success: false, error: error instanceof Error ? error.message : String(error) };
  }
})

// 直接添加单个媒体文件
ipcMain.handle("add-single-media", async (_, filePath) => {
  try {
    if (!filePath) {
      throw new Error("File path is required")
    }
    
    // 检查是否是支持的媒体文件
    const fileExtension = path.extname(filePath).toLowerCase()
    const supportedExtensions = ['.mp4', '.mkv', '.avi', '.mov', '.wmv', '.m4v']
    
    if (!supportedExtensions.includes(fileExtension)) {
      throw new Error(`不支持的文件格式: ${fileExtension}`)
    }
    
    // 从文件名解析元数据
    const fileName = path.basename(filePath)
    const { parseFileName } = require("./file-parser")
    const parsedInfo = parseFileName(fileName)
    
    // 确定媒体类型 (基于路径或文件名规则)
    let mediaType: "movie" | "tv" = "movie"
    if (filePath.includes("TV") || filePath.includes("Series") || 
        filePath.includes("电视剧") || fileName.match(/S\d+E\d+/i)) {
      mediaType = "tv"
    }
    
    // 创建媒体记录
    const mediaRecord = {
      id: `${mediaType}-${Buffer.from(filePath).toString("base64").slice(0, 12)}`,
      title: parsedInfo.title || fileName,
      type: mediaType,
      path: filePath,
      year: parsedInfo.year || "未知",
      posterPath: "",
      dateAdded: new Date().toISOString(),
      lastUpdated: new Date().toISOString(),
    }
    
    // 保存到数据库
    await mediaDatabase.saveMedia(mediaRecord)
    
    return { 
      success: true, 
      media: mediaRecord
    }
  } catch (error: unknown) {
    console.error("Failed to add single media file:", error)
    return { 
      success: false, 
      error: error instanceof Error ? error.message : String(error) 
    }
  }
})

// 抓取海报
ipcMain.handle("fetch-posters", async (_, mediaIds) => {
  try {
    console.log(`Fetching metadata for ${mediaIds.length} media items`)
    if (!metadataScraper.hasTmdbApiKey()) {
      console.error("No TMDB API key available for metadata scraper")
    }
    const results = await metadataScraper.fetchAllMetadata(mediaIds)
    const successCount = Object.values(results).filter(r => r !== null).length
    console.log(`Finished fetching metadata. Success: ${successCount}/${mediaIds.length}`)
    return { success: true, results }
  } catch (error: unknown) {
    console.error("Error fetching metadata:", error)
    return { success: false, error: (error as Error).message }
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

// 清空媒体缓存
ipcMain.handle("clear-media-cache", async () => {
  try {
    await mediaDatabase.clearMediaCache();
    return { success: true };
  } catch (error: unknown) {
    console.error("Failed to clear media cache:", error);
    return { success: false, error: error instanceof Error ? error.message : String(error) };
  }
})

// 按路径搜索媒体
ipcMain.handle("search-media-by-path", async (_, searchTerm) => {
  try {
    console.log(`Searching media with path containing: "${searchTerm}"`);
    const results = await mediaDatabase.searchMediaByPath(searchTerm);
    return { 
      success: true, 
      results 
    };
  } catch (error: unknown) {
    console.error("Failed to search media by path:", error);
    return { 
      success: false, 
      error: error instanceof Error ? error.message : String(error) 
    };
  }
})

// 检查TMDB API密钥
ipcMain.handle("check-tmdb-api", async () => {
  try {
    const hasApiKey = metadataScraper.hasTmdbApiKey();
    return { 
      success: true, 
      hasApiKey 
    };
  } catch (error: unknown) {
    console.error("Failed to check TMDB API:", error);
    return { success: false, error: error instanceof Error ? error.message : String(error) };
  }
})

// 获取TMDB API密钥
ipcMain.handle("get-tmdb-api-key", async () => {
  try {
    const apiKey = metadataScraper.getTmdbApiKey();
    return { 
      success: true, 
      apiKey 
    };
  } catch (error: unknown) {
    console.error("Failed to get TMDB API key:", error);
    return { success: false, error: error instanceof Error ? error.message : String(error) };
  }
})

// 设置TMDB API密钥
ipcMain.handle("set-tmdb-api-key", async (_, apiKey) => {
  try {
    metadataScraper.setTmdbApiKey(apiKey);
    return { success: true };
  } catch (error: unknown) {
    console.error("Failed to set TMDB API key:", error);
    return { success: false, error: error instanceof Error ? error.message : String(error) };
  }
})

// 搜索媒体
ipcMain.handle("search-media", async (_, searchTerm) => {
  try {
    if (!searchTerm || typeof searchTerm !== "string" || searchTerm.trim() === "") {
      return { success: true, results: [] };
    }
    
    console.log(`搜索媒体: "${searchTerm}"`);
    const results = await mediaDatabase.comprehensiveSearch(searchTerm);
    
    return { 
      success: true, 
      results,
      count: results.length
    };
  } catch (error) {
    console.error("搜索媒体时出错:", error);
    return { 
      success: false, 
      error: error instanceof Error ? error.message : String(error),
      results: [] 
    };
  }
});
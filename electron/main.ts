import path from "path"
import { app, BrowserWindow, dialog, protocol } from "electron"
import { MediaDatabase } from "./media-database"
import { MediaPlayer } from "./media-player"
import { MetadataScraper } from "./metadata-scraper"
import { AutoScanManager } from "./auto-scan-manager"
import { HashService } from "./hash-service"
import * as fs from "fs"
// Using new abstraction layer
import { NetworkStorageClient } from "./network-storage-client"
import { MediaPlayerClient } from "./media-player-client"
import { defaultProviderFactory } from "./provider-factory"
import { MediaProxyServer } from "./media-proxy-server"
import { createProductionServer } from "./server"

// 初始化 MPV.js - 使用动态路径查找
let mpvPluginInitialized = false
try {
  // 动态查找 mpv.js 模块路径
  const mpvModulePath = require.resolve('mpv.js')
  const mpvDir = path.dirname(mpvModulePath)
  const buildDir = path.join(mpvDir, 'build')
  const releaseBuildDir = path.join(buildDir, 'Release')
  const mpvBinaryPath = path.join(releaseBuildDir, 'mpvjs.node')
  
  console.log('[MPV] Looking for MPV binary at:', mpvBinaryPath)
  
  // 确保二进制文件存在
  if (!fs.existsSync(mpvBinaryPath)) {
    console.log('[MPV] Binary not found, extracting from prebuilt package...')
    
    // 创建目录
    if (!fs.existsSync(releaseBuildDir)) {
      fs.mkdirSync(releaseBuildDir, { recursive: true })
    }
    
    // 提取预构建的二进制文件
    const { execSync } = require('child_process')
    
    // 根据平台选择正确的预构建包
    let prebuiltFile = ''
    if (process.platform === 'darwin') {
      prebuiltFile = 'mpv.js-v0.3.0-node-v42-darwin-x64.tar.gz'
    } else if (process.platform === 'win32') {
      prebuiltFile = process.arch === 'x64' ? 
        'mpv.js-v0.3.0-node-v42-win32-x64.tar.gz' : 
        'mpv.js-v0.3.0-node-v42-win32-ia32.tar.gz'
    } else {
      prebuiltFile = 'mpv.js-v0.3.0-node-v42-linux-x64.tar.gz'
    }
    
    const prebuiltPath = path.join(mpvDir, 'prebuilds', prebuiltFile)
    
    if (fs.existsSync(prebuiltPath)) {
      try {
        execSync(`cd "${mpvDir}" && tar -xzf "${prebuiltPath}"`, { stdio: 'pipe' })
        console.log('[MPV] Successfully extracted prebuilt binary')
      } catch (extractError) {
        console.warn('[MPV] Failed to extract prebuilt binary:', extractError)
        throw extractError
      }
    } else {
      throw new Error(`Prebuilt binary not found: ${prebuiltPath}`)
    }
  }

  const { getPluginEntry } = require('mpv.js')
  
  // 注册 pepper 插件
  app.commandLine.appendSwitch('register-pepper-plugins', getPluginEntry(buildDir))
  
  // 允许运行不安全的内容 (PPAPI 插件需要)
  app.commandLine.appendSwitch('allow-running-insecure-content')
  
  // 禁用网络安全策略，以支持本地插件
  app.commandLine.appendSwitch('disable-web-security')
  
  // 启用插件支持
  app.commandLine.appendSwitch('enable-plugins')
  
  console.log('[MPV] MPV.js plugin registered successfully')
  mpvPluginInitialized = true
} catch (error) {
  console.error('[MPV] Failed to initialize MPV.js plugin:', error)
  mpvPluginInitialized = false
}

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
// Using new abstraction layer
let networkStorageClient: NetworkStorageClient
let mediaPlayerClient: MediaPlayerClient
let metadataScraper: MetadataScraper
let mediaDatabase: MediaDatabase
let mediaPlayer: MediaPlayer
let mediaProxyServer: MediaProxyServer
let autoScanManager: AutoScanManager
let hashService: HashService
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
      webSecurity: false, // 允许加载本地文件和MPV插件
      plugins: true, // 启用插件支持 (PPAPI)
      experimentalFeatures: true, // 启用实验性功能
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
    // 尝试多个可能的端口
    const possiblePorts = [5173, 5174, 3000]
    let serverUrl = "http://localhost:5173"
    
    // 检查哪个端口可用
    for (const port of possiblePorts) {
      try {
        const testUrl = `http://localhost:${port}`
        console.log(`Testing development server at: ${testUrl}`)
        // 这里我们将默认使用5173，如果不可用concurrently会使用其他端口
        serverUrl = testUrl
        break
      } catch (error) {
        console.log(`Port ${port} not available`)
      }
    }
    
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

    // Initialize network storage client with default provider factory
    networkStorageClient = new NetworkStorageClient(defaultProviderFactory)
    
    // Set SMB as the default provider
    networkStorageClient.setProvider('smb')
    
    // Initialize media player client
    mediaPlayerClient = new MediaPlayerClient()
    
    // Set MPV as the default media player provider
    try {
      mediaPlayerClient.setProvider('mpv')
    } catch (error) {
      console.warn('MPV provider not available, using system default')
      mediaPlayerClient.setProvider('system')
    }

    // 初始化海报抓取器，使用TMDB API密钥
    // 首先尝试从数据库获取TMDB API密钥
    let tmdbApiKey = await mediaDatabase.getTmdbApiKey()
    
    // 如果数据库中没有，尝试从.env.local文件读取
    if (!tmdbApiKey) {
      try {
        const envPath = path.join(process.cwd(), '.env.local')
        if (fs.existsSync(envPath)) {
          const envContent = fs.readFileSync(envPath, 'utf8')
          const matches = envContent.match(/VITE_TMDB_API_KEY=(.+)/)
          if (matches && matches[1]) {
            tmdbApiKey = matches[1].trim()
            console.log(`Found TMDB API key in .env.local: ${tmdbApiKey.substring(0, 5)}...`)
            // 保存到数据库以便下次使用
            await mediaDatabase.saveTmdbApiKey(tmdbApiKey)
          } else {
            console.log('TMDB API key not found in .env.local')
          }
        } else {
          console.log('.env.local file not found')
        }
      } catch (error) {
        console.error('Error reading TMDB API key:', error)
      }
    }

    // 尝试从环境变量获取
    if (!tmdbApiKey) {
      const envApiKey = process.env.VITE_TMDB_API_KEY || process.env.TMDB_API_KEY
      if (envApiKey) {
        tmdbApiKey = envApiKey
        console.log(`Using TMDB API key from environment: found`)
        // 保存到数据库以便下次使用
        await mediaDatabase.saveTmdbApiKey(tmdbApiKey)
      } else {
        console.log(`Using TMDB API key from environment: not found`)
      }
    }

    // 设置Gemini API密钥
    const geminiApiKey = process.env.VITE_GEMINI_API_KEY || process.env.GEMINI_API_KEY
    
    metadataScraper = new MetadataScraper(mediaDatabase, tmdbApiKey || undefined, geminiApiKey)
    
    // 初始化自动扫描管理器
    autoScanManager = new AutoScanManager(networkStorageClient, mediaDatabase, metadataScraper)

    // 初始化Hash服务
    hashService = new HashService(mediaDatabase)

    // 初始化媒体播放器
    mediaPlayer = new MediaPlayer()

    // 初始化媒体代理服务器
    mediaProxyServer = new MediaProxyServer(networkStorageClient)
    try {
      const proxyPort = await mediaProxyServer.start()
      console.log(`Media proxy server started on port ${proxyPort}`)
    } catch (error) {
      console.error("Failed to start media proxy server:", error)
    }

    // 从数据库加载配置
    const config = await mediaDatabase.getConfig()
    if (config) {
      // 检查配置是否完整
      if (config.host && config.host.trim() !== "" && config.sharePath && config.sharePath.trim() !== "") {
        console.log("Configuration loaded, applying to Go SMB client")
        networkStorageClient.configure(config)
        // 设置自动扫描管理器的共享路径
        if (config.sharePath) {
          autoScanManager.setSharePath(config.sharePath)
        }
        
        // 设置自动扫描管理器的选定文件夹
        if (config.selectedFolders) {
          autoScanManager.setSelectedFolders(config.selectedFolders)
        }
        
        // 设置Hash服务
        autoScanManager.setHashService(hashService)
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

// 初始化IPC处理器
async function initializeIPCHandlers() {
  const { initializeIPCHandlers } = await import('./ipc-handlers')
  
  initializeIPCHandlers({
    mediaDatabase,
    mediaPlayer,
    metadataScraper,
    networkStorageClient,
    mediaPlayerClient,
    mediaProxyServer,
    autoScanManager,
    mainWindow
  })
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
  initializeApp().then(() => {
    // 初始化应用后再设置IPC处理器
    initializeIPCHandlers()
  })

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

// 应用退出前清理资源
app.on("before-quit", async () => {
  try {
    // 停止代理服务器
    if (mediaProxyServer) {
      await mediaProxyServer.stop()
    }
    
    // 停止生产服务器
    if (productionServer) {
      productionServer.close?.()
    }
    
    // 断开Go SMB连接
    if (networkStorageClient) {
      networkStorageClient.disconnect()
    }
  } catch (error) {
    console.error("Error during cleanup:", error)
  }
})



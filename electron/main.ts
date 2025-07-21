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

// Initialize MPV.js - using dynamic path discovery
let mpvPluginInitialized = false
try {
  // Dynamically locate mpv.js module path
  const mpvModulePath = require.resolve('mpv.js')
  const mpvDir = path.dirname(mpvModulePath)
  const buildDir = path.join(mpvDir, 'build')
  const releaseBuildDir = path.join(buildDir, 'Release')
  const mpvBinaryPath = path.join(releaseBuildDir, 'mpvjs.node')
  
  console.log('[MPV] Looking for MPV binary at:', mpvBinaryPath)
  
  // Ensure binary file exists
  if (!fs.existsSync(mpvBinaryPath)) {
    console.log('[MPV] Binary not found, extracting from prebuilt package...')
    
    // Create directory
    if (!fs.existsSync(releaseBuildDir)) {
      fs.mkdirSync(releaseBuildDir, { recursive: true })
    }
    
    // Extract prebuilt binary file
    const { execSync } = require('child_process')
    
    // Select correct prebuilt package based on platform
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
  
  // Register pepper plugin
  app.commandLine.appendSwitch('register-pepper-plugins', getPluginEntry(buildDir))
  
  // Allow running insecure content (required for PPAPI plugins)
  app.commandLine.appendSwitch('allow-running-insecure-content')
  
  // Disable web security policy to support local plugins
  app.commandLine.appendSwitch('disable-web-security')
  
  // Enable plugin support
  app.commandLine.appendSwitch('enable-plugins')
  
  console.log('[MPV] MPV.js plugin registered successfully')
  mpvPluginInitialized = true
} catch (error) {
  console.error('[MPV] Failed to initialize MPV.js plugin:', error)
  mpvPluginInitialized = false
}

// Suppress IMK-related warnings on macOS
if (process.platform === 'darwin') {
  process.env.IMK_DISABLE_WAKEUP_RELIABLE = '1'
  // Disabling hardware acceleration can fix certain rendering issues on macOS
  if (process.platform === 'darwin') {
    app.disableHardwareAcceleration()
  }
}

// Global variables
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

// Create main window
function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1200,
    height: 800,
    webPreferences: {
      nodeIntegration: false,
      contextIsolation: true,
      preload: path.join(__dirname, 'preload.js'),
      webSecurity: false, // Allow loading local files and MPV plugins
      plugins: true, // Enable plugin support (PPAPI)
      experimentalFeatures: true, // Enable experimental features
    },
    // Set window icon - use correct icon path based on platform
    icon: process.platform === 'darwin' 
      ? path.join(__dirname, "../public/app-icons/mac/icon.icns") 
      : process.platform === 'win32'
        ? path.join(__dirname, "../public/app-icons/win/icon.ico")
        : path.join(__dirname, "../public/app-icons/linux/512x512.png"),
  })

  // Show window only after it's ready to avoid flashing
  mainWindow.once('ready-to-show', () => {
    mainWindow?.show()
  })

  // Load local server in development mode
  const isDev = process.env.NODE_ENV === "development"
  console.log(`Running in ${isDev ? "development" : "production"} mode`)
  
  if (isDev) {
    // Try multiple possible ports
    const possiblePorts = [5173, 5174, 3000]
    let serverUrl = "http://localhost:5173"
    
    // Check which port is available
    for (const port of possiblePorts) {
      try {
        const testUrl = `http://localhost:${port}`
        console.log(`Testing development server at: ${testUrl}`)
        // We'll default to 5173, if unavailable concurrently will use other ports
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
    // Start Hono server in production mode
    try {
      const server = createProductionServer(3000)
      productionServer = server.start()
      const serverUrl = "http://localhost:3000"
      console.log(`Started production server at: ${serverUrl}`)
      mainWindow.loadURL(serverUrl)
      // Also open dev tools in production mode for debugging convenience
      // mainWindow.webContents.openDevTools()
    } catch (error) {
      console.error('Failed to start production server:', error)
      // Fallback to file protocol
      const filePath = path.join(__dirname, "../renderer/index.html")
      console.log(`Fallback to file protocol: ${filePath}`)
      const fileUrl = `file://${filePath}`
      mainWindow.loadURL(fileUrl)
      mainWindow.webContents.openDevTools()
    }
  }

  // Clear reference when window is closed
  mainWindow.on("closed", () => {
    mainWindow = null
  })
}

// Application initialization
async function initializeApp() {
  try {
    // Initialize database
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
            // Save to database for next use
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
        // Save to database for next use
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



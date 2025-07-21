/**
 * Implementation of all IPC handlers
 * Using type-safe IPC architecture
 */

import { dialog } from 'electron'
import * as fs from 'fs'
import * as path from 'path'
import { MediaDatabase } from './media-database'
import { MediaPlayer } from './media-player'
import { MetadataScraper } from './metadata-scraper'
import { AutoScanManager } from './auto-scan-manager'
// Using new abstraction layer
import { NetworkStorageClient } from './network-storage-client'
import { MediaPlayerClient } from './media-player-client'
import { defaultProviderFactory } from './provider-factory'
import { registerIPCHandler } from './ipc-handler'
import { IPCChannels } from './ipc-channels'

/**
 * Initialize all IPC handlers
 * @param services Application services
 */
export function initializeIPCHandlers(services: {
  mediaDatabase: MediaDatabase
  mediaPlayer: MediaPlayer
  metadataScraper: MetadataScraper
  autoScanManager: AutoScanManager
  networkStorageClient: NetworkStorageClient
  mediaPlayerClient: MediaPlayerClient
  mainWindow: Electron.BrowserWindow | null
}) {
  const {
    mediaDatabase,
    mediaPlayer,
    metadataScraper,
    autoScanManager,
    networkStorageClient,
    mediaPlayerClient,
    mainWindow
  } = services

  // 配置相关处理器
  registerIPCHandler(IPCChannels.GET_CONFIG, async () => {
    return await mediaDatabase.getConfig()
  })

  registerIPCHandler(IPCChannels.SAVE_CONFIG, async (_, config) => {
    try {
      await mediaDatabase.saveConfig(config)
      networkStorageClient.configure(config)
      
      // 设置自动扫描管理器的共享路径
      if (config.sharePath) {
        autoScanManager.setSharePath(config.sharePath)
      }
      
      // 设置选定的文件夹列表（如果有）
      if (config.selectedFolders && config.selectedFolders.length > 0) {
        autoScanManager.setSelectedFolders(config.selectedFolders)
      }
      
      // 如果配置完整（有IP和共享路径），自动触发扫描
      if (config.host && config.host.trim() !== "" && 
          config.sharePath && config.sharePath.trim() !== "") {
        console.log("[SAVE_CONFIG] Configuration complete, triggering auto scan...")
        
        // 异步触发自动扫描（不等待完成）
        autoScanManager.startAutoScan().then((result) => {
          console.log("[SAVE_CONFIG] Auto scan started:", result)
        }).catch((error) => {
          console.error("[SAVE_CONFIG] Failed to start auto scan:", error)
        })
      }
      
      return { success: true }
    } catch (error: unknown) {
      console.error("Failed to save config:", error)
      return { success: false, error: error instanceof Error ? error.message : String(error) }
    }
  })

  registerIPCHandler(IPCChannels.GET_TMDB_API_KEY, async () => {
    try {
      // 从数据库获取API密钥
      const apiKey = await mediaDatabase.getTmdbApiKey()
      return { 
        success: true, 
        data: { apiKey: apiKey || "" }
      }
    } catch (error: unknown) {
      console.error("Failed to get TMDB API key:", error)
      return { success: false, error: error instanceof Error ? error.message : String(error) }
    }
  })

  registerIPCHandler(IPCChannels.SET_TMDB_API_KEY, async (_, apiKey) => {
    try {
      console.log(`[SET_TMDB_API_KEY] Attempting to save API key: ${apiKey.substring(0, 5)}...`)
      
      // 保存到数据库
      await mediaDatabase.saveTmdbApiKey(apiKey)
      console.log(`[SET_TMDB_API_KEY] Successfully saved to database`)
      
      // 同时设置到MetadataScraper中
      metadataScraper.setTmdbApiKey(apiKey)
      console.log(`[SET_TMDB_API_KEY] Successfully set in MetadataScraper`)
      
      return { success: true }
    } catch (error: unknown) {
      console.error("[SET_TMDB_API_KEY] Failed to set TMDB API key:", error)
      return { success: false, error: error instanceof Error ? error.message : String(error) }
    }
  })

  registerIPCHandler(IPCChannels.CHECK_TMDB_API, async () => {
    try {
      const hasApiKey = metadataScraper.hasTmdbApiKey()
      return { 
        success: true, 
        data: { hasApiKey }
      }
    } catch (error: unknown) {
      console.error("Failed to check TMDB API:", error)
      return { success: false, error: error instanceof Error ? error.message : String(error) }
    }
  })

  // 网络存储发现处理器
  registerIPCHandler(IPCChannels.GO_DISCOVER, async (_, serverConfig) => {
    try {
      console.log('使用网络存储客户端发现共享...')
      
      // 设置SMB提供者（默认）
      if (!networkStorageClient.getCurrentProviderType()) {
        networkStorageClient.setProvider('smb')
      }
      
      networkStorageClient.configure(serverConfig)
      
      // 检查提供者是否可用
      if (!networkStorageClient.isProviderAvailable()) {
        const systemInfo = await networkStorageClient.getSystemInfo()
        return {
          success: false,
          error: "网络存储提供者不可用",
          errorType: "provider_not_available",
          systemInfo: systemInfo
        }
      }
      
      // 首先测试连接
      const isConnected = await networkStorageClient.testConnection()
      if (!isConnected) {
        return {
          success: false,
          error: "无法连接到服务器",
          errorType: "connection_failed"
        }
      }
      
      // 发现共享
      const shares = await networkStorageClient.discoverShares()
      
      console.log(`发现了 ${shares.length} 个共享:`, shares.map(s => s.name))
      
      return {
        success: true,
        shares: shares.map(share => share.name),
        shareDetails: shares
      }
    } catch (error: any) {
      console.error('网络存储发现失败:', error)
      return {
        success: false,
        error: error.message,
        errorType: "discovery_failed"
      }
    }
  })

  // 服务器连接相关处理器
  registerIPCHandler(IPCChannels.CONNECT_SERVER, async (_, serverConfig) => {
    try {
      // 验证必要的配置
      if (!serverConfig.host || serverConfig.host.trim() === "") {
        return { 
          success: false, 
          error: "服务器IP必须指定",
          errorType: "invalid_config" 
        }
      }
      
      console.log(`使用网络存储客户端连接到服务器 ${serverConfig.host}`)
      
      // 设置提供者（如果未设置）
      if (!networkStorageClient.getCurrentProviderType()) {
        networkStorageClient.setProvider('smb')
      }
      
      // 配置网络存储客户端
      networkStorageClient.configure(serverConfig)
      
      // 检查提供者可用性
      if (!networkStorageClient.isProviderAvailable()) {
        const systemInfo = await networkStorageClient.getSystemInfo()
        return {
          success: false,
          error: "网络存储提供者不可用",
          errorType: "provider_not_available",
          systemInfo
        }
      }
      
      // 首先测试连接
      const isConnected = await networkStorageClient.testConnection()
      if (!isConnected) {
        return {
          success: false,
          error: "无法连接到服务器",
          errorType: "connection_failed"
        }
      }
      
      // 发现共享
      const shares = await networkStorageClient.discoverShares()
      
      console.log(`发现了 ${shares.length} 个共享:`, shares.map(s => s.name))
      
      return {
        success: true,
        shares: shares.map(share => share.name),
        shareDetails: shares
      }
    } catch (error: any) {
      console.error('网络存储连接失败:', error)
      return {
        success: false,
        error: error.message,
        errorType: "connection_failed"
      }
    }
  })

  registerIPCHandler(IPCChannels.LIST_SHARES, async () => {
    try {
      const shares = await networkStorageClient.discoverShares()
      // Format shares to match expected structure
      const shareNames = shares.map(share => share.name)
      return { success: true, data: { shares: shareNames } }
    } catch (error: unknown) {
      console.error("Failed to list shares:", error)
      return { success: false, error: error instanceof Error ? error.message : String(error) }
    }
  })

  registerIPCHandler(IPCChannels.LIST_FOLDERS, async (_, shareName) => {
    try {
      // Parse the path to get share and directory
      const pathParts = shareName.split('/').filter(Boolean)
      if (pathParts.length === 0) {
        throw new Error("Invalid path")
      }
      
      const shareNameOnly = pathParts[0]
      const directory = pathParts.length > 1 ? '/' + pathParts.slice(1).join('/') : '/'
      
      console.log(`Listing folders in share: "${shareNameOnly}", directory: "${directory}"`)
      
      // Use network storage client to list directory contents
      const items = await networkStorageClient.listDirectory(shareNameOnly, directory)
      
      // Filter only directories
      const folders = items.filter(item => item.isDirectory).map(item => item.name)
      
      return { success: true, data: { folders } }
    } catch (error: unknown) {
      console.error(`Failed to list folders in ${shareName}:`, error)
      return { 
        success: false, 
        error: error instanceof Error ? error.message : String(error),
        errorType: error instanceof Error && 'code' in error ? (error as any).code : 'unknown'
      }
    }
  })

  registerIPCHandler(IPCChannels.GET_DIR_CONTENTS, async (_, dirPath) => {
    try {
      console.log(`Getting directory contents for: "${dirPath}"`)
      
      if (dirPath === "/") {
        // Root path - show all available shares
        const result = await networkStorageClient.discoverShares()
        const shareItems = result.map(share => ({
          name: share.name,
          isDirectory: true,
          size: undefined,
          modifiedTime: undefined
        }))
        
        return { 
          success: true, 
          items: shareItems
        }
      } else {
        // Parse the path to extract share and directory
        const pathParts = dirPath.split('/').filter(Boolean)
        if (pathParts.length === 0) {
          throw new Error("Invalid path")
        }
        
        const shareName = pathParts[0]
        const directory = pathParts.length > 1 ? '/' + pathParts.slice(1).join('/') : '/'
        
        console.log(`Listing directory: share="${shareName}", directory="${directory}"`)
        
        // Use network storage client to list directory contents
        const items = await networkStorageClient.listDirectory(shareName, directory)
        
        // Convert GoDirectoryItem to FileItem format
        const fileItems = items.map(item => ({
          name: item.name,
          isDirectory: item.isDirectory,
          size: item.size,
          modifiedTime: item.modifiedTime
        }))
        
        return { 
          success: true, 
          items: fileItems
        }
      }
    } catch (error: unknown) {
      console.error(`Failed to get contents of directory ${dirPath}:`, error)
      return { 
        success: false, 
        error: error instanceof Error ? error.message : String(error),
        errorType: error instanceof Error && 'code' in error ? (error as any).code : 'unknown'
      }
    }
  })

  // 通用网络文件浏览器处理器
  registerIPCHandler(IPCChannels.GET_NETWORK_DIR_CONTENTS, async (_, request) => {
    try {
      const { path: dirPath, storageType = 'smb' } = request
      console.log(`Getting network directory contents for: "${dirPath}" using ${storageType}`)
      
      // 设置或切换存储类型
      if (networkStorageClient.getCurrentProviderType() !== storageType) {
        networkStorageClient.setProvider(storageType)
        
        // 重新配置（使用当前配置）
        const currentConfig = await mediaDatabase.getConfig()
        if (currentConfig) {
          networkStorageClient.configure(currentConfig)
        }
      }
      
      if (dirPath === "/") {
        // Root path - show all available shares
        const result = await networkStorageClient.discoverShares()
        const shareItems = result.map(share => ({
          name: share.name,
          isDirectory: true,
          size: undefined,
          modifiedTime: undefined
        }))
        
        return { 
          success: true, 
          items: shareItems
        }
      } else {
        // Parse the path to extract share and directory
        const pathParts = dirPath.split('/').filter(Boolean)
        if (pathParts.length === 0) {
          throw new Error("Invalid path")
        }
        
        const shareName = pathParts[0]
        const directory = pathParts.length > 1 ? '/' + pathParts.slice(1).join('/') : '/'
        
        console.log(`Listing directory: share="${shareName}", directory="${directory}", type="${storageType}"`)
        
        // Use network storage client to list directory contents
        const items = await networkStorageClient.listDirectory(shareName, directory)
        
        // Convert to expected format
        const fileItems = items.map(item => ({
          name: item.name,
          isDirectory: item.isDirectory,
          size: item.size,
          modifiedTime: item.modifiedTime
        }))
        
        return { 
          success: true, 
          items: fileItems
        }
      }
    } catch (error: unknown) {
      console.error(`Failed to get network contents of directory ${request.path}:`, error)
      return { 
        success: false, 
        error: error instanceof Error ? error.message : String(error),
        errorType: error instanceof Error && 'code' in error ? (error as any).code : 'unknown'
      }
    }
  })

  registerIPCHandler(IPCChannels.ADD_SINGLE_NETWORK_MEDIA, async (_, request) => {
    try {
      const { filePath, storageType = 'smb' } = request
      
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
        storageType: storageType // 记录存储类型
      }
      
      // 保存到数据库
      await mediaDatabase.saveMedia(mediaRecord)
      
      return { 
        success: true, 
        data: { media: mediaRecord }
      }
    } catch (error: unknown) {
      console.error("Failed to add single network media file:", error)
      return { 
        success: false, 
        error: error instanceof Error ? error.message : String(error) 
      }
    }
  })

  // 媒体相关处理器
  registerIPCHandler(IPCChannels.GET_MEDIA, async (_, type) => {
    try {
      if (type === "all") {
        const movies = await mediaDatabase.getMediaByType("movie")
        const tvShows = await mediaDatabase.getMediaByType("tv")
        const unknown = await mediaDatabase.getMediaByType("unknown")
        const allMedia = [...movies, ...tvShows, ...unknown]
        console.log(`Retrieved ${allMedia.length} total media items (${movies.length} movies, ${tvShows.length} TV shows, ${unknown.length} unknown)`)
        return allMedia
      } else {
        const validTypes = ["movie", "tv", "unknown"] as const
        const mediaType = validTypes.includes(type as any) ? type as "movie" | "tv" | "unknown" : "movie"
        const media = await mediaDatabase.getMediaByType(mediaType)
        console.log(`Retrieved ${media.length} ${mediaType} media items`)
        return media
      }
    } catch (error) {
      console.error(`Error getting ${type} media:`, error)
      return []
    }
  })

  registerIPCHandler(IPCChannels.GET_MEDIA_BY_ID, async (_, id) => {
    try {
      console.log(`获取媒体ID: ${id} 的详细信息`)
      const media = await mediaDatabase.getMediaById(id)
      if (media) {
        console.log(`成功获取媒体: ${media.title}, 海报路径: ${media.posterPath || '无'}`)
      } else {
        console.log(`未找到ID为 ${id} 的媒体`)
      }
      return media
    } catch (error) {
      console.error(`Error getting media with ID ${id}:`, error)
      return null
    }
  })

  registerIPCHandler(IPCChannels.GET_MEDIA_DETAILS, async (_, mediaId) => {
    try {
      console.log(`Getting details for media ID: ${mediaId}`)
      const media = await mediaDatabase.getMediaById(mediaId)
      if (!media) {
        console.error(`Media not found: ${mediaId}`)
        return null
      }
      
      // 确保 posterPath 存在且可访问
      if (media.posterPath && fs.existsSync(media.posterPath)) {
        // 将本地文件路径转换为 file:// 协议
        media.posterPath = `file://${media.posterPath}`
      }
      
      return media
    } catch (error: unknown) {
      console.error("Failed to get media details:", error)
      return null
    }
  })

  registerIPCHandler(IPCChannels.GET_RECENTLY_VIEWED, async () => {
    try {
      // 获取最近观看的媒体（可以按最后观看时间排序）
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

  registerIPCHandler(IPCChannels.SCAN_MEDIA, async (_, request) => {
    try {
      const { type, useCached = true } = request
      
      if (!networkStorageClient) {
        return { 
          success: false, 
          error: "Network storage client is not initialized" 
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
      
      // 确认AutoScanManager已正确配置
      autoScanManager.setSharePath(config.sharePath)
      if (config.selectedFolders && config.selectedFolders.length > 0) {
        autoScanManager.setSelectedFolders(config.selectedFolders)
      }
      
      let result = { count: 0, movies: 0, tvShows: 0 }
      
      // 如果使用缓存，先检查数据库中是否有指定类型的媒体
      if (useCached) {
        if (type === "movie") {
          const cachedMovies = await mediaDatabase.getMediaByType("movie")
          if (cachedMovies && cachedMovies.length > 0) {
            console.log(`Using cached data: ${cachedMovies.length} movies`)
            return { 
              success: true, 
              data: {
                count: cachedMovies.length,
                movieCount: cachedMovies.length 
              }
            }
          }
        } else if (type === "tv") {
          const cachedTvShows = await mediaDatabase.getMediaByType("tv")
          if (cachedTvShows && cachedTvShows.length > 0) {
            console.log(`Using cached data: ${cachedTvShows.length} TV shows`)
            return { 
              success: true, 
              data: {
                count: cachedTvShows.length,
                tvCount: cachedTvShows.length 
              }
            }
          }
        } else if (!type || type === "all") {
          const cachedMovies = await mediaDatabase.getMediaByType("movie")
          const cachedTvShows = await mediaDatabase.getMediaByType("tv")
          
          if ((cachedMovies && cachedMovies.length > 0) || 
              (cachedTvShows && cachedTvShows.length > 0)) {
            console.log(`Using cached data: ${cachedMovies.length} movies, ${cachedTvShows.length} TV shows`)
            return { 
              success: true, 
              data: {
                count: cachedMovies.length + cachedTvShows.length,
                movieCount: cachedMovies.length,
                tvCount: cachedTvShows.length 
              }
            }
          }
        }
        
        console.log("No cached data found, performing full scan")
      } else {
        console.log("Cache disabled, performing full scan")
      }
      
      // 使用新的自动扫描管理器进行扫描
      console.log("Starting manual scan using AutoScanManager...")
      const scanResult = await autoScanManager.startAutoScan(true) // force=true for manual scans
      
      if (!scanResult.started) {
        throw new Error(scanResult.message || "Failed to start scan")
      }
      
      // 等待扫描完成（简化版，实际应用中可以通过事件监听）
      await new Promise(resolve => {
        const checkComplete = () => {
          const status = autoScanManager.getStatus()
          if (!status.isScanning) {
            resolve(true)
          } else {
            setTimeout(checkComplete, 1000)
          }
        }
        setTimeout(checkComplete, 1000)
      })
      
      // 获取扫描结果
      const movies = await mediaDatabase.getMediaByType("movie")
      const tvShows = await mediaDatabase.getMediaByType("tv")
      
      result = {
        count: movies.length + tvShows.length,
        movies: movies.length,
        tvShows: tvShows.length
      }
      
      // 完成后重新返回所有媒体数据，以便更新UI
      return { 
        success: true,
        data: result
      }
    } catch (error: unknown) {
      console.error("Failed to scan media:", error)
      return { 
        success: false, 
        error: error instanceof Error ? error.message : String(error),
        data: { count: 0 }
      }
    }
  })

  registerIPCHandler(IPCChannels.ADD_SINGLE_MEDIA, async (_, filePath) => {
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
        data: { media: mediaRecord }
      }
    } catch (error: unknown) {
      console.error("Failed to add single media file:", error)
      return { 
        success: false, 
        error: error instanceof Error ? error.message : String(error) 
      }
    }
  })

  registerIPCHandler(IPCChannels.SEARCH_MEDIA, async (_, searchTerm) => {
    try {
      if (!searchTerm || typeof searchTerm !== "string" || searchTerm.trim() === "") {
        return { success: true, data: { results: [], count: 0 } }
      }
      
      console.log(`搜索媒体: "${searchTerm}"`)
      const results = await mediaDatabase.comprehensiveSearch(searchTerm)
      
      return { 
        success: true, 
        data: {
          results,
          count: results.length
        }
      }
    } catch (error) {
      console.error("搜索媒体时出错:", error)
      return { 
        success: false, 
        error: error instanceof Error ? error.message : String(error),
        data: { results: [], count: 0 }
      }
    }
  })

  registerIPCHandler(IPCChannels.SEARCH_MEDIA_BY_PATH, async (_, searchTerm) => {
    try {
      console.log(`Searching media with path containing: "${searchTerm}"`)
      const results = await mediaDatabase.searchMediaByPath(searchTerm)
      return { 
        success: true, 
        data: { results }
      }
    } catch (error: unknown) {
      console.error("Failed to search media by path:", error)
      return { 
        success: false, 
        error: error instanceof Error ? error.message : String(error) 
      }
    }
  })

  registerIPCHandler(IPCChannels.CLEAR_MEDIA_CACHE, async () => {
    try {
      await mediaDatabase.clearMediaCache()
      return { success: true }
    } catch (error: unknown) {
      console.error("Failed to clear media cache:", error)
      return { success: false, error: error instanceof Error ? error.message : String(error) }
    }
  })

  // 元数据相关处理器
  registerIPCHandler(IPCChannels.FETCH_POSTERS, async (_, mediaIds) => {
    try {
      console.log(`Fetching metadata for ${mediaIds.length} media items`)
      if (!metadataScraper.hasTmdbApiKey()) {
        console.error("No TMDB API key available for metadata scraper")
      }
      const results = await metadataScraper.batchScrapeMetadata(mediaIds)
      const successCount = results.filter(r => r.success).length
      console.log(`Finished fetching metadata. Success: ${successCount}/${mediaIds.length}`)
      return { success: true, data: { results } }
    } catch (error: unknown) {
      console.error("Error fetching metadata:", error)
      return { success: false, error: (error as Error).message }
    }
  })

  // 文件系统相关处理器
  registerIPCHandler(IPCChannels.SELECT_FOLDER, async () => {
    if (!mainWindow) return { canceled: true }

    const result = await dialog.showOpenDialog(mainWindow, {
      properties: ["openDirectory"],
    })

    return result
  })

  // MPV 可用性检查
  registerIPCHandler(IPCChannels.CHECK_MPV_AVAILABILITY, async () => {
    try {
      // 检查 mpv.js 模块是否可用
      const mpvModule = require('mpv.js')
      if (!mpvModule || !mpvModule.ReactMPV) {
        return {
          success: true,
          data: {
            available: false,
            reason: 'mpv.js module not found or ReactMPV component unavailable'
          }
        }
      }

      // mpv.js 包含了预构建的二进制文件，不需要系统安装
      console.log('[MPV] mpv.js is available with bundled binaries')
      return {
        success: true,
        data: {
          available: true,
          reason: 'MPV is available with bundled binaries (mpv.js)'
        }
      }
    } catch (error: unknown) {
      console.error('[MPV] Error checking MPV availability:', error)
      return {
        success: true,
        data: {
          available: false,
          reason: error instanceof Error ? error.message : 'Unknown error checking MPV availability'
        }
      }
    }
  })

  // 自动扫描相关处理器
  registerIPCHandler(IPCChannels.START_AUTO_SCAN, async (_, options) => {
    try {
      const { force = false } = options || {}
      console.log(`[AUTO_SCAN] Starting auto scan (force: ${force})`)
      
      const result = await autoScanManager.startAutoScan(force)
      return { 
        success: true, 
        data: result
      }
    } catch (error: unknown) {
      console.error("[AUTO_SCAN] Failed to start auto scan:", error)
      return { 
        success: false, 
        error: error instanceof Error ? error.message : String(error)
      }
    }
  })

  registerIPCHandler(IPCChannels.STOP_AUTO_SCAN, async () => {
    try {
      console.log(`[AUTO_SCAN] Stopping auto scan`)
      
      const result = await autoScanManager.stopAutoScan()
      return { 
        success: true, 
        data: result
      }
    } catch (error: unknown) {
      console.error("[AUTO_SCAN] Failed to stop auto scan:", error)
      return { 
        success: false, 
        error: error instanceof Error ? error.message : String(error)
      }
    }
  })

  registerIPCHandler(IPCChannels.GET_SCAN_STATUS, async () => {
    try {
      const status = autoScanManager.getStatus()
      return { 
        success: true, 
        data: status
      }
    } catch (error: unknown) {
      console.error("[AUTO_SCAN] Failed to get scan status:", error)
      return { 
        success: false, 
        error: error instanceof Error ? error.message : String(error)
      }
    }
  })

  registerIPCHandler(IPCChannels.GET_SCAN_PROGRESS, async () => {
    try {
      const status = autoScanManager.getStatus()
      return { 
        success: true, 
        data: {
          scanProgress: status.scanProgress || {
            phase: 'idle',
            current: 0,
            total: 0
          },
          scrapeProgress: status.scrapeProgress || {
            phase: 'idle',
            current: 0,
            total: 0
          }
        }
      }
    } catch (error: unknown) {
      console.error("[AUTO_SCAN] Failed to get scan progress:", error)
      return { 
        success: false, 
        error: error instanceof Error ? error.message : String(error)
      }
    }
  })

  // 设置自动扫描管理器的事件监听器来推送状态更新到前端
  autoScanManager.on('status:update', (status) => {
    if (mainWindow && !mainWindow.isDestroyed()) {
      mainWindow.webContents.send(IPCChannels.SCAN_PROGRESS_UPDATE, status)
    }
  })

  autoScanManager.on('scan:completed', (result) => {
    if (mainWindow && !mainWindow.isDestroyed()) {
      mainWindow.webContents.send(IPCChannels.SCAN_COMPLETED, result)
    }
  })

  autoScanManager.on('scan:error', (error) => {
    if (mainWindow && !mainWindow.isDestroyed()) {
      mainWindow.webContents.send(IPCChannels.SCAN_ERROR, error)
    }
  })

  console.log('[IPC] All handlers initialized successfully')
}
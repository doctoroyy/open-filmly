/**
 * 所有IPC处理器的实现
 * 使用类型安全的IPC架构
 */

import { dialog } from 'electron'
import * as fs from 'fs'
import * as path from 'path'
import { MediaDatabase } from './media-database'
import { MediaScanner } from './media-scanner'
import { MediaPlayer } from './media-player'
import { MetadataScraper } from './metadata-scraper'
import { SambaClient } from './smb-client'
import { MediaProxyServer } from './media-proxy-server'
import { registerIPCHandler } from './ipc-handler'
import { IPCChannels } from './ipc-channels'

/**
 * 初始化所有IPC处理器
 * @param services 应用程序服务
 */
export function initializeIPCHandlers(services: {
  mediaDatabase: MediaDatabase
  mediaScanner: MediaScanner
  mediaPlayer: MediaPlayer
  metadataScraper: MetadataScraper
  sambaClient: SambaClient
  mediaProxyServer: MediaProxyServer
  mainWindow: Electron.BrowserWindow | null
}) {
  const {
    mediaDatabase,
    mediaScanner,
    mediaPlayer,
    metadataScraper,
    sambaClient,
    mediaProxyServer,
    mainWindow
  } = services

  // 配置相关处理器
  registerIPCHandler(IPCChannels.GET_CONFIG, async () => {
    return await mediaDatabase.getConfig()
  })

  registerIPCHandler(IPCChannels.SAVE_CONFIG, async (_, config) => {
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

  // 服务器连接相关处理器
  registerIPCHandler(IPCChannels.CONNECT_SERVER, async (_, serverConfig) => {
    try {
      // 验证必要的配置
      if (!serverConfig.ip || serverConfig.ip.trim() === "") {
        return { 
          success: false, 
          error: "服务器IP必须指定",
          errorType: "invalid_config" 
        }
      }
      
      console.log(`连接到SMB服务器 ${serverConfig.ip}`)
      
      // 配置Samba客户端
      sambaClient.configure(serverConfig)
      
      try {
        // 尝试获取服务器上的所有共享
        console.log("尝试获取服务器上的所有共享...")
        const availableShares = await sambaClient.listShares()
        
        if (availableShares && availableShares.length > 0) {
          console.log(`发现可用共享: ${availableShares.join(', ')}`)
          
          // 返回发现的共享列表，让用户选择
          return { 
            success: true, 
            data: {
              needShareSelection: true,
              shares: availableShares
            }
          }
        } else {
          return {
            success: false,
            error: "无法在服务器上发现共享",
            errorType: "no_shares_found"
          }
        }
      } catch (error: any) {
        console.error("获取共享列表失败:", error)
        
        // 对特定的SMB错误进行更友好的提示
        if (error.code === 'STATUS_BAD_NETWORK_NAME') {
          return { 
            success: false, 
            error: `找不到指定的共享，请检查共享名称是否正确`,
            errorType: "share_not_found" 
          }
        } else if (error.code === 'STATUS_LOGON_FAILURE') {
          return { 
            success: false, 
            error: `认证失败，请检查用户名和密码`,
            errorType: "auth_failed" 
          }
        } else {
          return { 
            success: false, 
            error: error instanceof Error ? error.message : String(error),
            errorType: error.code || "unknown_error"
          }
        }
      }
    } catch (error: any) {
      console.error("连接服务器失败:", error)
      
      // 处理一些常见连接错误
      if (error.code === 'ETIMEDOUT' || error.code === 'EHOSTUNREACH' || error.code === 'ECONNREFUSED') {
        return { 
          success: false, 
          error: `无法连接到服务器 ${serverConfig.ip}，请检查IP地址是否正确且服务器是否在线`,
          errorType: "connection_failed" 
        }
      }
      
      return { 
        success: false, 
        error: error instanceof Error ? error.message : String(error),
        errorType: error.code || "unknown_error"
      }
    }
  })

  registerIPCHandler(IPCChannels.LIST_SHARES, async () => {
    try {
      const shares = await sambaClient.listShares()
      return { success: true, data: { shares } }
    } catch (error: unknown) {
      console.error("Failed to list shares:", error)
      return { success: false, error: error instanceof Error ? error.message : String(error) }
    }
  })

  registerIPCHandler(IPCChannels.LIST_FOLDERS, async (_, shareName) => {
    try {
      // 确保共享名称格式正确
      const formattedShareName = shareName === "/" ? "" : shareName.replace(/^\/+/, '')
      console.log(`Listing folders in: "${formattedShareName}"`)
      
      const files = await sambaClient.listFiles(formattedShareName)
      // 过滤只返回文件夹
      const folders = []
      
      for (const file of files) {
        if (file.startsWith('.')) continue
        
        try {
          // 构建子路径，保持一致的格式
          const subPath = formattedShareName 
            ? `${formattedShareName}\\${file}` 
            : file
            
          console.log(`Checking if is directory: "${subPath}"`)
          
          // 尝试列出文件，如果成功，则是文件夹
          await sambaClient.listFiles(subPath)
          folders.push(file)
        } catch (error) {
          // 忽略错误，表示不是文件夹或无权限
          console.log(`Not a directory or no permission: ${file}`)
        }
      }
      
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
      // 确保目录路径格式正确
      const formattedPath = dirPath === "/" ? "" : dirPath.replace(/^\/+/, '')
      console.log(`Getting directory contents for: "${formattedPath}"`)
      
      // 调试：检查SMB配置状态
      const configStatus = sambaClient.getConfigurationStatus();
      console.log('SMB Configuration Status:', configStatus);
      
      if (!configStatus.configured) {
        throw new Error("SMB client is not configured");
      }
      
      if (!configStatus.hasSharePath) {
        throw new Error("SMB share path is not configured");
      }
      
      // 使用新方法获取目录内容
      const items = await sambaClient.getDirContents(formattedPath)
      
      return { 
        success: true, 
        items: items // 直接返回items而不是嵌套在data中
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
      
      if (type === "movie" || type === "tv") {
        // 扫描指定类型的媒体
        const { movies, tvShows, total } = await mediaScanner.scanAllMedia(type as "movie" | "tv")
        result = { 
          count: total, 
          movies: movies.length, 
          tvShows: tvShows.length 
        }
      } else {
        // 扫描所有媒体
        const { movies, tvShows, total } = await mediaScanner.scanAllMedia()
        result = { 
          count: total,
          movies: movies.length,
          tvShows: tvShows.length
        }
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

  registerIPCHandler(IPCChannels.PLAY_MEDIA, async (_, request) => {
    try {
      console.log(`[PLAY_MEDIA] Request received:`, request)
      
      let filePath: string
      let mediaId: string
      let mediaTitle: string = 'Unknown Media'
      
      // 处理不同的请求格式
      if (typeof request === 'string') {
        // 如果请求是字符串，可能是mediaId
        mediaId = request
        const media = await mediaDatabase.getMediaById(mediaId)
        if (!media) {
          throw new Error(`Media with ID '${mediaId}' not found in database`)
        }
        
        // 优先使用path，然后fullPath，最后filePath
        filePath = media.path || media.fullPath || media.filePath
        if (!filePath) {
          throw new Error(`No valid file path found for media ID '${mediaId}'`)
        }
        
        mediaTitle = media.title
        console.log(`[PLAY_MEDIA] Found media: ${media.title}, path: ${filePath}`)
      } else if (typeof request === 'object' && request) {
        // 如果是对象，可能包含mediaId和filePath
        if (request.filePath) {
          filePath = request.filePath
          mediaId = request.mediaId || 'direct-play'
          console.log(`[PLAY_MEDIA] Direct file path provided: ${filePath}`)
        } else if (request.mediaId) {
          mediaId = request.mediaId
          const media = await mediaDatabase.getMediaById(mediaId)
          if (!media) {
            throw new Error(`Media with ID '${mediaId}' not found in database`)
          }
          
          filePath = media.path || media.fullPath || media.filePath
          if (!filePath) {
            throw new Error(`No valid file path found for media ID '${mediaId}'`)
          }
          
          mediaTitle = media.title
          console.log(`[PLAY_MEDIA] Found media: ${media.title}, path: ${filePath}`)
        } else {
          throw new Error("Invalid request: must provide either mediaId or filePath")
        }
      } else {
        throw new Error("Invalid request format")
      }
      
      // 检查代理服务器状态
      if (!mediaProxyServer.isRunning()) {
        throw new Error("Media proxy server is not running")
      }
      
      // 生成代理URL
      const proxyUrl = mediaProxyServer.getProxyUrl(filePath)
      console.log(`[PLAY_MEDIA] Generated proxy URL: ${proxyUrl}`)
      
      return { 
        success: true, 
        streamUrl: proxyUrl,
        title: mediaTitle,
        filePath: filePath,
        message: `Stream URL generated successfully`
      }
    } catch (error: unknown) {
      const errorMessage = error instanceof Error ? error.message : String(error)
      console.error("[PLAY_MEDIA] Failed to generate stream URL:", errorMessage)
      return { 
        success: false, 
        error: errorMessage
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
      const results = await metadataScraper.fetchAllMetadata(mediaIds)
      const successCount = Object.values(results).filter(r => r !== null).length
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

  console.log('[IPC] All handlers initialized successfully')
}
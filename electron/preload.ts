import { contextBridge, ipcRenderer } from "electron"
import { createIPCClient, ElectronAPI } from "./ipc-client"

// 创建类型安全的IPC客户端
const ipcClient = createIPCClient(ipcRenderer)
const electronAPI = new ElectronAPI(ipcClient)

// 暴露安全的API给渲染进程
contextBridge.exposeInMainWorld("electronAPI", {
  // 配置相关
  getConfig: () => electronAPI.config.getConfig(),
  saveConfig: (config: any) => electronAPI.config.saveConfig(config),
  connectServer: (serverConfig: any) => electronAPI.server.connectServer(serverConfig),
  listShares: () => electronAPI.server.listShares(),
  listFolders: (shareName: string) => electronAPI.server.listFolders(shareName),
  
  // 获取目录内容（包括文件和文件夹），用于浏览目录
  getDirContents: (dirPath: string) => electronAPI.server.getDirContents(dirPath),
  
  // 媒体相关
  getMedia: (type: string) => electronAPI.media.getMedia(type),
  
  // 根据ID获取媒体
  getMediaById: (id: string) => electronAPI.media.getMediaById(id),
  
  // 获取最近观看的媒体
  getRecentlyViewed: () => electronAPI.media.getRecentlyViewed(),
  scanMedia: (type: "movie" | "tv", useCached: boolean = true) => electronAPI.media.scanMedia(type, useCached),
  playMedia: (request: string | { mediaId: string; filePath?: string }) => electronAPI.media.playMedia(request),
  
  // 添加单个媒体文件
  addSingleMedia: (filePath: string) => electronAPI.media.addSingleMedia(filePath),

  // 海报相关
  fetchPosters: (mediaIds: string[]) => electronAPI.metadata.fetchPosters(mediaIds),

  // 文件选择
  selectFolder: () => electronAPI.filesystem.selectFolder(),
  
  // 缓存控制
  clearMediaCache: () => electronAPI.media.clearMediaCache(),

  // TMDB API相关函数
  checkTmdbApi: () => electronAPI.config.checkTmdbApi(),
  getTmdbApiKey: () => electronAPI.config.getTmdbApiKey(),
  setTmdbApiKey: (apiKey: string) => electronAPI.config.setTmdbApiKey(apiKey),
  
  // 从本地读取媒体详情
  getMediaDetails: (mediaId: string) => electronAPI.media.getMediaDetails(mediaId),

  // 暴露原始客户端供高级用法
  _client: ipcClient,
  
  // 暴露类型化API对象供高级用法
  _api: electronAPI,
})


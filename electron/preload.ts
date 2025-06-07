import { contextBridge, ipcRenderer } from "electron"

// 暴露安全的API给渲染进程
contextBridge.exposeInMainWorld("electronAPI", {
  // 配置相关
  getConfig: () => ipcRenderer.invoke("get-config"),
  saveConfig: (config: any) => ipcRenderer.invoke("save-config", config),
  connectServer: (serverConfig: any) => ipcRenderer.invoke("connect-server", serverConfig),
  listShares: () => ipcRenderer.invoke("list-shares"),
  listFolders: (shareName: string) => ipcRenderer.invoke("list-folders", shareName),
  
  // 新增：获取目录内容（包括文件和文件夹），用于浏览目录
  getDirContents: (dirPath: string) => ipcRenderer.invoke("get-dir-contents", dirPath),
  
  // 媒体相关
  getMedia: (type: string) => ipcRenderer.invoke("get-media", type),
  
  // 根据ID获取媒体
  getMediaById: (id: string) => ipcRenderer.invoke("get-media-by-id", id),
  
  // 获取最近观看的媒体
  getRecentlyViewed: () => ipcRenderer.invoke("get-recently-viewed"),
  scanMedia: (type: "movie" | "tv", useCached: boolean = true) => ipcRenderer.invoke("scan-media", type, useCached),
  playMedia: (mediaId: string) => ipcRenderer.invoke("play-media", mediaId),
  
  // 新增：添加单个媒体文件
  addSingleMedia: (filePath: string) => ipcRenderer.invoke("add-single-media", filePath),

  // 海报相关
  fetchPosters: (mediaIds: string[]) => ipcRenderer.invoke("fetch-posters", mediaIds),

  // 文件选择
  selectFolder: () => ipcRenderer.invoke("select-folder"),
  
  // 缓存控制
  clearMediaCache: () => ipcRenderer.invoke("clear-media-cache"),

  // TMDB API相关函数
  checkTmdbApi: () => ipcRenderer.invoke("check-tmdb-api"),
  getTmdbApiKey: () => ipcRenderer.invoke("get-tmdb-api-key"),
  setTmdbApiKey: (apiKey: string) => ipcRenderer.invoke("set-tmdb-api-key", apiKey),
  
  // 从本地读取媒体详情
  getMediaDetails: (mediaId: string) => ipcRenderer.invoke("get-media-details", mediaId),
})


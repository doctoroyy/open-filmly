import { contextBridge, ipcRenderer } from "electron"

// 暴露安全的API给渲染进程
contextBridge.exposeInMainWorld("electronAPI", {
  // 配置相关
  getConfig: () => ipcRenderer.invoke("get-config"),
  saveConfig: (config: any) => ipcRenderer.invoke("save-config", config),

  // 媒体相关
  getMedia: (type: "movie" | "tv") => ipcRenderer.invoke("get-media", type),
  getMediaById: (id: string) => ipcRenderer.invoke("get-media-by-id", id),
  getRecentlyViewed: () => ipcRenderer.invoke("get-recently-viewed"),
  scanMedia: (type: "movie" | "tv") => ipcRenderer.invoke("scan-media", type),
  playMedia: (mediaId: string) => ipcRenderer.invoke("play-media", mediaId),

  // 海报相关
  fetchPosters: (mediaIds: string[]) => ipcRenderer.invoke("fetch-posters", mediaIds),

  // 文件选择
  selectFolder: () => ipcRenderer.invoke("select-folder"),
})


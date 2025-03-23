interface ElectronAPI {
  // 配置相关
  getConfig: () => Promise<any>
  saveConfig: (config: any) => Promise<{ success: boolean; error?: string }>

  // 媒体相关
  getMedia: (type: "movie" | "tv") => Promise<any[]>
  getMediaById: (id: string) => Promise<any | null>
  getRecentlyViewed: () => Promise<any[]>
  scanMedia: (type: "movie" | "tv") => Promise<{ success: boolean; count?: number; error?: string }>
  playMedia: (mediaId: string) => Promise<{ success: boolean; error?: string }>

  // 海报相关
  fetchPosters: (mediaIds: string[]) => Promise<{ success: boolean; results?: any; error?: string }>

  // 文件选择
  selectFolder: () => Promise<{ canceled: boolean; filePaths?: string[] }>
}

interface Window {
  electronAPI?: ElectronAPI
} 
/**
 * Centralized IPC channel definitions
 * Provides type safety and unified interface definitions
 */

// 配置相关的IPC通道
export const ConfigChannels = {
  GET_CONFIG: 'config:get',
  SAVE_CONFIG: 'config:save',
  GET_TMDB_API_KEY: 'config:tmdb-api-key:get',
  SET_TMDB_API_KEY: 'config:tmdb-api-key:set',
  CHECK_TMDB_API: 'config:tmdb-api:check',
  GET_GEMINI_API_KEY: 'config:gemini-api-key:get',
  SET_GEMINI_API_KEY: 'config:gemini-api-key:set',
  CHECK_GEMINI_API: 'config:gemini-api:check',
} as const

// 服务器连接相关的IPC通道
export const ServerChannels = {
  CONNECT_SERVER: 'server:connect',
  GO_DISCOVER: 'server:go-discover',
  LIST_SHARES: 'server:shares:list',
  LIST_FOLDERS: 'server:folders:list',
  GET_DIR_CONTENTS: 'server:dir-contents:get',
  // 新增通用网络存储通道
  GET_NETWORK_DIR_CONTENTS: 'server:network-dir-contents:get',
} as const

// 媒体相关的IPC通道
export const MediaChannels = {
  GET_MEDIA: 'media:get',
  GET_MEDIA_BY_ID: 'media:get-by-id',
  GET_MEDIA_DETAILS: 'media:details:get',
  GET_RECENTLY_VIEWED: 'media:recently-viewed:get',
  SCAN_MEDIA: 'media:scan',
  ADD_SINGLE_MEDIA: 'media:add-single',
  // 新增网络媒体添加通道
  ADD_SINGLE_NETWORK_MEDIA: 'media:add-single-network',
  PLAY_MEDIA: 'media:play',
  SEARCH_MEDIA: 'media:search',
  SEARCH_MEDIA_BY_PATH: 'media:search-by-path',
  CLEAR_MEDIA_CACHE: 'media:cache:clear',
  CHECK_MPV_AVAILABILITY: 'media:mpv:check',
} as const

// 海报/元数据相关的IPC通道
export const MetadataChannels = {
  FETCH_POSTERS: 'metadata:posters:fetch',
  INTELLIGENT_RECOGNIZE: 'metadata:intelligent:recognize',
  INTELLIGENT_BATCH_RECOGNIZE: 'metadata:intelligent:batch-recognize',
} as const

// 文件系统相关的IPC通道
export const FileSystemChannels = {
  SELECT_FOLDER: 'filesystem:folder:select',
} as const

// 任务和进度相关的IPC通道
export const TaskChannels = {
  START_AUTO_SCAN: 'task:auto-scan:start',
  STOP_AUTO_SCAN: 'task:auto-scan:stop',
  GET_SCAN_STATUS: 'task:scan:status:get',
  GET_SCAN_PROGRESS: 'task:scan:progress:get',
  
  // 进度推送事件
  SCAN_PROGRESS_UPDATE: 'task:scan:progress:update',
  SCAN_PHASE_UPDATE: 'task:scan:phase:update',
  SCAN_COMPLETED: 'task:scan:completed',
  SCAN_ERROR: 'task:scan:error',
  
  // 刮削进度
  SCRAPE_PROGRESS_UPDATE: 'task:scrape:progress:update',
  SCRAPE_ITEM_UPDATE: 'task:scrape:item:update',
  SCRAPE_COMPLETED: 'task:scrape:completed',
  SCRAPE_ERROR: 'task:scrape:error',
} as const

// 所有IPC通道的联合类型
export const IPCChannels = {
  ...ConfigChannels,
  ...ServerChannels,
  ...MediaChannels,
  ...MetadataChannels,
  ...FileSystemChannels,
  ...TaskChannels,
} as const

// 类型定义
export type IPCChannelName = typeof IPCChannels[keyof typeof IPCChannels]

// IPC请求和响应的类型定义
export interface IPCRequest<T = any> {
  channel: IPCChannelName
  data?: T
}

export interface IPCResponse<T = any> {
  success: boolean
  data?: T
  error?: string
  errorType?: string
}

// 具体API的类型定义
export interface ConfigTypes {
  [ConfigChannels.GET_CONFIG]: {
    request: void
    response: IPCResponse<any>
  }
  [ConfigChannels.SAVE_CONFIG]: {
    request: any
    response: IPCResponse<{ success: boolean }>
  }
  [ConfigChannels.GET_TMDB_API_KEY]: {
    request: void
    response: IPCResponse<{ apiKey: string }>
  }
  [ConfigChannels.SET_TMDB_API_KEY]: {
    request: string
    response: IPCResponse<void>
  }
  [ConfigChannels.CHECK_TMDB_API]: {
    request: void
    response: IPCResponse<{ hasApiKey: boolean }>
  }
  [ConfigChannels.GET_GEMINI_API_KEY]: {
    request: void
    response: IPCResponse<{ apiKey: string }>
  }
  [ConfigChannels.SET_GEMINI_API_KEY]: {
    request: string
    response: IPCResponse<void>
  }
  [ConfigChannels.CHECK_GEMINI_API]: {
    request: void
    response: IPCResponse<{ hasApiKey: boolean }>
  }
}

export interface ServerTypes {
  [ServerChannels.CONNECT_SERVER]: {
    request: any
    response: IPCResponse<{ needShareSelection?: boolean; shares?: string[] }>
  }
  [ServerChannels.LIST_SHARES]: {
    request: void
    response: IPCResponse<{ shares: string[] }>
  }
  [ServerChannels.LIST_FOLDERS]: {
    request: string
    response: IPCResponse<{ folders: string[] }>
  }
  [ServerChannels.GET_DIR_CONTENTS]: {
    request: string
    response: IPCResponse<{ items: any[] }>
  }
  [ServerChannels.GET_NETWORK_DIR_CONTENTS]: {
    request: { path: string; storageType?: string }
    response: IPCResponse<{ items: any[] }>
  }
}

export interface MediaTypes {
  [MediaChannels.GET_MEDIA]: {
    request: string
    response: any[]
  }
  [MediaChannels.GET_MEDIA_BY_ID]: {
    request: string
    response: any | null
  }
  [MediaChannels.GET_MEDIA_DETAILS]: {
    request: string
    response: any | null
  }
  [MediaChannels.GET_RECENTLY_VIEWED]: {
    request: void
    response: any[]
  }
  [MediaChannels.SCAN_MEDIA]: {
    request: { type: "movie" | "tv" | "all"; useCached?: boolean }
    response: IPCResponse<{ count: number; movies?: number; tvShows?: number }>
  }
  [MediaChannels.ADD_SINGLE_MEDIA]: {
    request: string
    response: IPCResponse<{ media: any }>
  }
  [MediaChannels.ADD_SINGLE_NETWORK_MEDIA]: {
    request: { filePath: string; storageType?: string }
    response: IPCResponse<{ media: any }>
  }
  [MediaChannels.PLAY_MEDIA]: {
    request: string | { mediaId: string; filePath?: string }
    response: IPCResponse<{ 
      message?: string;
      streamUrl?: string;
      title?: string;
      filePath?: string;
    }>
  }
  [MediaChannels.SEARCH_MEDIA]: {
    request: string
    response: IPCResponse<{ results: any[]; count: number }>
  }
  [MediaChannels.SEARCH_MEDIA_BY_PATH]: {
    request: string
    response: IPCResponse<{ results: any[] }>
  }
  [MediaChannels.CLEAR_MEDIA_CACHE]: {
    request: void
    response: IPCResponse<void>
  }
  [MediaChannels.CHECK_MPV_AVAILABILITY]: {
    request: void
    response: IPCResponse<{ available: boolean; reason?: string }>
  }
}

export interface MetadataTypes {
  [MetadataChannels.FETCH_POSTERS]: {
    request: string[]
    response: IPCResponse<{ results: any }>
  }
  [MetadataChannels.INTELLIGENT_RECOGNIZE]: {
    request: { filename: string; filePath?: string }
    response: IPCResponse<{
      originalTitle: string
      cleanTitle: string
      mediaType: 'movie' | 'tv' | 'unknown'
      year?: string
      confidence: number
      enrichedContext?: string
      alternativeNames?: string[]
    }>
  }
  [MetadataChannels.INTELLIGENT_BATCH_RECOGNIZE]: {
    request: { filenames: string[]; filePaths?: string[] }
    response: IPCResponse<{
      results: Array<{
        originalTitle: string
        cleanTitle: string
        mediaType: 'movie' | 'tv' | 'unknown'
        year?: string
        confidence: number
        enrichedContext?: string
        alternativeNames?: string[]
      }>
    }>
  }
}

export interface FileSystemTypes {
  [FileSystemChannels.SELECT_FOLDER]: {
    request: void
    response: { canceled: boolean; filePaths?: string[] }
  }
}

export interface TaskTypes {
  [TaskChannels.START_AUTO_SCAN]: {
    request: { force?: boolean }
    response: IPCResponse<{ started: boolean; message?: string }>
  }
  [TaskChannels.STOP_AUTO_SCAN]: {
    request: void
    response: IPCResponse<{ stopped: boolean }>
  }
  [TaskChannels.GET_SCAN_STATUS]: {
    request: void
    response: IPCResponse<{
      isScanning: boolean
      currentPhase?: string
      totalFiles?: number
      processedFiles?: number
      currentFile?: string
      startTime?: string
      errors?: string[]
    }>
  }
  [TaskChannels.GET_SCAN_PROGRESS]: {
    request: void
    response: IPCResponse<{
      scanProgress: {
        phase: string
        current: number
        total: number
        currentItem?: string
      }
      scrapeProgress?: {
        phase: string
        current: number
        total: number
        currentItem?: string
      }
    }>
  }
}

// 所有API类型的联合
export type AllIPCTypes = ConfigTypes & ServerTypes & MediaTypes & MetadataTypes & FileSystemTypes & TaskTypes
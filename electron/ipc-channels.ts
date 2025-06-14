/**
 * 集中化的IPC通道定义
 * 提供类型安全和统一的接口定义
 */

// 配置相关的IPC通道
export const ConfigChannels = {
  GET_CONFIG: 'config:get',
  SAVE_CONFIG: 'config:save',
  GET_TMDB_API_KEY: 'config:tmdb-api-key:get',
  SET_TMDB_API_KEY: 'config:tmdb-api-key:set',
  CHECK_TMDB_API: 'config:tmdb-api:check',
} as const

// 服务器连接相关的IPC通道
export const ServerChannels = {
  CONNECT_SERVER: 'server:connect',
  LIST_SHARES: 'server:shares:list',
  LIST_FOLDERS: 'server:folders:list',
  GET_DIR_CONTENTS: 'server:dir-contents:get',
} as const

// 媒体相关的IPC通道
export const MediaChannels = {
  GET_MEDIA: 'media:get',
  GET_MEDIA_BY_ID: 'media:get-by-id',
  GET_MEDIA_DETAILS: 'media:details:get',
  GET_RECENTLY_VIEWED: 'media:recently-viewed:get',
  SCAN_MEDIA: 'media:scan',
  ADD_SINGLE_MEDIA: 'media:add-single',
  PLAY_MEDIA: 'media:play',
  SEARCH_MEDIA: 'media:search',
  SEARCH_MEDIA_BY_PATH: 'media:search-by-path',
  CLEAR_MEDIA_CACHE: 'media:cache:clear',
} as const

// 海报/元数据相关的IPC通道
export const MetadataChannels = {
  FETCH_POSTERS: 'metadata:posters:fetch',
} as const

// 文件系统相关的IPC通道
export const FileSystemChannels = {
  SELECT_FOLDER: 'filesystem:folder:select',
} as const

// 所有IPC通道的联合类型
export const IPCChannels = {
  ...ConfigChannels,
  ...ServerChannels,
  ...MediaChannels,
  ...MetadataChannels,
  ...FileSystemChannels,
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
  [MediaChannels.PLAY_MEDIA]: {
    request: { mediaId: string; filePath?: string }
    response: IPCResponse<void>
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
}

export interface MetadataTypes {
  [MetadataChannels.FETCH_POSTERS]: {
    request: string[]
    response: IPCResponse<{ results: any }>
  }
}

export interface FileSystemTypes {
  [FileSystemChannels.SELECT_FOLDER]: {
    request: void
    response: { canceled: boolean; filePaths?: string[] }
  }
}

// 所有API类型的联合
export type AllIPCTypes = ConfigTypes & ServerTypes & MediaTypes & MetadataTypes & FileSystemTypes
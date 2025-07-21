/**
 * 抽象接口和Provider架构定义
 * 支持多种网络存储协议和媒体播放器的可插拔架构
 */

// ==================== 网络存储抽象 ====================

export interface NetworkStorageConfig {
  host: string
  port?: number
  username?: string
  password?: string
  domain?: string
  sharePath?: string
  [key: string]: any // 允许扩展配置
}

export interface StorageShareInfo {
  name: string
  type: string
  comment?: string
  permissions?: string
  [key: string]: any
}

export interface StorageDirectoryItem {
  name: string
  isDirectory: boolean
  size: number
  modifiedTime: string
  path: string
  [key: string]: any
}

export interface StorageDirectoryResult {
  path: string
  success: boolean
  items: StorageDirectoryItem[]
  error?: string
}

export interface StorageDiscoveryResult {
  host: string
  port: number
  success: boolean
  shares: StorageShareInfo[]
  error?: string
  timestamp: string
}

export interface MediaFile {
  path: string
  fullPath: string
  type: 'movie' | 'tv' | 'unknown'
  name: string
  size?: number
  modifiedTime?: string
  [key: string]: any
}

/**
 * 网络存储提供者抽象接口
 */
export interface INetworkStorageProvider {
  // 配置管理
  configure(config: NetworkStorageConfig): void
  getConfiguration(): NetworkStorageConfig | null
  getConfigurationStatus(): {
    configured: boolean
    hasSharePath: boolean
    details: any
  }

  // 连接管理
  testConnection(): Promise<boolean>
  disconnect(): void

  // 发现和列举
  discoverShares(): Promise<StorageShareInfo[]>
  listDirectory(shareName: string, directory?: string): Promise<StorageDirectoryItem[]>

  // 文件操作
  readFile(filePath: string): Promise<Buffer>
  
  // 媒体扫描
  scanMediaFiles(directory: string): Promise<MediaFile[]>

  // 工具方法
  isAvailable(): boolean
  getProviderInfo(): {
    name: string
    version: string
    available: boolean
    [key: string]: any
  }
  getSystemInfo(): Promise<any>
}

// ==================== 媒体播放器抽象 ====================

export interface MediaPlayerConfig {
  [key: string]: any // 播放器特定配置
}

export interface PlaybackOptions {
  url: string
  startTime?: number
  volume?: number
  fullscreen?: boolean
  subtitle?: string
  [key: string]: any
}

export interface PlaybackStatus {
  isPlaying: boolean
  duration?: number
  position?: number
  volume?: number
  [key: string]: any
}

/**
 * 媒体播放器提供者抽象接口
 */
export interface IMediaPlayerProvider {
  // 配置管理
  configure(config: MediaPlayerConfig): void
  getConfiguration(): MediaPlayerConfig | null

  // 播放控制
  play(options: PlaybackOptions): Promise<void>
  pause(): Promise<void>
  stop(): Promise<void>
  seek(position: number): Promise<void>
  setVolume(volume: number): Promise<void>

  // 状态查询
  getStatus(): Promise<PlaybackStatus>
  isPlaying(): Promise<boolean>

  // 工具方法
  isAvailable(): boolean
  getPlayerInfo(): {
    name: string
    version: string
    available: boolean
    supportedFormats: string[]
    [key: string]: any
  }
}

// ==================== Provider工厂 ====================

export type NetworkStorageProviderType = 'smb' | 'ftp' | 'nfs' | 'webdav'
export type MediaPlayerProviderType = 'mpv' | 'vlc' | 'browser' | 'system'

export interface IProviderFactory {
  createStorageProvider(type: NetworkStorageProviderType): INetworkStorageProvider
  createMediaPlayerProvider(type: MediaPlayerProviderType): IMediaPlayerProvider
  
  getAvailableStorageProviders(): NetworkStorageProviderType[]
  getAvailableMediaPlayerProviders(): MediaPlayerProviderType[]
}

// ==================== 事件系统 ====================

export interface ProviderEvent {
  type: string
  provider: string
  data?: any
  timestamp: Date
}

export interface IProviderEventEmitter {
  on(event: string, listener: (data: ProviderEvent) => void): this
  off(event: string, listener: (data: ProviderEvent) => void): this
  emit(event: string, data: ProviderEvent): boolean
}

// ==================== 错误处理 ====================

export class ProviderError extends Error {
  constructor(
    message: string,
    public readonly provider: string,
    public readonly code?: string,
    public readonly originalError?: Error
  ) {
    super(message)
    this.name = 'ProviderError'
  }
}

export class StorageProviderError extends ProviderError {
  constructor(message: string, provider: string, code?: string, originalError?: Error) {
    super(message, provider, code, originalError)
    this.name = 'StorageProviderError'
  }
}

export class MediaPlayerProviderError extends ProviderError {
  constructor(message: string, provider: string, code?: string, originalError?: Error) {
    super(message, provider, code, originalError)
    this.name = 'MediaPlayerProviderError'
  }
}
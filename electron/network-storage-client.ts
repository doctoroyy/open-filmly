/**
 * 网络存储客户端抽象层
 * 提供统一的网络存储接口，支持多种存储协议的可插拔实现
 */

import { EventEmitter } from 'events'
import {
  INetworkStorageProvider,
  IProviderFactory,
  IProviderEventEmitter,
  NetworkStorageConfig,
  NetworkStorageProviderType,
  StorageShareInfo,
  StorageDirectoryItem,
  MediaFile,
  StorageProviderError,
  ProviderEvent
} from './types/providers'

/**
 * Provider事件发射器实现
 */
class ProviderEventEmitter extends EventEmitter implements IProviderEventEmitter {
  on(event: string, listener: (data: ProviderEvent) => void): this {
    return super.on(event, listener)
  }

  off(event: string, listener: (data: ProviderEvent) => void): this {
    return super.off(event, listener)
  }

  emit(event: string, data: ProviderEvent): boolean {
    return super.emit(event, data)
  }
}

/**
 * 网络存储客户端 - 主要的抽象层
 */
export class NetworkStorageClient {
  private provider: INetworkStorageProvider | null = null
  private providerType: NetworkStorageProviderType | null = null
  private factory: IProviderFactory
  private eventEmitter: ProviderEventEmitter

  constructor(factory: IProviderFactory) {
    this.factory = factory
    this.eventEmitter = new ProviderEventEmitter()
  }

  // ==================== Provider管理 ====================

  /**
   * 设置存储提供者类型
   */
  public setProvider(type: NetworkStorageProviderType): void {
    try {
      this.provider = this.factory.createStorageProvider(type)
      this.providerType = type
      
      this.emitEvent('provider_changed', {
        type: 'provider_changed',
        provider: type,
        data: { type },
        timestamp: new Date()
      })
      
      console.log(`[NetworkStorageClient] Provider set to: ${type}`)
    } catch (error: any) {
      throw new StorageProviderError(
        `Failed to set provider: ${error.message}`,
        type,
        'PROVIDER_SET_FAILED',
        error
      )
    }
  }

  /**
   * 获取当前提供者类型
   */
  public getCurrentProviderType(): NetworkStorageProviderType | null {
    return this.providerType
  }

  /**
   * 获取可用的存储提供者列表
   */
  public getAvailableProviders(): NetworkStorageProviderType[] {
    return this.factory.getAvailableStorageProviders()
  }

  /**
   * 检查当前提供者是否可用
   */
  public isProviderAvailable(): boolean {
    return this.provider?.isAvailable() || false
  }

  // ==================== 配置管理 ====================

  /**
   * 配置存储连接
   */
  public configure(config: NetworkStorageConfig): void {
    this.ensureProvider()
    
    try {
      this.provider!.configure(config)
      
      this.emitEvent('configured', {
        type: 'configured',
        provider: this.providerType!,
        data: { host: config.host, port: config.port },
        timestamp: new Date()
      })
      
      console.log(`[NetworkStorageClient] Configured for: ${config.host}:${config.port || 'default'}`)
    } catch (error: any) {
      throw new StorageProviderError(
        `Configuration failed: ${error.message}`,
        this.providerType!,
        'CONFIGURATION_FAILED',
        error
      )
    }
  }

  /**
   * 获取当前配置
   */
  public getConfiguration(): NetworkStorageConfig | null {
    if (!this.provider) return null
    return this.provider.getConfiguration()
  }

  /**
   * 获取配置状态
   */
  public getConfigurationStatus() {
    this.ensureProvider()
    return this.provider!.getConfigurationStatus()
  }

  // ==================== 连接管理 ====================

  /**
   * 测试连接
   */
  public async testConnection(): Promise<boolean> {
    this.ensureProvider()
    
    try {
      const success = await this.provider!.testConnection()
      
      this.emitEvent(success ? 'connection_success' : 'connection_failed', {
        type: success ? 'connection_success' : 'connection_failed',
        provider: this.providerType!,
        data: { success },
        timestamp: new Date()
      })
      
      return success
    } catch (error: any) {
      this.emitEvent('connection_error', {
        type: 'connection_error',
        provider: this.providerType!,
        data: { error: error.message },
        timestamp: new Date()
      })
      
      throw new StorageProviderError(
        `Connection test failed: ${error.message}`,
        this.providerType!,
        'CONNECTION_TEST_FAILED',
        error
      )
    }
  }

  /**
   * 断开连接
   */
  public disconnect(): void {
    if (!this.provider) return
    
    try {
      this.provider.disconnect()
      
      this.emitEvent('disconnected', {
        type: 'disconnected',
        provider: this.providerType!,
        timestamp: new Date()
      })
    } catch (error: any) {
      console.warn(`[NetworkStorageClient] Disconnect error: ${error.message}`)
    }
  }

  // ==================== 发现和列举 ====================

  /**
   * 发现共享资源
   */
  public async discoverShares(): Promise<StorageShareInfo[]> {
    this.ensureProvider()
    
    try {
      const shares = await this.provider!.discoverShares()
      
      this.emitEvent('shares_discovered', {
        type: 'shares_discovered',
        provider: this.providerType!,
        data: { count: shares.length, shares: shares.map((s: StorageShareInfo) => s.name) },
        timestamp: new Date()
      })
      
      return shares
    } catch (error: any) {
      throw new StorageProviderError(
        `Share discovery failed: ${error.message}`,
        this.providerType!,
        'SHARE_DISCOVERY_FAILED',
        error
      )
    }
  }

  /**
   * 列出目录内容
   */
  public async listDirectory(shareName: string, directory: string = '/'): Promise<StorageDirectoryItem[]> {
    this.ensureProvider()
    
    try {
      const items = await this.provider!.listDirectory(shareName, directory)
      
      this.emitEvent('directory_listed', {
        type: 'directory_listed',
        provider: this.providerType!,
        data: { 
          shareName, 
          directory, 
          itemCount: items.length,
          fileCount: items.filter((i: StorageDirectoryItem) => !i.isDirectory).length,
          directoryCount: items.filter((i: StorageDirectoryItem) => i.isDirectory).length
        },
        timestamp: new Date()
      })
      
      return items
    } catch (error: any) {
      throw new StorageProviderError(
        `Directory listing failed: ${error.message}`,
        this.providerType!,
        'DIRECTORY_LISTING_FAILED',
        error
      )
    }
  }

  // ==================== 文件操作 ====================

  /**
   * 读取文件内容
   */
  public async readFile(filePath: string): Promise<Buffer> {
    this.ensureProvider()
    
    try {
      const buffer = await this.provider!.readFile(filePath)
      
      this.emitEvent('file_read', {
        type: 'file_read',
        provider: this.providerType!,
        data: { filePath, size: buffer.length },
        timestamp: new Date()
      })
      
      return buffer
    } catch (error: any) {
      throw new StorageProviderError(
        `File read failed: ${error.message}`,
        this.providerType!,
        'FILE_READ_FAILED',
        error
      )
    }
  }

  // ==================== 媒体扫描 ====================

  /**
   * 扫描媒体文件
   */
  public async scanMediaFiles(directory: string): Promise<MediaFile[]> {
    this.ensureProvider()
    
    try {
      const mediaFiles = await this.provider!.scanMediaFiles(directory)
      
      this.emitEvent('media_scan_completed', {
        type: 'media_scan_completed',
        provider: this.providerType!,
        data: { 
          directory,
          totalFiles: mediaFiles.length,
          movieCount: mediaFiles.filter((f: MediaFile) => f.type === 'movie').length,
          tvCount: mediaFiles.filter((f: MediaFile) => f.type === 'tv').length,
          unknownCount: mediaFiles.filter((f: MediaFile) => f.type === 'unknown').length
        },
        timestamp: new Date()
      })
      
      return mediaFiles
    } catch (error: any) {
      throw new StorageProviderError(
        `Media scan failed: ${error.message}`,
        this.providerType!,
        'MEDIA_SCAN_FAILED',
        error
      )
    }
  }

  // ==================== 信息获取 ====================

  /**
   * 获取提供者信息
   */
  public getProviderInfo() {
    if (!this.provider) {
      return {
        name: 'none',
        version: 'N/A',
        available: false,
        type: this.providerType
      }
    }
    
    return {
      ...this.provider.getProviderInfo(),
      type: this.providerType
    }
  }

  /**
   * 获取系统信息
   */
  public async getSystemInfo(): Promise<any> {
    if (!this.provider) {
      return {
        provider: 'none',
        available: false
      }
    }
    
    return {
      providerType: this.providerType,
      providerInfo: this.provider.getProviderInfo(),
      systemInfo: await this.provider.getSystemInfo()
    }
  }

  // ==================== 事件处理 ====================

  /**
   * 监听事件
   */
  public on(event: string, listener: (data: ProviderEvent) => void): void {
    this.eventEmitter.on(event, listener)
  }

  /**
   * 取消监听事件
   */
  public off(event: string, listener: (data: ProviderEvent) => void): void {
    this.eventEmitter.off(event, listener)
  }

  // ==================== 私有方法 ====================

  private ensureProvider(): void {
    if (!this.provider) {
      throw new StorageProviderError(
        'No storage provider configured',
        'none',
        'NO_PROVIDER'
      )
    }
  }

  private emitEvent(type: string, event: ProviderEvent): void {
    this.eventEmitter.emit(type, event)
  }
}
/**
 * Provider工厂实现
 * 负责创建和管理各种存储和播放器提供者
 */

import {
  IProviderFactory,
  INetworkStorageProvider,
  IMediaPlayerProvider,
  NetworkStorageProviderType,
  MediaPlayerProviderType,
  ProviderError
} from './types/providers'

/**
 * 默认Provider工厂实现
 */
export class DefaultProviderFactory implements IProviderFactory {
  
  // ==================== 存储Provider创建 ====================

  /**
   * 创建网络存储提供者
   */
  createStorageProvider(type: NetworkStorageProviderType): INetworkStorageProvider {
    try {
      switch (type) {
        case 'smb':
          const { SMBStorageProvider } = require('./providers/storage/smb-provider')
          return new SMBStorageProvider()
        
        case 'ftp':
          const { FTPStorageProvider } = require('./providers/storage/ftp-provider')
          return new FTPStorageProvider()
        
        case 'nfs':
          const { NFSStorageProvider } = require('./providers/storage/nfs-provider')
          return new NFSStorageProvider()
        
        case 'webdav':
          const { WebDAVStorageProvider } = require('./providers/storage/webdav-provider')
          return new WebDAVStorageProvider()
        
        default:
          throw new ProviderError(
            `Unsupported storage provider: ${type}`,
            type,
            'UNSUPPORTED_STORAGE_PROVIDER'
          )
      }
    } catch (error: any) {
      if (error instanceof ProviderError) {
        throw error
      }
      
      // 如果是模块加载错误，可能是Provider未实现
      if (error.code === 'MODULE_NOT_FOUND') {
        throw new ProviderError(
          `Storage provider not implemented: ${type}`,
          type,
          'PROVIDER_NOT_IMPLEMENTED',
          error
        )
      }
      
      throw new ProviderError(
        `Failed to create storage provider ${type}: ${error.message}`,
        type,
        'PROVIDER_CREATION_FAILED',
        error
      )
    }
  }

  // ==================== 媒体播放器Provider创建 ====================

  /**
   * 创建媒体播放器提供者
   */
  createMediaPlayerProvider(type: MediaPlayerProviderType): IMediaPlayerProvider {
    try {
      switch (type) {
        case 'mpv':
          const { MPVPlayerProvider } = require('./providers/player/mpv-provider')
          return new MPVPlayerProvider()
        
        case 'vlc':
          const { VLCPlayerProvider } = require('./providers/player/vlc-provider')
          return new VLCPlayerProvider()
        
        case 'browser':
          const { BrowserPlayerProvider } = require('./providers/player/browser-provider')
          return new BrowserPlayerProvider()
        
        case 'system':
          const { SystemPlayerProvider } = require('./providers/player/system-provider')
          return new SystemPlayerProvider()
        
        default:
          throw new ProviderError(
            `Unsupported media player provider: ${type}`,
            type,
            'UNSUPPORTED_PLAYER_PROVIDER'
          )
      }
    } catch (error: any) {
      if (error instanceof ProviderError) {
        throw error
      }
      
      // 如果是模块加载错误，可能是Provider未实现
      if (error.code === 'MODULE_NOT_FOUND') {
        throw new ProviderError(
          `Media player provider not implemented: ${type}`,
          type,
          'PROVIDER_NOT_IMPLEMENTED',
          error
        )
      }
      
      throw new ProviderError(
        `Failed to create media player provider ${type}: ${error.message}`,
        type,
        'PROVIDER_CREATION_FAILED',
        error
      )
    }
  }

  // ==================== 可用性检查 ====================

  /**
   * 获取可用的存储提供者列表
   */
  getAvailableStorageProviders(): NetworkStorageProviderType[] {
    const allProviders: NetworkStorageProviderType[] = ['smb', 'ftp', 'nfs', 'webdav']
    const availableProviders: NetworkStorageProviderType[] = []

    for (const providerType of allProviders) {
      try {
        const provider = this.createStorageProvider(providerType)
        if (provider.isAvailable()) {
          availableProviders.push(providerType)
        }
      } catch (error) {
        console.warn(`[DefaultProviderFactory] Storage provider ${providerType} not available:`, error)
      }
    }

    console.log(`[DefaultProviderFactory] Available storage providers:`, availableProviders)
    return availableProviders
  }

  /**
   * 获取可用的媒体播放器提供者列表
   */
  getAvailableMediaPlayerProviders(): MediaPlayerProviderType[] {
    const allProviders: MediaPlayerProviderType[] = ['mpv', 'vlc', 'browser', 'system']
    const availableProviders: MediaPlayerProviderType[] = []

    for (const providerType of allProviders) {
      try {
        const provider = this.createMediaPlayerProvider(providerType)
        if (provider.isAvailable()) {
          availableProviders.push(providerType)
        }
      } catch (error) {
        console.warn(`[DefaultProviderFactory] Media player provider ${providerType} not available:`, error)
      }
    }

    console.log(`[DefaultProviderFactory] Available media player providers:`, availableProviders)
    return availableProviders
  }

  // ==================== 工具方法 ====================

  /**
   * 检查特定存储提供者是否可用
   */
  isStorageProviderAvailable(type: NetworkStorageProviderType): boolean {
    try {
      const provider = this.createStorageProvider(type)
      return provider.isAvailable()
    } catch (error) {
      return false
    }
  }

  /**
   * 检查特定媒体播放器提供者是否可用
   */
  isMediaPlayerProviderAvailable(type: MediaPlayerProviderType): boolean {
    try {
      const provider = this.createMediaPlayerProvider(type)
      return provider.isAvailable()
    } catch (error) {
      return false
    }
  }

  /**
   * 获取存储提供者信息
   */
  getStorageProviderInfo(type: NetworkStorageProviderType): any {
    try {
      const provider = this.createStorageProvider(type)
      return provider.getProviderInfo()
    } catch (error: any) {
      return {
        name: `${type} Storage Provider`,
        available: false,
        error: error.message
      }
    }
  }

  /**
   * 获取媒体播放器提供者信息
   */
  getMediaPlayerProviderInfo(type: MediaPlayerProviderType): any {
    try {
      const provider = this.createMediaPlayerProvider(type)
      return provider.getPlayerInfo()
    } catch (error: any) {
      return {
        name: `${type} Player Provider`,
        available: false,
        error: error.message
      }
    }
  }

  /**
   * 获取所有提供者的详细信息
   */
  getAllProvidersInfo(): {
    storage: { [key in NetworkStorageProviderType]: any }
    player: { [key in MediaPlayerProviderType]: any }
  } {
    const storageInfo: { [key in NetworkStorageProviderType]: any } = {} as any
    const playerInfo: { [key in MediaPlayerProviderType]: any } = {} as any

    // 存储提供者信息
    const allStorageProviders: NetworkStorageProviderType[] = ['smb', 'ftp', 'nfs', 'webdav']
    for (const type of allStorageProviders) {
      storageInfo[type] = this.getStorageProviderInfo(type)
    }

    // 播放器提供者信息
    const allPlayerProviders: MediaPlayerProviderType[] = ['mpv', 'vlc', 'browser', 'system']
    for (const type of allPlayerProviders) {
      playerInfo[type] = this.getMediaPlayerProviderInfo(type)
    }

    return {
      storage: storageInfo,
      player: playerInfo
    }
  }
}

// ==================== 单例工厂实例 ====================

/**
 * 默认的全局Provider工厂实例
 */
export const defaultProviderFactory = new DefaultProviderFactory()

/**
 * 获取默认Provider工厂实例的便捷函数
 */
export function getProviderFactory(): IProviderFactory {
  return defaultProviderFactory
}
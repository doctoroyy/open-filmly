/**
 * 媒体播放器客户端抽象层
 * 提供统一的媒体播放接口，支持多种播放器的可插拔实现
 */

import { EventEmitter } from 'events'
import {
  IMediaPlayerProvider,
  MediaPlayerProviderType,
  MediaPlayerConfig,
  PlaybackOptions,
  PlaybackStatus,
  MediaPlayerProviderError,
  ProviderEvent
} from './types/providers'

/**
 * 媒体播放器客户端 - 主要的抽象层
 */
export class MediaPlayerClient {
  private provider: IMediaPlayerProvider | null = null
  private providerType: MediaPlayerProviderType | null = null
  private eventEmitter: EventEmitter

  constructor() {
    this.eventEmitter = new EventEmitter()
  }

  // ==================== Provider管理 ====================

  /**
   * 设置媒体播放器提供者类型
   */
  public setProvider(type: MediaPlayerProviderType, config?: MediaPlayerConfig): void {
    try {
      // 根据类型创建相应的Provider
      this.provider = this.createProvider(type)
      this.providerType = type
      
      if (config) {
        this.provider.configure(config)
      }
      
      this.emitEvent('provider_changed', {
        type: 'provider_changed',
        provider: type,
        data: { type, config },
        timestamp: new Date()
      })
      
      console.log(`[MediaPlayerClient] Provider set to: ${type}`)
    } catch (error: any) {
      throw new MediaPlayerProviderError(
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
  public getCurrentProviderType(): MediaPlayerProviderType | null {
    return this.providerType
  }

  /**
   * 获取可用的媒体播放器提供者列表
   */
  public getAvailableProviders(): MediaPlayerProviderType[] {
    return ['mpv', 'vlc', 'browser', 'system']
  }

  /**
   * 检查当前提供者是否可用
   */
  public isProviderAvailable(): boolean {
    return this.provider?.isAvailable() || false
  }

  // ==================== 配置管理 ====================

  /**
   * 配置播放器
   */
  public configure(config: MediaPlayerConfig): void {
    this.ensureProvider()
    
    try {
      this.provider!.configure(config)
      
      this.emitEvent('configured', {
        type: 'configured',
        provider: this.providerType!,
        data: config,
        timestamp: new Date()
      })
      
      console.log(`[MediaPlayerClient] Configured ${this.providerType} player`)
    } catch (error: any) {
      throw new MediaPlayerProviderError(
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
  public getConfiguration(): MediaPlayerConfig | null {
    if (!this.provider) return null
    return this.provider.getConfiguration()
  }

  // ==================== 播放控制 ====================

  /**
   * 播放媒体
   */
  public async play(options: PlaybackOptions): Promise<void> {
    this.ensureProvider()
    
    try {
      await this.provider!.play(options)
      
      this.emitEvent('play_started', {
        type: 'play_started',
        provider: this.providerType!,
        data: { url: options.url, options },
        timestamp: new Date()
      })
    } catch (error: any) {
      this.emitEvent('play_error', {
        type: 'play_error',
        provider: this.providerType!,
        data: { error: error.message, url: options.url },
        timestamp: new Date()
      })
      
      throw new MediaPlayerProviderError(
        `Playback failed: ${error.message}`,
        this.providerType!,
        'PLAYBACK_FAILED',
        error
      )
    }
  }

  /**
   * 暂停播放
   */
  public async pause(): Promise<void> {
    this.ensureProvider()
    
    try {
      await this.provider!.pause()
      
      this.emitEvent('paused', {
        type: 'paused',
        provider: this.providerType!,
        timestamp: new Date()
      })
    } catch (error: any) {
      throw new MediaPlayerProviderError(
        `Pause failed: ${error.message}`,
        this.providerType!,
        'PAUSE_FAILED',
        error
      )
    }
  }

  /**
   * 停止播放
   */
  public async stop(): Promise<void> {
    this.ensureProvider()
    
    try {
      await this.provider!.stop()
      
      this.emitEvent('stopped', {
        type: 'stopped',
        provider: this.providerType!,
        timestamp: new Date()
      })
    } catch (error: any) {
      throw new MediaPlayerProviderError(
        `Stop failed: ${error.message}`,
        this.providerType!,
        'STOP_FAILED',
        error
      )
    }
  }

  /**
   * 跳转到指定位置
   */
  public async seek(position: number): Promise<void> {
    this.ensureProvider()
    
    try {
      await this.provider!.seek(position)
      
      this.emitEvent('seeked', {
        type: 'seeked',
        provider: this.providerType!,
        data: { position },
        timestamp: new Date()
      })
    } catch (error: any) {
      throw new MediaPlayerProviderError(
        `Seek failed: ${error.message}`,
        this.providerType!,
        'SEEK_FAILED',
        error
      )
    }
  }

  /**
   * 设置音量
   */
  public async setVolume(volume: number): Promise<void> {
    this.ensureProvider()
    
    // 验证音量范围
    if (volume < 0 || volume > 100) {
      throw new MediaPlayerProviderError(
        `Invalid volume: ${volume}. Must be between 0 and 100.`,
        this.providerType!,
        'INVALID_VOLUME'
      )
    }
    
    try {
      await this.provider!.setVolume(volume)
      
      this.emitEvent('volume_changed', {
        type: 'volume_changed',
        provider: this.providerType!,
        data: { volume },
        timestamp: new Date()
      })
    } catch (error: any) {
      throw new MediaPlayerProviderError(
        `Set volume failed: ${error.message}`,
        this.providerType!,
        'VOLUME_FAILED',
        error
      )
    }
  }

  // ==================== 状态查询 ====================

  /**
   * 获取播放状态
   */
  public async getStatus(): Promise<PlaybackStatus> {
    this.ensureProvider()
    
    try {
      const status = await this.provider!.getStatus()
      
      this.emitEvent('status_updated', {
        type: 'status_updated',
        provider: this.providerType!,
        data: status,
        timestamp: new Date()
      })
      
      return status
    } catch (error: any) {
      throw new MediaPlayerProviderError(
        `Get status failed: ${error.message}`,
        this.providerType!,
        'STATUS_FAILED',
        error
      )
    }
  }

  /**
   * 检查是否正在播放
   */
  public async isPlaying(): Promise<boolean> {
    this.ensureProvider()
    
    try {
      return await this.provider!.isPlaying()
    } catch (error: any) {
      throw new MediaPlayerProviderError(
        `Is playing check failed: ${error.message}`,
        this.providerType!,
        'IS_PLAYING_FAILED',
        error
      )
    }
  }

  // ==================== 信息获取 ====================

  /**
   * 获取播放器信息
   */
  public getPlayerInfo() {
    if (!this.provider) {
      return {
        name: 'none',
        version: 'N/A',
        available: false,
        supportedFormats: [],
        type: this.providerType
      }
    }
    
    return {
      ...this.provider.getPlayerInfo(),
      type: this.providerType
    }
  }

  // ==================== 事件处理 ====================

  /**
   * 监听事件
   */
  public on(event: string, listener: (data: ProviderEvent) => void): this {
    this.eventEmitter.on(event, listener)
    return this
  }

  /**
   * 取消监听事件
   */
  public off(event: string, listener: (data: ProviderEvent) => void): this {
    this.eventEmitter.off(event, listener)
    return this
  }

  /**
   * 监听播放器状态变化
   * 自动轮询状态更新
   */
  public startStatusMonitoring(interval: number = 1000): void {
    if (!this.provider) return
    
    const statusInterval = setInterval(async () => {
      try {
        const status = await this.getStatus()
        
        this.emitEvent('status_monitor', {
          type: 'status_monitor',
          provider: this.providerType!,
          data: status,
          timestamp: new Date()
        })
      } catch (error) {
        // 忽略监控过程中的错误，避免spam
      }
    }, interval)
    
    // 存储interval ID用于清理
    this.eventEmitter.emit('monitoring_started', statusInterval)
  }

  /**
   * 停止状态监控
   */
  public stopStatusMonitoring(): void {
    this.eventEmitter.emit('stop_monitoring')
  }

  // ==================== 私有方法 ====================

  private ensureProvider(): void {
    if (!this.provider) {
      throw new MediaPlayerProviderError(
        'No media player provider configured',
        'none',
        'NO_PROVIDER'
      )
    }
  }

  private emitEvent(type: string, event: ProviderEvent): void {
    this.eventEmitter.emit(type, event)
  }

  /**
   * 创建指定类型的Provider
   */
  private createProvider(type: MediaPlayerProviderType): IMediaPlayerProvider {
    // 简单的工厂方法，实际使用时可以通过依赖注入或工厂类实现
    switch (type) {
      case 'mpv':
        // 动态导入MPV Provider
        const { MPVPlayerProvider } = require('./providers/player/mpv-provider')
        return new MPVPlayerProvider()
      
      case 'vlc':
        // 动态导入VLC Provider
        const { VLCPlayerProvider } = require('./providers/player/vlc-provider')
        return new VLCPlayerProvider()
      
      case 'browser':
        // 动态导入Browser Provider
        const { BrowserPlayerProvider } = require('./providers/player/browser-provider')
        return new BrowserPlayerProvider()
      
      case 'system':
        // 动态导入System Provider
        const { SystemPlayerProvider } = require('./providers/player/system-provider')
        return new SystemPlayerProvider()
      
      default:
        throw new MediaPlayerProviderError(
          `Unsupported player provider: ${type}`,
          type,
          'UNSUPPORTED_PROVIDER'
        )
    }
  }
}
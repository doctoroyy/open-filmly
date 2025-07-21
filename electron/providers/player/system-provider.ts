/**
 * 系统默认媒体播放器提供者
 * 使用操作系统默认的媒体播放器
 */

import { spawn } from 'child_process'
import {
  IMediaPlayerProvider,
  MediaPlayerConfig,
  PlaybackOptions,
  PlaybackStatus,
  MediaPlayerProviderError
} from '../../types/providers'

export class SystemPlayerProvider implements IMediaPlayerProvider {
  private config: MediaPlayerConfig | null = null

  // ==================== Provider接口实现 ====================

  /**
   * 配置系统播放器（基本上无需配置）
   */
  public configure(config: MediaPlayerConfig): void {
    this.config = { ...config }
    console.log('[SystemPlayerProvider] Configured')
  }

  /**
   * 获取当前配置
   */
  public getConfiguration(): MediaPlayerConfig | null {
    return this.config
  }

  /**
   * 播放媒体文件（使用系统默认程序打开）
   */
  public async play(options: PlaybackOptions): Promise<void> {
    try {
      let command: string
      let args: string[]

      // 根据平台选择打开命令
      switch (process.platform) {
        case 'darwin':
          command = 'open'
          args = [options.url]
          break
        case 'win32':
          command = 'start'
          args = ['', options.url] // start命令需要第一个参数为窗口标题
          break
        default: // linux
          command = 'xdg-open'
          args = [options.url]
          break
      }

      console.log(`[SystemPlayerProvider] Playing: ${options.url} with ${command}`)
      
      const childProcess = spawn(command, args, {
        stdio: 'ignore',
        detached: true
      })

      // 让子进程独立运行
      childProcess.unref()

      // 等待一小段时间确保命令执行
      await new Promise(resolve => setTimeout(resolve, 100))

    } catch (error: any) {
      throw new MediaPlayerProviderError(
        `System player failed: ${error.message}`,
        'system',
        'PLAYBACK_FAILED',
        error
      )
    }
  }

  /**
   * 暂停播放（系统播放器通常不支持外部控制）
   */
  public async pause(): Promise<void> {
    console.warn('[SystemPlayerProvider] Pause not supported by system player')
  }

  /**
   * 停止播放（系统播放器通常不支持外部控制）
   */
  public async stop(): Promise<void> {
    console.warn('[SystemPlayerProvider] Stop not supported by system player')
  }

  /**
   * 跳转到指定位置（系统播放器通常不支持外部控制）
   */
  public async seek(position: number): Promise<void> {
    console.warn('[SystemPlayerProvider] Seek not supported by system player')
  }

  /**
   * 设置音量（系统播放器通常不支持外部控制）
   */
  public async setVolume(volume: number): Promise<void> {
    console.warn('[SystemPlayerProvider] Volume control not supported by system player')
  }

  /**
   * 获取播放状态（系统播放器无法获取状态）
   */
  public async getStatus(): Promise<PlaybackStatus> {
    return {
      isPlaying: false // 无法确定系统播放器状态
    }
  }

  /**
   * 检查是否正在播放（系统播放器无法获取状态）
   */
  public async isPlaying(): Promise<boolean> {
    return false // 无法确定系统播放器状态
  }

  /**
   * 检查提供者是否可用（系统播放器总是可用）
   */
  public isAvailable(): boolean {
    return true
  }

  /**
   * 获取播放器信息
   */
  public getPlayerInfo(): { name: string; version: string; available: boolean; supportedFormats: string[]; [key: string]: any } {
    return {
      name: 'System Default Player',
      version: 'N/A',
      available: true,
      supportedFormats: [
        // 系统播放器支持的格式取决于系统安装的编解码器
        'mp4', 'mkv', 'avi', 'mov', 'wmv', 'm4v', 
        'mp3', 'aac', 'wav', 'm4a'
      ],
      platform: process.platform,
      description: 'Uses the operating system default media player'
    }
  }
}
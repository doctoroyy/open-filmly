/**
 * MPV媒体播放器提供者实现
 * 使用MPV可执行文件进行媒体播放的Provider实现
 */

import { spawn, ChildProcess } from 'child_process'
import * as path from 'path'
import * as fs from 'fs'
import * as os from 'os'
import {
  IMediaPlayerProvider,
  MediaPlayerConfig,
  PlaybackOptions,
  PlaybackStatus,
  MediaPlayerProviderError
} from '../../types/providers'

// MPV特定的配置接口
interface MPVConfig extends MediaPlayerConfig {
  mpvPath?: string
  extraArgs?: string[]
  enableIPC?: boolean
  ipcSocket?: string
}

// MPV进程状态
interface MPVProcessInfo {
  process: ChildProcess | null
  isRunning: boolean
  currentFile?: string
  startTime?: Date
}

/**
 * MPV媒体播放器提供者
 * 通过MPV可执行文件实现媒体播放支持
 */
export class MPVPlayerProvider implements IMediaPlayerProvider {
  private config: MPVConfig | null = null
  private mpvPath: string | null = null
  private processInfo: MPVProcessInfo = {
    process: null,
    isRunning: false
  }
  
  constructor() {
    this.initializeMPVPath()
  }

  // ==================== Provider接口实现 ====================

  /**
   * 配置MPV播放器参数
   */
  public configure(config: MediaPlayerConfig): void {
    this.config = { ...config } as MPVConfig
    
    // 如果提供了自定义MPV路径，使用它
    if (this.config.mpvPath && fs.existsSync(this.config.mpvPath)) {
      this.mpvPath = this.config.mpvPath
    }
    
    console.log(`[MPVPlayerProvider] Configured with MPV at: ${this.mpvPath}`)
  }

  /**
   * 获取当前配置
   */
  public getConfiguration(): MediaPlayerConfig | null {
    return this.config
  }

  /**
   * 播放媒体文件
   */
  public async play(options: PlaybackOptions): Promise<void> {
    if (!this.isAvailable()) {
      throw new MediaPlayerProviderError('MPV binary not available', 'mpv', 'BINARY_NOT_FOUND')
    }

    // 停止当前播放
    if (this.processInfo.isRunning) {
      await this.stop()
    }

    try {
      const args = this.buildMPVArgs(options)
      
      console.log(`[MPVPlayerProvider] Starting playback: ${options.url}`)
      console.log(`[MPVPlayerProvider] MPV args:`, args)
      
      const mpvProcess = spawn(this.mpvPath!, args, {
        stdio: ['pipe', 'pipe', 'pipe'],
        detached: false
      })

      this.processInfo = {
        process: mpvProcess,
        isRunning: true,
        currentFile: options.url,
        startTime: new Date()
      }

      // 监听进程事件
      mpvProcess.on('error', (error) => {
        console.error('[MPVPlayerProvider] Process error:', error)
        this.processInfo.isRunning = false
        this.processInfo.process = null
      })

      mpvProcess.on('exit', (code, signal) => {
        console.log(`[MPVPlayerProvider] Process exited with code: ${code}, signal: ${signal}`)
        this.processInfo.isRunning = false
        this.processInfo.process = null
        this.processInfo.currentFile = undefined
      })

      // 监听stdout和stderr用于调试
      mpvProcess.stdout?.on('data', (data) => {
        console.log(`[MPVPlayerProvider] stdout: ${data.toString().trim()}`)
      })

      mpvProcess.stderr?.on('data', (data) => {
        console.error(`[MPVPlayerProvider] stderr: ${data.toString().trim()}`)
      })

      // 等待一小段时间确保进程启动
      await new Promise(resolve => setTimeout(resolve, 500))

      if (!this.processInfo.isRunning || !this.processInfo.process) {
        throw new MediaPlayerProviderError(
          'Failed to start MPV process',
          'mpv',
          'PROCESS_START_FAILED'
        )
      }

    } catch (error: any) {
      this.processInfo.isRunning = false
      this.processInfo.process = null
      
      if (error instanceof MediaPlayerProviderError) {
        throw error
      }
      throw new MediaPlayerProviderError(
        `MPV playback failed: ${error.message}`,
        'mpv',
        'PLAYBACK_FAILED',
        error
      )
    }
  }

  /**
   * 暂停播放
   */
  public async pause(): Promise<void> {
    if (!this.processInfo.isRunning || !this.processInfo.process) {
      throw new MediaPlayerProviderError('No active playback to pause', 'mpv', 'NO_ACTIVE_PLAYBACK')
    }

    try {
      // MPV使用空格键暂停/恢复
      this.processInfo.process.stdin?.write(' ')
      console.log('[MPVPlayerProvider] Pause/resume toggled')
    } catch (error: any) {
      throw new MediaPlayerProviderError(
        `Pause failed: ${error.message}`,
        'mpv',
        'PAUSE_FAILED',
        error
      )
    }
  }

  /**
   * 停止播放
   */
  public async stop(): Promise<void> {
    if (!this.processInfo.isRunning || !this.processInfo.process) {
      console.log('[MPVPlayerProvider] No active playback to stop')
      return
    }

    try {
      // 发送退出命令
      this.processInfo.process.stdin?.write('q')
      
      // 等待进程结束
      await new Promise(resolve => {
        const timeout = setTimeout(() => {
          if (this.processInfo.process && !this.processInfo.process.killed) {
            this.processInfo.process.kill('SIGTERM')
          }
          resolve(undefined)
        }, 3000)
        
        this.processInfo.process?.on('exit', () => {
          clearTimeout(timeout)
          resolve(undefined)
        })
      })

      this.processInfo = {
        process: null,
        isRunning: false
      }
      
      console.log('[MPVPlayerProvider] Playback stopped')
    } catch (error: any) {
      throw new MediaPlayerProviderError(
        `Stop failed: ${error.message}`,
        'mpv',
        'STOP_FAILED',
        error
      )
    }
  }

  /**
   * 跳转到指定位置（秒）
   */
  public async seek(position: number): Promise<void> {
    if (!this.processInfo.isRunning || !this.processInfo.process) {
      throw new MediaPlayerProviderError('No active playback to seek', 'mpv', 'NO_ACTIVE_PLAYBACK')
    }

    try {
      // MPV seek命令格式: seek <position> <type>
      // type: 0=relative, 1=percentage, 2=absolute
      const seekCommand = `seek ${position} 2\n`
      this.processInfo.process.stdin?.write(seekCommand)
      console.log(`[MPVPlayerProvider] Seeking to position: ${position}s`)
    } catch (error: any) {
      throw new MediaPlayerProviderError(
        `Seek failed: ${error.message}`,
        'mpv',
        'SEEK_FAILED',
        error
      )
    }
  }

  /**
   * 设置音量（0-100）
   */
  public async setVolume(volume: number): Promise<void> {
    if (!this.processInfo.isRunning || !this.processInfo.process) {
      throw new MediaPlayerProviderError('No active playback to set volume', 'mpv', 'NO_ACTIVE_PLAYBACK')
    }

    if (volume < 0 || volume > 100) {
      throw new MediaPlayerProviderError(
        `Invalid volume: ${volume}. Must be between 0 and 100.`,
        'mpv',
        'INVALID_VOLUME'
      )
    }

    try {
      // MPV volume命令
      const volumeCommand = `set volume ${volume}\n`
      this.processInfo.process.stdin?.write(volumeCommand)
      console.log(`[MPVPlayerProvider] Volume set to: ${volume}%`)
    } catch (error: any) {
      throw new MediaPlayerProviderError(
        `Set volume failed: ${error.message}`,
        'mpv',
        'VOLUME_FAILED',
        error
      )
    }
  }

  /**
   * 获取播放状态
   */
  public async getStatus(): Promise<PlaybackStatus> {
    const status: PlaybackStatus = {
      isPlaying: this.processInfo.isRunning,
      duration: undefined,
      position: undefined,
      volume: undefined
    }

    if (this.processInfo.isRunning && this.processInfo.startTime) {
      // 简单的估算播放时间（实际应该通过IPC获取准确信息）
      const elapsed = (Date.now() - this.processInfo.startTime.getTime()) / 1000
      status.position = elapsed
    }

    return status
  }

  /**
   * 检查是否正在播放
   */
  public async isPlaying(): Promise<boolean> {
    return this.processInfo.isRunning
  }

  /**
   * 检查提供者是否可用
   */
  public isAvailable(): boolean {
    return this.mpvPath !== null && fs.existsSync(this.mpvPath)
  }

  /**
   * 获取播放器信息
   */
  public getPlayerInfo(): { name: string; version: string; available: boolean; supportedFormats: string[]; [key: string]: any } {
    return {
      name: 'MPV Player',
      version: 'Unknown', // 可以通过执行 mpv --version 获取
      available: this.isAvailable(),
      supportedFormats: [
        // MPV支持的主要视频格式
        'mp4', 'mkv', 'avi', 'mov', 'wmv', 'm4v', 'flv', 'webm',
        // 音频格式
        'mp3', 'flac', 'aac', 'ogg', 'wav', 'm4a',
        // 流媒体协议
        'http', 'https', 'rtmp', 'rtsp'
      ],
      binaryPath: this.mpvPath,
      platform: process.platform,
      processInfo: {
        isRunning: this.processInfo.isRunning,
        currentFile: this.processInfo.currentFile,
        startTime: this.processInfo.startTime
      }
    }
  }

  // ==================== 私有方法 ====================

  /**
   * 初始化MPV可执行文件路径
   */
  private initializeMPVPath(): void {
    const platform = process.platform
    const extension = platform === 'win32' ? '.exe' : ''
    const binaryName = `mpv${extension}`

    // 查找MPV的可能路径
    const possiblePaths = [
      // 系统PATH中的mpv
      binaryName,
      // 常见安装路径
      ...(platform === 'win32' ? [
        'C:\\Program Files\\mpv\\mpv.exe',
        'C:\\Program Files (x86)\\mpv\\mpv.exe',
        path.join(os.homedir(), 'AppData', 'Local', 'mpv', 'mpv.exe')
      ] : []),
      ...(platform === 'darwin' ? [
        '/usr/local/bin/mpv',
        '/opt/homebrew/bin/mpv',
        '/Applications/mpv.app/Contents/MacOS/mpv'
      ] : []),
      ...(platform === 'linux' ? [
        '/usr/bin/mpv',
        '/usr/local/bin/mpv',
        '/snap/bin/mpv',
        '/var/lib/flatpak/exports/bin/io.mpv.Mpv'
      ] : []),
      // 项目本地目录
      path.join(__dirname, '..', '..', 'bin', binaryName),
      path.join(process.cwd(), 'bin', binaryName)
    ]

    for (const mpvPath of possiblePaths) {
      try {
        if (mpvPath === binaryName) {
          // 对于系统PATH中的命令，使用which/where命令检查
          continue // 简化处理，假设在PATH中存在
        } else if (fs.existsSync(mpvPath)) {
          this.mpvPath = mpvPath
          console.log(`[MPVPlayerProvider] Found MPV at: ${mpvPath}`)
          return
        }
      } catch (error) {
        // 忽略检查错误
      }
    }

    // 如果没有找到具体路径，假设系统PATH中有mpv
    this.mpvPath = binaryName
    console.log(`[MPVPlayerProvider] Using MPV from system PATH: ${binaryName}`)
  }

  /**
   * 构建MPV命令行参数
   */
  private buildMPVArgs(options: PlaybackOptions): string[] {
    const args: string[] = []

    // 基础参数
    args.push('--no-terminal') // 不显示终端输出
    args.push('--force-window=yes') // 强制显示窗口
    
    // 全屏设置
    if (options.fullscreen) {
      args.push('--fullscreen=yes')
    }

    // 起始时间
    if (options.startTime && options.startTime > 0) {
      args.push(`--start=${options.startTime}`)
    }

    // 音量设置
    if (options.volume !== undefined) {
      args.push(`--volume=${Math.max(0, Math.min(100, options.volume))}`)
    }

    // 字幕文件
    if (options.subtitle) {
      args.push(`--sub-file=${options.subtitle}`)
    }

    // 自定义参数
    if (this.config?.extraArgs) {
      args.push(...this.config.extraArgs)
    }

    // 启用IPC（如果配置了）
    if (this.config?.enableIPC) {
      const socketPath = this.config.ipcSocket || path.join(os.tmpdir(), `mpv-socket-${Date.now()}`)
      args.push(`--input-ipc-server=${socketPath}`)
    }

    // 媒体文件URL（必须放在最后）
    args.push(options.url)

    return args
  }
}
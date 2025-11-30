import { spawn, ChildProcess } from 'child_process'
import * as path from 'path'
import * as fs from 'fs'
import {
  IMediaPlayerProvider,
  MediaPlayerConfig,
  PlaybackOptions,
  PlaybackStatus,
  MediaPlayerProviderError
} from '../../types/providers'

export class VLCPlayerProvider implements IMediaPlayerProvider {
  private config: MediaPlayerConfig | null = null
  private vlcProcess: ChildProcess | null = null
  private binaryPath: string | null = null

  constructor() {
    this.findBinary()
  }

  // ==================== Provider接口实现 ====================

  public configure(config: MediaPlayerConfig): void {
    this.config = { ...config }
    console.log('[VLCPlayerProvider] Configured')
  }

  public getConfiguration(): MediaPlayerConfig | null {
    return this.config
  }

  public async play(options: PlaybackOptions): Promise<void> {
    if (!this.binaryPath) {
      this.findBinary()
      if (!this.binaryPath) {
        throw new MediaPlayerProviderError(
          'VLC binary not found',
          'vlc',
          'BINARY_NOT_FOUND'
        )
      }
    }

    try {
      // 停止当前播放
      await this.stop()

      const args = [
        options.url,
        '--no-video-title-show', // 不显示标题
        '--play-and-exit',       // 播放完退出 (可选，看需求)
        '--fullscreen'           // 全屏
      ]

      console.log(`[VLCPlayerProvider] Playing: ${options.url} with ${this.binaryPath}`)
      
      this.vlcProcess = spawn(this.binaryPath, args, {
        stdio: 'ignore',
        detached: false // 不分离，以便我们可以控制它
      })

      this.vlcProcess.on('error', (err) => {
        console.error('[VLCPlayerProvider] Process error:', err)
      })

      this.vlcProcess.on('exit', (code, signal) => {
        console.log(`[VLCPlayerProvider] Process exited with code ${code} and signal ${signal}`)
        this.vlcProcess = null
      })

    } catch (error: any) {
      throw new MediaPlayerProviderError(
        `VLC player failed: ${error.message}`,
        'vlc',
        'PLAYBACK_FAILED',
        error
      )
    }
  }

  public async pause(): Promise<void> {
    // VLC CLI control is complex without RC interface. 
    // For now, we might not support pause via IPC unless we use RC.
    console.warn('[VLCPlayerProvider] Pause not implemented (requires RC interface)')
  }

  public async stop(): Promise<void> {
    if (this.vlcProcess) {
      this.vlcProcess.kill()
      this.vlcProcess = null
    }
  }

  public async seek(position: number): Promise<void> {
    console.warn('[VLCPlayerProvider] Seek not implemented')
  }

  public async setVolume(volume: number): Promise<void> {
    console.warn('[VLCPlayerProvider] Volume control not implemented')
  }

  public async getStatus(): Promise<PlaybackStatus> {
    return {
      isPlaying: !!this.vlcProcess
    }
  }

  public async isPlaying(): Promise<boolean> {
    return !!this.vlcProcess
  }

  public isAvailable(): boolean {
    return !!this.binaryPath
  }

  public getPlayerInfo() {
    return {
      name: 'VLC Media Player',
      version: 'Unknown',
      available: this.isAvailable(),
      supportedFormats: ['mp4', 'mkv', 'avi', 'mov', 'wmv', 'm4v'],
      binaryPath: this.binaryPath
    }
  }

  // ==================== 私有方法 ====================

  private findBinary() {
    const platform = process.platform
    const arch = process.arch
    const possiblePaths: string[] = []
    let appName = ''
    const systemPaths: string[] = []

    if (platform === 'darwin') {
      appName = 'VLC.app'
      systemPaths.push('/Applications/VLC.app/Contents/MacOS/VLC')
    } else if (platform === 'win32') {
      appName = 'vlc.exe'
      systemPaths.push(
        'C:\\Program Files\\VideoLAN\\VLC\\vlc.exe',
        'C:\\Program Files (x86)\\VideoLAN\\VLC\\vlc.exe'
      )
    } else { // Linux
      appName = 'vlc'
      systemPaths.push('/usr/bin/vlc')
    }

    // 1. Check in resources/bin (standard production path)
    const resourceBin = path.join(process.resourcesPath, 'bin')
    // 2. Check in app.asar.unpacked/bin (for unpacked Electron apps)
    const unpackedBin = path.join(process.resourcesPath, 'app.asar.unpacked', 'bin')
    // 3. Check in current working directory (dev mode)
    const localBin = path.join(process.cwd(), 'bin')
    // 4. Check in tools/bin (dev mode fallback)
    const toolsBin = path.join(process.cwd(), 'tools', 'bin')
    
    const basePathsToCheck = [
      resourceBin,
      unpackedBin,
      localBin,
      toolsBin
    ]

    for (const basePath of basePathsToCheck) {
      if (platform === 'darwin') {
        // macOS: VLC.app/Contents/MacOS/VLC
        possiblePaths.push(
          path.join(basePath, 'darwin', arch, appName, 'Contents', 'MacOS', 'VLC'),
          path.join(basePath, 'darwin', 'x64', appName, 'Contents', 'MacOS', 'VLC'), // Fallback to x64 on arm64 (Rosetta)
          path.join(basePath, appName, 'Contents', 'MacOS', 'VLC') // Legacy flat path
        )
      } else if (platform === 'win32') {
        // Windows: vlc.exe
        possiblePaths.push(
          path.join(basePath, 'win32', arch, appName),
          path.join(basePath, appName) // Legacy flat path
        )
      } else { // Linux
        // Linux: vlc
        possiblePaths.push(
          path.join(basePath, 'linux', arch, appName),
          path.join(basePath, appName) // Legacy flat path
        )
      }
    }

    // Add system-wide paths as a final fallback
    possiblePaths.push(...systemPaths)

    console.log('[VLCPlayerProvider] Looking for binary in:', possiblePaths)

    for (const p of possiblePaths) {
      if (fs.existsSync(p)) {
        this.binaryPath = p
        console.log('[VLCPlayerProvider] Found binary at:', p)
        
        // Ensure executable permissions on Unix-like systems
        if (process.platform !== 'win32') {
          try {
            fs.chmodSync(p, 0o755)
            console.log('[VLCPlayerProvider] Set executable permissions for:', p)
          } catch (error) {
            console.warn('[VLCPlayerProvider] Failed to set permissions:', error)
          }
        }
        
        return
      }
    }

    console.warn('[VLCPlayerProvider] Binary not found')
    this.binaryPath = null
  }
}

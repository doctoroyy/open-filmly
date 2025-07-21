/**
 * MPV Player Client - Controls MPV via Go binary
 */

import { spawn } from 'child_process'
import * as path from 'path'
import * as fs from 'fs'

export interface MPVPlayOptions {
  filePath: string
  title?: string
  startTime?: number
  volume?: number
  fullscreen?: boolean
  subtitles?: string
  windowTitle?: string
}

export interface MPVInfo {
  available: boolean
  version?: string
  path?: string
  error?: string
}

export interface PlayResult {
  success: boolean
  pid?: number
  error?: string
}

export interface StatusResult {
  isPlaying: boolean
  pid?: number
}

export class MPVPlayerClient {
  private binaryPath: string | null = null

  constructor() {
    this.initializeBinary()
  }

  /**
   * Find and initialize the MPV player binary
   */
  private initializeBinary(): void {
    const platform = process.platform
    const arch = process.arch

    // Normalize architecture
    const normalizedArch = arch === 'x64' ? 'amd64' : arch

    const binaryName = `mpv-player-${platform}-${normalizedArch}`
    
    // Search paths for the binary
    const searchPaths = [
      path.join(__dirname, '..', 'bin', binaryName),
      path.join(process.cwd(), 'bin', binaryName),
      path.join(__dirname, '..', '..', 'bin', binaryName),
      path.join(process.resourcesPath || '', 'bin', binaryName)
    ]

    console.log(`[MPVPlayerClient] Looking for binary: ${binaryName}`)
    console.log('[MPVPlayerClient] Search paths:', searchPaths)

    for (const searchPath of searchPaths) {
      try {
        if (fs.existsSync(searchPath) && fs.statSync(searchPath).isFile()) {
          this.binaryPath = searchPath
          console.log(`[MPVPlayerClient] Found binary at: ${searchPath}`)
          return
        }
      } catch (error) {
        // Continue searching
      }
    }

    console.warn('[MPVPlayerClient] MPV player binary not found')
  }

  /**
   * Check if MPV player is available
   */
  public isAvailable(): boolean {
    return this.binaryPath !== null
  }

  /**
   * Get MPV player information
   */
  public async getInfo(): Promise<MPVInfo> {
    if (!this.binaryPath) {
      return { available: false, error: 'MPV player binary not found' }
    }

    return new Promise((resolve) => {
      const proc = spawn(this.binaryPath!, ['info'], { stdio: 'pipe' })
      let output = ''

      proc.stdout?.on('data', (data) => {
        output += data.toString()
      })

      proc.on('close', (code) => {
        try {
          const info: MPVInfo = JSON.parse(output)
          resolve(info)
        } catch (error) {
          resolve({ available: false, error: 'Failed to parse MPV info' })
        }
      })

      proc.on('error', (error) => {
        resolve({ available: false, error: error.message })
      })

      // Timeout after 5 seconds
      setTimeout(() => {
        proc.kill()
        resolve({ available: false, error: 'Timeout getting MPV info' })
      }, 5000)
    })
  }

  /**
   * Play media file
   */
  public async play(options: MPVPlayOptions): Promise<PlayResult> {
    if (!this.binaryPath) {
      return { success: false, error: 'MPV player binary not found' }
    }

    const requestJson = JSON.stringify(options)

    return new Promise((resolve) => {
      const proc = spawn(this.binaryPath!, ['play', requestJson], { stdio: 'pipe' })
      let output = ''

      proc.stdout?.on('data', (data) => {
        output += data.toString()
      })

      proc.on('close', (code) => {
        try {
          const result: PlayResult = JSON.parse(output)
          resolve(result)
        } catch (error) {
          resolve({ success: false, error: 'Failed to parse play result' })
        }
      })

      proc.on('error', (error) => {
        resolve({ success: false, error: error.message })
      })

      // Timeout after 10 seconds
      setTimeout(() => {
        proc.kill()
        resolve({ success: false, error: 'Timeout starting playback' })
      }, 10000)
    })
  }

  /**
   * Get player status
   */
  public async getStatus(): Promise<StatusResult> {
    if (!this.binaryPath) {
      return { isPlaying: false }
    }

    return new Promise((resolve) => {
      const proc = spawn(this.binaryPath!, ['status'], { stdio: 'pipe' })
      let output = ''

      proc.stdout?.on('data', (data) => {
        output += data.toString()
      })

      proc.on('close', (code) => {
        try {
          const status: StatusResult = JSON.parse(output)
          resolve(status)
        } catch (error) {
          resolve({ isPlaying: false })
        }
      })

      proc.on('error', (error) => {
        resolve({ isPlaying: false })
      })

      // Timeout after 3 seconds
      setTimeout(() => {
        proc.kill()
        resolve({ isPlaying: false })
      }, 3000)
    })
  }

  /**
   * Stop current playback
   */
  public async stop(): Promise<PlayResult> {
    if (!this.binaryPath) {
      return { success: false, error: 'MPV player binary not found' }
    }

    return new Promise((resolve) => {
      const proc = spawn(this.binaryPath!, ['stop'], { stdio: 'pipe' })
      let output = ''

      proc.stdout?.on('data', (data) => {
        output += data.toString()
      })

      proc.on('close', (code) => {
        try {
          const result: PlayResult = JSON.parse(output)
          resolve(result)
        } catch (error) {
          resolve({ success: true }) // Assume success if we can't parse
        }
      })

      proc.on('error', (error) => {
        resolve({ success: false, error: error.message })
      })

      // Timeout after 5 seconds
      setTimeout(() => {
        proc.kill()
        resolve({ success: false, error: 'Timeout stopping playback' })
      }, 5000)
    })
  }

  /**
   * Check if currently playing
   */
  public async isPlaying(): Promise<boolean> {
    const status = await this.getStatus()
    return status.isPlaying
  }

  /**
   * Find subtitle files for a video file
   */
  public findSubtitles(videoPath: string): string[] {
    const subtitles: string[] = []
    const videoDir = path.dirname(videoPath)
    const videoName = path.basename(videoPath, path.extname(videoPath))
    
    const subtitleExtensions = ['.srt', '.ass', '.ssa', '.sub', '.vtt']
    
    try {
      const files = fs.readdirSync(videoDir)
      
      for (const file of files) {
        const ext = path.extname(file).toLowerCase()
        if (subtitleExtensions.includes(ext)) {
          const baseName = path.basename(file, ext)
          if (baseName.includes(videoName) || videoName.includes(baseName)) {
            subtitles.push(path.join(videoDir, file))
          }
        }
      }
    } catch (error) {
      console.warn('[MPVPlayerClient] Could not scan for subtitles:', error)
    }
    
    return subtitles
  }
}
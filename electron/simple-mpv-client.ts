/**
 * Simple MPV Player Client - Direct system MPV integration
 * Uses spawn to launch system MPV player
 */

import { spawn, ChildProcess } from 'child_process'
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

export class SimpleMPVClient {
  private currentProcess: ChildProcess | null = null
  private mpvPath: string | null = null

  constructor() {
    this.findMPV()
  }

  /**
   * Find system MPV installation
   */
  private async findMPV(): Promise<void> {
    const possiblePaths = [
      'mpv', // System PATH
      '/usr/local/bin/mpv',
      '/usr/bin/mpv',
      '/opt/homebrew/bin/mpv',
      '/Applications/mpv.app/Contents/MacOS/mpv'
    ]

    for (const mpvPath of possiblePaths) {
      try {
        // Test if mpv works by getting version
        const { spawn } = require('child_process')
        const proc = spawn(mpvPath, ['--version'], { stdio: 'pipe' })
        
        await new Promise((resolve, reject) => {
          let output = ''
          proc.stdout?.on('data', (data: Buffer) => {
            output += data.toString()
          })
          
          proc.on('close', (code: number) => {
            if (code === 0 && output.includes('mpv')) {
              this.mpvPath = mpvPath
              console.log(`[SimpleMPV] Found MPV at: ${mpvPath}`)
              resolve(true)
            } else {
              reject(new Error(`MPV test failed: code ${code}`))
            }
          })
          
          proc.on('error', reject)
          
          // Timeout
          setTimeout(() => {
            proc.kill()
            reject(new Error('Timeout'))
          }, 3000)
        })
        
        // If we get here, MPV was found
        return
      } catch (error) {
        // Continue to next path
      }
    }

    console.warn('[SimpleMPV] MPV not found in system')
  }

  /**
   * Check if MPV is available
   */
  public isAvailable(): boolean {
    return this.mpvPath !== null
  }

  /**
   * Get MPV information
   */
  public async getInfo(): Promise<MPVInfo> {
    if (!this.mpvPath) {
      return { 
        available: false, 
        error: 'MPV not found. Please install MPV: brew install mpv (macOS) or apt install mpv (Linux)' 
      }
    }

    try {
      const proc = spawn(this.mpvPath, ['--version'], { stdio: 'pipe' })
      let output = ''

      return new Promise((resolve) => {
        proc.stdout?.on('data', (data) => {
          output += data.toString()
        })

        proc.on('close', (code) => {
          if (code === 0 && output.includes('mpv')) {
            const lines = output.split('\n')
            const version = lines[0]?.split(' ')[1] || 'unknown'
            
            resolve({
              available: true,
              version,
              path: this.mpvPath!
            })
          } else {
            resolve({ available: false, error: 'MPV version check failed' })
          }
        })

        proc.on('error', (error) => {
          resolve({ available: false, error: error.message })
        })

        setTimeout(() => {
          proc.kill()
          resolve({ available: false, error: 'Timeout getting MPV info' })
        }, 5000)
      })
    } catch (error) {
      return { available: false, error: (error as Error).message }
    }
  }

  /**
   * Play media file
   */
  public async play(options: MPVPlayOptions): Promise<{ success: boolean; error?: string }> {
    if (!this.mpvPath) {
      return { 
        success: false, 
        error: 'MPV not found. Please install MPV: brew install mpv (macOS) or apt install mpv (Linux)' 
      }
    }

    // Stop any current playback
    if (this.currentProcess) {
      this.stop()
    }

    try {
      const args = this.buildMPVArgs(options)
      
      console.log(`[SimpleMPV] Playing: ${options.filePath}`)
      console.log(`[SimpleMPV] Args:`, args)

      this.currentProcess = spawn(this.mpvPath, args, {
        stdio: ['ignore', 'pipe', 'pipe'],
        detached: false
      })

      // Handle process events
      this.currentProcess.on('spawn', () => {
        console.log('[SimpleMPV] MPV started successfully')
      })

      this.currentProcess.on('error', (error) => {
        console.error('[SimpleMPV] Process error:', error)
        this.currentProcess = null
      })

      this.currentProcess.on('exit', (code, signal) => {
        console.log(`[SimpleMPV] Process exited: code=${code}, signal=${signal}`)
        this.currentProcess = null
      })

      // Optional: log stderr for debugging
      this.currentProcess.stderr?.on('data', (data) => {
        const message = data.toString().trim()
        if (message && !message.includes('libva')) {
          console.log(`[SimpleMPV] ${message}`)
        }
      })

      return { success: true }

    } catch (error) {
      console.error('[SimpleMPV] Failed to start MPV:', error)
      return { success: false, error: (error as Error).message }
    }
  }

  /**
   * Stop current playback
   */
  public stop(): void {
    if (this.currentProcess && !this.currentProcess.killed) {
      console.log('[SimpleMPV] Stopping playback')
      this.currentProcess.kill('SIGTERM')
      
      // Force kill after 2 seconds
      setTimeout(() => {
        if (this.currentProcess && !this.currentProcess.killed) {
          this.currentProcess.kill('SIGKILL')
        }
      }, 2000)
    }
    this.currentProcess = null
  }

  /**
   * Check if currently playing
   */
  public isPlaying(): boolean {
    return this.currentProcess !== null && !this.currentProcess.killed
  }

  /**
   * Build MPV arguments
   */
  private buildMPVArgs(options: MPVPlayOptions): string[] {
    const args: string[] = []

    // Basic playback options
    args.push('--player-operation-mode=pseudo-gui')
    args.push('--force-window=yes')
    args.push('--keep-open=yes')
    
    // Window title
    const title = options.windowTitle || options.title
    if (title) {
      args.push(`--title=${title}`)
    }

    // Fullscreen
    if (options.fullscreen) {
      args.push('--fullscreen')
    }

    // Start time
    if (options.startTime && options.startTime > 0) {
      args.push(`--start=${options.startTime}`)
    }

    // Volume
    if (options.volume !== undefined) {
      const vol = Math.max(0, Math.min(100, options.volume))
      args.push(`--volume=${vol}`)
    }

    // Subtitle file
    if (options.subtitles && fs.existsSync(options.subtitles)) {
      args.push(`--sub-file=${options.subtitles}`)
    }

    // Enable subtitle auto-loading
    args.push('--sub-auto=fuzzy')

    // Network options for SMB files
    if (options.filePath.startsWith('smb://') || options.filePath.startsWith('\\\\')) {
      args.push('--network-timeout=30')
      args.push('--cache=yes')
      args.push('--cache-secs=10')
    }

    // The file to play (must be last)
    args.push(options.filePath)

    return args
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
      console.warn('[SimpleMPV] Could not scan for subtitles:', error)
    }
    
    return subtitles
  }
}
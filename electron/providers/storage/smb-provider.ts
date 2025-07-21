/**
 * SMB存储提供者实现
 * 使用Go二进制文件进行SMB操作的Provider实现
 */

import { exec, spawn } from 'child_process'
import { promisify } from 'util'
import * as path from 'path'
import * as fs from 'fs'
import * as os from 'os'
import {
  INetworkStorageProvider,
  NetworkStorageConfig,
  StorageShareInfo,
  StorageDirectoryItem,
  MediaFile,
  StorageProviderError
} from '../../types/providers'

const execPromise = promisify(exec)

// SMB特定的配置接口
interface SMBConfig extends NetworkStorageConfig {
  domain?: string
}

// Go二进制文件的响应接口
interface GoDiscoveryResult {
  host: string
  port: number
  success: boolean
  shares: StorageShareInfo[]
  error?: string
  timestamp: string
}

interface GoDirectoryResult {
  path: string
  success: boolean
  items: StorageDirectoryItem[]
  error?: string
}

/**
 * SMB存储提供者
 * 通过Go二进制文件实现SMB协议支持
 */
export class SMBStorageProvider implements INetworkStorageProvider {
  private config: SMBConfig | null = null
  private binaryPath: string | null = null

  constructor() {
    this.initializeBinary()
  }

  // ==================== Provider接口实现 ====================

  /**
   * 配置SMB连接参数
   */
  public configure(config: NetworkStorageConfig): void {
    this.config = { ...config } as SMBConfig
    console.log(`[SMBStorageProvider] Configured for server: ${config.host}:${config.port || 445}`)
  }

  /**
   * 获取当前配置
   */
  public getConfiguration(): NetworkStorageConfig | null {
    return this.config
  }

  /**
   * 获取配置状态
   */
  public getConfigurationStatus(): { configured: boolean; hasSharePath: boolean; details: any } {
    return {
      configured: !!this.config,
      hasSharePath: !!(this.config?.sharePath && this.config.sharePath.trim() !== ''),
      details: {
        host: this.config?.host || 'not set',
        sharePath: this.config?.sharePath || 'not set',
        username: this.config?.username || 'not set',
        hasPassword: !!(this.config?.password && this.config.password.trim() !== ''),
        domain: this.config?.domain || 'WORKGROUP'
      }
    }
  }

  /**
   * 测试服务器连接
   */
  public async testConnection(): Promise<boolean> {
    if (!this.config?.host) {
      throw new StorageProviderError('Host address is required', 'smb', 'NO_HOST')
    }

    if (!this.isAvailable()) {
      throw new StorageProviderError('SMB binary not available', 'smb', 'BINARY_NOT_FOUND')
    }

    try {
      const args = ['test', this.config.host]
      if (this.config.port && this.config.port !== 445) {
        args.push(this.config.port.toString())
      }

      const result = await this.executeBinary(args)
      return result.success === true
    } catch (error: any) {
      console.error('[SMBStorageProvider] Connection test failed:', error.message)
      return false
    }
  }

  /**
   * 断开连接
   */
  public disconnect(): void {
    // Go二进制客户端是无状态的，所以不需要断开连接
    console.log('[SMBStorageProvider] Disconnect called (no-op for binary client)')
  }

  /**
   * 发现服务器上的共享资源
   */
  public async discoverShares(): Promise<StorageShareInfo[]> {
    if (!this.config?.host) {
      throw new StorageProviderError('Host address is required', 'smb', 'NO_HOST')
    }

    if (!this.isAvailable()) {
      throw new StorageProviderError('SMB binary not available', 'smb', 'BINARY_NOT_FOUND')
    }

    console.log(`[SMBStorageProvider] Discovering shares on ${this.config.host}`)

    try {
      const args = [
        'discover',
        this.config.host,
        this.config.username || 'guest',
        this.config.password || '',
        this.config.domain || 'WORKGROUP'
      ]

      if (this.config.port && this.config.port !== 445) {
        args.push(this.config.port.toString())
      }

      const result = await this.executeBinary(args) as GoDiscoveryResult

      if (result.success) {
        console.log(`[SMBStorageProvider] Found ${result.shares.length} shares:`, result.shares.map(s => s.name))
        return result.shares
      } else {
        throw new StorageProviderError(
          result.error || 'Unknown error during share discovery',
          'smb',
          'DISCOVERY_FAILED'
        )
      }
    } catch (error: any) {
      if (error instanceof StorageProviderError) {
        throw error
      }
      throw new StorageProviderError(
        `Share discovery failed: ${error.message}`,
        'smb',
        'DISCOVERY_ERROR',
        error
      )
    }
  }

  /**
   * 列出指定共享中的目录内容
   */
  public async listDirectory(shareName: string, directory: string = '/'): Promise<StorageDirectoryItem[]> {
    if (!this.config?.host) {
      throw new StorageProviderError('Host address is required', 'smb', 'NO_HOST')
    }

    if (!this.isAvailable()) {
      throw new StorageProviderError('SMB binary not available', 'smb', 'BINARY_NOT_FOUND')
    }

    console.log(`[SMBStorageProvider] Listing directory: ${shareName}/${directory}`)

    try {
      const args = [
        'list',
        this.config.host,
        shareName,
        directory === '/' ? '/' : directory,
        this.config.username || 'guest',
        this.config.password || '',
        this.config.domain || 'WORKGROUP'
      ]

      if (this.config.port && this.config.port !== 445) {
        args.push(this.config.port.toString())
      }

      const result = await this.executeBinary(args) as GoDirectoryResult

      if (result.success) {
        // 为每个项目添加完整路径
        const items = result.items.map(item => ({
          ...item,
          path: `${shareName}/${directory === '/' ? '' : directory + '/'}${item.name}`.replace(/\/+/g, '/')
        }))
        
        console.log(`[SMBStorageProvider] Found ${items.length} items in ${shareName}/${directory}`)
        return items
      } else {
        throw new StorageProviderError(
          result.error || 'Unknown error during directory listing',
          'smb',
          'LISTING_FAILED'
        )
      }
    } catch (error: any) {
      if (error instanceof StorageProviderError) {
        throw error
      }
      throw new StorageProviderError(
        `Directory listing failed: ${error.message}`,
        'smb',
        'LISTING_ERROR',
        error
      )
    }
  }

  /**
   * 读取文件内容
   */
  public async readFile(filePath: string): Promise<Buffer> {
    if (!this.config?.host) {
      throw new StorageProviderError('Host address is required', 'smb', 'NO_HOST')
    }

    if (!this.isAvailable()) {
      throw new StorageProviderError('SMB binary not available', 'smb', 'BINARY_NOT_FOUND')
    }

    // 解析文件路径以提取共享名和相对路径
    const pathParts = filePath.split('/').filter(Boolean)
    if (pathParts.length === 0) {
      throw new StorageProviderError('Invalid file path', 'smb', 'INVALID_PATH')
    }

    const shareName = pathParts[0]
    const relativeFilePath = pathParts.length > 1 ? pathParts.slice(1).join('/') : ''

    console.log(`[SMBStorageProvider] Reading file: ${shareName}/${relativeFilePath}`)

    try {
      const args = [
        'read',
        this.config.host,
        shareName,
        relativeFilePath,
        this.config.username || 'guest',
        this.config.password || '',
        this.config.domain || 'WORKGROUP'
      ]

      if (this.config.port && this.config.port !== 445) {
        args.push(this.config.port.toString())
      }

      const result = await this.executeBinary(args)

      if (result.success && result.data) {
        // 将base64数据转换为Buffer
        return Buffer.from(result.data, 'base64')
      } else {
        throw new StorageProviderError(
          result.error || 'Failed to read file',
          'smb',
          'FILE_READ_FAILED'
        )
      }
    } catch (error: any) {
      if (error instanceof StorageProviderError) {
        throw error
      }
      throw new StorageProviderError(
        `Error reading file ${filePath}: ${error.message}`,
        'smb',
        'FILE_READ_ERROR',
        error
      )
    }
  }

  /**
   * 扫描媒体文件
   */
  public async scanMediaFiles(directory: string): Promise<MediaFile[]> {
    if (!this.config?.host) {
      throw new StorageProviderError('Host address is required', 'smb', 'NO_HOST')
    }

    console.log(`[SMBStorageProvider] Scanning media files in: ${directory}`)

    const mediaFiles: MediaFile[] = []

    try {
      // 解析目录路径
      const pathParts = directory.split('/').filter(Boolean)
      if (pathParts.length === 0) {
        throw new StorageProviderError('Invalid directory path', 'smb', 'INVALID_PATH')
      }

      const shareName = pathParts[0]
      const relativePath = pathParts.length > 1 ? '/' + pathParts.slice(1).join('/') : '/'

      // 获取目录内容
      const items = await this.listDirectory(shareName, relativePath)

      for (const item of items) {
        if (item.isDirectory) {
          // 递归扫描子目录
          const subPath = `${directory}/${item.name}`
          try {
            const subFiles = await this.scanMediaFiles(subPath)
            mediaFiles.push(...subFiles)
          } catch (error) {
            console.error(`Error scanning subdirectory ${subPath}:`, error)
          }
        } else {
          // 检查是否为媒体文件
          const fileExt = path.extname(item.name).toLowerCase()
          const mediaExtensions = ['.mp4', '.mkv', '.avi', '.mov', '.wmv', '.m4v']

          if (mediaExtensions.includes(fileExt)) {
            const type = this.determineMediaType(`${directory}/${item.name}`, item.name)
            mediaFiles.push({
              path: `${directory}/${item.name}`,
              fullPath: `${directory}/${item.name}`,
              type,
              name: path.basename(item.name, fileExt),
              size: item.size,
              modifiedTime: item.modifiedTime
            })
          }
        }
      }

      return mediaFiles
    } catch (error: any) {
      if (error instanceof StorageProviderError) {
        throw error
      }
      throw new StorageProviderError(
        `Error scanning media files in ${directory}: ${error.message}`,
        'smb',
        'SCAN_ERROR',
        error
      )
    }
  }

  /**
   * 检查提供者是否可用
   */
  public isAvailable(): boolean {
    return this.binaryPath !== null && fs.existsSync(this.binaryPath)
  }

  /**
   * 获取提供者信息
   */
  public getProviderInfo(): { name: string; version: string; available: boolean; [key: string]: any } {
    return {
      name: 'SMB Storage Provider',
      version: '1.0.0',
      available: this.isAvailable(),
      binaryPath: this.binaryPath,
      supportedProtocols: ['smb', 'cifs'],
      platform: process.platform,
      arch: process.arch
    }
  }

  /**
   * 获取系统信息
   */
  public async getSystemInfo(): Promise<any> {
    const info = {
      platform: process.platform,
      arch: process.arch,
      nodeVersion: process.version,
      providerInfo: this.getProviderInfo(),
      config: this.config,
      searchPaths: [
        path.join(__dirname, '..', 'tools', 'smb-discover', 'bin'),
        path.join(process.resourcesPath, 'bin'),
        path.join(process.cwd(), 'bin'),
        path.join(__dirname, '..', 'bin')
      ]
    }

    console.log('[SMBStorageProvider] System info:', JSON.stringify(info, null, 2))
    return info
  }

  // ==================== 私有方法 ====================

  /**
   * 初始化Go二进制文件路径
   */
  private initializeBinary(): void {
    const platform = process.platform
    const arch = process.arch

    // 映射Node.js架构名称到Go架构名称
    const archMap: { [key: string]: string } = {
      'x64': 'amd64',
      'arm64': 'arm64'
    }

    const goArch = archMap[arch] || arch

    // 映射平台名称
    const platformMap: { [key: string]: string } = {
      'darwin': 'darwin',
      'win32': 'windows',
      'linux': 'linux'
    }

    const goPlatform = platformMap[platform] || platform
    const extension = platform === 'win32' ? '.exe' : ''

    // 构建二进制文件名
    const binaryName = `smb-discover-${goPlatform}-${goArch}${extension}`

    // 查找二进制文件的可能路径
    const possiblePaths = [
      // 开发环境中的路径 - 使用process.cwd()代替__dirname
      path.join(process.cwd(), 'tools', 'smb-discover', 'bin', binaryName),
      // 打包后的路径
      path.join(process.resourcesPath || '', 'bin', binaryName),
      // 当前目录下的bin文件夹
      path.join(process.cwd(), 'bin', binaryName),
      // 工具目录
      path.join(process.cwd(), 'dist', 'bin', binaryName),
      // 使用相对路径查找
      path.resolve(process.cwd(), '..', 'tools', 'smb-discover', 'bin', binaryName),
      path.resolve(process.cwd(), '..', 'bin', binaryName)
    ]

    console.log(`[SMBStorageProvider] Looking for binary: ${binaryName}`)
    console.log(`[SMBStorageProvider] Search paths:`, possiblePaths)

    for (const binaryPath of possiblePaths) {
      if (fs.existsSync(binaryPath)) {
        this.binaryPath = binaryPath
        console.log(`[SMBStorageProvider] Found binary at: ${binaryPath}`)

        // 确保二进制文件可执行 (Unix系统)
        if (platform !== 'win32') {
          try {
            fs.chmodSync(binaryPath, 0o755)
          } catch (error) {
            console.warn(`[SMBStorageProvider] Failed to set executable permission: ${error}`)
          }
        }

        return
      }
    }

    console.error(`[SMBStorageProvider] Binary not found. Searched paths:`, possiblePaths)
    console.error(`[SMBStorageProvider] Platform: ${platform}, Arch: ${arch}, Expected: ${binaryName}`)
    
    // 如果都找不到，假设系统PATH中有二进制文件
    console.warn(`[SMBStorageProvider] Fallback to system PATH: ${binaryName}`)
    this.binaryPath = binaryName
  }

  /**
   * 执行Go二进制文件并解析JSON响应
   */
  private async executeBinary(args: string[]): Promise<any> {
    if (!this.binaryPath) {
      throw new StorageProviderError('SMB binary not found', 'smb', 'BINARY_NOT_FOUND')
    }

    return new Promise((resolve, reject) => {
      const process = spawn(this.binaryPath!, args, {
        stdio: ['pipe', 'pipe', 'pipe']
      })

      let stdout = ''
      let stderr = ''

      process.stdout.on('data', (data) => {
        stdout += data.toString()
      })

      process.stderr.on('data', (data) => {
        stderr += data.toString()
      })

      process.on('close', (code) => {
        if (code !== 0) {
          const errorMsg = stderr || `Process exited with code ${code}`
          console.error(`[SMBStorageProvider] Binary execution failed: ${errorMsg}`)
          reject(new StorageProviderError(errorMsg, 'smb', 'BINARY_EXECUTION_FAILED'))
          return
        }

        try {
          const result = JSON.parse(stdout)
          resolve(result)
        } catch (parseError) {
          console.error(`[SMBStorageProvider] Failed to parse JSON response: ${parseError}`)
          console.error(`[SMBStorageProvider] Raw output: ${stdout}`)
          reject(new StorageProviderError(
            `Invalid JSON response: ${parseError}`,
            'smb',
            'JSON_PARSE_ERROR'
          ))
        }
      })

      process.on('error', (error) => {
        console.error(`[SMBStorageProvider] Failed to start binary: ${error}`)
        reject(new StorageProviderError(
          `Failed to start binary: ${error.message}`,
          'smb',
          'BINARY_START_FAILED',
          error
        ))
      })

      // 设置超时
      const timeout = setTimeout(() => {
        process.kill()
        reject(new StorageProviderError('Binary execution timeout', 'smb', 'TIMEOUT'))
      }, 30000) // 30秒超时

      process.on('close', () => {
        clearTimeout(timeout)
      })
    })
  }

  /**
   * 判断媒体文件类型
   */
  private determineMediaType(filePath: string, fileName: string): 'movie' | 'tv' | 'unknown' {
    const lowerPath = filePath.toLowerCase()
    const lowerName = fileName.toLowerCase()

    // 检查路径中的TV节目关键词
    if (lowerPath.includes('tv') ||
        lowerPath.includes('series') ||
        lowerPath.includes('season') ||
        lowerPath.includes('episode')) {
      return 'tv'
    }

    // 检查路径中的电影关键词
    if (lowerPath.includes('movie') ||
        lowerPath.includes('film')) {
      return 'movie'
    }

    // 检查文件名中的TV节目模式: S01E01, s01e01 等
    if (/s\d+e\d+/i.test(lowerName) ||
        /season\s*\d+/i.test(lowerName) ||
        /episode\s*\d+/i.test(lowerName)) {
      return 'tv'
    }

    // 其他TV节目模式: 包含年份和集数
    if (/\(\d{4}\).*\d+x\d+/i.test(lowerName)) {
      return 'tv'
    }

    // 如果文件名包含年份(2020)但没有季集指示符，可能是电影
    if (/\(\d{4}\)/i.test(lowerName) && !(/\d+x\d+/i.test(lowerName))) {
      return 'movie'
    }

    return 'unknown'
  }
}
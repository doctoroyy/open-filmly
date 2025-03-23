import samba from "samba-client"
import * as path from "path"
import * as fs from "fs"
import * as os from "os"

interface SambaConfig {
  ip: string
  port?: number
  username?: string
  password?: string
  domain?: string
  sharePath?: string
}

interface MediaFile {
  path: string
  type: 'movie' | 'tv' | 'unknown'
  name: string
}

export class SambaClient {
  private config: SambaConfig | null = null
  private client: any = null

  constructor() {
    // 默认配置
    this.config = {
      ip: "192.168.31.252",
      port: 445,
      username: "guest",
      password: "",
      sharePath: "",
    }
  }

  // 配置Samba客户端
  public configure(config: SambaConfig): void {
    this.config = {
      ...this.config,
      ...config,
    }

    // 重置客户端，下次使用时会重新创建
    this.client = null
  }

  // 获取Samba客户端实例
  private getClient(): any {
    if (!this.client && this.config) {
      const { ip, username, password, domain } = this.config

      // 创建Samba客户端
      this.client = new samba({
        address: `//${ip}`,
        username: username || "guest",
        password: password || "",
        domain: domain || "",
        maxProtocol: "SMB3",
        maskCmd: false
      })
    }

    return this.client
  }

  // 列出目录中的文件并自动分类媒体文件
  public async scanMediaFiles(directory: string): Promise<MediaFile[]> {
    if (!this.config) {
      throw new Error("Samba client not configured")
    }

    try {
      const client = this.getClient()
      const files = await client.listFiles(directory)
      const mediaFiles: MediaFile[] = []

      for (const file of files) {
        // 跳过隐藏文件和目录
        if (file.startsWith('.')) continue

        const filePath = path.join(directory, file)
        
        try {
          // 检查是否是目录
          const subFiles = await client.listFiles(filePath)
          // 是目录，递归扫描
          const subMediaFiles = await this.scanMediaFiles(filePath)
          mediaFiles.push(...subMediaFiles)
        } catch (error) {
          // 不是目录，检查是否是媒体文件
          const fileExt = path.extname(file).toLowerCase()
          const mediaExtensions = ['.mp4', '.mkv', '.avi', '.mov', '.wmv', '.m4v']
          
          if (mediaExtensions.includes(fileExt)) {
            // 基于文件路径和文件名判断类型
            const type = this.determineMediaType(filePath, file)
            mediaFiles.push({
              path: filePath,
              type,
              name: path.basename(file, fileExt)
            })
          }
        }
      }
      
      return mediaFiles
    } catch (error: unknown) {
      console.error(`Error scanning media files in ${directory}:`, error)
      throw error
    }
  }

  // 判断媒体文件类型
  private determineMediaType(filePath: string, fileName: string): 'movie' | 'tv' | 'unknown' {
    const lowerPath = filePath.toLowerCase()
    const lowerName = fileName.toLowerCase()
    
    // 检查路径中是否包含明显的电视剧关键词
    if (lowerPath.includes('tv') || 
        lowerPath.includes('series') || 
        lowerPath.includes('season') || 
        lowerPath.includes('episode')) {
      return 'tv'
    }
    
    // 检查路径中是否包含明显的电影关键词
    if (lowerPath.includes('movie') || 
        lowerPath.includes('film')) {
      return 'movie'
    }
    
    // 检查文件名模式：S01E01, s01e01 等格式
    if (/s\d+e\d+/i.test(lowerName) || 
        /season\s*\d+/i.test(lowerName) || 
        /episode\s*\d+/i.test(lowerName)) {
      return 'tv'
    }
    
    // 其他可能的电视剧模式：包含年份和序号
    if (/\(\d{4}\).*\d+x\d+/i.test(lowerName)) {
      return 'tv'
    }
    
    // 如果文件名包含年份格式 (2020) 但没有季集号标识，可能是电影
    if (/\(\d{4}\)/i.test(lowerName) && !(/\d+x\d+/i.test(lowerName))) {
      return 'movie'
    }
    
    // 无法确定的情况
    return 'unknown'
  }

  // 获取文件内容
  public async readFile(filePath: string): Promise<Buffer> {
    if (!this.config) {
      throw new Error("Samba client not configured")
    }

    try {
      const client = this.getClient()
      const content = await client.readFile(filePath)
      return content
    } catch (error: unknown) {
      console.error(`Error reading file ${filePath}:`, error)
      throw error
    }
  }

  // 将文件下载到本地临时目录
  public async downloadFile(remotePath: string): Promise<string> {
    if (!this.config) {
      throw new Error("Samba client not configured")
    }

    try {
      const client = this.getClient()
      const content = await client.readFile(remotePath)

      // 创建临时文件
      const tempDir = path.join(os.tmpdir(), "nas-poster-wall")
      if (!fs.existsSync(tempDir)) {
        fs.mkdirSync(tempDir, { recursive: true })
      }

      const fileName = path.basename(remotePath)
      const localPath = path.join(tempDir, fileName)

      // 写入文件
      fs.writeFileSync(localPath, content)

      return localPath
    } catch (error: unknown) {
      console.error(`Error downloading file ${remotePath}:`, error)
      throw error
    }
  }

  // 按类型获取媒体文件
  public async getMediaByType(directory: string, type: 'movie' | 'tv' | 'unknown'): Promise<MediaFile[]> {
    const allMedia = await this.scanMediaFiles(directory)
    return allMedia.filter(media => media.type === type)
  }

  // 列出目录中的文件
  public async listFiles(directory: string): Promise<string[]> {
    if (!this.config) {
      throw new Error("Samba client not configured")
    }

    try {
      const client = this.getClient()
      const files = await client.listFiles(directory)
      return files
    } catch (error: unknown) {
      console.error(`Error listing files in ${directory}:`, error)
      throw error
    }
  }
}


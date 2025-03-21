import * as samba from "samba-client"
import * as path from "path"
import * as fs from "fs"
import * as os from "os"

interface SambaConfig {
  ip: string
  port?: number
  username?: string
  password?: string
  domain?: string
  moviePath?: string
  tvPath?: string
}

export class SambaClient {
  private config: SambaConfig | null = null
  private client: any = null

  constructor() {
    // 默认配置
    this.config = {
      ip: "192.168.31.100",
      port: 445,
      username: "",
      password: "",
      moviePath: "movies",
      tvPath: "tv",
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
      this.client = new samba.Client({
        address: `//${ip}`,
        username: username || "guest",
        password: password || "",
        domain: domain || "",
        maxProtocol: "SMB3",
        autoCloseTimeout: 5000,
      })
    }

    return this.client
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
    } catch (error) {
      console.error(`Error listing files in ${directory}:`, error)
      throw error
    }
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
    } catch (error) {
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
    } catch (error) {
      console.error(`Error downloading file ${remotePath}:`, error)
      throw error
    }
  }

  // 获取电影目录
  public getMoviePath(): string {
    return this.config?.moviePath || "movies"
  }

  // 获取电视剧目录
  public getTvPath(): string {
    return this.config?.tvPath || "tv"
  }
}


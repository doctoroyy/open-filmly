/**
 * SMB媒体代理服务器
 * 将SMB文件流转换为HTTP流，供HTML5视频播放器使用
 */

import * as http from 'http'
import * as url from 'url'
import { GoSMBClient } from './go-smb-client'

export class MediaProxyServer {
  private server: http.Server | null = null
  private port: number = 0
  private goSmbClient: GoSMBClient

  constructor(goSmbClient: GoSMBClient) {
    this.goSmbClient = goSmbClient
  }

  /**
   * 启动代理服务器
   */
  public async start(): Promise<number> {
    return new Promise((resolve, reject) => {
      this.server = http.createServer(this.handleRequest.bind(this))
      
      // 监听随机可用端口
      this.server.listen(0, '127.0.0.1', () => {
        const address = this.server?.address()
        if (address && typeof address === 'object') {
          this.port = address.port
          console.log(`[MediaProxy] Server started on port ${this.port}`)
          resolve(this.port)
        } else {
          reject(new Error('Failed to start media proxy server'))
        }
      })

      this.server.on('error', (error) => {
        console.error('[MediaProxy] Server error:', error)
        reject(error)
      })
    })
  }

  /**
   * 停止代理服务器
   */
  public async stop(): Promise<void> {
    return new Promise((resolve) => {
      if (this.server) {
        this.server.close(() => {
          console.log('[MediaProxy] Server stopped')
          this.server = null
          this.port = 0
          resolve()
        })
      } else {
        resolve()
      }
    })
  }

  /**
   * 获取代理URL
   */
  public getProxyUrl(filePath: string): string {
    if (!this.server || this.port === 0) {
      throw new Error('Media proxy server is not running')
    }
    
    // 将文件路径编码为URL参数
    const encodedPath = encodeURIComponent(filePath)
    return `http://127.0.0.1:${this.port}/stream?file=${encodedPath}`
  }

  /**
   * 处理HTTP请求
   */
  private async handleRequest(req: http.IncomingMessage, res: http.ServerResponse): Promise<void> {
    try {
      const parsedUrl = url.parse(req.url || '', true)
      
      // 处理CORS
      res.setHeader('Access-Control-Allow-Origin', '*')
      res.setHeader('Access-Control-Allow-Methods', 'GET, HEAD, OPTIONS')
      res.setHeader('Access-Control-Allow-Headers', 'Range, Content-Type')

      if (req.method === 'OPTIONS') {
        res.writeHead(200)
        res.end()
        return
      }

      if (parsedUrl.pathname === '/stream') {
        await this.handleStreamRequest(req, res, parsedUrl.query)
      } else {
        res.writeHead(404, { 'Content-Type': 'text/plain' })
        res.end('Not Found')
      }
    } catch (error) {
      console.error('[MediaProxy] Request handling error:', error)
      res.writeHead(500, { 'Content-Type': 'text/plain' })
      res.end('Internal Server Error')
    }
  }

  /**
   * 处理流媒体请求
   */
  private async handleStreamRequest(
    req: http.IncomingMessage, 
    res: http.ServerResponse, 
    query: any
  ): Promise<void> {
    const filePath = query.file as string
    
    if (!filePath) {
      res.writeHead(400, { 'Content-Type': 'text/plain' })
      res.end('Missing file parameter')
      return
    }

    try {
      console.log(`[MediaProxy] Streaming file: ${filePath}`)

      // 从Go SMB读取文件
      const fileBuffer = await this.goSmbClient.readFile(filePath)
      const fileSize = fileBuffer.length

      // 解析Range请求（用于视频拖拽）
      const range = req.headers.range
      
      if (range) {
        // 处理Range请求
        const ranges = this.parseRange(range, fileSize)
        
        if (ranges.length === 1) {
          const { start, end } = ranges[0]
          const chunkSize = end - start + 1
          const chunk = fileBuffer.slice(start, end + 1)

          res.writeHead(206, {
            'Content-Range': `bytes ${start}-${end}/${fileSize}`,
            'Accept-Ranges': 'bytes',
            'Content-Length': chunkSize,
            'Content-Type': this.getContentType(filePath),
            'Cache-Control': 'no-cache'
          })

          res.end(chunk)
        } else {
          res.writeHead(416, { 'Content-Range': `bytes */${fileSize}` })
          res.end()
        }
      } else {
        // 完整文件响应
        res.writeHead(200, {
          'Content-Length': fileSize,
          'Content-Type': this.getContentType(filePath),
          'Accept-Ranges': 'bytes',
          'Cache-Control': 'no-cache'
        })

        res.end(fileBuffer)
      }
    } catch (error) {
      console.error(`[MediaProxy] Error streaming file ${filePath}:`, error)
      res.writeHead(500, { 'Content-Type': 'text/plain' })
      res.end('Error reading file')
    }
  }

  /**
   * 解析Range头
   */
  private parseRange(range: string, size: number): Array<{ start: number; end: number }> {
    const ranges: Array<{ start: number; end: number }> = []
    
    if (!range.startsWith('bytes=')) {
      return ranges
    }

    const rangeSpec = range.substring(6)
    const rangeParts = rangeSpec.split(',')

    for (const part of rangeParts) {
      const [startStr, endStr] = part.trim().split('-')
      
      let start = parseInt(startStr, 10)
      let end = parseInt(endStr, 10)

      if (isNaN(start)) {
        start = size - end
        end = size - 1
      } else if (isNaN(end)) {
        end = size - 1
      }

      if (start >= 0 && end < size && start <= end) {
        ranges.push({ start, end })
      }
    }

    return ranges
  }

  /**
   * 根据文件扩展名获取Content-Type
   */
  private getContentType(filePath: string): string {
    const ext = filePath.toLowerCase().split('.').pop()
    
    const mimeTypes: { [key: string]: string } = {
      'mp4': 'video/mp4',
      'mkv': 'video/x-matroska',
      'avi': 'video/x-msvideo',
      'mov': 'video/quicktime',
      'wmv': 'video/x-ms-wmv',
      'm4v': 'video/x-m4v',
      'webm': 'video/webm',
      'flv': 'video/x-flv',
      'ts': 'video/mp2t',
      'm3u8': 'application/x-mpegURL'
    }

    return mimeTypes[ext || ''] || 'video/mp4'
  }

  /**
   * 获取服务器状态
   */
  public isRunning(): boolean {
    return this.server !== null && this.port > 0
  }

  /**
   * 获取当前端口
   */
  public getPort(): number {
    return this.port
  }
}
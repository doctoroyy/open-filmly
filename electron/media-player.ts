import { exec } from "child_process"
import { promisify } from "util"
import * as os from "os"
import * as path from "path"

const execAsync = promisify(exec)

export class MediaPlayer {
  // 播放媒体文件
  public async play(filePath: string): Promise<void> {
    try {
      const platform = os.platform()
      
      // 规范化文件路径，确保适合当前操作系统
      const normalizedPath = this.normalizePath(filePath, platform)
      
      console.log(`Attempting to play file: ${normalizedPath}`)

      // 根据操作系统选择播放方式
      if (platform === "win32") {
        // Windows
        await execAsync(`start "" "${normalizedPath}"`)
      } else if (platform === "darwin") {
        // macOS
        await execAsync(`open "${normalizedPath}"`)
      } else if (platform === "linux") {
        // Linux
        await execAsync(`xdg-open "${normalizedPath}"`)
      } else {
        throw new Error(`Unsupported platform: ${platform}`)
      }
    } catch (error) {
      console.error(`Error playing file ${filePath}:`, error)
      throw error
    }
  }

  // 使用VLC播放媒体文件
  public async playWithVlc(filePath: string): Promise<void> {
    try {
      const platform = os.platform()
      
      // 规范化文件路径，确保适合当前操作系统
      const normalizedPath = this.normalizePath(filePath, platform)

      // 根据操作系统选择VLC路径
      let vlcCommand = ""

      if (platform === "win32") {
        // Windows
        vlcCommand = `"C:\\Program Files\\VideoLAN\\VLC\\vlc.exe" "${normalizedPath}"`
      } else if (platform === "darwin") {
        // macOS
        vlcCommand = `/Applications/VLC.app/Contents/MacOS/VLC "${normalizedPath}"`
      } else if (platform === "linux") {
        // Linux
        vlcCommand = `vlc "${normalizedPath}"`
      } else {
        throw new Error(`Unsupported platform: ${platform}`)
      }

      await execAsync(vlcCommand)
    } catch (error) {
      console.error(`Error playing file with VLC ${filePath}:`, error)
      throw error
    }
  }
  
  // 规范化文件路径，处理不同操作系统的路径差异
  private normalizePath(filePath: string, platform: string): string {
    // 首先将反斜杠转换为正斜杠
    let normalizedPath = filePath.replace(/\\/g, '/');
    
    // 检查路径是否为SMB/网络路径
    if (normalizedPath.startsWith('/') && !normalizedPath.startsWith('//')) {
      // 如果该路径是相对于共享的路径，我们需要更完整的路径
      if (platform === 'win32') {
        // Windows平台，保持格式不变
        return normalizedPath.replace(/\//g, '\\');
      } else if (platform === 'darwin') {
        // 在macOS中，我们需要确保文件路径是完整的本地路径或SMB路径
        if (normalizedPath.includes(':/')) {
          // 已经是一个完整的路径（如smb://server/share/path）
          return normalizedPath;
        }
        
        // 检查是否是一个相对于当前目录的路径
        if (!path.isAbsolute(normalizedPath)) {
          // 相对路径，保持原样
          return normalizedPath;
        }
      }
    }
    
    // 处理完整的SMB路径
    if (normalizedPath.includes('smb://')) {
      // macOS格式的SMB路径，无需更改
      return normalizedPath;
    }
    
    return normalizedPath;
  }
}


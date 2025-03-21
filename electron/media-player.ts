import { exec } from "child_process"
import { promisify } from "util"
import * as os from "os"

const execAsync = promisify(exec)

export class MediaPlayer {
  // 播放媒体文件
  public async play(filePath: string): Promise<void> {
    try {
      const platform = os.platform()

      // 根据操作系统选择播放方式
      if (platform === "win32") {
        // Windows
        await execAsync(`start "" "${filePath}"`)
      } else if (platform === "darwin") {
        // macOS
        await execAsync(`open "${filePath}"`)
      } else if (platform === "linux") {
        // Linux
        await execAsync(`xdg-open "${filePath}"`)
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

      // 根据操作系统选择VLC路径
      let vlcCommand = ""

      if (platform === "win32") {
        // Windows
        vlcCommand = `"C:\\Program Files\\VideoLAN\\VLC\\vlc.exe" "${filePath}"`
      } else if (platform === "darwin") {
        // macOS
        vlcCommand = `/Applications/VLC.app/Contents/MacOS/VLC "${filePath}"`
      } else if (platform === "linux") {
        // Linux
        vlcCommand = `vlc "${filePath}"`
      } else {
        throw new Error(`Unsupported platform: ${platform}`)
      }

      await execAsync(vlcCommand)
    } catch (error) {
      console.error(`Error playing file with VLC ${filePath}:`, error)
      throw error
    }
  }
}


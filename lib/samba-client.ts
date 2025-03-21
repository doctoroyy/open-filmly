import type { MediaItem } from "@/types/media"
import { scrapeChinesePoster } from "./poster-scraper"
import { parseFileName } from "./file-parser"

// 简化的Samba配置，只需要IP地址
interface SambaConfig {
  ip: string
  port?: number
  moviePath?: string
  tvPath?: string
}

// 获取配置
const getSambaConfig = (): SambaConfig => {
  return {
    ip: process.env.SAMBA_IP || "192.168.31.100",
    port: 445, // 默认SMB端口
    moviePath: "movies",
    tvPath: "tv",
  }
}

// 模拟从Samba获取文件列表
// 在实际应用中，这将通过本地应用或服务器端代码实现
async function listSambaFiles(ip: string, path: string): Promise<string[]> {
  console.log(`[Samba] Listing files from smb://${ip}/${path}`)

  // 这里是模拟数据，实际实现会通过SMB协议获取文件列表
  if (path.includes("movie")) {
    return [
      "流浪地球2 (2023).mkv",
      "满江红 (2023).mp4",
      "独行月球 (2022).mkv",
      "长津湖 (2021).mp4",
      "你好，李焕英 (2021).mkv",
      "我和我的家乡 (2020).mp4",
    ]
  } else if (path.includes("tv")) {
    return ["三体 (2023)", "狂飙 (2023)", "风起陇西 (2022)", "梦华录 (2022)", "山海情 (2021)", "觉醒年代 (2021)"]
  }
  return []
}

// 获取媒体文件
export async function getMediaFromSamba(type: "movie" | "tv"): Promise<MediaItem[]> {
  const config = getSambaConfig()
  const directoryPath = type === "movie" ? config.moviePath : config.tvPath

  try {
    // 列出指定路径中的文件
    const files = await listSambaFiles(config.ip, directoryPath || "")

    // 处理每个文件以提取媒体信息
    const mediaItems: MediaItem[] = await Promise.all(
      files.map(async (file, index) => {
        // 解析文件名以提取标题、年份等
        const { title, year } = parseFileName(file)

        // 创建唯一ID
        const id = `${type}-${index}-${Buffer.from(file).toString("base64").slice(0, 8)}`

        // 创建完整的文件路径
        const filePath = `\\\\${config.ip}\\${directoryPath}\\${file}`

        // 创建媒体项
        const mediaItem: MediaItem = {
          id,
          title: title || file,
          year: year || "未知",
          posterUrl: "/placeholder.svg?height=450&width=300", // 默认占位图
          path: filePath,
        }

        return mediaItem
      }),
    )

    // 为每个媒体项获取海报
    const mediaWithPosters = await Promise.all(
      mediaItems.map(async (item) => {
        try {
          // 尝试从中文源获取海报
          const posterUrl = await scrapeChinesePoster(item.title, item.year, type)
          return { ...item, posterUrl, rating: await getRating(item.title, item.year) }
        } catch (error) {
          console.error(`Failed to fetch poster for ${item.title}:`, error)
          return item
        }
      }),
    )

    return mediaWithPosters
  } catch (error) {
    console.error(`Error getting media from Samba (${type}):`, error)

    // 返回模拟数据，以防出错
    const mockData: MediaItem[] =
      type === "movie"
        ? [
            {
              id: "1",
              title: "流浪地球2",
              year: "2023",
              posterUrl: "/placeholder.svg?height=450&width=300",
              path: `\\\\${config.ip}\\${directoryPath}\\流浪地球2.mkv`,
              rating: "8.6",
            },
            {
              id: "2",
              title: "满江红",
              year: "2023",
              posterUrl: "/placeholder.svg?height=450&width=300",
              path: `\\\\${config.ip}\\${directoryPath}\\满江红.mp4`,
              rating: "7.9",
            },
            {
              id: "3",
              title: "独行月球",
              year: "2022",
              posterUrl: "/placeholder.svg?height=450&width=300",
              path: `\\\\${config.ip}\\${directoryPath}\\独行月球.mkv`,
              rating: "7.4",
            },
            {
              id: "4",
              title: "长津湖",
              year: "2021",
              posterUrl: "/placeholder.svg?height=450&width=300",
              path: `\\\\${config.ip}\\${directoryPath}\\长津湖.mp4`,
              rating: "9.1",
            },
            {
              id: "5",
              title: "你好，李焕英",
              year: "2021",
              posterUrl: "/placeholder.svg?height=450&width=300",
              path: `\\\\${config.ip}\\${directoryPath}\\你好，李焕英.mkv`,
              rating: "8.2",
            },
            {
              id: "6",
              title: "我和我的家乡",
              year: "2020",
              posterUrl: "/placeholder.svg?height=450&width=300",
              path: `\\\\${config.ip}\\${directoryPath}\\我和我的家乡.mp4`,
              rating: "7.5",
            },
          ]
        : [
            {
              id: "7",
              title: "三体",
              year: "2023",
              posterUrl: "/placeholder.svg?height=450&width=300",
              path: `\\\\${config.ip}\\${directoryPath}\\三体`,
              rating: "8.3",
            },
            {
              id: "8",
              title: "狂飙",
              year: "2023",
              posterUrl: "/placeholder.svg?height=450&width=300",
              path: `\\\\${config.ip}\\${directoryPath}\\狂飙`,
              rating: "9.0",
            },
            {
              id: "9",
              title: "风起陇西",
              year: "2022",
              posterUrl: "/placeholder.svg?height=450&width=300",
              path: `\\\\${config.ip}\\${directoryPath}\\风起陇西`,
              rating: "8.7",
            },
            {
              id: "10",
              title: "梦华录",
              year: "2022",
              posterUrl: "/placeholder.svg?height=450&width=300",
              path: `\\\\${config.ip}\\${directoryPath}\\梦华录`,
              rating: "8.0",
            },
            {
              id: "11",
              title: "山海情",
              year: "2021",
              posterUrl: "/placeholder.svg?height=450&width=300",
              path: `\\\\${config.ip}\\${directoryPath}\\山海情`,
              rating: "9.4",
            },
            {
              id: "12",
              title: "觉醒年代",
              year: "2021",
              posterUrl: "/placeholder.svg?height=450&width=300",
              path: `\\\\${config.ip}\\${directoryPath}\\觉醒年代`,
              rating: "9.3",
            },
          ]

    return mockData
  }
}

// 模拟获取评分
async function getRating(title: string, year: string): Promise<string | undefined> {
  // 模拟评分数据
  const ratings: Record<string, string> = {
    流浪地球2: "8.6",
    满江红: "7.9",
    独行月球: "7.4",
    长津湖: "9.1",
    "你好，李焕英": "8.2",
    我和我的家乡: "7.5",
    三体: "8.3",
    狂飙: "9.0",
    风起陇西: "8.7",
    梦华录: "8.0",
    山海情: "9.4",
    觉醒年代: "9.3",
  }

  return ratings[title]
}


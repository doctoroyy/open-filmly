import * as path from "path"
import * as fs from "fs"
import * as os from "os"
import axios from "axios"
import type { MediaDatabase } from "./media-database"

export class PosterScraper {
  private mediaDatabase: MediaDatabase
  private posterCacheDir: string

  constructor(mediaDatabase: MediaDatabase) {
    this.mediaDatabase = mediaDatabase

    // 创建海报缓存目录
    this.posterCacheDir = path.join(os.homedir(), ".nas-poster-wall", "posters")
    if (!fs.existsSync(this.posterCacheDir)) {
      fs.mkdirSync(this.posterCacheDir, { recursive: true })
    }
  }

  // 为单个媒体项抓取海报
  public async fetchPoster(mediaId: string): Promise<string | null> {
    try {
      // 从数据库获取媒体项
      const media = await this.mediaDatabase.getMediaById(mediaId)
      if (!media) {
        throw new Error(`Media not found: ${mediaId}`)
      }

      // 如果已经有海报，直接返回
      if (media.posterPath && fs.existsSync(media.posterPath)) {
        return media.posterPath
      }

      // 构建缓存文件路径
      const posterFileName = `${mediaId}.jpg`
      const posterPath = path.join(this.posterCacheDir, posterFileName)

      // 尝试从豆瓣抓取海报
      const posterUrl = await this.searchDoubanPoster(media.title, media.year, media.type)

      if (posterUrl) {
        // 下载海报
        await this.downloadPoster(posterUrl, posterPath)

        // 更新数据库
        await this.mediaDatabase.updateMediaPoster(mediaId, posterPath)

        return posterPath
      }

      return null
    } catch (error) {
      console.error(`Error fetching poster for ${mediaId}:`, error)
      return null
    }
  }

  // 为多个媒体项抓取海报
  public async fetchPosters(mediaIds: string[]): Promise<Record<string, string | null>> {
    const results: Record<string, string | null> = {}

    for (const mediaId of mediaIds) {
      results[mediaId] = await this.fetchPoster(mediaId)
    }

    return results
  }

  // 从豆瓣搜索海报
  private async searchDoubanPoster(title: string, year: string, type: "movie" | "tv"): Promise<string | null> {
    try {
      // 构建搜索URL
      const searchQuery = encodeURIComponent(`${title} ${year}`)
      const searchUrl = `https://www.douban.com/search?cat=1002&q=${searchQuery}`

      // 发送请求
      const response = await axios.get(searchUrl, {
        headers: {
          "User-Agent":
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36",
        },
      })

      // 解析HTML
      const html = response.data

      // 提取第一个结果的URL
      const resultUrlMatch = html.match(
        /<a href="(https:\/\/movie\.douban\.com\/subject\/\d+\/)" target="_blank" class="nbg">/,
      )
      if (!resultUrlMatch || !resultUrlMatch[1]) {
        return null
      }

      const movieUrl = resultUrlMatch[1]

      // 获取电影详情页
      const movieResponse = await axios.get(movieUrl, {
        headers: {
          "User-Agent":
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36",
        },
      })

      // 提取海报URL
      const posterMatch = movieResponse.data.match(
        /<img src="(https:\/\/img\d+\.doubanio\.com\/view\/photo\/s_ratio_poster\/public\/[^"]+)" title="点击看更多海报" rel="v:image" \/>/,
      )
      if (!posterMatch || !posterMatch[1]) {
        return null
      }

      // 返回高质量海报URL
      return posterMatch[1].replace("/s_ratio_poster/", "/l_ratio_poster/")
    } catch (error) {
      console.error(`Error searching Douban for ${title}:`, error)
      return null
    }
  }

  // 下载海报
  private async downloadPoster(url: string, filePath: string): Promise<void> {
    try {
      const response = await axios({
        method: "GET",
        url,
        responseType: "stream",
        headers: {
          "User-Agent":
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36",
        },
      })

      const writer = fs.createWriteStream(filePath)

      return new Promise((resolve, reject) => {
        response.data.pipe(writer)
        writer.on("finish", resolve)
        writer.on("error", reject)
      })
    } catch (error) {
      console.error(`Error downloading poster from ${url}:`, error)
      throw error
    }
  }
}


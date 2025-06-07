import { useEffect, useState } from "react"
import { MediaCard } from "./media-card"
import type { Media } from "@/types/media"
import { Card, CardContent } from "@/components/ui/card"
import { Link } from "react-router-dom"

export interface MediaGridProps {
  media: Media[]
}

export function MediaGrid({ media }: MediaGridProps) {
  const [mediaWithPosters, setMediaWithPosters] = useState<Media[]>(media)

  // 获取海报
  useEffect(() => {
    const fetchPosters = async () => {
      try {
        // 找出没有海报的媒体
        const mediaWithoutPosters = media.filter((item) => !item.posterPath)

        if (mediaWithoutPosters.length === 0) {
          setMediaWithPosters(media)
          return
        }

        // 获取海报
        const mediaIds = mediaWithoutPosters.map((item) => item.id)
        const response = await window.electronAPI.fetchPosters(mediaIds)

        if (response.success && response.results) {
          // 更新媒体数据
          const updatedMedia = media.map((item) => {
            const posterPath = response.results?.[item.id]
            if (posterPath) {
              return { ...item, posterPath } as Media
            }
            return item
          })

          setMediaWithPosters(updatedMedia)
        }
      } catch (error) {
        console.error("Failed to fetch posters:", error)
      }
    }

    fetchPosters()
  }, [media])

  if (media.length === 0) {
    return (
      <div className="flex flex-col items-center justify-center py-12 text-center">
        <h3 className="text-xl font-medium text-gray-400">没有找到媒体</h3>
        <p className="mt-2 text-sm text-gray-500">请在设置中配置媒体路径并扫描</p>
      </div>
    )
  }

  return (
    <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-6 gap-4">
      {mediaWithPosters.map((item) => (
        <Link key={item.id} to={`/${item.id}`}>
          <Card className="overflow-hidden h-full transition-all duration-200 hover:scale-105 hover:shadow-xl bg-gray-900 border-gray-800">
            <div className="relative aspect-[2/3] w-full">
              {item.posterPath ? (
                <img
                  src={`file://${item.posterPath}`}
                  alt={item.title}
                  className="w-full h-full object-cover"
                />
              ) : (
                <div className="w-full h-full flex items-center justify-center bg-gray-800">
                  <span className="text-gray-400">No Poster</span>
                </div>
              )}
            </div>
            <CardContent className="p-3">
              <h3 className="font-medium text-sm line-clamp-1">{item.title}</h3>
              <p className="text-xs text-gray-400 mt-1">{item.year}</p>
            </CardContent>
          </Card>
        </Link>
      ))}
    </div>
  )
}


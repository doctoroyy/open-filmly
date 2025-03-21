"use client"

import { useEffect, useState } from "react"
import { MediaCard } from "./media-card"
import type { Media } from "../../types/media"

interface MediaGridProps {
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
        const results = await window.electronAPI.fetchPosters(mediaIds)

        // 更新媒体数据
        const updatedMedia = media.map((item) => {
          if (results[item.id]) {
            return { ...item, posterPath: results[item.id] }
          }
          return item
        })

        setMediaWithPosters(updatedMedia)
      } catch (error) {
        console.error("Failed to fetch posters:", error)
      }
    }

    fetchPosters()
  }, [media])

  return (
    <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-6 gap-4">
      {mediaWithPosters.map((item) => (
        <MediaCard key={item.id} media={item} />
      ))}

      {mediaWithPosters.length === 0 && (
        <div className="col-span-full text-center py-12">
          <p className="text-gray-400">没有找到媒体文件</p>
          <p className="text-gray-500 text-sm mt-2">点击"扫描"按钮以扫描媒体文件</p>
        </div>
      )}
    </div>
  )
}


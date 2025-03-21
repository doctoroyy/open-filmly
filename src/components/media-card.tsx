"use client"

import { useState } from "react"
import Image from "next/image"
import { Play } from "lucide-react"
import { cn } from "@/lib/utils"
import type { Media } from "../../types/media"

interface MediaCardProps {
  media: Media
}

export function MediaCard({ media }: MediaCardProps) {
  const [isHovering, setIsHovering] = useState(false)
  const [imageError, setImageError] = useState(false)

  const handlePlay = async () => {
    try {
      const result = await window.electronAPI.playMedia(media.id)

      if (!result.success) {
        console.error("Failed to play media:", result.error)
      }
    } catch (error) {
      console.error("Error playing media:", error)
    }
  }

  // 获取海报路径
  const getPosterPath = () => {
    if (imageError || !media.posterPath) {
      return `/placeholder.svg?height=450&width=300&text=${encodeURIComponent(media.title)}`
    }

    // 如果是本地文件路径，使用file://协议
    if (media.posterPath.startsWith("/") || media.posterPath.includes(":\\")) {
      return `file://${media.posterPath}`
    }

    return media.posterPath
  }

  return (
    <div
      className="relative aspect-[2/3] rounded-lg overflow-hidden group cursor-pointer transition-transform duration-200 hover:scale-105"
      onMouseEnter={() => setIsHovering(true)}
      onMouseLeave={() => setIsHovering(false)}
      onClick={handlePlay}
    >
      <Image
        src={getPosterPath() || "/placeholder.svg"}
        alt={media.title}
        fill
        className="object-cover"
        onError={() => setImageError(true)}
        unoptimized
      />

      <div
        className={cn(
          "absolute inset-0 bg-gradient-to-t from-black/80 to-transparent p-4 flex flex-col justify-end",
          isHovering ? "opacity-100" : "opacity-0 sm:opacity-0 md:group-hover:opacity-100",
        )}
        style={{ transition: "opacity 0.3s ease" }}
      >
        <h3 className="text-white font-medium line-clamp-2">{media.title}</h3>
        <p className="text-gray-300 text-sm">{media.year}</p>

        <div className="absolute top-1/2 left-1/2 transform -translate-x-1/2 -translate-y-1/2">
          <div className="bg-white/20 backdrop-blur-sm rounded-full p-3 border border-white/30">
            <Play className="w-8 h-8 text-white fill-white" />
          </div>
        </div>
      </div>

      {media.rating && (
        <div className="absolute top-2 right-2 bg-yellow-500 text-black font-bold rounded-full w-8 h-8 flex items-center justify-center">
          {media.rating}
        </div>
      )}
    </div>
  )
}


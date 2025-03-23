"use client"

import { useState } from "react"
import Image from "next/image"
import { Play, Star, Info } from "lucide-react"
import { cn } from "@/lib/utils"
import type { MediaItem } from "@/types/media"

interface MediaCardProps {
  media: MediaItem
}

export function MediaCard({ media }: MediaCardProps) {
  const [isHovering, setIsHovering] = useState(false)
  const [imageError, setImageError] = useState(false)

  const handlePlay = async () => {
    try {
      // 尝试使用本地协议处理程序打开文件
      // 这将尝试使用系统默认的媒体播放器打开文件
      window.location.href = `smb:${media.path.replace(/\\/g, "/")}`

      // 备用方法：通过API
      const response = await fetch("/api/play", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ path: media.path }),
      })

      const data = await response.json()

      if (!data.success) {
        console.error("Failed to start playback:", data.error)
      }
    } catch (error) {
      console.error("Error starting playback:", error)
    }
  }

  return (
    <div
      className="relative aspect-[2/3] rounded-lg overflow-hidden group cursor-pointer transition-transform duration-200 hover:scale-105"
      onMouseEnter={() => setIsHovering(true)}
      onMouseLeave={() => setIsHovering(false)}
      onClick={handlePlay}
    >
      <Image
        src={
          imageError ? `/placeholder.svg?height=450&width=300&text=${encodeURIComponent(media.title)}` : media.posterUrl
        }
        alt={media.title}
        fill
        className="object-cover"
        onError={() => setImageError(true)}
        crossOrigin="anonymous"
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


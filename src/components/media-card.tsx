import { useState } from "react"
import { Play, Star, Tv } from "lucide-react"
import { useNavigate } from "react-router-dom"
import { cn } from "@/lib/utils"
import { useVideoPlayer } from "@/contexts/video-player-context"
import { useToast } from "@/components/ui/use-toast"
import type { Media } from "@/types/media"

interface MediaCardProps {
  media: Media
}

export function MediaCard({ media }: MediaCardProps) {
  const navigate = useNavigate()
  const { openPlayer } = useVideoPlayer()
  const { toast } = useToast()
  const [isHovering, setIsHovering] = useState(false)
  const [imageError, setImageError] = useState(false)

  const handlePlay = async (e: React.MouseEvent) => {
    e.stopPropagation() // 防止触发卡片点击
    
    try {
      console.log(`[MediaCard] Playing media:`, media)
      
      // 如果是电视剧且有剧集，播放第一集
      if (media.type === 'tv' && media.episodes && media.episodes.length > 0) {
        // 获取第一季第一集，或者按照顺序排序后的第一集
        const firstEpisode = media.episodes
          .sort((a, b) => {
            if (a.season !== b.season) return a.season - b.season;
            return a.episode - b.episode;
          })[0];
          
        console.log(`[MediaCard] Playing TV episode:`, firstEpisode);
        
        // 获取流媒体URL
        const result = await window.electronAPI?.playMedia({
          mediaId: `${media.id}-ep${firstEpisode.season}x${firstEpisode.episode}`,
          filePath: firstEpisode.path
        });
        
        if (result?.success && result.streamUrl) {
          // 打开内置播放器
          openPlayer(
            result.streamUrl, 
            `${media.title} - S${firstEpisode.season}E${firstEpisode.episode}`,
            media.posterPath || undefined
          );
          console.log("TV episode stream opened successfully");
        } else {
          toast({
            title: "播放失败",
            description: result?.error || "无法获取视频流",
            variant: "destructive",
          });
        }
      } else {
        // 电影或不含剧集的媒体，直接播放
        console.log(`[MediaCard] Playing media:`, media);
        
        // 获取流媒体URL
        const result = await window.electronAPI?.playMedia(media.id);
        
        if (result?.success && result.streamUrl) {
          // 打开内置播放器
          openPlayer(
            result.streamUrl, 
            result.title || media.title,
            media.posterPath || undefined
          );
          console.log("Media stream opened successfully");
        } else {
          toast({
            title: "播放失败",
            description: result?.error || "无法获取视频流",
            variant: "destructive",
          });
        }
      }
    } catch (error) {
      console.error("Error playing media:", error);
      toast({
        title: "播放失败",
        description: "播放时发生错误",
        variant: "destructive",
      });
    }
  }

  const handleCardClick = () => {
    console.log(`Navigating to media detail: /${media.id}`)
    navigate(`/${media.id}`)
  }

  // 获取海报路径
  const getPosterPath = () => {
    if (imageError || !media.posterPath) {
      return `/placeholder.svg?height=450&width=300&text=${encodeURIComponent(media.title)}`
    }

    // 如果是TMDB URL，直接返回
    if (media.posterPath.startsWith('https://image.tmdb.org/')) {
      return media.posterPath
    }

    // 如果是本地文件路径
    if (media.posterPath.startsWith("/") || media.posterPath.includes(":\\") || media.posterPath.startsWith("\\")) {
      // 确保路径格式正确
      let path = media.posterPath;
      // 如果还没有file://前缀，添加它
      if (!path.startsWith("file://")) {
        console.log(`Converting local path to file URL: ${path}`);
        // 为Windows路径处理反斜杠
        if (path.includes(":\\") || path.startsWith("\\")) {
          path = path.replace(/\\/g, "/");
        }
        return `file://${path}`;
      }
      return path;
    }

    return media.posterPath
  }

  // Format rating to one decimal place
  const formattedRating = media.rating ? 
    (typeof media.rating === 'number' ? media.rating.toFixed(1) : media.rating) 
    : null;

  return (
    <div className="group cursor-pointer transition-transform duration-200 hover:scale-105">
      <div
        className="relative aspect-[2/3] rounded-xl overflow-hidden shadow-lg"
        onMouseEnter={() => setIsHovering(true)}
        onMouseLeave={() => setIsHovering(false)}
        onClick={handleCardClick}
      >
        <img
          src={getPosterPath() || "/placeholder.svg"}
          alt={media.title}
          className="w-full h-full object-cover"
          onError={() => setImageError(true)}
        />

        {/* Hover overlay with play button */}
        <div
          className={cn(
            "absolute inset-0 bg-black/40 flex items-center justify-center",
            isHovering ? "opacity-100" : "opacity-0",
          )}
          style={{ transition: "opacity 0.3s ease" }}
        >
          <div 
            className="bg-white/20 backdrop-blur-sm rounded-full p-3 border border-white/30"
            onClick={handlePlay}
          >
            <Play className="w-8 h-8 text-white fill-white" />
          </div>
        </div>

        {formattedRating && (
          <div className="absolute top-2 right-2 bg-green-600 text-white text-xs font-bold rounded px-1.5 py-0.5 min-w-[28px] flex items-center justify-center">
            {formattedRating}
          </div>
        )}
      </div>

      {/* Title and year always visible below poster */}
      <div className="mt-3 px-1">
        <h3 className="text-base font-semibold text-foreground line-clamp-2 leading-snug mb-1" title={media.title}>
          {media.title}
        </h3>
        <div className="flex items-center justify-between">
          <p className="text-sm text-muted-foreground">{media.year}</p>
          {media.type === 'tv' && media.episodeCount && (
            <div className="flex items-center text-xs text-muted-foreground bg-accent px-2 py-1 rounded-full">
              <span>共{media.episodeCount}集</span>
            </div>
          )}
        </div>
      </div>
    </div>
  )
}


import { useState, useRef, useEffect } from "react"
import { Play, Star, Clock, Calendar, Eye, Info, MoreVertical, Heart, Download, Share2, Bookmark } from "lucide-react"
import { useNavigate } from "react-router-dom"
import { cn } from "@/lib/utils"
import { useVideoPlayer } from "@/contexts/video-player-context"
import { useToast } from "@/components/ui/use-toast"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { Tooltip, TooltipContent, TooltipProvider, TooltipTrigger } from "@/components/ui/tooltip"
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuSeparator, DropdownMenuTrigger } from "@/components/ui/dropdown-menu"
import type { Media } from "@/types/media"

interface EnhancedMediaCardProps {
  media: Media
  variant?: 'default' | 'compact' | 'detailed' | 'grid'
  showActions?: boolean
  showProgress?: boolean
  className?: string
  onFavorite?: (media: Media) => void
  onDownload?: (media: Media) => void
  onShare?: (media: Media) => void
}

export function EnhancedMediaCard({ 
  media, 
  variant = 'default',
  showActions = true,
  showProgress = false,
  className,
  onFavorite,
  onDownload,
  onShare
}: EnhancedMediaCardProps) {
  const navigate = useNavigate()
  const { openPlayer } = useVideoPlayer()
  const { toast } = useToast()
  const [isHovering, setIsHovering] = useState(false)
  const [imageError, setImageError] = useState(false)
  const [imageLoaded, setImageLoaded] = useState(false)
  const [isFavorited, setIsFavorited] = useState(false)
  const cardRef = useRef<HTMLDivElement>(null)

  // 处理播放
  const handlePlay = async (e: React.MouseEvent) => {
    e.stopPropagation()
    
    try {
      console.log(`[EnhancedMediaCard] Playing media:`, media)
      
      if (media.type === 'tv' && media.episodes && media.episodes.length > 0) {
        const firstEpisode = media.episodes
          .sort((a, b) => {
            if (a.season !== b.season) return a.season - b.season;
            return a.episode - b.episode;
          })[0];
          
        const result = await window.electronAPI?.playMedia({
          mediaId: `${media.id}-ep${firstEpisode.season}x${firstEpisode.episode}`,
          filePath: firstEpisode.path
        });
        
        if (result?.success && result.streamUrl) {
          openPlayer(
            result.streamUrl, 
            `${media.title} - S${firstEpisode.season}E${firstEpisode.episode}`,
            media.posterPath || undefined
          );
        } else {
          throw new Error(result?.error || "无法获取视频流")
        }
      } else {
        const result = await window.electronAPI?.playMedia(media.id);
        
        if (result?.success && result.streamUrl) {
          openPlayer(
            result.streamUrl, 
            result.title || media.title,
            media.posterPath || undefined
          );
        } else {
          throw new Error(result?.error || "无法获取视频流")
        }
      }
    } catch (error: any) {
      console.error("Error playing media:", error);
      toast({
        title: "播放失败",
        description: error.message || "播放时发生错误",
        variant: "destructive",
      });
    }
  }

  // 处理卡片点击
  const handleCardClick = () => {
    navigate(`/${media.id}`)
  }

  // 处理收藏
  const handleFavorite = (e: React.MouseEvent) => {
    e.stopPropagation()
    setIsFavorited(!isFavorited)
    onFavorite?.(media)
    toast({
      title: isFavorited ? "已取消收藏" : "已添加到收藏",
      description: media.title,
    })
  }

  // 处理下载
  const handleDownload = (e: React.MouseEvent) => {
    e.stopPropagation()
    onDownload?.(media)
    toast({
      title: "开始下载",
      description: media.title,
    })
  }

  // 处理分享
  const handleShare = (e: React.MouseEvent) => {
    e.stopPropagation()
    onShare?.(media)
    navigator.clipboard.writeText(`${media.title} - 来自 Open Filmly`)
    toast({
      title: "已复制到剪贴板",
      description: "可以分享给朋友了",
    })
  }

  // 获取海报路径
  const getPosterPath = () => {
    if (imageError || !media.posterPath) {
      return `/placeholder.svg?height=450&width=300&text=${encodeURIComponent(media.title)}`
    }

    if (media.posterPath.startsWith('https://image.tmdb.org/')) {
      return media.posterPath
    }

    if (media.posterPath.startsWith("/") || media.posterPath.includes(":\\") || media.posterPath.startsWith("\\")) {
      let path = media.posterPath;
      if (!path.startsWith("file://")) {
        if (path.includes(":\\") || path.startsWith("\\")) {
          path = path.replace(/\\/g, "/");
        }
        return `file://${path}`;
      }
      return path;
    }

    return media.posterPath
  }

  // 格式化评分
  const formattedRating = media.rating ? 
    (typeof media.rating === 'number' ? media.rating.toFixed(1) : media.rating) 
    : null;

  // 获取年份
  const year = media.year || (media.releaseDate ? new Date(media.releaseDate).getFullYear().toString() : '')

  // 根据变体返回不同的布局
  if (variant === 'compact') {
    return (
      <div className={cn("group flex items-center p-3 rounded-lg hover:bg-accent/50 transition-colors cursor-pointer", className)}
           onClick={handleCardClick}>
        <div className="relative w-16 h-24 rounded-md overflow-hidden flex-shrink-0">
          <img
            src={getPosterPath()}
            alt={media.title}
            className="w-full h-full object-cover"
            onError={() => setImageError(true)}
            onLoad={() => setImageLoaded(true)}
          />
          {!imageLoaded && !imageError && (
            <div className="absolute inset-0 bg-gray-200 animate-pulse" />
          )}
        </div>
        <div className="ml-4 flex-1 min-w-0">
          <h3 className="font-medium text-sm truncate">{media.title}</h3>
          <div className="flex items-center gap-2 mt-1">
            <span className="text-xs text-muted-foreground">{year}</span>
            {media.type === 'tv' && (
              <Badge variant="secondary" className="text-xs">剧集</Badge>
            )}
            {formattedRating && (
              <div className="flex items-center gap-1">
                <Star className="w-3 h-3 text-yellow-500 fill-current" />
                <span className="text-xs">{formattedRating}</span>
              </div>
            )}
          </div>
        </div>
        <Button size="sm" variant="ghost" onClick={handlePlay} className="opacity-0 group-hover:opacity-100 transition-opacity">
          <Play className="w-4 h-4" />
        </Button>
      </div>
    )
  }

  if (variant === 'detailed') {
    return (
      <div className={cn("group relative bg-card rounded-xl overflow-hidden shadow-lg hover:shadow-xl transition-all duration-300", className)}
           onMouseEnter={() => setIsHovering(true)}
           onMouseLeave={() => setIsHovering(false)}>
        <div className="relative aspect-[16/9] overflow-hidden">
          <img
            src={media.backdropPath || getPosterPath()}
            alt={media.title}
            className="w-full h-full object-cover transition-transform duration-300 group-hover:scale-105"
            onError={() => setImageError(true)}
            onLoad={() => setImageLoaded(true)}
          />
          {!imageLoaded && !imageError && (
            <div className="absolute inset-0 bg-gray-200 animate-pulse" />
          )}
          
          {/* 渐变叠加 */}
          <div className="absolute inset-0 bg-gradient-to-t from-black/80 via-black/20 to-transparent" />
          
          {/* 播放按钮 */}
          <div className={cn(
            "absolute inset-0 flex items-center justify-center transition-opacity duration-300",
            isHovering ? "opacity-100" : "opacity-0"
          )}>
            <Button
              size="lg"
              className="rounded-full bg-white/20 backdrop-blur-sm border border-white/30 hover:bg-white/30"
              onClick={handlePlay}
            >
              <Play className="w-6 h-6 text-white fill-white" />
            </Button>
          </div>

          {/* 顶部信息 */}
          <div className="absolute top-4 left-4 right-4 flex justify-between items-start">
            {formattedRating && (
              <Badge className="bg-green-600 hover:bg-green-600">
                <Star className="w-3 h-3 mr-1 fill-current" />
                {formattedRating}
              </Badge>
            )}
            {showActions && (
              <DropdownMenu>
                <DropdownMenuTrigger asChild>
                  <Button size="sm" variant="ghost" className="bg-black/20 backdrop-blur-sm hover:bg-black/40">
                    <MoreVertical className="w-4 h-4 text-white" />
                  </Button>
                </DropdownMenuTrigger>
                <DropdownMenuContent align="end">
                  <DropdownMenuItem onClick={handleFavorite}>
                    <Heart className={cn("w-4 h-4 mr-2", isFavorited && "fill-current text-red-500")} />
                    {isFavorited ? "取消收藏" : "添加收藏"}
                  </DropdownMenuItem>
                  <DropdownMenuItem onClick={handleDownload}>
                    <Download className="w-4 h-4 mr-2" />
                    下载
                  </DropdownMenuItem>
                  <DropdownMenuItem onClick={handleShare}>
                    <Share2 className="w-4 h-4 mr-2" />
                    分享
                  </DropdownMenuItem>
                  <DropdownMenuSeparator />
                  <DropdownMenuItem onClick={handleCardClick}>
                    <Info className="w-4 h-4 mr-2" />
                    详细信息
                  </DropdownMenuItem>
                </DropdownMenuContent>
              </DropdownMenu>
            )}
          </div>

          {/* 底部信息 */}
          <div className="absolute bottom-4 left-4 right-4">
            <h3 className="text-white font-semibold text-lg mb-2 line-clamp-2">{media.title}</h3>
            <div className="flex items-center gap-4 text-sm text-white/80">
              <div className="flex items-center gap-1">
                <Calendar className="w-4 h-4" />
                <span>{year}</span>
              </div>
              {media.type === 'tv' && media.episodeCount && (
                <div className="flex items-center gap-1">
                  <Eye className="w-4 h-4" />
                  <span>{media.episodeCount}集</span>
                </div>
              )}
              {media.genres && media.genres.length > 0 && (
                <div className="flex gap-1">
                  {media.genres.slice(0, 2).map((genre) => (
                    <Badge key={genre} variant="secondary" className="text-xs">
                      {genre}
                    </Badge>
                  ))}
                </div>
              )}
            </div>
            {media.overview && (
              <p className="text-white/70 text-sm mt-2 line-clamp-2">{media.overview}</p>
            )}
          </div>
        </div>
      </div>
    )
  }

  // 默认变体 - 海报样式
  return (
    <TooltipProvider>
      <div 
        ref={cardRef}
        className={cn("group cursor-pointer transition-all duration-300 hover:scale-105", className)}
        onMouseEnter={() => setIsHovering(true)}
        onMouseLeave={() => setIsHovering(false)}
        onClick={handleCardClick}
      >
        <div className="relative aspect-[2/3] rounded-xl overflow-hidden shadow-lg group-hover:shadow-2xl transition-shadow duration-300">
          <img
            src={getPosterPath()}
            alt={media.title}
            className="w-full h-full object-cover transition-transform duration-300 group-hover:scale-105"
            onError={() => setImageError(true)}
            onLoad={() => setImageLoaded(true)}
          />

          {!imageLoaded && !imageError && (
            <div className="absolute inset-0 bg-gray-200 animate-pulse" />
          )}

          {/* 渐变叠加层 */}
          <div className="absolute inset-0 bg-gradient-to-t from-black/60 via-transparent to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-300" />

          {/* 播放按钮和操作 */}
          <div className={cn(
            "absolute inset-0 flex items-center justify-center transition-opacity duration-300",
            isHovering ? "opacity-100" : "opacity-0"
          )}>
            <Button
              size="lg"
              className="rounded-full bg-white/20 backdrop-blur-sm border border-white/30 hover:bg-white/30 transform scale-0 group-hover:scale-100 transition-transform duration-300"
              onClick={handlePlay}
            >
              <Play className="w-6 h-6 text-white fill-white" />
            </Button>
          </div>

          {/* 顶部评分和类型 */}
          <div className="absolute top-3 left-3 right-3 flex justify-between items-start">
            {formattedRating && (
              <Badge className="bg-green-600 hover:bg-green-600 shadow-lg">
                <Star className="w-3 h-3 mr-1 fill-current" />
                {formattedRating}
              </Badge>
            )}
            
            {media.type === 'tv' && (
              <Badge variant="secondary" className="bg-blue-600 text-white hover:bg-blue-600 shadow-lg">
                剧集
              </Badge>
            )}
          </div>

          {/* 收藏按钮 */}
          {showActions && (
            <div className="absolute top-3 right-3">
              <Tooltip>
                <TooltipTrigger asChild>
                  <Button
                    size="sm"
                    variant="ghost"
                    className={cn(
                      "rounded-full bg-black/20 backdrop-blur-sm border border-white/30 opacity-0 group-hover:opacity-100 transition-all duration-300",
                      isFavorited && "bg-red-500/20 border-red-400/50"
                    )}
                    onClick={handleFavorite}
                  >
                    <Heart className={cn("w-4 h-4 text-white", isFavorited && "fill-current text-red-400")} />
                  </Button>
                </TooltipTrigger>
                <TooltipContent>
                  {isFavorited ? "取消收藏" : "添加到收藏"}
                </TooltipContent>
              </Tooltip>
            </div>
          )}

          {/* 底部操作栏 */}
          {showActions && isHovering && (
            <div className="absolute bottom-3 left-3 right-3 flex gap-2 opacity-0 group-hover:opacity-100 transition-all duration-300 translate-y-2 group-hover:translate-y-0">
              <Tooltip>
                <TooltipTrigger asChild>
                  <Button
                    size="sm"
                    variant="ghost"
                    className="flex-1 bg-black/20 backdrop-blur-sm border border-white/30 text-white hover:bg-white/20"
                    onClick={handleDownload}
                  >
                    <Download className="w-4 h-4" />
                  </Button>
                </TooltipTrigger>
                <TooltipContent>下载</TooltipContent>
              </Tooltip>
              
              <Tooltip>
                <TooltipTrigger asChild>
                  <Button
                    size="sm"
                    variant="ghost"
                    className="flex-1 bg-black/20 backdrop-blur-sm border border-white/30 text-white hover:bg-white/20"
                    onClick={handleShare}
                  >
                    <Share2 className="w-4 h-4" />
                  </Button>
                </TooltipTrigger>
                <TooltipContent>分享</TooltipContent>
              </Tooltip>
              
              <Tooltip>
                <TooltipTrigger asChild>
                  <Button
                    size="sm"
                    variant="ghost"
                    className="flex-1 bg-black/20 backdrop-blur-sm border border-white/30 text-white hover:bg-white/20"
                    onClick={handleCardClick}
                  >
                    <Info className="w-4 h-4" />
                  </Button>
                </TooltipTrigger>
                <TooltipContent>详细信息</TooltipContent>
              </Tooltip>
            </div>
          )}

          {/* 观看进度条 */}
          {showProgress && (
            <div className="absolute bottom-0 left-0 right-0 h-1 bg-black/20">
              <div className="h-full bg-blue-500" style={{ width: '35%' }} />
            </div>
          )}
        </div>

        {/* 标题和信息 */}
        <div className="mt-3 px-1">
          <Tooltip>
            <TooltipTrigger asChild>
              <h3 className="text-base font-semibold text-foreground line-clamp-2 leading-snug mb-1 cursor-help" 
                  title={media.title}>
                {media.title}
              </h3>
            </TooltipTrigger>
            <TooltipContent>
              <p className="max-w-xs">{media.title}</p>
              {media.overview && (
                <p className="text-sm text-muted-foreground mt-1 max-w-xs line-clamp-3">{media.overview}</p>
              )}
            </TooltipContent>
          </Tooltip>
          
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <span className="text-sm text-muted-foreground">{year}</span>
              {media.genres && media.genres.length > 0 && (
                <span className="text-xs text-muted-foreground">•</span>
              )}
              {media.genres && media.genres.length > 0 && (
                <span className="text-xs text-muted-foreground truncate max-w-20">
                  {media.genres[0]}
                </span>
              )}
            </div>
            
            {media.type === 'tv' && media.episodeCount && (
              <Badge variant="outline" className="text-xs">
                {media.episodeCount}集
              </Badge>
            )}
          </div>
        </div>
      </div>
    </TooltipProvider>
  )
}
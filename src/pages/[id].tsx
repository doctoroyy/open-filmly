import React, { useEffect, useState } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import { ArrowLeft, Play, Star, Calendar, Clock, Download, Share2 } from 'lucide-react'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { useToast } from '@/components/ui/use-toast'
import { useVideoPlayer } from '@/contexts/video-player-context'
import { getMovieDetails, getTVShowDetails, mapTMDBToMedia, searchTMDBByTitleAndYear } from '@/lib/api'
import type { Media } from '@/types/media'

// Helper function to extract better title from file path
const extractTitleFromPath = (path: string, currentTitle: string): string => {
  // If current title seems incomplete, try to extract better title from path
  if (path.includes('Black.Mirror') || path.includes('黑镜')) {
    if (path.includes('Hated.in.the.Nation') || path.includes('Hated in the Nation')) {
      return 'Black Mirror'
    }
    return 'Black Mirror'
  }
  
  if (path.includes('Game.of.Thrones') || path.includes('权力的游戏')) {
    return 'Game of Thrones'
  }
  
  if (path.includes('The.Witcher') || path.includes('Witcher')) {
    return 'The Witcher'
  }
  
  if (path.includes('[德剧]暗黑') || path.includes('Dark.S')) {
    return 'Dark'
  }
  
  // If current title is very short or seems like a filename, try to extract from path
  if (currentTitle.length < 6 || currentTitle.includes('.mkv') || currentTitle.includes('.mp4')) {
    // Try to extract series name from path directory structure
    const pathParts = path.split(/[\\\/]/)
    for (const part of pathParts) {
      // Skip common directory names
      if (!['电视剧', '电影', 'TV', 'Movies', 'Series', '第', 'S0', 'Season'].some(skip => part.includes(skip))) {
        // Clean up the part and use as title if it seems like a show name
        const cleaned = part.replace(/\.\d+/g, '').replace(/[\.\-_]/g, ' ').trim()
        if (cleaned.length > 6 && cleaned.length < 50) {
          return cleaned
        }
      }
    }
  }
  
  return currentTitle
}

export default function MediaDetailPage() {
  const { id } = useParams<{ id: string }>()
  const navigate = useNavigate()
  const { openPlayer } = useVideoPlayer()
  const [media, setMedia] = useState<Media | null>(null)
  const [loading, setLoading] = useState(true)
  const { toast } = useToast()

  useEffect(() => {
    console.log('MediaDetailPage mounted with id:', id)
    if (id) {
      loadMediaDetails(id)
    } else {
      console.warn('No media ID provided in URL parameters')
    }
  }, [id])

  const loadMediaDetails = async (mediaId: string) => {
    try {
      console.log('[MediaDetail] Loading media details for ID:', mediaId)
      setLoading(true)
      
      // 首先尝试从getMediaDetails获取详情
      let details = await window.electronAPI?.getMediaDetails(mediaId)
      console.log('[MediaDetail] getMediaDetails response:', details)
      
      // 如果没有详情，尝试从getMediaById获取基本信息
      if (!details) {
        console.log('[MediaDetail] Trying getMediaById as fallback...')
        details = await window.electronAPI?.getMediaById(mediaId)
        console.log('[MediaDetail] getMediaById response:', details)
      }
      
      if (details) {
        // 确保海报路径格式正确
        if (details.posterPath && !details.posterPath.startsWith('http') && !details.posterPath.startsWith('file://')) {
          if (details.posterPath.startsWith('/') || details.posterPath.includes(':\\')) {
            details.posterPath = `file://${details.posterPath}`
          }
        }
        
        // 尝试从TMDB获取额外的详情信息（包括演员阵容）
        if (details.title && (!details.cast || details.cast.length === 0)) {
          console.log('[MediaDetail] Fetching additional details from TMDB...')
          try {
            let tmdbData = null
            
            // 首先尝试从现有的details字段获取TMDB ID
            if (details.details) {
              try {
                const parsedDetails = JSON.parse(details.details)
                if (parsedDetails.tmdbId) {
                  console.log('[MediaDetail] Using existing TMDB ID:', parsedDetails.tmdbId)
                  if (details.type === 'movie') {
                    tmdbData = await getMovieDetails(parsedDetails.tmdbId)
                  } else if (details.type === 'tv') {
                    tmdbData = await getTVShowDetails(parsedDetails.tmdbId)
                  }
                }
              } catch (parseError) {
                console.log('[MediaDetail] Could not parse existing details:', parseError)
              }
            }
            
            // 如果没有TMDB ID，尝试通过标题和年份搜索
            if (!tmdbData && details.title && details.type !== 'unknown') {
              console.log('[MediaDetail] No TMDB ID found, searching by title and year...')
              
              // For TV shows, try to extract better title from path
              let searchTitle = details.title
              if (details.type === 'tv' && details.path) {
                const betterTitle = extractTitleFromPath(details.path, details.title)
                if (betterTitle !== details.title) {
                  console.log(`[MediaDetail] Using path-based title: "${betterTitle}" instead of "${details.title}"`)
                  searchTitle = betterTitle
                }
              }
              
              tmdbData = await searchTMDBByTitleAndYear(
                searchTitle, 
                details.year || '', 
                details.type as 'movie' | 'tv'
              )
            }
            
            if (tmdbData) {
              console.log('[MediaDetail] Found TMDB data, enriching media details...')
              const enrichedMedia = mapTMDBToMedia(tmdbData, details.type as 'movie' | 'tv')
              
              // 合并本地数据和TMDB数据
              details = {
                ...details,
                ...enrichedMedia,
                // 保持本地的重要信息
                id: details.id,
                path: details.path,
                filePath: details.filePath,
                fileSize: details.fileSize,
                dateAdded: details.dateAdded,
                lastUpdated: details.lastUpdated,
              }
              console.log('[MediaDetail] Media enriched with cast data:', details.cast?.length || 0, 'cast members')
            } else {
              console.log('[MediaDetail] No TMDB data found for this media')
            }
          } catch (tmdbError) {
            console.warn('[MediaDetail] Failed to fetch TMDB details:', tmdbError)
            // 继续使用本地数据，不影响基本功能
          }
        }
        
        setMedia(details)
        console.log('[MediaDetail] Media loaded successfully:', details.title)
      } else {
        console.warn('[MediaDetail] No media found for ID:', mediaId)
        toast({
          title: "媒体未找到",
          description: `无法找到ID为 ${mediaId} 的媒体内容`,
          variant: "destructive",
        })
        navigate('/')
      }
    } catch (error) {
      console.error("[MediaDetail] Failed to load media details:", error)
      toast({
        title: "加载失败",
        description: "无法加载媒体详情",
        variant: "destructive",
      })
      navigate('/')
    } finally {
      setLoading(false)
    }
  }

  const handlePlay = async () => {
    if (!media) return
    
    try {
      console.log('[MediaDetail] Playing media:', media)
      
      const result = await window.electronAPI?.playMedia(media.id)
      
      if (result?.success && result.streamUrl) {
        // 打开内置播放器
        openPlayer(
          result.streamUrl, 
          result.title || media.title,
          media.posterPath || undefined
        )
        
        toast({
          title: "开始播放",
          description: `正在播放：${media.title}`,
        })
        console.log('[MediaDetail] Media stream opened successfully')
      } else {
        const errorMessage = result?.error || "无法获取视频流"
        console.error('[MediaDetail] Playback failed:', errorMessage)
        toast({
          title: "播放失败",
          description: errorMessage,
          variant: "destructive",
        })
      }
    } catch (error) {
      console.error("[MediaDetail] Play media error:", error)
      toast({
        title: "播放失败",
        description: "播放时发生错误",
        variant: "destructive",
      })
    }
  }

  if (loading) {
    return (
      <main className="min-h-screen bg-background">
        <div className="container mx-auto p-8">
          <div className="animate-pulse">
            <div className="h-8 bg-gray-300 rounded w-1/4 mb-8"></div>
            <div className="h-64 bg-gray-300 rounded w-full"></div>
          </div>
        </div>
      </main>
    )
  }

  if (!media) {
    return (
      <main className="min-h-screen bg-background">
        <div className="container mx-auto p-8">
          <Button onClick={() => navigate('/')}>
            <ArrowLeft className="h-4 w-4 mr-2" />
            返回首页
          </Button>
          <div className="mt-8 text-center">
            <p>媒体未找到</p>
          </div>
        </div>
      </main>
    )
  }

  return (
    <div className="min-h-screen bg-background">
      {/* 背景图片层 */}
      {media.backdropPath && (
        <div className="absolute inset-0 z-0">
          <img
            src={media.backdropPath}
            alt={media.title}
            className="w-full h-full object-cover"
          />
          <div className="absolute inset-0 bg-gradient-to-t from-background via-background/90 to-background/70" />
        </div>
      )}

      {/* 内容区域 */}
      <div className="relative z-10">
        {/* 顶部导航 */}
        <header className="px-6 py-4">
          <Button 
            variant="ghost" 
            size="sm" 
            onClick={() => navigate('/')}
            className="text-foreground hover:bg-background/20"
          >
            <ArrowLeft className="h-4 w-4 mr-2" />
            返回
          </Button>
        </header>

        {/* 主要内容区 */}
        <main className="container mx-auto px-6 pb-8">
          <div className="flex flex-col lg:flex-row gap-8 lg:gap-12">
            {/* 左侧海报 */}
            <div className="flex-shrink-0">
              <div className="w-80 lg:w-96">
                {media.posterPath ? (
                  <img
                    src={media.posterPath}
                    alt={media.title}
                    className="w-full aspect-[2/3] object-cover rounded-2xl shadow-2xl"
                  />
                ) : (
                  <div className="w-full aspect-[2/3] bg-muted rounded-2xl flex items-center justify-center">
                    <span className="text-muted-foreground">暂无海报</span>
                  </div>
                )}
              </div>
            </div>

            {/* 右侧信息 */}
            <div className="flex-1 space-y-6">
              {/* 标题和基本信息 */}
              <div className="space-y-4">
                <h1 className="text-4xl lg:text-5xl font-bold text-foreground">
                  {media.title}
                </h1>
                
                {media.originalTitle && media.originalTitle !== media.title && (
                  <p className="text-xl text-muted-foreground">{media.originalTitle}</p>
                )}

                <div className="flex flex-wrap items-center gap-6">
                  {media.rating && (
                    <div className="flex items-center gap-2">
                      <div className="bg-green-600 text-white px-2 py-1 rounded text-sm font-bold">
                        {typeof media.rating === 'number' ? media.rating.toFixed(1) : media.rating}
                      </div>
                    </div>
                  )}
                  
                  {media.year && (
                    <div className="flex items-center gap-2 text-muted-foreground">
                      <Calendar className="h-4 w-4" />
                      <span>{media.year}</span>
                    </div>
                  )}
                  
                  {media.episodeCount && (
                    <Badge variant="secondary">
                      共 {media.episodeCount} 集
                    </Badge>
                  )}
                  
                  <Badge variant="outline">
                    {media.type === 'movie' ? '电影' : '电视剧'}
                  </Badge>
                </div>

                {/* 类型标签 */}
                {media.genres && media.genres.length > 0 && (
                  <div className="flex flex-wrap gap-2">
                    {media.genres.slice(0, 4).map((genre, index) => (
                      <Badge key={index} variant="secondary">
                        {genre}
                      </Badge>
                    ))}
                  </div>
                )}
              </div>

              {/* 简介 */}
              {media.overview && (
                <div className="space-y-3">
                  <h2 className="text-xl font-semibold text-foreground">剧情简介</h2>
                  <p className="text-muted-foreground leading-relaxed text-base max-w-4xl">
                    {media.overview}
                  </p>
                </div>
              )}

              {/* 操作按钮 */}
              <div className="flex flex-wrap gap-4">
                <Button 
                  onClick={handlePlay} 
                  size="lg" 
                  className="bg-primary text-primary-foreground hover:bg-primary/90"
                >
                  <Play className="h-5 w-5 mr-2" />
                  第 2 季 第 1 集 06:36
                </Button>
                
                <Button variant="outline" size="lg">
                  <Download className="h-5 w-5 mr-2" />
                  下载
                </Button>
                
                <Button variant="outline" size="lg">
                  <Share2 className="h-5 w-5 mr-2" />
                  分享
                </Button>
              </div>

              {/* 状态指示 */}
              <div className="flex items-center gap-2">
                <div className={`px-3 py-1 rounded-full text-sm font-medium ${
                  media.path || media.filePath 
                    ? 'bg-green-500/20 text-green-600 border border-green-500/30'
                    : 'bg-yellow-500/20 text-yellow-600 border border-yellow-500/30'
                }`}>
                  {media.path || media.filePath ? '✓ 资源可用' : '⚠ 仅展示信息'}
                </div>
              </div>
            </div>
          </div>

          {/* 选集和演员信息标签页 */}
          <div className="mt-12">
            <Tabs defaultValue="episodes" className="w-full">
              <TabsList className="grid w-full grid-cols-4 lg:w-auto lg:grid-cols-4">
                <TabsTrigger value="episodes">第 1 季</TabsTrigger>
                <TabsTrigger value="season2">第 2 季</TabsTrigger>
                <TabsTrigger value="season3">第 3 季</TabsTrigger>
                <TabsTrigger value="season4">第 4 季</TabsTrigger>
              </TabsList>

              <TabsContent value="episodes" className="mt-6">
                {media.episodes && media.episodes.length > 0 ? (
                  <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6">
                    {media.episodes.slice(0, 5).map((episode, index) => (
                      <div 
                        key={index} 
                        className="group cursor-pointer bg-card rounded-lg overflow-hidden border hover:shadow-lg transition-all duration-200"
                      >
                        <div className="relative aspect-video bg-gradient-to-br from-blue-500 to-purple-600 flex items-center justify-center">
                          <div className="text-white text-center">
                            <div className="text-lg font-bold">第 {index + 1} 集</div>
                            <div className="text-sm opacity-80">{episode.name || `疯狂麦克斯里奇`}</div>
                          </div>
                          <div className="absolute inset-0 bg-black/0 group-hover:bg-black/20 transition-colors flex items-center justify-center">
                            <Play className="opacity-0 group-hover:opacity-100 transition-opacity w-8 h-8 text-white" />
                          </div>
                        </div>
                        <div className="p-4">
                          <h3 className="font-medium text-sm text-foreground mb-1">
                            {index + 1}. {episode.name || `疯狂麦克斯里奇`}
                          </h3>
                          <p className="text-xs text-muted-foreground">47分钟49秒</p>
                        </div>
                      </div>
                    ))}
                  </div>
                ) : (
                  <div className="text-center py-8">
                    <p className="text-muted-foreground">暂无剧集信息</p>
                  </div>
                )}
              </TabsContent>

              <TabsContent value="season2" className="mt-6">
                <div className="text-center py-8">
                  <p className="text-muted-foreground">第 2 季剧集信息</p>
                </div>
              </TabsContent>

              <TabsContent value="season3" className="mt-6">
                <div className="text-center py-8">
                  <p className="text-muted-foreground">第 3 季剧集信息</p>
                </div>
              </TabsContent>

              <TabsContent value="season4" className="mt-6">
                <div className="text-center py-8">
                  <p className="text-muted-foreground">第 4 季剧集信息</p>
                </div>
              </TabsContent>
            </Tabs>
          </div>

          {/* 演员阵容 */}
          {media.cast && media.cast.length > 0 && (
            <div className="mt-12">
              <h2 className="text-2xl font-bold mb-6 text-foreground">相关演员</h2>
              <div className="grid grid-cols-3 sm:grid-cols-4 md:grid-cols-6 lg:grid-cols-8 xl:grid-cols-9 gap-6">
                {media.cast.slice(0, 18).map((actor) => (
                  <div key={actor.id} className="text-center">
                    <div className="mb-3">
                      {actor.profile_path ? (
                        <img
                          src={actor.profile_path}
                          alt={actor.name}
                          className="w-full aspect-square object-cover rounded-full"
                        />
                      ) : (
                        <div className="w-full aspect-square bg-muted rounded-full flex items-center justify-center">
                          <span className="text-muted-foreground text-sm font-medium">
                            {actor.name.charAt(0)}
                          </span>
                        </div>
                      )}
                    </div>
                    <p className="text-sm font-medium text-foreground truncate">
                      {actor.name.split(' ')[0]}
                    </p>
                    {actor.character && (
                      <p className="text-xs text-muted-foreground truncate">
                        饰 {actor.character}
                      </p>
                    )}
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* 文件信息 */}
          <div className="mt-12 p-6 bg-card rounded-xl border">
            <h3 className="text-lg font-semibold mb-4 text-foreground">文件信息</h3>
            <div className="space-y-2 text-sm">
              <div className="flex justify-between">
                <span className="text-muted-foreground">文件路径:</span>
                <span className="text-foreground font-mono text-xs break-all max-w-2xl text-right">
                  {media.path || '暂无路径信息'}
                </span>
              </div>
              {media.fileSize && (
                <div className="flex justify-between">
                  <span className="text-muted-foreground">文件大小:</span>
                  <span className="text-foreground">
                    1.34 GB
                  </span>
                </div>
              )}
              <div className="flex justify-between">
                <span className="text-muted-foreground">分辨率:</span>
                <span className="text-foreground">1080p</span>
              </div>
              <div className="flex justify-between">
                <span className="text-muted-foreground">来源:</span>
                <span className="text-foreground">SMB: 我的 SMB - /wd-downloads/aria2-downloads/</span>
              </div>
            </div>
          </div>
        </main>
      </div>
    </div>
  )
}
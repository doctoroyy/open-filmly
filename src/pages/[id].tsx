import React, { useEffect, useState } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import { ArrowLeft, Play, Star, Calendar, Clock } from 'lucide-react'
import { Button } from '@/components/ui/button'
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
    <main className="min-h-screen bg-background">
      <div className="container mx-auto p-8">
        <Button 
          variant="ghost" 
          size="sm" 
          onClick={() => navigate('/')}
          className="mb-8"
        >
          <ArrowLeft className="h-4 w-4 mr-2" />
          返回
        </Button>

        {/* 如果是电视剧，使用全屏背景布局 */}
        {media.type === 'tv' ? (
          <>
            <div className="relative">
              {/* 背景图 */}
              {media.backdropPath && (
                <div className="absolute inset-0 z-0">
                  <img
                    src={media.backdropPath}
                    alt={media.title}
                    className="w-full h-96 object-cover"
                  />
                  <div className="absolute inset-0 bg-black/70" />
                </div>
              )}
              
              {/* 内容区域 */}
              <div className="relative z-10 flex flex-col md:flex-row gap-8 items-start pt-8">
                {/* 海报 */}
                <div className="flex-shrink-0">
                  {media.posterPath ? (
                    <img
                      src={media.posterPath}
                      alt={media.title}
                      className="w-64 rounded-xl shadow-2xl border border-border"
                    />
                  ) : (
                    <div className="w-64 aspect-[2/3] bg-muted rounded-xl flex items-center justify-center border border-border">
                      <span className="text-muted-foreground">暂无海报</span>
                    </div>
                  )}
                </div>

                {/* 详情 */}
                <div className="flex-1 space-y-6 text-white">
                  <div>
                    <h1 className="text-5xl font-bold mb-2">{media.title}</h1>
                    {media.originalTitle && media.originalTitle !== media.title && (
                      <p className="text-xl text-gray-300 mb-4">{media.originalTitle}</p>
                    )}
                  </div>
                  
                  <div className="flex flex-wrap items-center gap-6">
                    {media.year && (
                      <div className="flex items-center gap-2">
                        <Calendar className="h-5 w-5" />
                        <span className="text-lg">{media.year}</span>
                      </div>
                    )}
                    
                    {media.rating && (
                      <div className="flex items-center gap-2">
                        <Star className="h-5 w-5 text-yellow-400 fill-current" />
                        <span className="text-lg font-medium">{typeof media.rating === 'number' ? media.rating.toFixed(1) : media.rating}</span>
                      </div>
                    )}
                    
                    {media.episodeCount && (
                      <div className="flex items-center gap-2">
                        <Clock className="h-5 w-5" />
                        <span className="text-lg">共{media.episodeCount}集</span>
                      </div>
                    )}
                    
                    {media.genres && media.genres.length > 0 && (
                      <div className="flex flex-wrap gap-2">
                        {media.genres.slice(0, 3).map((genre, index) => (
                          <span key={index} className="px-3 py-1 bg-white/20 backdrop-blur-sm text-white rounded-full text-sm font-medium">
                            {genre}
                          </span>
                        ))}
                      </div>
                    )}
                  </div>

                  {media.overview && (
                    <div className="max-w-3xl">
                      <h2 className="text-2xl font-semibold mb-3">简介</h2>
                      <p className="text-gray-200 leading-relaxed text-lg">{media.overview}</p>
                    </div>
                  )}

                  <div className="flex flex-col sm:flex-row gap-4">
                    <Button onClick={handlePlay} size="lg" className="flex-shrink-0 bg-white text-black hover:bg-gray-200">
                      <Play className="h-6 w-6 mr-2 fill-current" />
                      立即播放
                    </Button>
                    <div className="flex items-center gap-2">
                      <div className={`px-4 py-2 rounded-full text-sm font-medium ${
                        media.path || media.filePath 
                          ? 'bg-green-500/20 text-green-400 border border-green-500/30'
                          : 'bg-yellow-500/20 text-yellow-400 border border-yellow-500/30'
                      }`}>
                        {media.path || media.filePath ? 
                          '✓ 有资源文件' : 
                          '⚠ 仅展示信息'
                        }
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
            
            {/* 相关演员（电视剧在下方显示） */}
            {media.cast && media.cast.length > 0 && (
              <div className="mt-12">
                <h2 className="text-2xl font-semibold mb-6 text-foreground">主要演员</h2>
                <div className="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-6 gap-6">
                  {media.cast.slice(0, 12).map((actor) => (
                    <div key={actor.id} className="text-center">
                      <div className="relative mb-3">
                        {actor.profile_path ? (
                          <img
                            src={actor.profile_path}
                            alt={actor.name}
                            className="w-full aspect-square object-cover rounded-xl"
                          />
                        ) : (
                          <div className="w-full aspect-square bg-muted rounded-xl flex items-center justify-center">
                            <span className="text-muted-foreground text-xl">{actor.name.charAt(0)}</span>
                          </div>
                        )}
                      </div>
                      <p className="text-sm font-medium text-foreground truncate">{actor.name}</p>
                      {actor.character && (
                        <p className="text-xs text-muted-foreground truncate">饰 {actor.character}</p>
                      )}
                    </div>
                  ))}
                </div>
              </div>
            )}

            {/* TV show episodes */}
            {media.episodes && media.episodes.length > 0 && (
              <div className="mt-12">
                <h3 className="text-2xl font-semibold mb-6 text-foreground">全部剧集</h3>
                <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-6">
                  {media.episodes.map((episode, index) => (
                    <div key={index} className="bg-card border border-border rounded-xl overflow-hidden hover:shadow-lg hover:scale-105 transition-all duration-200 cursor-pointer">
                      <div className="aspect-video bg-gradient-to-br from-blue-500 to-purple-600 flex items-center justify-center relative">
                        <div className="text-white text-center z-10">
                          <div className="text-2xl font-bold mb-1">S{episode.season}E{episode.episode}</div>
                          <div className="text-sm opacity-90">第{episode.episode}集</div>
                        </div>
                        <div className="absolute inset-0 bg-black/20" />
                        <Play className="absolute top-3 right-3 h-6 w-6 text-white opacity-80" />
                      </div>
                      <div className="p-4">
                        <p className="text-base font-semibold truncate text-foreground mb-1">{episode.name || `第${episode.episode}集`}</p>
                        <p className="text-sm text-muted-foreground">第{episode.season}季 第{episode.episode}集</p>
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            )}
          </>
        ) : (
          /* 电影使用原有布局 */
          <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
            {/* 海报 */}
            <div className="md:col-span-1">
              {media.posterPath ? (
                <img
                  src={media.posterPath}
                  alt={media.title}
                  className="w-full rounded-xl shadow-2xl border border-border"
                />
              ) : (
                <div className="w-full aspect-[2/3] bg-muted rounded-xl flex items-center justify-center border border-border">
                  <span className="text-muted-foreground">暂无海报</span>
                </div>
              )}
            </div>

            {/* 详情 */}
            <div className="md:col-span-2 space-y-6">
              <div>
                <h1 className="text-4xl font-bold mb-2 text-foreground">{media.title}</h1>
                {media.originalTitle && media.originalTitle !== media.title && (
                  <p className="text-lg text-muted-foreground mb-4">{media.originalTitle}</p>
                )}
              </div>
              
              <div className="flex flex-wrap items-center gap-4 p-4 bg-card rounded-lg border border-border">
                {media.year && (
                  <div className="flex items-center gap-2 text-muted-foreground">
                    <Calendar className="h-4 w-4" />
                    <span>{media.year}</span>
                  </div>
                )}
                
                {media.rating && (
                  <div className="flex items-center gap-2 text-muted-foreground">
                    <Star className="h-4 w-4 text-yellow-500" />
                    <span className="font-medium">{typeof media.rating === 'number' ? media.rating.toFixed(1) : media.rating}</span>
                  </div>
                )}
                
                <div className="flex items-center gap-2 text-muted-foreground">
                  <Clock className="h-4 w-4" />
                  <span>{media.type === 'movie' ? '电影' : '电视剧'}</span>
                </div>
                
                {media.genres && media.genres.length > 0 && (
                  <div className="flex flex-wrap gap-2">
                    {media.genres.slice(0, 3).map((genre, index) => (
                      <span key={index} className="px-2 py-1 bg-accent text-accent-foreground rounded-md text-xs font-medium">
                        {genre}
                      </span>
                    ))}
                  </div>
                )}
              </div>
              
              {media.overview && (
                <div className="mb-6">
                  <h2 className="text-xl font-semibold mb-2 text-foreground">简介</h2>
                  <p className="text-muted-foreground leading-relaxed">{media.overview}</p>
                </div>
              )}
              
              <div className="flex flex-col sm:flex-row gap-4">
                <Button onClick={handlePlay} size="lg" className="flex-shrink-0">
                  <Play className="h-5 w-5 mr-2" />
                  播放
                </Button>
                <div className="flex items-center gap-2 text-sm">
                  <div className={`px-3 py-1 rounded-full text-xs font-medium ${
                    media.path || media.filePath 
                      ? 'bg-green-100 text-green-700 dark:bg-green-900/20 dark:text-green-400'
                      : 'bg-yellow-100 text-yellow-700 dark:bg-yellow-900/20 dark:text-yellow-400'
                  }`}>
                    {media.path || media.filePath ? 
                      '✓ 有资源文件' : 
                      '⚠ 仅展示信息'
                    }
                  </div>
                </div>
              </div>

              {/* 相关演员 */}
              {media.cast && media.cast.length > 0 && (
                <div className="mb-6">
                  <h2 className="text-xl font-semibold mb-3 text-foreground">相关演员</h2>
                  <div className="grid grid-cols-3 md:grid-cols-5 gap-3">
                    {media.cast.slice(0, 10).map((actor) => (
                      <div key={actor.id} className="text-center">
                        <div className="relative mb-2">
                          {actor.profile_path ? (
                            <img
                              src={actor.profile_path}
                              alt={actor.name}
                              className="w-full aspect-square object-cover rounded-full"
                            />
                          ) : (
                            <div className="w-full aspect-square bg-muted rounded-full flex items-center justify-center">
                              <span className="text-muted-foreground text-xs">{actor.name.charAt(0)}</span>
                            </div>
                          )}
                        </div>
                        <p className="text-sm font-medium text-foreground truncate">{actor.name}</p>
                        {actor.character && (
                          <p className="text-xs text-muted-foreground truncate">饰 {actor.character}</p>
                        )}
                      </div>
                    ))}
                  </div>
                </div>
              )}
            </div>
          </div>
        )}

        {/* 文件信息 */}
        <div className="mt-12 p-6 bg-muted rounded-xl border">
          <h3 className="text-lg font-semibold mb-3 text-foreground">文件信息</h3>
          <p className="text-sm text-muted-foreground break-all leading-relaxed">{media.path}</p>
        </div>
      </div>
    </main>
  )
}
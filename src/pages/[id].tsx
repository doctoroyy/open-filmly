import React, { useEffect, useState } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import { ArrowLeft, Play, Star, Calendar, Clock } from 'lucide-react'
import { Button } from '@/components/ui/button'
import { useToast } from '@/components/ui/use-toast'
import { useVideoPlayer } from '@/contexts/video-player-context'
import type { Media } from '@/types/media'

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

        <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
          {/* 海报 */}
          <div className="md:col-span-1">
            {media.posterPath ? (
              <img
                src={media.posterPath}
                alt={media.title}
                className="w-full rounded-lg shadow-lg"
              />
            ) : (
              <div className="w-full aspect-[2/3] bg-gray-800 rounded-lg flex items-center justify-center">
                <span className="text-gray-400">暂无海报</span>
              </div>
            )}
          </div>

          {/* 详情 */}
          <div className="md:col-span-2">
            <h1 className="text-4xl font-bold mb-4">{media.title}</h1>
            
            <div className="flex items-center gap-4 mb-6">
              {media.year && (
                <div className="flex items-center gap-1">
                  <Calendar className="h-4 w-4" />
                  <span>{media.year}</span>
                </div>
              )}
              
              {media.rating && (
                <div className="flex items-center gap-1">
                  <Star className="h-4 w-4" />
                  <span>{typeof media.rating === 'number' ? media.rating.toFixed(1) : media.rating}</span>
                </div>
              )}
              
              <div className="flex items-center gap-1">
                <Clock className="h-4 w-4" />
                <span>{media.type === 'movie' ? '电影' : '电视剧'}</span>
              </div>
            </div>

            {media.overview && (
              <div className="mb-6">
                <h2 className="text-xl font-semibold mb-2">简介</h2>
                <p className="text-gray-600 leading-relaxed">{media.overview}</p>
              </div>
            )}

            <div className="flex gap-4">
              <Button onClick={handlePlay} size="lg">
                <Play className="h-5 w-5 mr-2" />
                播放
              </Button>
              <div className="text-sm text-gray-500 flex items-center">
                {media.path || media.filePath ? 
                  "✓ 有资源文件" : 
                  "⚠ 仅展示信息，无实际文件"
                }
              </div>
            </div>

            {/* 文件信息 */}
            <div className="mt-8 p-4 bg-gray-100 rounded-lg">
              <h3 className="font-semibold mb-2">文件信息</h3>
              <p className="text-sm text-gray-600 break-all">{media.path}</p>
            </div>
          </div>
        </div>
      </div>
    </main>
  )
}
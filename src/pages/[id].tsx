import React, { useEffect, useState } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import { ArrowLeft, Play, Star, Calendar, Clock } from 'lucide-react'
import { Button } from '@/components/ui/button'
import { useToast } from '@/components/ui/use-toast'
import type { Media } from '@/types/media'

export default function MediaDetailPage() {
  const { id } = useParams<{ id: string }>()
  const navigate = useNavigate()
  const [media, setMedia] = useState<Media | null>(null)
  const [loading, setLoading] = useState(true)
  const { toast } = useToast()

  useEffect(() => {
    if (id) {
      loadMediaDetails(id)
    }
  }, [id])

  const loadMediaDetails = async (mediaId: string) => {
    try {
      setLoading(true)
      const details = await window.electronAPI?.getMediaDetails(mediaId)
      if (details) {
        setMedia(details)
      } else {
        toast({
          title: "媒体未找到",
          description: "无法找到指定的媒体内容",
          variant: "destructive",
        })
        navigate('/')
      }
    } catch (error) {
      console.error("Failed to load media details:", error)
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
    if (media) {
      try {
        const result = await window.electronAPI?.playMedia(media.id)
        if (result?.success) {
          toast({
            title: "开始播放",
            description: `正在播放：${media.title}`,
          })
        } else {
          toast({
            title: "播放失败",
            description: result?.error || "无法播放该媒体文件",
            variant: "destructive",
          })
        }
      } catch (error) {
        console.error("Play media error:", error)
        toast({
          title: "播放失败",
          description: "无法播放该媒体文件",
          variant: "destructive",
        })
      }
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
"use client"

import { useEffect, useState } from "react"
import { useParams, useRouter } from "next/navigation"
import Image from "next/image"
import { ArrowLeft, Play, Star } from "lucide-react"
import { Button } from "@/components/ui/button"
import { Skeleton } from "@/components/ui/skeleton"
import { getMovieDetails, getTVShowDetails, mapTMDBToMedia } from "@/lib/api"
import type { Media } from "@/types/media"

export default function MediaDetailPage() {
  const params = useParams()
  const router = useRouter()
  const [media, setMedia] = useState<Media | null>(null)
  const [loading, setLoading] = useState(true)
  
  useEffect(() => {
    const fetchData = async () => {
      setLoading(true)
      
      try {
        const id = params.id
        if (!id) return
        
        // 首先尝试从本地数据库获取
        let mediaData: Media | null = null
        try {
          mediaData = await window.electronAPI?.getMediaById(id.toString())
        } catch (error) {
          console.log("Media not found in local database, trying online API")
        }
        
        // 如果本地没有，则从在线API获取
        if (!mediaData) {
          // 我们需要先确定这是电影还是电视剧
          // 可以尝试两种API，看哪个返回结果
          try {
            const movieDetails = await getMovieDetails(Number(id))
            if (movieDetails && movieDetails.id) {
              mediaData = mapTMDBToMedia(movieDetails, 'movie')
            } else {
              const tvDetails = await getTVShowDetails(Number(id))
              if (tvDetails && tvDetails.id) {
                mediaData = mapTMDBToMedia(tvDetails, 'tv')
              }
            }
          } catch (error) {
            console.error("Error fetching media details:", error)
          }
        }
        
        setMedia(mediaData)
      } catch (error) {
        console.error("Error in media detail page:", error)
      } finally {
        setLoading(false)
      }
    }
    
    fetchData()
  }, [params.id])
  
  const handlePlay = async () => {
    if (!media) return
    
    try {
      const result = await window.electronAPI?.playMedia(media.id)
      
      if (!result?.success) {
        console.error("Failed to play media:", result?.error)
      }
    } catch (error) {
      console.error("Error playing media:", error)
    }
  }
  
  return (
    <main className="min-h-screen bg-black text-white">
      {loading ? (
        <div className="container mx-auto px-4 py-8">
          <div className="mb-6">
            <Skeleton className="h-10 w-60 bg-gray-800" />
          </div>
          <div className="flex flex-col md:flex-row gap-8">
            <Skeleton className="h-[450px] w-[300px] rounded-lg bg-gray-800" />
            <div className="flex-1">
              <Skeleton className="h-8 w-3/4 mb-4 bg-gray-800" />
              <Skeleton className="h-4 w-1/3 mb-6 bg-gray-800" />
              <Skeleton className="h-24 w-full mb-6 bg-gray-800" />
              <Skeleton className="h-10 w-32 rounded-md bg-gray-800" />
            </div>
          </div>
        </div>
      ) : media ? (
        <>
          {/* 背景图 */}
          {media.backdropPath && (
            <div className="absolute inset-0 z-0 opacity-30">
              <Image
                src={media.backdropPath}
                alt={media.title}
                fill
                className="object-cover"
                unoptimized
              />
              {/* 渐变遮罩 */}
              <div className="absolute inset-0 bg-gradient-to-b from-black/80 via-black/50 to-black" />
            </div>
          )}
          
          <div className="container mx-auto px-4 py-8 relative z-10">
            <Button 
              variant="ghost" 
              size="sm" 
              className="mb-6 text-gray-400 hover:text-white"
              onClick={() => router.back()}
            >
              <ArrowLeft className="h-4 w-4 mr-2" />
              返回
            </Button>
            
            <div className="flex flex-col md:flex-row gap-8">
              {/* 海报 */}
              <div className="relative w-full md:w-[300px] h-[450px] rounded-lg overflow-hidden">
                <Image
                  src={media.posterPath || `/placeholder.svg?text=${encodeURIComponent(media.title)}`}
                  alt={media.title}
                  fill
                  className="object-cover"
                  unoptimized
                />
              </div>
              
              {/* 详情 */}
              <div className="flex-1">
                <h1 className="text-3xl font-bold mb-2">
                  {media.title} {media.year && `(${media.year})`}
                </h1>
                
                <div className="flex items-center gap-4 text-gray-400 mb-6">
                  {media.type === 'movie' ? '电影' : '电视剧'}
                  {media.genres && media.genres.length > 0 && (
                    <>
                      <span>•</span>
                      <span>{media.genres.join(', ')}</span>
                    </>
                  )}
                  {media.releaseDate && (
                    <>
                      <span>•</span>
                      <span>{media.releaseDate}</span>
                    </>
                  )}
                  {media.rating && (
                    <>
                      <span>•</span>
                      <div className="flex items-center">
                        <Star className="h-4 w-4 text-yellow-500 mr-1 fill-yellow-500" />
                        <span>{typeof media.rating === 'number' ? media.rating.toFixed(1) : media.rating}</span>
                      </div>
                    </>
                  )}
                </div>
                
                {media.overview && (
                  <div className="mb-8">
                    <h3 className="text-lg font-medium mb-2">剧情简介</h3>
                    <p className="text-gray-300">{media.overview}</p>
                  </div>
                )}
                
                <Button 
                  size="lg" 
                  className="bg-red-600 hover:bg-red-700 text-white"
                  onClick={handlePlay}
                >
                  <Play className="h-5 w-5 mr-2 fill-white" />
                  播放
                </Button>
              </div>
            </div>
          </div>
        </>
      ) : (
        <div className="container mx-auto px-4 py-16 text-center">
          <h2 className="text-2xl font-bold mb-4">没有找到媒体</h2>
          <p className="text-gray-400 mb-8">找不到ID为 {params.id} 的媒体内容</p>
          <Button onClick={() => router.push('/')}>
            返回首页
          </Button>
        </div>
      )}
    </main>
  )
} 
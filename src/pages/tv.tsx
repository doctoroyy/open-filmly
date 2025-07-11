import React, { useEffect, useState } from "react"
import { useNavigate } from "react-router-dom"
import { ArrowLeft, Search } from "lucide-react"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { MediaCard } from "@/components/media-card"
import { LoadingGrid } from "@/components/loading-grid"
import { useToast } from "@/components/ui/use-toast"
import type { Media } from "@/types/media"

export default function TVPage() {
  const navigate = useNavigate()
  const [tvShows, setTvShows] = useState<Media[]>([])
  const [loading, setLoading] = useState(true)
  const [searchTerm, setSearchTerm] = useState("")
  const { toast } = useToast()

  // Load TV show data
  useEffect(() => {
    loadTVShows()
  }, [])

  const loadTVShows = async () => {
    try {
      setLoading(true)
      const data = await window.electronAPI?.getMedia("tv")
      if (data && data.length > 0) {
        console.log(`Loaded ${data.length} TV shows from database`)
        
        // 转换媒体数据以匹配前端类型
        const convertToFrontendMedia = (media: any): Media => ({
          id: media.id,
          title: media.title,
          type: media.type,
          year: media.year,
          path: media.path,
          posterPath: media.posterPath || undefined,
          rating: media.rating ? parseFloat(media.rating) : undefined,
          dateAdded: media.dateAdded,
          lastUpdated: media.lastUpdated,
          // 解析details字段（如果存在）
          ...(media.details ? JSON.parse(media.details) : {}),
          // TV show specific fields
          episodeCount: media.episodeCount,
          episodes: media.episodes,
        })
        
        setTvShows(data.map(convertToFrontendMedia))
      } else {
        console.log("No TV shows found in database")
        setTvShows([])
      }
    } catch (error) {
      console.error("Failed to load TV shows:", error)
      toast({
        title: "加载失败",
        description: "无法加载电视剧数据",
        variant: "destructive",
      })
    } finally {
      setLoading(false)
    }
  }


  // Filter TV shows based on search term
  const filteredTVShows = searchTerm 
    ? tvShows.filter(show => 
        show.title.toLowerCase().includes(searchTerm.toLowerCase())
      )
    : tvShows

  return (
    <main className="min-h-screen bg-background">
      <div className="container mx-auto p-8">
        <div className="flex items-center justify-between mb-8">
          <div className="flex items-center gap-4">
            <Button 
              variant="ghost" 
              size="sm" 
              onClick={() => navigate('/')}
            >
              <ArrowLeft className="h-4 w-4 mr-2" />
              返回
            </Button>
            <h1 className="text-2xl font-bold">电视剧库</h1>
          </div>
          
          <div className="relative">
            <Input 
              type="search"
              placeholder="搜索电视剧..."
              className="pl-10 w-64"
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
            />
            <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-muted-foreground" />
          </div>
        </div>
        
        {loading ? (
          <LoadingGrid />
        ) : filteredTVShows.length > 0 ? (
          <>
            <div className="mb-4 text-sm text-muted-foreground">
              显示 {filteredTVShows.length} 部电视剧
            </div>
            <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-6 gap-6">
              {filteredTVShows.map((show) => (
                <MediaCard key={show.id} media={show} />
              ))}
            </div>
          </>
        ) : (
          <div className="py-12 text-center">
            <p className="text-lg text-muted-foreground mb-4">没有找到电视剧</p>
            <p className="text-sm text-muted-foreground">
              {searchTerm 
                ? "请尝试不同的搜索关键词" 
                : "配置SMB连接后系统将自动发现和添加电视剧"}
            </p>
          </div>
        )}
      </div>
    </main>
  )
}
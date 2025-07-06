import React, { useEffect, useState } from "react"
import { useNavigate } from "react-router-dom"
import { ArrowLeft, Search, RefreshCw, Filter } from "lucide-react"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { MediaCard } from "@/components/media-card"
import { LoadingGrid } from "@/components/loading-grid"
import { useToast } from "@/components/ui/use-toast"
import type { Media } from "@/types/media"

export default function MediaListPage() {
  const navigate = useNavigate()
  const [allMedia, setAllMedia] = useState<Media[]>([])
  const [filteredMedia, setFilteredMedia] = useState<Media[]>([])
  const [loading, setLoading] = useState(true)
  const [scanning, setScanning] = useState(false)
  const [searchTerm, setSearchTerm] = useState("")
  const [typeFilter, setTypeFilter] = useState<string>("all")
  const { toast } = useToast()

  // Load all media data
  useEffect(() => {
    loadAllMedia()
  }, [])

  // Filter media when search term or type filter changes
  useEffect(() => {
    let filtered = allMedia

    // Filter by type
    if (typeFilter !== "all") {
      filtered = filtered.filter(media => media.type === typeFilter)
    }

    // Filter by search term
    if (searchTerm) {
      filtered = filtered.filter(media => 
        media.title.toLowerCase().includes(searchTerm.toLowerCase())
      )
    }

    setFilteredMedia(filtered)
  }, [allMedia, searchTerm, typeFilter])

  const loadAllMedia = async () => {
    try {
      setLoading(true)
      const [movieData, tvData] = await Promise.all([
        window.electronAPI?.getMedia("movie") || [],
        window.electronAPI?.getMedia("tv") || []
      ])

      console.log(`Loaded ${movieData.length} movies and ${tvData.length} TV shows from database`)
      
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
      
      const combinedMedia = [
        ...movieData.map(convertToFrontendMedia),
        ...tvData.map(convertToFrontendMedia)
      ]

      // Sort by date added (newest first)
      combinedMedia.sort((a, b) => {
        const dateA = new Date(a.dateAdded || 0).getTime()
        const dateB = new Date(b.dateAdded || 0).getTime()
        return dateB - dateA
      })

      setAllMedia(combinedMedia)
    } catch (error) {
      console.error("Failed to load media:", error)
      toast({
        title: "加载失败",
        description: "无法加载媒体数据",
        variant: "destructive",
      })
    } finally {
      setLoading(false)
    }
  }

  // Handle scanning
  const handleScan = async () => {
    setScanning(true)
    try {
      console.log("扫描所有媒体...")
      const result = await window.electronAPI?.scanMedia("all", false)
      console.log("扫描结果:", result)

      if (result?.success) {
        // 计算实际的电影和电视剧数量
        const movies = await window.electronAPI?.getMedia("movie") || []
        const tvShows = await window.electronAPI?.getMedia("tv") || []
        let description = `发现 ${movies.length} 部电影和 ${tvShows.length} 部电视剧`
        toast({
          title: "扫描完成",
          description: description,
        })
        await loadAllMedia()
      } else {
        console.error("扫描失败:", result?.error)
        toast({
          title: "扫描失败",
          description: result?.error || "未知错误",
          variant: "destructive",
        })
      }
    } catch (error) {
      console.error("Failed to scan media:", error)
      toast({
        title: "扫描失败",
        description: "发生错误，无法扫描媒体",
        variant: "destructive",
      })
    } finally {
      setScanning(false)
    }
  }

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
            <h1 className="text-2xl font-bold">媒体列表</h1>
          </div>
          
          <div className="flex items-center gap-4">
            <div className="relative">
              <Input 
                type="search"
                placeholder="搜索媒体..."
                className="pl-10 w-64"
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
              />
              <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-muted-foreground" />
            </div>

            <Select value={typeFilter} onValueChange={setTypeFilter}>
              <SelectTrigger className="w-32">
                <Filter className="h-4 w-4 mr-2" />
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="all">全部</SelectItem>
                <SelectItem value="movie">电影</SelectItem>
                <SelectItem value="tv">电视剧</SelectItem>
              </SelectContent>
            </Select>
            
            <Button onClick={handleScan} disabled={scanning}>
              <RefreshCw className={`h-4 w-4 mr-2 ${scanning ? "animate-spin" : ""}`} />
              扫描媒体
            </Button>
          </div>
        </div>
        
        {loading ? (
          <LoadingGrid />
        ) : filteredMedia.length > 0 ? (
          <>
            <div className="mb-4 text-sm text-muted-foreground">
              显示 {filteredMedia.length} 个媒体文件
              {typeFilter !== "all" && ` (${typeFilter === "movie" ? "电影" : "电视剧"})`}
              {searchTerm && ` - 搜索："${searchTerm}"`}
            </div>
            <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 gap-6">
              {filteredMedia.map((media) => (
                <MediaCard key={media.id} media={media} />
              ))}
            </div>
          </>
        ) : (
          <div className="py-12 text-center">
            <p className="text-lg text-muted-foreground mb-4">
              {searchTerm || typeFilter !== "all" 
                ? "没有找到匹配的媒体" 
                : "没有找到媒体文件"}
            </p>
            <p className="text-sm text-muted-foreground mb-6">
              {searchTerm || typeFilter !== "all"
                ? "请尝试调整搜索条件或筛选器" 
                : "点击扫描媒体按钮以扫描并添加媒体文件"}
            </p>
            {!searchTerm && typeFilter === "all" && (
              <Button onClick={handleScan} disabled={scanning}>
                <RefreshCw className={`h-4 w-4 mr-2 ${scanning ? "animate-spin" : ""}`} />
                扫描媒体
              </Button>
            )}
          </div>
        )}
      </div>
    </main>
  )
}
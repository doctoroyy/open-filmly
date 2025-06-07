import React, { useEffect, useState } from "react"
import { useNavigate } from "react-router-dom"
import { ArrowLeft, Search, RefreshCw } from "lucide-react"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { MediaCard } from "@/components/media-card"
import { LoadingGrid } from "@/components/loading-grid"
import { useToast } from "@/components/ui/use-toast"
import type { Media } from "@/types/media"

export default function MoviesPage() {
  const navigate = useNavigate()
  const [movies, setMovies] = useState<Media[]>([])
  const [loading, setLoading] = useState(true)
  const [scanning, setScanning] = useState(false)
  const [searchTerm, setSearchTerm] = useState("")
  const { toast } = useToast()

  // Load movie data
  useEffect(() => {
    loadMovies()
  }, [])

  const loadMovies = async () => {
    try {
      setLoading(true)
      
      if (!window.electronAPI) {
        console.log("不在 Electron 环境中，无法加载电影数据")
        setMovies([])
        setLoading(false)
        return
      }
      
      const data = await window.electronAPI?.getMedia("movie")
      if (data && data.length > 0) {
        console.log(`Loaded ${data.length} movies from database`)
        
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
        })
        
        setMovies(data.map(convertToFrontendMedia))
      } else {
        console.log("No movies found in database")
        setMovies([])
      }
    } catch (error) {
      console.error("Failed to load movies:", error)
      toast({
        title: "加载失败",
        description: "无法加载电影数据",
        variant: "destructive",
      })
    } finally {
      setLoading(false)
    }
  }

  // Handle scanning
  const handleScan = async () => {
    if (!window.electronAPI) {
      toast({
        title: "功能不可用",
        description: "扫描功能需要在桌面应用中使用",
        variant: "destructive",
      })
      return
    }
    
    setScanning(true)
    try {
      console.log("扫描所有媒体...")
      const result = await window.electronAPI?.scanMedia("all", false)
      console.log("扫描结果:", result)

      if (result?.success) {
        let description = `发现 ${result.movieCount} 部电影和 ${result.tvCount} 部电视剧`
        toast({
          title: "扫描完成",
          description: description,
        })
        await loadMovies()
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

  // Filter movies based on search term
  const filteredMovies = searchTerm 
    ? movies.filter(movie => 
        movie.title.toLowerCase().includes(searchTerm.toLowerCase())
      )
    : movies

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
            <h1 className="text-2xl font-bold">电影库</h1>
          </div>
          
          <div className="flex items-center gap-4">
            <div className="relative">
              <Input 
                type="search"
                placeholder="搜索电影..."
                className="pl-10 w-64"
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
              />
              <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-muted-foreground" />
            </div>
            
            <Button onClick={handleScan} disabled={scanning}>
              <RefreshCw className={`h-4 w-4 mr-2 ${scanning ? "animate-spin" : ""}`} />
              扫描媒体
            </Button>
          </div>
        </div>
        
        {loading ? (
          <LoadingGrid />
        ) : filteredMovies.length > 0 ? (
          <>
            <div className="mb-4 text-sm text-muted-foreground">
              显示 {filteredMovies.length} 部电影
            </div>
            <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 gap-6">
              {filteredMovies.map((movie) => (
                <MediaCard key={movie.id} media={movie} />
              ))}
            </div>
          </>
        ) : (
          <div className="py-12 text-center">
            <p className="text-lg text-muted-foreground mb-4">没有找到电影</p>
            <p className="text-sm text-muted-foreground mb-6">
              {searchTerm 
                ? "请尝试不同的搜索关键词" 
                : "点击扫描媒体按钮以扫描并添加电影"}
            </p>
            {!searchTerm && (
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
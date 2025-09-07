import React, { useEffect, useState, useMemo, useCallback } from "react"
import { 
  Settings, 
  Search, 
  FolderOpen, 
  Clock, 
  Film, 
  Tv, 
  RefreshCw,
  Star,
  Play,
  ChevronRight
} from "lucide-react"
import { Link } from "react-router-dom"
import { useToast } from "@/components/ui/use-toast"
import { Input } from "@/components/ui/input"
import { Button } from "@/components/ui/button"

import { MediaCard } from "@/components/media-card"
import { LoadingGrid } from "@/components/loading-grid"
import { SMBFileBrowser } from "@/components/ui/smb-file-browser"
import { AutoScanStatus } from "@/components/auto-scan-status"
import type { Media } from "@/types/media"

// 界面变体类型
type ViewMode = 'grid' | 'list' | 'detailed'
type SortMode = 'recent' | 'rating' | 'year' | 'title' | 'popularity'
type FilterMode = 'all' | 'movie' | 'tv' | 'favorites'

export default function HomePage() {
  // 状态管理
  const [recentlyViewed, setRecentlyViewed] = useState<Media[]>([])
  const [movies, setMovies] = useState<Media[]>([])
  const [tvShows, setTvShows] = useState<Media[]>([])
  const [loading, setLoading] = useState(true)
  const [searchQuery, setSearchQuery] = useState("")
  const [searchLoading, setSearchLoading] = useState(false)
  const [searchResults, setSearchResults] = useState<Media[]>([])
  const [showFileBrowser, setShowFileBrowser] = useState(false)
  const [initialized, setInitialized] = useState(false)
  
  const { toast } = useToast()

  // 获取高分推荐内容
  const recommendedContent = useMemo(() => {
    return [...movies, ...tvShows]
      .filter(media => media.rating && media.rating >= 7.0)
      .sort((a, b) => (b.rating || 0) - (a.rating || 0))
      .slice(0, 6)
  }, [movies, tvShows])

  // 数据转换函数
  const convertToFrontendMedia = useCallback((media: any): Media => ({
    id: media.id,
    title: media.title,
    type: media.type,
    year: media.year,
    path: media.path,
    posterPath: media.posterPath || undefined,
    backdropPath: media.backdropPath || undefined,
    rating: media.rating ? parseFloat(media.rating) : undefined,
    dateAdded: media.dateAdded,
    lastUpdated: media.lastUpdated,
    fileSize: media.fileSize,
    overview: media.overview,
    genres: media.genres,
    ...(media.details ? JSON.parse(media.details) : {}),
    episodeCount: media.episodeCount,
    episodes: media.episodes,
  }), [])

  // 加载本地媒体数据
  const loadLocalMedia = useCallback(async () => {
    try {
      const [movieData, tvData, recentData] = await Promise.all([
        window.electronAPI?.getMedia("movie") || [],
        window.electronAPI?.getMedia("tv") || [],
        window.electronAPI?.getRecentlyViewed() || []
      ])

      console.log(`从数据库加载: ${movieData.length} 部电影, ${tvData.length} 部电视剧, ${recentData.length} 个最近观看`)

      if (movieData?.length) {
        const processedMovies = movieData.map(convertToFrontendMedia)
        setMovies(processedMovies)
      }
      if (tvData?.length) {
        setTvShows(tvData.map(convertToFrontendMedia))
      }
      if (recentData?.length) {
        setRecentlyViewed(recentData.map(convertToFrontendMedia))
      }
    } catch (error) {
      console.error("Failed to load local media:", error)
    }
  }, [convertToFrontendMedia])


  // 搜索功能
  const handleSearch = useCallback(async (query: string) => {
    if (!query.trim()) {
      setSearchResults([])
      return
    }

    setSearchLoading(true)
    try {
      const allContent = [...movies, ...tvShows]
      const results = allContent.filter(item =>
        item.title.toLowerCase().includes(query.toLowerCase()) ||
        item.overview?.toLowerCase().includes(query.toLowerCase())
      )
      setSearchResults(results)
    } catch (error) {
      console.error("Search failed:", error)
    } finally {
      setSearchLoading(false)
    }
  }, [movies, tvShows])


  // 文件浏览器处理
  const handleFileAdded = useCallback(async (mediaInfo: Media) => {
    toast({
      title: "媒体已添加",
      description: `已添加：${mediaInfo.title}`,
    })
    await loadLocalMedia()
  }, [loadLocalMedia, toast])

  // 初始化
  useEffect(() => {
    const initializeApp = async () => {
      if (initialized) return
      
      setLoading(true)
      try {
        if (window.electronAPI) {
          await loadLocalMedia()
        }
      } catch (error) {
        console.error("初始化应用失败:", error)
      } finally {
        setLoading(false)
        setInitialized(true)
      }
    }

    initializeApp()
  }, [initialized, loadLocalMedia])

  // 搜索防抖
  useEffect(() => {
    const timer = setTimeout(() => {
      handleSearch(searchQuery)
    }, 300)

    return () => clearTimeout(timer)
  }, [searchQuery, handleSearch])

  // 监听扫描完成事件
  useEffect(() => {
    const handleScanCompleted = () => {
      loadLocalMedia()
    }

    window.addEventListener('scan-completed', handleScanCompleted)
    return () => window.removeEventListener('scan-completed', handleScanCompleted)
  }, [loadLocalMedia])

  return (
    <div className="min-h-screen bg-background">
      {/* 顶部导航栏 */}
      <header className="bg-background/95 backdrop-blur-sm border-b sticky top-0 z-40">
        <div className="container mx-auto px-6 py-4">
          <div className="flex items-center justify-between">
            {/* Logo 和导航 */}
            <div className="flex items-center space-x-8">
              <div className="flex items-center space-x-2">
                <h1 className="text-xl font-bold">Open Filmly</h1>
              </div>
              
              <nav className="flex items-center space-x-6">
                <Link to="/" className="flex items-center space-x-2 text-sm font-medium text-foreground">
                  首页
                </Link>
                <Link to="/movies" className="flex items-center space-x-2 text-sm text-muted-foreground hover:text-foreground">
                  <Film className="w-4 h-4" />
                  电影
                  {movies.length > 0 && (
                    <span className="bg-muted text-muted-foreground text-xs px-1.5 py-0.5 rounded-full">
                      {movies.length}
                    </span>
                  )}
                </Link>
                <Link to="/tv" className="flex items-center space-x-2 text-sm text-muted-foreground hover:text-foreground">
                  <Tv className="w-4 h-4" />
                  电视剧
                  {tvShows.length > 0 && (
                    <span className="bg-muted text-muted-foreground text-xs px-1.5 py-0.5 rounded-full">
                      {tvShows.length}
                    </span>
                  )}
                </Link>
                <Link to="/recently-viewed" className="flex items-center space-x-2 text-sm text-muted-foreground hover:text-foreground">
                  <Clock className="w-4 h-4" />
                  最近观看
                </Link>
              </nav>
            </div>

            {/* 搜索和操作 */}
            <div className="flex items-center space-x-4">
              <div className="relative">
                <Input 
                  type="search"
                  placeholder="输入影片名称搜索"
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  className="pl-10 w-80 bg-muted/50"
                />
                <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-muted-foreground" />
                {searchLoading && (
                  <RefreshCw className="absolute right-3 top-1/2 transform -translate-y-1/2 h-4 w-4 animate-spin" />
                )}
              </div>

              <AutoScanStatus />
              
              <Button 
                variant="outline" 
                size="sm"
                onClick={() => setShowFileBrowser(true)}
              >
                <FolderOpen className="h-4 w-4 mr-2" />
                浏览文件
              </Button>

              <Link to="/config">
                <Button variant="outline" size="sm">
                  <Settings className="h-4 w-4" />
                </Button>
              </Link>
            </div>
          </div>
        </div>
      </header>

      {/* 主内容区 */}
      <main className="container mx-auto px-6 py-8">
        {/* 搜索结果 */}
        {searchQuery && (
          <section className="mb-8">
            <h2 className="text-2xl font-bold mb-6">
              搜索结果 "{searchQuery}" ({searchResults.length})
            </h2>
            {searchLoading ? (
              <div className="flex items-center justify-center py-12">
                <RefreshCw className="w-8 h-8 animate-spin mr-3" />
                <p>正在搜索...</p>
              </div>
            ) : searchResults.length > 0 ? (
              <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-6 gap-6">
                {searchResults.map((media) => (
                  <MediaCard key={media.id} media={media} />
                ))}
              </div>
            ) : (
              <div className="text-center py-12">
                <p className="text-muted-foreground">没有找到与 "{searchQuery}" 相关的内容</p>
              </div>
            )}
          </section>
        )}

        {/* 主要内容 */}
        {!searchQuery && (
          <>
            {loading ? (
              <LoadingGrid />
            ) : (
              <div className="space-y-12">
                {/* 最近观看 */}
                {recentlyViewed.length > 0 && (
                  <section>
                    <div className="flex items-center justify-between mb-6">
                      <h2 className="text-2xl font-bold flex items-center">
                        <Clock className="w-6 h-6 mr-3 text-blue-500" />
                        最近观看
                      </h2>
                      <Link to="/recently-viewed">
                        <Button variant="ghost" size="sm" className="flex items-center">
                          查看全部
                          <ChevronRight className="w-4 h-4 ml-1" />
                        </Button>
                      </Link>
                    </div>
                    <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5 gap-6">
                      {recentlyViewed.slice(0, 10).map((media) => (
                        <MediaCard key={media.id} media={media} />
                      ))}
                    </div>
                  </section>
                )}

                {/* 高分推荐 */}
                {recommendedContent.length > 0 && (
                  <section>
                    <div className="flex items-center justify-between mb-6">
                      <h2 className="text-2xl font-bold flex items-center">
                        <Star className="w-6 h-6 mr-3 text-yellow-500" />
                        高分推荐
                      </h2>
                    </div>
                    <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-6 gap-6">
                      {recommendedContent.map((media) => (
                        <MediaCard key={media.id} media={media} />
                      ))}
                    </div>
                  </section>
                )}

                {/* 电影 */}
                {movies.length > 0 && (
                  <section>
                    <div className="flex items-center justify-between mb-6">
                      <h2 className="text-2xl font-bold flex items-center">
                        <Film className="w-6 h-6 mr-3 text-red-500" />
                        电影
                      </h2>
                      <Link to="/movies">
                        <Button variant="ghost" size="sm" className="flex items-center">
                          查看全部 ({movies.length})
                          <ChevronRight className="w-4 h-4 ml-1" />
                        </Button>
                      </Link>
                    </div>
                    <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-6 gap-6">
                      {movies.slice(0, 12).map((media) => (
                        <MediaCard key={media.id} media={media} />
                      ))}
                    </div>
                  </section>
                )}

                {/* 电视剧 */}
                {tvShows.length > 0 && (
                  <section>
                    <div className="flex items-center justify-between mb-6">
                      <h2 className="text-2xl font-bold flex items-center">
                        <Tv className="w-6 h-6 mr-3 text-green-500" />
                        电视剧
                      </h2>
                      <Link to="/tv">
                        <Button variant="ghost" size="sm" className="flex items-center">
                          查看全部 ({tvShows.length})
                          <ChevronRight className="w-4 h-4 ml-1" />
                        </Button>
                      </Link>
                    </div>
                    <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-6 gap-6">
                      {tvShows.slice(0, 12).map((media) => (
                        <MediaCard key={media.id} media={media} />
                      ))}
                    </div>
                  </section>
                )}

                {/* 空状态 */}
                {movies.length === 0 && tvShows.length === 0 && (
                  <div className="text-center py-20">
                    <div className="max-w-md mx-auto">
                      <div className="w-16 h-16 mx-auto mb-4 rounded-full bg-muted flex items-center justify-center">
                        <Film className="w-8 h-8 text-muted-foreground" />
                      </div>
                      <h3 className="text-lg font-semibold mb-2">暂无媒体内容</h3>
                      <p className="text-muted-foreground mb-6">
                        配置 SMB 连接后，系统将自动发现和添加您的媒体文件
                      </p>
                      <div className="space-x-4">
                        <Button onClick={() => setShowFileBrowser(true)}>
                          <FolderOpen className="w-4 h-4 mr-2" />
                          浏览文件
                        </Button>
                        <Link to="/config">
                          <Button variant="outline">
                            <Settings className="w-4 h-4 mr-2" />
                            设置
                          </Button>
                        </Link>
                      </div>
                    </div>
                  </div>
                )}
              </div>
            )}
          </>
        )}
      </main>
      
      {/* 文件浏览器弹窗 */}
      {showFileBrowser && (
        <div className="fixed inset-0 bg-black/50 backdrop-blur-sm flex items-center justify-center z-50 p-4">
          <div className="bg-background rounded-xl w-full max-w-4xl max-h-[90vh] overflow-hidden shadow-2xl">
            <div className="p-6 border-b">
              <div className="flex justify-between items-center">
                <div>
                  <h3 className="text-lg font-semibold">文件浏览器</h3>
                  <p className="text-sm text-muted-foreground">浏览并添加媒体文件到库</p>
                </div>
                <Button variant="ghost" size="sm" onClick={() => setShowFileBrowser(false)}>
                  关闭
                </Button>
              </div>
            </div>
            <SMBFileBrowser 
              initialPath="/"
              allowFileAddition={true}
              onFileAdded={handleFileAdded}
            />
          </div>
        </div>
      )}
    </div>
  )
}
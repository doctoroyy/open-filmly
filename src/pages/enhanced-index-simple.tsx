import React, { useEffect, useState, useMemo, useCallback } from "react"
import { 
  Settings, 
  Search, 
  FolderOpen, 
  Home, 
  Clock, 
  Film, 
  Tv, 
  FolderHeart, 
  ListChecks,
  TrendingUp,
  Sparkles,
  Filter,
  SortDesc,
  Grid3X3,
  List,
  RefreshCw,
  Star
} from "lucide-react"
import { Link } from "react-router-dom"
import { useToast } from "@/components/ui/use-toast"
import { Input } from "@/components/ui/input"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger } from "@/components/ui/dropdown-menu"

import { MediaCard } from "@/components/media-card"
import { LoadingGrid } from "@/components/loading-grid"
import { SMBFileBrowser } from "@/components/ui/smb-file-browser"
import { AutoScanStatus } from "@/components/auto-scan-status"
import type { Media } from "@/types/media"
import { getTrendingMovies, getTrendingTVShows, mapTMDBToMedia } from "@/lib/api"

// 界面变体类型
type ViewMode = 'grid' | 'list' | 'detailed'
type SortMode = 'recent' | 'rating' | 'year' | 'title' | 'popularity'
type FilterMode = 'all' | 'movie' | 'tv' | 'favorites'

export default function EnhancedHomePage() {
  // 状态管理
  const [recentlyViewed, setRecentlyViewed] = useState<Media[]>([])
  const [movies, setMovies] = useState<Media[]>([])
  const [tvShows, setTvShows] = useState<Media[]>([])
  const [favorites, setFavorites] = useState<Media[]>([])
  const [trending, setTrending] = useState<Media[]>([])
  const [loading, setLoading] = useState(true)
  const [searchQuery, setSearchQuery] = useState("")
  const [searchLoading, setSearchLoading] = useState(false)
  const [searchResults, setSearchResults] = useState<Media[]>([])
  const [showFileBrowser, setShowFileBrowser] = useState(false)
  const [initialized, setInitialized] = useState(false)
  
  // UI 状态
  const [viewMode, setViewMode] = useState<ViewMode>('grid')
  const [sortMode, setSortMode] = useState<SortMode>('recent')
  const [filterMode, setFilterMode] = useState<FilterMode>('all')
  const [selectedTab, setSelectedTab] = useState("overview")
  
  const { toast } = useToast()

  // 计算分类数据
  const categorizedMovies = useMemo(() => {
    const action = movies.filter(movie => 
      movie.genres?.some(genre => 
        ['Action', 'Adventure', 'Thriller', '动作', '冒险', '惊悚'].includes(genre)
      )
    )
    const drama = movies.filter(movie => 
      movie.genres?.some(genre => 
        ['Drama', 'Romance', 'Biography', '剧情', '爱情', '传记'].includes(genre)
      )
    )
    const comedy = movies.filter(movie => 
      movie.genres?.some(genre => 
        ['Comedy', 'Family', 'Animation', '喜剧', '家庭', '动画'].includes(genre)
      )
    )
    
    return { action: action.slice(0, 8), drama: drama.slice(0, 8), comedy: comedy.slice(0, 8) }
  }, [movies])

  // 过滤和排序逻辑
  const filteredAndSortedContent = useMemo(() => {
    let allContent: Media[] = []
    
    switch (filterMode) {
      case 'movie':
        allContent = movies
        break
      case 'tv':
        allContent = tvShows
        break
      case 'favorites':
        allContent = favorites
        break
      default:
        allContent = [...movies, ...tvShows]
    }

    // 搜索过滤
    if (searchQuery.trim()) {
      allContent = allContent.filter(item =>
        item.title.toLowerCase().includes(searchQuery.toLowerCase()) ||
        item.overview?.toLowerCase().includes(searchQuery.toLowerCase()) ||
        item.genres?.some(genre => genre.toLowerCase().includes(searchQuery.toLowerCase()))
      )
    }

    // 排序
    switch (sortMode) {
      case 'rating':
        allContent.sort((a, b) => (b.rating || 0) - (a.rating || 0))
        break
      case 'year':
        allContent.sort((a, b) => parseInt(b.year || '0') - parseInt(a.year || '0'))
        break
      case 'title':
        allContent.sort((a, b) => a.title.localeCompare(b.title))
        break
      case 'popularity':
        allContent.sort((a, b) => (b.rating || 0) * (b.genres?.length || 1) - (a.rating || 0) * (a.genres?.length || 1))
        break
      default: // recent
        allContent.sort((a, b) => new Date(b.dateAdded || 0).getTime() - new Date(a.dateAdded || 0).getTime())
    }

    return allContent
  }, [movies, tvShows, favorites, searchQuery, sortMode, filterMode])

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

  // 加载在线数据
  const loadOnlineMedia = useCallback(async () => {
    try {
      const [trendingMovies, trendingTVShows] = await Promise.all([
        getTrendingMovies(),
        getTrendingTVShows()
      ])
      
      const allTrending = [
        ...trendingMovies.slice(0, 10).map((movie: any) => mapTMDBToMedia(movie, 'movie')),
        ...trendingTVShows.slice(0, 10).map((show: any) => mapTMDBToMedia(show, 'tv'))
      ]
      
      setTrending(allTrending)

      // 只有当本地没有数据时才使用在线数据
      if (movies.length === 0) {
        setMovies(trendingMovies.map((movie: any) => mapTMDBToMedia(movie, 'movie')))
      }
      if (tvShows.length === 0) {
        setTvShows(trendingTVShows.map((show: any) => mapTMDBToMedia(show, 'tv')))
      }
      if (recentlyViewed.length === 0) {
        setRecentlyViewed(allTrending.slice(0, 6))
      }
    } catch (error) {
      console.error("Failed to load online media:", error)
      toast({
        title: "加载失败",
        description: "无法加载在线媒体数据",
        variant: "destructive",
      })
    }
  }, [movies.length, tvShows.length, recentlyViewed.length, toast])

  // 搜索功能
  const handleSearch = useCallback(async (query: string) => {
    if (!query.trim()) {
      setSearchResults([])
      return
    }

    setSearchLoading(true)
    try {
      const localResults = filteredAndSortedContent.filter(item =>
        item.title.toLowerCase().includes(query.toLowerCase())
      )
      setSearchResults(localResults)
    } catch (error) {
      console.error("Search failed:", error)
    } finally {
      setSearchLoading(false)
    }
  }, [filteredAndSortedContent])

  // 处理收藏
  const handleFavorite = useCallback((media: Media) => {
    setFavorites(prev => {
      const isFavorited = prev.some(fav => fav.id === media.id)
      if (isFavorited) {
        return prev.filter(fav => fav.id !== media.id)
      } else {
        return [...prev, media]
      }
    })
    
    toast({
      title: favorites.some(fav => fav.id === media.id) ? "已取消收藏" : "已添加到收藏",
      description: media.title,
    })
  }, [favorites, toast])

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
        await loadOnlineMedia()
      } catch (error) {
        console.error("初始化应用失败:", error)
      } finally {
        setLoading(false)
        setInitialized(true)
      }
    }

    initializeApp()
  }, [initialized, loadLocalMedia, loadOnlineMedia])

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
    <main className="min-h-screen bg-gradient-to-br from-background via-background to-muted/20">
      <div className="flex h-screen">
        {/* 增强的侧边栏 */}
        <aside className="w-64 h-full bg-sidebar-background/95 backdrop-blur-sm border-r border-sidebar-border/50 p-4">
          <div className="mb-8">
            <h1 className="text-xl font-bold text-sidebar-foreground flex items-center gap-2">
              <Sparkles className="w-6 h-6 text-primary" />
              Open Filmly
            </h1>
            <p className="text-xs text-sidebar-foreground/60 mt-1">智能媒体管理平台</p>
          </div>
          
          <nav className="space-y-2 mb-8">
            <Link to="/" className="flex items-center p-3 bg-sidebar-accent rounded-md text-sidebar-accent-foreground transition-colors">
              <Home className="mr-3 h-5 w-5" />
              <span>首页</span>
              <Badge variant="secondary" className="ml-auto text-xs">
                {movies.length + tvShows.length}
              </Badge>
            </Link>
            <Link to="/recently-viewed" className="flex items-center p-3 rounded-md hover:bg-sidebar-accent text-sidebar-foreground hover:text-sidebar-accent-foreground transition-colors">
              <Clock className="mr-3 h-5 w-5" />
              <span>最近观看</span>
              {recentlyViewed.length > 0 && (
                <Badge variant="outline" className="ml-auto text-xs">
                  {recentlyViewed.length}
                </Badge>
              )}
            </Link>
            <Link to="/movies" className="flex items-center p-3 rounded-md hover:bg-sidebar-accent text-sidebar-foreground hover:text-sidebar-accent-foreground transition-colors">
              <Film className="mr-3 h-5 w-5" />
              <span>电影</span>
              {movies.length > 0 && (
                <Badge variant="outline" className="ml-auto text-xs">
                  {movies.length}
                </Badge>
              )}
            </Link>
            <Link to="/tv" className="flex items-center p-3 rounded-md hover:bg-sidebar-accent text-sidebar-foreground hover:text-sidebar-accent-foreground transition-colors">
              <Tv className="mr-3 h-5 w-5" />
              <span>电视剧</span>
              {tvShows.length > 0 && (
                <Badge variant="outline" className="ml-auto text-xs">
                  {tvShows.length}
                </Badge>
              )}
            </Link>
            <Link to="/favorites" className="flex items-center p-3 rounded-md hover:bg-sidebar-accent text-sidebar-foreground hover:text-sidebar-accent-foreground transition-colors">
              <FolderHeart className="mr-3 h-5 w-5" />
              <span>收藏</span>
              {favorites.length > 0 && (
                <Badge variant="outline" className="ml-auto text-xs">
                  {favorites.length}
                </Badge>
              )}
            </Link>
            <Link to="/media-list" className="flex items-center p-3 rounded-md hover:bg-sidebar-accent text-sidebar-foreground hover:text-sidebar-accent-foreground transition-colors">
              <ListChecks className="mr-3 h-5 w-5" />
              <span>媒体列表</span>
            </Link>
          </nav>

          {/* 热门内容预览 */}
          {trending.length > 0 && (
            <div className="space-y-3">
              <h3 className="text-sm font-medium text-sidebar-foreground flex items-center gap-2">
                <TrendingUp className="w-4 h-4" />
                热门内容
              </h3>
              <div className="space-y-2">
                {trending.slice(0, 3).map((item) => (
                  <div key={item.id} className="flex items-center gap-3 p-2 rounded-md hover:bg-sidebar-accent/50 cursor-pointer transition-colors">
                    <div className="w-8 h-12 bg-muted rounded flex-shrink-0 overflow-hidden">
                      {item.posterPath && (
                        <img src={item.posterPath} alt={item.title} className="w-full h-full object-cover" />
                      )}
                    </div>
                    <div className="flex-1 min-w-0">
                      <p className="text-xs font-medium text-sidebar-foreground truncate">{item.title}</p>
                      <div className="flex items-center gap-1 mt-1">
                        <Star className="w-3 h-3 text-yellow-500 fill-current" />
                        <span className="text-xs text-sidebar-foreground/60">{item.rating?.toFixed(1)}</span>
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}
        </aside>

        {/* 主内容区 */}
        <div className="flex-1 overflow-auto">
          <div className="container mx-auto p-8">
            {/* 增强的顶部栏 */}
            <div className="flex justify-between items-center mb-8">
              <div>
                <h2 className="text-3xl font-bold bg-gradient-to-r from-foreground to-foreground/70 bg-clip-text text-transparent">
                  欢迎回来
                </h2>
                <p className="text-muted-foreground mt-1">发现和管理您的媒体收藏</p>
              </div>
              
              <div className="flex items-center space-x-4">
                {/* 搜索框 */}
                <div className="relative">
                  <Input 
                    type="search"
                    placeholder="搜索电影、电视剧..."
                    value={searchQuery}
                    onChange={(e) => setSearchQuery(e.target.value)}
                    className="pl-10 w-80 bg-muted/50 border-input focus:border-ring"
                  />
                  <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-muted-foreground" />
                  {searchLoading && (
                    <RefreshCw className="absolute right-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-muted-foreground animate-spin" />
                  )}
                </div>

                {/* 视图和排序控制 */}
                <div className="flex items-center gap-2">
                  <DropdownMenu>
                    <DropdownMenuTrigger asChild>
                      <Button variant="outline" size="icon">
                        <Filter className="h-4 w-4" />
                      </Button>
                    </DropdownMenuTrigger>
                    <DropdownMenuContent align="end">
                      <DropdownMenuItem onClick={() => setFilterMode('all')}>
                        全部内容
                      </DropdownMenuItem>
                      <DropdownMenuItem onClick={() => setFilterMode('movie')}>
                        仅电影
                      </DropdownMenuItem>
                      <DropdownMenuItem onClick={() => setFilterMode('tv')}>
                        仅电视剧
                      </DropdownMenuItem>
                      <DropdownMenuItem onClick={() => setFilterMode('favorites')}>
                        收藏内容
                      </DropdownMenuItem>
                    </DropdownMenuContent>
                  </DropdownMenu>

                  <Select value={sortMode} onValueChange={(value: SortMode) => setSortMode(value)}>
                    <SelectTrigger className="w-32">
                      <SortDesc className="w-4 h-4 mr-2" />
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="recent">最新添加</SelectItem>
                      <SelectItem value="rating">评分</SelectItem>
                      <SelectItem value="year">年份</SelectItem>
                      <SelectItem value="title">标题</SelectItem>
                      <SelectItem value="popularity">热门度</SelectItem>
                    </SelectContent>
                  </Select>

                  <div className="flex rounded-md border">
                    <Button
                      variant={viewMode === 'grid' ? 'default' : 'ghost'}
                      size="sm"
                      onClick={() => setViewMode('grid')}
                      className="rounded-r-none"
                    >
                      <Grid3X3 className="h-4 w-4" />
                    </Button>
                    <Button
                      variant={viewMode === 'list' ? 'default' : 'ghost'}
                      size="sm"
                      onClick={() => setViewMode('list')}
                      className="rounded-none border-x"
                    >
                      <List className="h-4 w-4" />
                    </Button>
                  </div>
                </div>

                {/* 操作按钮 */}
                <Button 
                  variant="outline" 
                  size="icon"
                  onClick={() => setShowFileBrowser(true)}
                >
                  <FolderOpen className="h-5 w-5" />
                </Button>

                <AutoScanStatus />

                <Link to="/config">
                  <Button variant="outline" size="icon">
                    <Settings className="h-5 w-5" />
                  </Button>
                </Link>
              </div>
            </div>

            {/* 搜索结果 */}
            {searchQuery && (
              <section className="mb-8">
                <h3 className="text-xl font-semibold mb-4">
                  搜索结果 "{searchQuery}" ({searchResults.length})
                </h3>
                {searchLoading ? (
                  <div className="flex items-center justify-center py-12">
                    <div className="text-center space-y-4">
                      <RefreshCw className="w-8 h-8 animate-spin mx-auto" />
                      <p>正在搜索 "{searchQuery}"...</p>
                    </div>
                  </div>
                ) : searchResults.length > 0 ? (
                  <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 xl:grid-cols-7 gap-6">
                    {searchResults.map((media) => (
                      <MediaCard key={media.id} media={media} />
                    ))}
                  </div>
                ) : (
                  <div className="text-center py-12">
                    <p className="text-muted-foreground">没有找到与 "{searchQuery}" 相关的媒体</p>
                  </div>
                )}
              </section>
            )}

            {/* 主要内容标签页 */}
            {!searchQuery && (
              <Tabs value={selectedTab} onValueChange={setSelectedTab} className="space-y-8">
                <TabsList className="grid w-full grid-cols-4">
                  <TabsTrigger value="overview">概览</TabsTrigger>
                  <TabsTrigger value="movies">电影</TabsTrigger>
                  <TabsTrigger value="tv">电视剧</TabsTrigger>
                  <TabsTrigger value="recent">最近</TabsTrigger>
                </TabsList>

                <TabsContent value="overview" className="space-y-8">
                  {loading ? (
                    <LoadingGrid />
                  ) : (
                    <>
                      {/* 最近观看 */}
                      {recentlyViewed.length > 0 && (
                        <section>
                          <div className="flex justify-between items-center mb-6">
                            <h3 className="text-2xl font-semibold flex items-center gap-2">
                              <Clock className="w-6 h-6 text-primary" />
                              继续观看
                            </h3>
                            <Link to="/recently-viewed">
                              <Button variant="ghost" size="sm">
                                查看全部 →
                              </Button>
                            </Link>
                          </div>
                          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                            {recentlyViewed.slice(0, 3).map((media) => (
                              <MediaCard key={media.id} media={media} />
                            ))}
                          </div>
                        </section>
                      )}

                      {/* 热门推荐 */}
                      {trending.length > 0 && (
                        <section>
                          <div className="flex justify-between items-center mb-6">
                            <h3 className="text-2xl font-semibold flex items-center gap-2">
                              <TrendingUp className="w-6 h-6 text-primary" />
                              热门推荐
                            </h3>
                          </div>
                          <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 xl:grid-cols-7 gap-6">
                            {trending.slice(0, 7).map((media) => (
                              <MediaCard key={media.id} media={media} />
                            ))}
                          </div>
                        </section>
                      )}

                      {/* 电影精选 */}
                      {movies.length > 0 && (
                        <section>
                          <div className="flex justify-between items-center mb-6">
                            <h3 className="text-2xl font-semibold flex items-center gap-2">
                              <Film className="w-6 h-6 text-primary" />
                              电影精选
                            </h3>
                            <Link to="/movies">
                              <Button variant="ghost" size="sm">
                                查看全部 ({movies.length}) →
                              </Button>
                            </Link>
                          </div>
                          <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 xl:grid-cols-7 gap-6">
                            {movies.slice(0, 7).map((media) => (
                              <MediaCard key={media.id} media={media} />
                            ))}
                          </div>
                        </section>
                      )}

                      {/* 电视剧推荐 */}
                      {tvShows.length > 0 && (
                        <section>
                          <div className="flex justify-between items-center mb-6">
                            <h3 className="text-2xl font-semibold flex items-center gap-2">
                              <Tv className="w-6 h-6 text-primary" />
                              电视剧推荐
                            </h3>
                            <Link to="/tv">
                              <Button variant="ghost" size="sm">
                                查看全部 ({tvShows.length}) →
                              </Button>
                            </Link>
                          </div>
                          <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 xl:grid-cols-7 gap-6">
                            {tvShows.slice(0, 7).map((media) => (
                              <MediaCard key={media.id} media={media} />
                            ))}
                          </div>
                        </section>
                      )}

                      {/* 分类浏览 */}
                      <section>
                        <h3 className="text-2xl font-semibold mb-6">分类浏览</h3>
                        <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
                          <div 
                            className="relative h-48 rounded-xl overflow-hidden cursor-pointer group bg-gradient-to-br from-red-500 to-orange-600 hover:scale-[1.02] transition-transform"
                            onClick={() => window.location.href = '/movies?genre=action'}
                          >
                            <div className="absolute inset-0 bg-black/40 group-hover:bg-black/20 transition-colors"></div>
                            <div className="absolute inset-0 p-6 flex flex-col justify-end">
                              <h4 className="text-white text-2xl font-bold mb-2">动作冒险</h4>
                              <p className="text-white/80">
                                {categorizedMovies.action.length > 0 ? `${categorizedMovies.action.length} 部影片` : '暂无影片'}
                              </p>
                            </div>
                          </div>

                          <div 
                            className="relative h-48 rounded-xl overflow-hidden cursor-pointer group bg-gradient-to-br from-blue-500 to-purple-600 hover:scale-[1.02] transition-transform"
                            onClick={() => window.location.href = '/movies?genre=drama'}
                          >
                            <div className="absolute inset-0 bg-black/40 group-hover:bg-black/20 transition-colors"></div>
                            <div className="absolute inset-0 p-6 flex flex-col justify-end">
                              <h4 className="text-white text-2xl font-bold mb-2">剧情情感</h4>
                              <p className="text-white/80">
                                {categorizedMovies.drama.length > 0 ? `${categorizedMovies.drama.length} 部影片` : '暂无影片'}
                              </p>
                            </div>
                          </div>

                          <div 
                            className="relative h-48 rounded-xl overflow-hidden cursor-pointer group bg-gradient-to-br from-green-500 to-yellow-500 hover:scale-[1.02] transition-transform"
                            onClick={() => window.location.href = '/movies?genre=comedy'}
                          >
                            <div className="absolute inset-0 bg-black/40 group-hover:bg-black/20 transition-colors"></div>
                            <div className="absolute inset-0 p-6 flex flex-col justify-end">
                              <h4 className="text-white text-2xl font-bold mb-2">喜剧轻松</h4>
                              <p className="text-white/80">
                                {categorizedMovies.comedy.length > 0 ? `${categorizedMovies.comedy.length} 部影片` : '暂无影片'}
                              </p>
                            </div>
                          </div>
                        </div>
                      </section>
                    </>
                  )}
                </TabsContent>

                <TabsContent value="movies">
                  {loading ? (
                    <LoadingGrid />
                  ) : movies.length > 0 ? (
                    <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 xl:grid-cols-7 gap-6">
                      {movies.map((media) => (
                        <MediaCard key={media.id} media={media} />
                      ))}
                    </div>
                  ) : (
                    <div className="text-center py-12">
                      <p className="text-muted-foreground mb-4">暂无电影</p>
                      <p className="text-sm text-muted-foreground">配置SMB连接后将自动发现和添加电影</p>
                      <Button className="mt-4" onClick={() => setShowFileBrowser(true)}>
                        <FolderOpen className="w-4 h-4 mr-2" />
                        浏览文件
                      </Button>
                    </div>
                  )}
                </TabsContent>

                <TabsContent value="tv">
                  {loading ? (
                    <LoadingGrid />
                  ) : tvShows.length > 0 ? (
                    <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 xl:grid-cols-7 gap-6">
                      {tvShows.map((media) => (
                        <MediaCard key={media.id} media={media} />
                      ))}
                    </div>
                  ) : (
                    <div className="text-center py-12">
                      <p className="text-muted-foreground mb-4">暂无电视剧</p>
                      <p className="text-sm text-muted-foreground">配置SMB连接后将自动发现和添加电视剧</p>
                      <Button className="mt-4" onClick={() => setShowFileBrowser(true)}>
                        <FolderOpen className="w-4 h-4 mr-2" />
                        浏览文件
                      </Button>
                    </div>
                  )}
                </TabsContent>

                <TabsContent value="recent">
                  {loading ? (
                    <LoadingGrid />
                  ) : recentlyViewed.length > 0 ? (
                    <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                      {recentlyViewed.map((media) => (
                        <MediaCard key={media.id} media={media} />
                      ))}
                    </div>
                  ) : (
                    <div className="text-center py-12">
                      <p className="text-muted-foreground">暂无最近观看</p>
                      <p className="text-sm text-muted-foreground mt-2">开始观看媒体后，这里将显示您的观看历史</p>
                    </div>
                  )}
                </TabsContent>
              </Tabs>
            )}
          </div>
        </div>
      </div>
      
      {/* 文件浏览器弹窗 */}
      {showFileBrowser && (
        <div className="fixed inset-0 bg-black/50 backdrop-blur-sm flex items-center justify-center z-50 p-4">
          <div className="bg-background rounded-xl w-full max-w-4xl max-h-[90vh] overflow-hidden shadow-2xl">
            <div className="p-6 border-b">
              <div className="flex justify-between items-center">
                <div>
                  <h3 className="text-lg font-semibold">文件浏览器</h3>
                  <p className="text-sm text-muted-foreground">
                    浏览并添加媒体文件到库
                  </p>
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
    </main>
  )
}
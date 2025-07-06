import React, { useEffect, useState } from "react"
import { Settings, Search, FolderOpen, Home, Clock, Film, Tv, FolderHeart, ListChecks } from "lucide-react"
import { MediaCard } from "@/components/media-card"
import { LoadingGrid } from "@/components/loading-grid"
import { Button } from "@/components/ui/button"
import { useToast } from "@/components/ui/use-toast"
import { Input } from "@/components/ui/input"
import { Link } from "react-router-dom"
import type { Media } from "@/types/media"
import { getTrendingMovies, getTrendingTVShows, mapTMDBToMedia } from "@/lib/api"
import { SMBFileBrowser } from "@/components/ui/smb-file-browser"
import { AutoScanStatus } from "@/components/auto-scan-status"

export default function HomePage() {
  const [recentlyViewed, setRecentlyViewed] = useState<Media[]>([])
  const [movies, setMovies] = useState<Media[]>([])
  const [tvShows, setTvShows] = useState<Media[]>([])
  const [loading, setLoading] = useState(true)
  const [showFileBrowser, setShowFileBrowser] = useState(false)
  const [initialized, setInitialized] = useState(false)
  const { toast } = useToast()

  // 加载本地媒体数据
  const loadLocalMedia = async () => {
    try {
      const movieData = await window.electronAPI?.getMedia("movie")
      const tvData = await window.electronAPI?.getMedia("tv")
      const recentData = await window.electronAPI?.getRecentlyViewed()

      console.log(`从数据库加载: ${movieData?.length || 0} 部电影, ${tvData?.length || 0} 部电视剧, ${recentData?.length || 0} 个最近观看`)

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
      });

      if (movieData?.length) {
        setMovies(movieData.map(convertToFrontendMedia))
        console.log(`设置了 ${movieData.length} 部电影到界面`)
      }
      if (tvData?.length) {
        setTvShows(tvData.map(convertToFrontendMedia))
        console.log(`设置了 ${tvData.length} 部电视剧到界面`)
      }
      if (recentData?.length) {
        setRecentlyViewed(recentData.map(convertToFrontendMedia))
        console.log(`设置了 ${recentData.length} 个最近观看项目到界面`)
      }
    } catch (error) {
      console.error("Failed to load local media:", error)
    }
  }

  // 加载在线数据
  const loadOnlineMedia = async () => {
    try {
      console.log("加载在线媒体数据...")
      // Get trending movies from TMDB
      const trendingMovies = await getTrendingMovies()
      const mappedMovies = trendingMovies.map((movie: any) => mapTMDBToMedia(movie, 'movie'))
      
      // 只有当本地没有电影数据时才使用在线数据
      if (movies.length === 0) {
        console.log("使用在线电影数据作为备用")
        setMovies(mappedMovies)
      } else {
        console.log("已有本地电影数据，不使用在线数据")
      }

      // Get trending TV shows from TMDB
      const trendingTVShows = await getTrendingTVShows()
      const mappedTVShows = trendingTVShows.map((show: any) => mapTMDBToMedia(show, 'tv'))
      
      // 只有当本地没有电视剧数据时才使用在线数据
      if (tvShows.length === 0) {
        console.log("使用在线电视剧数据作为备用")
        setTvShows(mappedTVShows)
      } else {
        console.log("已有本地电视剧数据，不使用在线数据")
      }

      // 如果本地没有最近观看数据，使用一些热门项目
      if (recentlyViewed.length === 0) {
        console.log("使用在线数据作为最近观看的备用")
        setRecentlyViewed([
          ...trendingMovies.slice(0, 2).map((movie: any) => mapTMDBToMedia(movie, 'movie')),
          ...trendingTVShows.slice(0, 1).map((show: any) => mapTMDBToMedia(show, 'tv'))
        ])
      } else {
        console.log("已有本地最近观看数据，不使用在线数据")
      }
    } catch (error) {
      console.error("Failed to load online media:", error)
      toast({
        title: "加载失败",
        description: "无法加载在线媒体数据",
        variant: "destructive",
      })
    } finally {
      setLoading(false)
    }
  }


  // 处理关闭文件浏览器
  const handleCloseFileBrowser = () => {
    setShowFileBrowser(false);
  }

  // 处理文件添加
  const handleFileAdded = async (mediaInfo: Media) => {
    toast({
      title: "媒体已添加",
      description: `已添加：${mediaInfo.title}`,
    });
    
    // 重新加载媒体列表
    if (window.electronAPI) {
      await loadLocalMedia();
    }
    
    // 可选：关闭文件浏览器
    // setShowFileBrowser(false);
  }

  // 打开文件浏览器
  const openFileBrowser = () => {
    setShowFileBrowser(true);
  }

  // 监听扫描完成事件，重新加载数据
  useEffect(() => {
    const handleScanCompleted = () => {
      console.log('Scan completed event received, reloading media data...')
      loadLocalMedia()
    }

    window.addEventListener('scan-completed', handleScanCompleted)

    return () => {
      window.removeEventListener('scan-completed', handleScanCompleted)
    }
  }, [])

  // 初始加载 - 组件挂载时执行一次
  useEffect(() => {
    const initializeApp = async () => {
      if (initialized) return; // 如果已初始化，不再执行
      
      setLoading(true)
      console.log("开始初始化应用...")
      console.log("HomePage 组件已加载，开始检查 Electron API...")
      console.log("window.electronAPI:", window.electronAPI)
      
      try {
        // 检查是否在 Electron 环境中
        if (!window.electronAPI) {
          console.log("不在 Electron 环境中，跳过本地数据加载")
          setLoading(false)
          setInitialized(true)
          return
        }
        
        // 首先尝试加载本地媒体数据
        const movieData = await window.electronAPI?.getMedia("movie") || []
        const tvData = await window.electronAPI?.getMedia("tv") || []
        const recentData = await window.electronAPI?.getRecentlyViewed() || []
        
        console.log(`直接获取数据库数据: ${movieData.length} 部电影, ${tvData.length} 部电视剧, ${recentData.length} 个最近观看`)
        
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
        });
        
        // 更新状态
        const hasMovies = movieData.length > 0
        const hasTVShows = tvData.length > 0
        const hasRecent = recentData.length > 0
        
        if (hasMovies) {
          setMovies(movieData.map(convertToFrontendMedia))
          console.log(`设置了 ${movieData.length} 部电影到界面`)
        }
        
        if (hasTVShows) {
          setTvShows(tvData.map(convertToFrontendMedia))
          console.log(`设置了 ${tvData.length} 部电视剧到界面`)
        }
        
        if (hasRecent) {
          setRecentlyViewed(recentData.map(convertToFrontendMedia))
          console.log(`设置了 ${recentData.length} 个最近观看项目到界面`)
        }
        
        // 确认本地数据是否完整，如果不完整则加载在线数据
        const needOnlineData = !hasMovies || !hasTVShows || !hasRecent;
        console.log(`本地数据完整性检查: 需要在线数据=${needOnlineData} (有电影=${hasMovies}, 有电视剧=${hasTVShows}, 有最近=${hasRecent})`)
        
        if (needOnlineData) {
          console.log("本地数据不完整，加载在线数据作为补充...")
          try {
            // 加载在线数据来填补缺失的内容
            const trendingMovies = await getTrendingMovies()
            const trendingTVShows = await getTrendingTVShows()
            
            // 只有在本地没有电影数据时才使用在线电影数据
            if (!hasMovies) {
              const mappedMovies = trendingMovies.map((movie: any) => mapTMDBToMedia(movie, 'movie'))
              setMovies(mappedMovies)
              console.log(`使用 ${mappedMovies.length} 部在线电影数据作为备用`)
            }
            
            // 只有在本地没有电视剧数据时才使用在线电视剧数据
            if (!hasTVShows) {
              const mappedTVShows = trendingTVShows.map((show: any) => mapTMDBToMedia(show, 'tv'))
              setTvShows(mappedTVShows)
              console.log(`使用 ${mappedTVShows.length} 部在线电视剧数据作为备用`)
            }
            
            // 只有在本地没有最近观看数据时才使用在线数据
            if (!hasRecent) {
              const recentItems = [
                ...trendingMovies.slice(0, 2).map((movie: any) => mapTMDBToMedia(movie, 'movie')),
                ...trendingTVShows.slice(0, 1).map((show: any) => mapTMDBToMedia(show, 'tv'))
              ]
              setRecentlyViewed(recentItems)
              console.log(`使用 ${recentItems.length} 个在线项目作为最近观看的备用`)
            }
          } catch (error) {
            console.error("加载在线数据失败:", error)
            toast({
              title: "加载失败",
              description: "无法加载在线媒体数据",
              variant: "destructive",
            })
          }
        } else {
          console.log("已有完整的本地数据，不需要加载在线数据")
        }
      } catch (error) {
        console.error("初始化应用失败:", error)
        // 如果本地数据加载失败，尝试加载在线数据作为兜底
        try {
          console.log("本地数据加载失败，尝试加载在线数据...")
          await loadOnlineMedia()
        } catch (onlineError) {
          console.error("加载在线数据也失败:", onlineError)
        }
      } finally {
        setLoading(false)
        setInitialized(true)
        console.log("初始化完成")
      }
    }

    initializeApp()
  }, [])

  return (
    <main className="min-h-screen bg-background">
      <div className="flex h-screen">
        {/* 侧边栏导航 */}
        <aside className="w-64 h-full bg-sidebar-background border-r border-sidebar-border p-4">
          <div className="mb-8">
            <h1 className="text-xl font-bold text-sidebar-foreground">媒体库</h1>
          </div>
          
          <nav className="w-full space-y-2 mb-8">
            <Link to="/" className="flex items-center p-3 bg-sidebar-accent rounded-md hover:bg-sidebar-accent text-sidebar-accent-foreground">
              <Home className="mr-2 h-5 w-5" /> 首页
            </Link>
            <Link to="/recently-viewed" className="flex items-center p-3 rounded-md hover:bg-sidebar-accent text-sidebar-foreground hover:text-sidebar-accent-foreground">
              <Clock className="mr-2 h-5 w-5" /> 最近观看
            </Link>
            <Link to="/movies" className="flex items-center p-3 rounded-md hover:bg-sidebar-accent text-sidebar-foreground hover:text-sidebar-accent-foreground">
              <Film className="mr-2 h-5 w-5" /> 电影
            </Link>
            <Link to="/tv" className="flex items-center p-3 rounded-md hover:bg-sidebar-accent text-sidebar-foreground hover:text-sidebar-accent-foreground">
              <Tv className="mr-2 h-5 w-5" /> 电视剧
            </Link>
            <Link to="/other" className="flex items-center p-3 rounded-md hover:bg-sidebar-accent text-sidebar-foreground hover:text-sidebar-accent-foreground">
              <FolderHeart className="mr-2 h-5 w-5" /> 收藏
            </Link>
            <Link to="/media-list" className="flex items-center p-3 rounded-md hover:bg-sidebar-accent text-sidebar-foreground hover:text-sidebar-accent-foreground">
              <ListChecks className="mr-2 h-5 w-5" /> 媒体列表
            </Link>
          </nav>
        </aside>

        {/* 主内容区 */}
        <div className="flex-1 p-8 overflow-auto">
          <div className="container mx-auto">
            <div className="flex justify-between items-center mb-8">
              <h2 className="text-2xl font-bold">首页</h2>
              <div className="flex items-center space-x-4">
                <div className="relative">
                  <Input 
                    type="search"
                    placeholder="搜索..."
                    className="pl-10 bg-muted border-input focus:border-ring text-foreground"
                  />
                  <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-muted-foreground" />
                </div>
                <Button 
                  variant="outline" 
                  size="icon" 
                  className="border-input text-foreground hover:text-foreground"
                  onClick={openFileBrowser}
                >
                  <FolderOpen className="h-5 w-5" />
                  <span className="sr-only">浏览文件</span>
                </Button>
                <AutoScanStatus />
                <Link to="/config">
                  <Button variant="outline" size="icon" className="border-input text-foreground hover:text-foreground">
                    <Settings className="h-5 w-5" />
                    <span className="sr-only">设置</span>
                  </Button>
                </Link>
              </div>
            </div>

            {/* 最近观看 */}
            <section className="mb-12">
              <div className="flex justify-between items-center mb-4">
                <h3 className="text-xl font-semibold">最近观看 &rarr;</h3>
                {recentlyViewed.length > 0 && !loading && (
                  <div className="text-sm text-muted-foreground">
                    显示 {recentlyViewed.length} 个最近项目
                  </div>
                )}
              </div>

              {loading ? (
                <LoadingGrid />
              ) : recentlyViewed.length > 0 ? (
                <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-3 gap-6">
                  {recentlyViewed.slice(0, 3).map((media) => (
                    <MediaCard key={media.id} media={media} />
                  ))}
                </div>
              ) : (
                <div className="p-8 text-center text-muted-foreground">
                  <p>暂无最近观看的媒体</p>
                  <p className="text-sm mt-2">配置SMB连接后将自动扫描和显示媒体文件</p>
                </div>
              )}
            </section>

            {/* 电影 */}
            <section className="mb-12">
              <div className="flex justify-between items-center mb-4">
                <Link to="/movies" className="flex items-center hover:text-blue-600 transition-colors">
                  <h3 className="text-xl font-semibold">电影 &rarr;</h3>
                </Link>
                {movies.length > 0 && !loading && (
                  <div className="text-sm text-muted-foreground">
                    显示 {movies.length} 部电影
                  </div>
                )}
              </div>

              {loading ? (
                <LoadingGrid />
              ) : movies.length > 0 ? (
                <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-8 gap-4">
                  {movies.slice(0, 8).map((media) => (
                    <MediaCard key={media.id} media={media} />
                  ))}
                </div>
              ) : (
                <div className="p-8 text-center text-muted-foreground">
                  <p>暂无电影</p>
                  <p className="text-sm mt-2">配置SMB连接后将自动发现和添加电影</p>
                </div>
              )}
            </section>

            {/* 电视剧 */}
            <section>
              <div className="flex justify-between items-center mb-4">
                <Link to="/tv" className="flex items-center hover:text-blue-600 transition-colors">
                  <h3 className="text-xl font-semibold">电视剧 &rarr;</h3>
                </Link>
                {tvShows.length > 0 && !loading && (
                  <div className="text-sm text-muted-foreground">
                    显示 {tvShows.length} 部电视剧
                  </div>
                )}
              </div>

              {loading ? (
                <LoadingGrid />
              ) : tvShows.length > 0 ? (
                <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-8 gap-4">
                  {tvShows.slice(0, 8).map((media) => (
                    <MediaCard key={media.id} media={media} />
                  ))}
                </div>
              ) : (
                <div className="p-8 text-center text-muted-foreground">
                  <p>暂无电视剧</p>
                  <p className="text-sm mt-2">配置SMB连接后将自动发现和添加电视剧</p>
                </div>
              )}
            </section>
          </div>
        </div>
      </div>
      
      {/* 文件浏览器弹窗 */}
      {showFileBrowser && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
          <div className="bg-background rounded-lg w-full max-w-4xl">
            <div className="p-4 border-b">
              <div className="flex justify-between items-center">
                <h3 className="text-lg font-semibold">文件浏览器</h3>
                <Button variant="ghost" size="sm" onClick={handleCloseFileBrowser}>
                  关闭
                </Button>
              </div>
              <p className="text-sm text-muted-foreground">
                浏览并添加媒体文件到库。点击文件旁边的"添加"按钮将其加入到媒体库。
              </p>
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
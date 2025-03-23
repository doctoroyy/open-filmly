"use client"

import { useEffect, useState } from "react"
import { Settings, RefreshCw, Search } from "lucide-react"
import { MediaCard } from "@/components/media-card"
import { LoadingGrid } from "@/components/loading-grid"
import { Button } from "@/components/ui/button"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { useToast } from "@/components/ui/use-toast"
import { Input } from "@/components/ui/input"
import Link from "next/link"
import type { Media } from "@/types/media"
import { getTrendingMovies, getTrendingTVShows, mapTMDBToMedia } from "@/lib/api"

export default function HomePage() {
  const [recentlyViewed, setRecentlyViewed] = useState<Media[]>([])
  const [movies, setMovies] = useState<Media[]>([])
  const [tvShows, setTvShows] = useState<Media[]>([])
  const [loading, setLoading] = useState(true)
  const [scanning, setScanning] = useState(false)
  const { toast } = useToast()

  // 加载本地媒体数据
  const loadLocalMedia = async () => {
    try {
      const movieData = await window.electronAPI?.getMedia("movie")
      const tvData = await window.electronAPI?.getMedia("tv")
      const recentData = await window.electronAPI?.getRecentlyViewed()

      if (movieData?.length) setMovies(movieData)
      if (tvData?.length) setTvShows(tvData)
      if (recentData?.length) setRecentlyViewed(recentData)
    } catch (error) {
      console.error("Failed to load local media:", error)
    }
  }

  // 加载在线数据
  const loadOnlineMedia = async () => {
    setLoading(true)
    try {
      // Get trending movies from TMDB
      const trendingMovies = await getTrendingMovies()
      const mappedMovies = trendingMovies.map((movie: any) => mapTMDBToMedia(movie, 'movie'))
      setMovies(mappedMovies)

      // Get trending TV shows from TMDB
      const trendingTVShows = await getTrendingTVShows()
      const mappedTVShows = trendingTVShows.map((show: any) => mapTMDBToMedia(show, 'tv'))
      setTvShows(mappedTVShows)

      // If we don't have any recently viewed media from local DB, use some trending items
      if (recentlyViewed.length === 0) {
        setRecentlyViewed([
          ...trendingMovies.slice(0, 2).map((movie: any) => mapTMDBToMedia(movie, 'movie')),
          ...trendingTVShows.slice(0, 1).map((show: any) => mapTMDBToMedia(show, 'tv'))
        ])
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

  // 扫描媒体
  const handleScan = async (type: "movie" | "tv") => {
    setScanning(true)
    try {
      const result = await window.electronAPI?.scanMedia(type)

      if (result?.success) {
        toast({
          title: "扫描完成",
          description: `发现 ${result.count} 个${type === "movie" ? "电影" : "电视剧"}`,
        })

        // 重新加载媒体数据
        await loadLocalMedia()
      } else {
        toast({
          title: "扫描失败",
          description: result?.error || "未知错误",
          variant: "destructive",
        })
      }
    } catch (error) {
      console.error(`Failed to scan ${type}:`, error)
      toast({
        title: "扫描失败",
        description: "发生错误，无法扫描媒体",
        variant: "destructive",
      })
    } finally {
      setScanning(false)
    }
  }

  // 初始加载
  useEffect(() => {
    const initializeApp = async () => {
      await loadLocalMedia()
      if (movies.length === 0 || tvShows.length === 0) {
        await loadOnlineMedia()
      } else {
        setLoading(false)
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
          
          <nav className="space-y-1">
            <Link href="/" className="flex items-center p-3 bg-sidebar-accent rounded-md hover:bg-sidebar-accent text-sidebar-accent-foreground">
              <span>首页</span>
            </Link>
            <Link href="/recently-viewed" className="flex items-center p-3 rounded-md hover:bg-sidebar-accent text-sidebar-foreground hover:text-sidebar-accent-foreground">
              <span>最近观看</span>
            </Link>
            <Link href="/movies" className="flex items-center p-3 rounded-md hover:bg-sidebar-accent text-sidebar-foreground hover:text-sidebar-accent-foreground">
              <span>电影</span>
            </Link>
            <Link href="/tv" className="flex items-center p-3 rounded-md hover:bg-sidebar-accent text-sidebar-foreground hover:text-sidebar-accent-foreground">
              <span>电视剧</span>
            </Link>
            <Link href="/other" className="flex items-center p-3 rounded-md hover:bg-sidebar-accent text-sidebar-foreground hover:text-sidebar-accent-foreground">
              <span>其他</span>
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
                <Link href="/config">
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
              </div>

              {loading ? (
                <LoadingGrid />
              ) : (
                <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-3 gap-6">
                  {recentlyViewed.slice(0, 3).map((media) => (
                    <MediaCard key={media.id} media={media} />
                  ))}
                </div>
              )}
            </section>

            {/* 电影 */}
            <section className="mb-12">
              <div className="flex justify-between items-center mb-4">
                <h3 className="text-xl font-semibold">电影 &rarr;</h3>
                <Button variant="outline" size="sm" onClick={() => handleScan("movie")} disabled={scanning} className="border-input text-foreground hover:text-foreground">
                  <RefreshCw className={`h-4 w-4 mr-2 ${scanning ? "animate-spin" : ""}`} />
                  扫描
                </Button>
              </div>

              {loading ? (
                <LoadingGrid />
              ) : (
                <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-8 gap-4">
                  {movies.slice(0, 8).map((media) => (
                    <MediaCard key={media.id} media={media} />
                  ))}
                </div>
              )}
            </section>

            {/* 电视剧 */}
            <section>
              <div className="flex justify-between items-center mb-4">
                <h3 className="text-xl font-semibold">电视剧 &rarr;</h3>
                <Button variant="outline" size="sm" onClick={() => handleScan("tv")} disabled={scanning} className="border-input text-foreground hover:text-foreground">
                  <RefreshCw className={`h-4 w-4 mr-2 ${scanning ? "animate-spin" : ""}`} />
                  扫描
                </Button>
              </div>

              {loading ? (
                <LoadingGrid />
              ) : (
                <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-8 gap-4">
                  {tvShows.slice(0, 8).map((media) => (
                    <MediaCard key={media.id} media={media} />
                  ))}
                </div>
              )}
            </section>
          </div>
        </div>
      </div>
    </main>
  )
}


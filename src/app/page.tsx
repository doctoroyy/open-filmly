"use client"

import { useEffect, useState } from "react"
import { Settings, RefreshCw } from "lucide-react"
import { MediaGrid } from "@/components/media-grid"
import { LoadingGrid } from "@/components/loading-grid"
import { Button } from "@/components/ui/button"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { useToast } from "@/components/ui/use-toast"
import Link from "next/link"
import type { Media } from "@/types/media"

export default function HomePage() {
  const [movies, setMovies] = useState<Media[]>([])
  const [tvShows, setTvShows] = useState<Media[]>([])
  const [loading, setLoading] = useState(true)
  const [scanning, setScanning] = useState(false)
  const { toast } = useToast()

  // 加载媒体数据
  const loadMedia = async () => {
    setLoading(true)
    try {
      const movieData = await window.electronAPI.getMedia("movie")
      const tvData = await window.electronAPI.getMedia("tv")

      setMovies(movieData)
      setTvShows(tvData)
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

  // 扫描媒体
  const handleScan = async (type: "movie" | "tv") => {
    setScanning(true)
    try {
      const result = await window.electronAPI.scanMedia(type)

      if (result.success) {
        toast({
          title: "扫描完成",
          description: `发现 ${result.count} 个${type === "movie" ? "电影" : "电视剧"}`,
        })

        // 重新加载媒体数据
        await loadMedia()
      } else {
        toast({
          title: "扫描失败",
          description: result.error || "未知错误",
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
    loadMedia()
  }, [])

  return (
    <main className="min-h-screen bg-black text-white">
      <div className="container mx-auto px-4 py-8">
        <div className="flex justify-between items-center mb-8">
          <h1 className="text-3xl font-bold">我的媒体库</h1>
          <div className="flex space-x-2">
            <Link href="/config">
              <Button variant="outline" size="icon">
                <Settings className="h-5 w-5" />
                <span className="sr-only">设置</span>
              </Button>
            </Link>
          </div>
        </div>

        <Tabs defaultValue="movies" className="w-full">
          <TabsList className="grid w-full max-w-md mx-auto grid-cols-2 mb-8">
            <TabsTrigger value="movies">电影</TabsTrigger>
            <TabsTrigger value="tv">电视剧</TabsTrigger>
          </TabsList>

          <TabsContent value="movies">
            <div className="flex justify-between items-center mb-4">
              <h2 className="text-2xl font-semibold">电影</h2>
              <Button variant="outline" size="sm" onClick={() => handleScan("movie")} disabled={scanning}>
                <RefreshCw className={`h-4 w-4 mr-2 ${scanning ? "animate-spin" : ""}`} />
                扫描
              </Button>
            </div>

            {loading ? <LoadingGrid /> : <MediaGrid media={movies} />}
          </TabsContent>

          <TabsContent value="tv">
            <div className="flex justify-between items-center mb-4">
              <h2 className="text-2xl font-semibold">电视剧</h2>
              <Button variant="outline" size="sm" onClick={() => handleScan("tv")} disabled={scanning}>
                <RefreshCw className={`h-4 w-4 mr-2 ${scanning ? "animate-spin" : ""}`} />
                扫描
              </Button>
            </div>

            {loading ? <LoadingGrid /> : <MediaGrid media={tvShows} />}
          </TabsContent>
        </Tabs>
      </div>
    </main>
  )
}


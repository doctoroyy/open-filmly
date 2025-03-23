"use client"

import { useState, useEffect } from 'react'
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from "@/components/ui/card"
import { useToast } from "@/components/ui/use-toast"
import { ArrowLeft, RefreshCw, Loader2 } from "lucide-react"
import Link from "next/link"
import Image from "next/image"

interface DebugLog {
  timestamp: string;
  message: string;
  type: 'info' | 'error' | 'success';
}

export default function DebugPage() {
  const [logs, setLogs] = useState<DebugLog[]>([]);
  const [mediaId, setMediaId] = useState<string>('');
  const [loading, setLoading] = useState(false);
  const [posterUrl, setPosterUrl] = useState<string | null>(null);
  const { toast } = useToast();

  const addLog = (message: string, type: 'info' | 'error' | 'success' = 'info') => {
    const timestamp = new Date().toISOString().split('T')[1].substring(0, 8);
    setLogs(prev => [...prev, { timestamp, message, type }]);
  };

  const handleFetchPoster = async () => {
    if (!mediaId) {
      toast({
        title: "请输入媒体ID",
        description: "需要提供有效的媒体ID才能获取海报",
        variant: "destructive",
      });
      return;
    }

    setLoading(true);
    setPosterUrl(null);
    setLogs([]);
    
    addLog(`开始获取媒体ID: ${mediaId} 的海报`);
    
    try {
      // 首先查询媒体信息
      addLog(`正在从数据库获取媒体信息...`);
      const media = await window.electronAPI?.getMediaById(mediaId);
      
      if (!media) {
        addLog(`未找到ID为 ${mediaId} 的媒体`, 'error');
        toast({
          title: "未找到媒体",
          description: `未找到ID为 ${mediaId} 的媒体`,
          variant: "destructive",
        });
        setLoading(false);
        return;
      }
      
      addLog(`成功获取媒体信息: ${media.title} (${media.year})`, 'success');
      
      // 检查是否已有海报
      if (media.posterPath) {
        addLog(`媒体已有海报路径: ${media.posterPath}`);
        setPosterUrl(media.posterPath);
      } else {
        addLog(`媒体没有海报，将尝试抓取`);
      }
      
      // 调用抓取海报API
      addLog(`正在调用fetchPosters API...`);
      const result = await window.electronAPI?.fetchPosters([mediaId]);
      
      if (result?.success) {
        addLog(`API调用成功`, 'success');
        
        if (result.results && result.results[mediaId]) {
          addLog(`成功获取海报路径: ${result.results[mediaId]}`, 'success');
          setPosterUrl(result.results[mediaId]);
          
          // 刷新媒体信息以获取更新后的海报路径
          const updatedMedia = await window.electronAPI?.getMediaById(mediaId);
          if (updatedMedia && updatedMedia.posterPath) {
            addLog(`数据库中更新的海报路径: ${updatedMedia.posterPath}`, 'success');
          }
        } else {
          addLog(`未能找到海报`, 'error');
        }
      } else {
        addLog(`API调用失败: ${result?.error || '未知错误'}`, 'error');
      }
    } catch (error) {
      console.error("Error fetching poster:", error);
      addLog(`获取海报时发生错误: ${error instanceof Error ? error.message : String(error)}`, 'error');
    } finally {
      setLoading(false);
    }
  };

  const handleScanMedia = async (type: "movie" | "tv") => {
    setLoading(true);
    setLogs([]);
    
    addLog(`开始扫描${type === "movie" ? "电影" : "电视剧"}...`);
    
    try {
      const result = await window.electronAPI?.scanMedia(type, false);
      
      if (result?.success) {
        addLog(`扫描成功，发现 ${result.count} 个媒体文件`, 'success');
        
        // 获取媒体列表
        const mediaList = await window.electronAPI?.getMedia(type);
        if (mediaList && mediaList.length > 0) {
          addLog(`成功获取媒体列表，共 ${mediaList.length} 个项目`, 'success');
          
          // 显示第一个媒体ID
          if (mediaList[0]) {
            setMediaId(mediaList[0].id);
            addLog(`已自动选择第一个媒体ID: ${mediaList[0].id} (${mediaList[0].title})`, 'info');
          }
        } else {
          addLog(`未找到任何媒体`, 'error');
        }
      } else {
        addLog(`扫描失败: ${result?.error || '未知错误'}`, 'error');
      }
    } catch (error) {
      console.error("Error scanning media:", error);
      addLog(`扫描媒体时发生错误: ${error instanceof Error ? error.message : String(error)}`, 'error');
    } finally {
      setLoading(false);
    }
  };

  return (
    <main className="min-h-screen bg-black text-white">
      <div className="container mx-auto px-4 py-8">
        <div className="flex items-center mb-8">
          <Link href="/">
            <Button variant="ghost" size="icon" className="mr-2">
              <ArrowLeft className="h-5 w-5" />
              <span className="sr-only">返回</span>
            </Button>
          </Link>
          <h1 className="text-3xl font-bold">海报获取调试</h1>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          <Card className="bg-gray-900 border-gray-800">
            <CardHeader>
              <CardTitle>海报获取工具</CardTitle>
              <CardDescription>测试和调试海报抓取功能</CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="space-y-2">
                <Label htmlFor="mediaId">媒体ID</Label>
                <div className="flex space-x-2">
                  <Input
                    id="mediaId"
                    value={mediaId}
                    onChange={(e) => setMediaId(e.target.value)}
                    placeholder="例如: movie-xxxx 或 tv-series-xxxx"
                    className="bg-gray-800 border-gray-700"
                  />
                  <Button 
                    onClick={handleFetchPoster}
                    disabled={loading || !mediaId}
                  >
                    {loading ? (
                      <>
                        <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                        获取中
                      </>
                    ) : "获取海报"}
                  </Button>
                </div>
              </div>

              <div className="grid grid-cols-2 gap-2">
                <Button 
                  variant="outline" 
                  onClick={() => handleScanMedia("movie")}
                  disabled={loading}
                >
                  <RefreshCw className={`mr-2 h-4 w-4 ${loading ? "animate-spin" : ""}`} />
                  扫描电影
                </Button>
                <Button 
                  variant="outline" 
                  onClick={() => handleScanMedia("tv")}
                  disabled={loading}
                >
                  <RefreshCw className={`mr-2 h-4 w-4 ${loading ? "animate-spin" : ""}`} />
                  扫描电视剧
                </Button>
              </div>

              {/* 海报预览 */}
              {posterUrl && (
                <div className="mt-4">
                  <Label>海报预览</Label>
                  <div className="relative w-40 h-60 mx-auto mt-2 border border-gray-700 rounded overflow-hidden">
                    <Image
                      src={posterUrl.startsWith("/") || posterUrl.includes(":\\") ? `file://${posterUrl}` : posterUrl}
                      alt="Poster"
                      fill
                      className="object-cover"
                      unoptimized
                      onError={() => {
                        addLog(`海报图片加载失败: ${posterUrl}`, 'error');
                      }}
                    />
                  </div>
                  <p className="text-xs mt-2 text-gray-400 break-all">
                    路径: {posterUrl}
                  </p>
                </div>
              )}
            </CardContent>
          </Card>

          <Card className="bg-gray-900 border-gray-800">
            <CardHeader>
              <CardTitle>处理日志</CardTitle>
              <CardDescription>查看海报获取流程的详细日志</CardDescription>
            </CardHeader>
            <CardContent>
              <div className="bg-gray-950 p-4 rounded h-[500px] overflow-y-auto font-mono text-sm">
                {logs.length === 0 ? (
                  <p className="text-gray-500">尚无日志数据。点击"获取海报"按钮开始记录。</p>
                ) : (
                  logs.map((log, index) => (
                    <div key={index} className={`mb-1 ${
                      log.type === 'error' ? 'text-red-400' : 
                      log.type === 'success' ? 'text-green-400' : 
                      'text-gray-300'
                    }`}>
                      <span className="text-gray-500">[{log.timestamp}]</span> {log.message}
                    </div>
                  ))
                )}
              </div>
            </CardContent>
            <CardFooter>
              <Button 
                variant="outline" 
                onClick={() => setLogs([])}
                className="w-full"
                disabled={logs.length === 0}
              >
                清空日志
              </Button>
            </CardFooter>
          </Card>
        </div>
      </div>
    </main>
  )
} 
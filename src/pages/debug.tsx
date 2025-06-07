import React, { useState, useEffect } from "react"
import { useNavigate } from "react-router-dom"
import { ArrowLeft, RefreshCw, Database, Settings, Wifi } from "lucide-react"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { useToast } from "@/components/ui/use-toast"

interface DebugInfo {
  database?: {
    movieCount: number
    tvCount: number
    totalCount: number
  }
  connection?: {
    status: string
    server?: string
    share?: string
  }
  system?: {
    platform: string
    version: string
  }
}

export default function DebugPage() {
  const navigate = useNavigate()
  const [debugInfo, setDebugInfo] = useState<DebugInfo>({})
  const [loading, setLoading] = useState(true)
  const [refreshing, setRefreshing] = useState(false)
  const { toast } = useToast()

  useEffect(() => {
    loadDebugInfo()
  }, [])

  const loadDebugInfo = async () => {
    try {
      setLoading(true)
      
      // Load database info
      const [movieData, tvData] = await Promise.all([
        window.electronAPI?.getMedia("movie") || [],
        window.electronAPI?.getMedia("tv") || []
      ])

      // Load config info
      const config = await window.electronAPI?.getConfig()

      setDebugInfo({
        database: {
          movieCount: movieData.length,
          tvCount: tvData.length,
          totalCount: movieData.length + tvData.length
        },
        connection: {
          status: config?.ip ? "已配置" : "未配置",
          server: config?.ip,
          share: config?.sharePath
        },
        system: {
          platform: navigator.platform,
          version: "1.0.0"
        }
      })
    } catch (error) {
      console.error("Failed to load debug info:", error)
      toast({
        title: "加载失败",
        description: "无法加载调试信息",
        variant: "destructive",
      })
    } finally {
      setLoading(false)
    }
  }

  const handleRefresh = async () => {
    setRefreshing(true)
    await loadDebugInfo()
    setRefreshing(false)
    toast({
      title: "刷新完成",
      description: "调试信息已更新",
    })
  }

  const handleClearCache = async () => {
    try {
      const result = await window.electronAPI?.clearMediaCache()
      if (result?.success) {
        toast({
          title: "缓存已清空",
          description: "媒体库缓存已成功清空",
        })
        await loadDebugInfo()
      } else {
        toast({
          title: "清空失败",
          description: result?.error || "无法清空缓存",
          variant: "destructive",
        })
      }
    } catch (error) {
      console.error("Failed to clear cache:", error)
      toast({
        title: "清空失败",
        description: "发生错误，无法清空缓存",
        variant: "destructive",
      })
    }
  }

  const handleTestConnection = async () => {
    try {
      const config = await window.electronAPI?.getConfig()
      if (!config?.ip) {
        toast({
          title: "连接测试失败",
          description: "请先配置服务器连接",
          variant: "destructive",
        })
        return
      }

      const result = await window.electronAPI?.connectServer(config)
      if (result?.success) {
        toast({
          title: "连接测试成功",
          description: "服务器连接正常",
        })
      } else {
        toast({
          title: "连接测试失败",
          description: result?.error || "无法连接到服务器",
          variant: "destructive",
        })
      }
    } catch (error) {
      console.error("Connection test failed:", error)
      toast({
        title: "连接测试失败",
        description: "发生错误，无法测试连接",
        variant: "destructive",
      })
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
            <h1 className="text-2xl font-bold">调试信息</h1>
          </div>
          
          <Button onClick={handleRefresh} disabled={loading || refreshing}>
            <RefreshCw className={`h-4 w-4 mr-2 ${refreshing ? "animate-spin" : ""}`} />
            刷新
          </Button>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {/* 数据库信息 */}
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <Database className="h-5 w-5" />
                数据库状态
              </CardTitle>
              <CardDescription>媒体库数据统计</CardDescription>
            </CardHeader>
            <CardContent>
              {loading ? (
                <div className="space-y-2">
                  <div className="h-4 bg-gray-200 rounded animate-pulse"></div>
                  <div className="h-4 bg-gray-200 rounded animate-pulse"></div>
                  <div className="h-4 bg-gray-200 rounded animate-pulse"></div>
                </div>
              ) : (
                <div className="space-y-2">
                  <div className="flex justify-between">
                    <span>电影:</span>
                    <span className="font-mono">{debugInfo.database?.movieCount || 0}</span>
                  </div>
                  <div className="flex justify-between">
                    <span>电视剧:</span>
                    <span className="font-mono">{debugInfo.database?.tvCount || 0}</span>
                  </div>
                  <div className="flex justify-between font-semibold border-t pt-2">
                    <span>总计:</span>
                    <span className="font-mono">{debugInfo.database?.totalCount || 0}</span>
                  </div>
                </div>
              )}
            </CardContent>
          </Card>

          {/* 连接状态 */}
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <Wifi className="h-5 w-5" />
                连接状态
              </CardTitle>
              <CardDescription>服务器连接信息</CardDescription>
            </CardHeader>
            <CardContent>
              {loading ? (
                <div className="space-y-2">
                  <div className="h-4 bg-gray-200 rounded animate-pulse"></div>
                  <div className="h-4 bg-gray-200 rounded animate-pulse"></div>
                  <div className="h-4 bg-gray-200 rounded animate-pulse"></div>
                </div>
              ) : (
                <div className="space-y-2">
                  <div className="flex justify-between">
                    <span>状态:</span>
                    <span className={`font-mono ${debugInfo.connection?.status === "已配置" ? "text-green-600" : "text-red-600"}`}>
                      {debugInfo.connection?.status || "未知"}
                    </span>
                  </div>
                  <div className="flex justify-between">
                    <span>服务器:</span>
                    <span className="font-mono text-sm">{debugInfo.connection?.server || "未配置"}</span>
                  </div>
                  <div className="flex justify-between">
                    <span>共享:</span>
                    <span className="font-mono text-sm">{debugInfo.connection?.share || "未配置"}</span>
                  </div>
                </div>
              )}
            </CardContent>
          </Card>

          {/* 系统信息 */}
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <Settings className="h-5 w-5" />
                系统信息
              </CardTitle>
              <CardDescription>应用程序信息</CardDescription>
            </CardHeader>
            <CardContent>
              {loading ? (
                <div className="space-y-2">
                  <div className="h-4 bg-gray-200 rounded animate-pulse"></div>
                  <div className="h-4 bg-gray-200 rounded animate-pulse"></div>
                </div>
              ) : (
                <div className="space-y-2">
                  <div className="flex justify-between">
                    <span>平台:</span>
                    <span className="font-mono text-sm">{debugInfo.system?.platform}</span>
                  </div>
                  <div className="flex justify-between">
                    <span>版本:</span>
                    <span className="font-mono">{debugInfo.system?.version}</span>
                  </div>
                </div>
              )}
            </CardContent>
          </Card>
        </div>

        {/* 操作按钮 */}
        <div className="mt-8 flex gap-4 flex-wrap">
          <Button onClick={handleTestConnection} variant="outline">
            测试连接
          </Button>
          <Button onClick={handleClearCache} variant="outline">
            清空缓存
          </Button>
        </div>
      </div>
    </main>
  )
}
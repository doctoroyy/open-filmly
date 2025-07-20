import React, { useState, useEffect } from "react"
import { motion, AnimatePresence } from "framer-motion"
import { 
  Play, 
  Pause, 
  Square, 
  CheckCircle, 
  AlertCircle, 
  Clock, 
  Download,
  Sparkles,
  Brain,
  Database,
  Zap,
  TrendingUp,
  Activity
} from "lucide-react"
import { Button } from "@/components/ui/button"
import { Progress } from "@/components/ui/progress"
import { Badge } from "@/components/ui/badge"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { useToast } from "@/components/ui/use-toast"
import { cn } from "@/lib/utils"

interface ScrapingStats {
  total: number
  completed: number
  failed: number
  inProgress: number
  averageTime: number
  estimatedTimeRemaining: number
  successRate: number
}

interface ScrapingItem {
  id: string
  title: string
  status: 'pending' | 'processing' | 'completed' | 'failed'
  method?: 'tmdb_exact' | 'tmdb_fuzzy' | 'ai_enhanced' | 'web_search'
  confidence?: number
  processingTime?: number
  error?: string
  retries?: number
}

interface EnhancedScrapingMonitorProps {
  isVisible: boolean
  onClose: () => void
  onStart: () => void
  onPause: () => void
  onStop: () => void
  onRetry: (itemId: string) => void
}

export function EnhancedScrapingMonitor({
  isVisible,
  onClose,
  onStart,
  onPause,
  onStop,
  onRetry
}: EnhancedScrapingMonitorProps) {
  const [isRunning, setIsRunning] = useState(false)
  const [isPaused, setIsPaused] = useState(false)
  const [stats, setStats] = useState<ScrapingStats>({
    total: 0,
    completed: 0,
    failed: 0,
    inProgress: 0,
    averageTime: 0,
    estimatedTimeRemaining: 0,
    successRate: 0
  })
  const [items, setItems] = useState<ScrapingItem[]>([])
  const [selectedTab, setSelectedTab] = useState("overview")
  const { toast } = useToast()

  // 模拟数据更新
  useEffect(() => {
    if (!isRunning || isPaused) return

    const interval = setInterval(() => {
      // 模拟进度更新
      setStats(prev => {
        const newCompleted = Math.min(prev.completed + 1, prev.total)
        const newSuccessRate = prev.total > 0 ? (newCompleted / prev.total) * 100 : 0
        const remaining = prev.total - newCompleted
        const estimatedTime = remaining * prev.averageTime

        return {
          ...prev,
          completed: newCompleted,
          inProgress: Math.max(0, Math.min(3, remaining)),
          successRate: newSuccessRate,
          estimatedTimeRemaining: estimatedTime
        }
      })

      // 模拟项目状态更新
      setItems(prev => {
        const updated = [...prev]
        const processingIndex = updated.findIndex(item => item.status === 'processing')
        
        if (processingIndex !== -1) {
          updated[processingIndex] = {
            ...updated[processingIndex],
            status: Math.random() > 0.1 ? 'completed' : 'failed',
            method: ['tmdb_exact', 'tmdb_fuzzy', 'ai_enhanced'][Math.floor(Math.random() * 3)] as any,
            confidence: Math.random() * 0.4 + 0.6,
            processingTime: Math.random() * 3000 + 1000
          }
        }

        const nextPendingIndex = updated.findIndex(item => item.status === 'pending')
        if (nextPendingIndex !== -1) {
          updated[nextPendingIndex] = {
            ...updated[nextPendingIndex],
            status: 'processing'
          }
        }

        return updated
      })
    }, 2000)

    return () => clearInterval(interval)
  }, [isRunning, isPaused])

  // 初始化数据
  useEffect(() => {
    if (isVisible && items.length === 0) {
      const mockItems: ScrapingItem[] = Array.from({ length: 25 }, (_, i) => ({
        id: `item-${i}`,
        title: `Media Item ${i + 1}`,
        status: 'pending',
        retries: 0
      }))
      
      setItems(mockItems)
      setStats({
        total: mockItems.length,
        completed: 0,
        failed: 0,
        inProgress: 0,
        averageTime: 2500,
        estimatedTimeRemaining: mockItems.length * 2500,
        successRate: 0
      })
    }
  }, [isVisible, items.length])

  const handleStart = () => {
    setIsRunning(true)
    setIsPaused(false)
    onStart()
    toast({
      title: "开始刮削",
      description: "智能元数据刮削已开始",
    })
  }

  const handlePause = () => {
    setIsPaused(!isPaused)
    onPause()
    toast({
      title: isPaused ? "已恢复" : "已暂停",
      description: isPaused ? "刮削已恢复" : "刮削已暂停",
    })
  }

  const handleStop = () => {
    setIsRunning(false)
    setIsPaused(false)
    onStop()
    toast({
      title: "已停止",
      description: "刮削已停止",
      variant: "destructive",
    })
  }

  const handleRetryItem = (itemId: string) => {
    setItems(prev => prev.map(item => 
      item.id === itemId 
        ? { ...item, status: 'pending', error: undefined, retries: (item.retries || 0) + 1 }
        : item
    ))
    onRetry(itemId)
  }

  const completedItems = items.filter(item => item.status === 'completed')
  const failedItems = items.filter(item => item.status === 'failed')
  const processingItems = items.filter(item => item.status === 'processing')

  if (!isVisible) return null

  return (
    <AnimatePresence>
      <motion.div
        className="fixed inset-0 bg-black/50 backdrop-blur-sm flex items-center justify-center z-50 p-4"
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        exit={{ opacity: 0 }}
      >
        <motion.div
          className="bg-background rounded-xl w-full max-w-6xl max-h-[90vh] overflow-hidden shadow-2xl"
          initial={{ scale: 0.9, opacity: 0 }}
          animate={{ scale: 1, opacity: 1 }}
          exit={{ scale: 0.9, opacity: 0 }}
        >
          {/* 头部 */}
          <div className="p-6 border-b bg-gradient-to-r from-primary/5 to-primary/10">
            <div className="flex justify-between items-center">
              <div>
                <h3 className="text-2xl font-bold flex items-center gap-3">
                  <div className="p-2 bg-primary/10 rounded-lg">
                    <Sparkles className="w-6 h-6 text-primary" />
                  </div>
                  智能刮削监控器
                </h3>
                <p className="text-muted-foreground mt-1">
                  AI驱动的元数据刮削，让您的媒体库更智能
                </p>
              </div>
              <div className="flex items-center gap-3">
                {!isRunning ? (
                  <Button onClick={handleStart} className="gap-2">
                    <Play className="w-4 h-4" />
                    开始刮削
                  </Button>
                ) : (
                  <>
                    <Button 
                      variant="outline" 
                      onClick={handlePause}
                      className={cn("gap-2", isPaused && "text-orange-600")}
                    >
                      {isPaused ? <Play className="w-4 h-4" /> : <Pause className="w-4 h-4" />}
                      {isPaused ? "恢复" : "暂停"}
                    </Button>
                    <Button variant="outline" onClick={handleStop} className="gap-2 text-red-600">
                      <Square className="w-4 h-4" />
                      停止
                    </Button>
                  </>
                )}
                <Button variant="ghost" onClick={onClose}>
                  关闭
                </Button>
              </div>
            </div>
          </div>

          <div className="p-6">
            <Tabs value={selectedTab} onValueChange={setSelectedTab} className="space-y-6">
              <TabsList className="grid w-full grid-cols-4">
                <TabsTrigger value="overview" className="gap-2">
                  <Activity className="w-4 h-4" />
                  概览
                </TabsTrigger>
                <TabsTrigger value="progress" className="gap-2">
                  <TrendingUp className="w-4 h-4" />
                  进度
                </TabsTrigger>
                <TabsTrigger value="completed" className="gap-2">
                  <CheckCircle className="w-4 h-4" />
                  已完成 ({completedItems.length})
                </TabsTrigger>
                <TabsTrigger value="failed" className="gap-2">
                  <AlertCircle className="w-4 h-4" />
                  失败 ({failedItems.length})
                </TabsTrigger>
              </TabsList>

              <TabsContent value="overview" className="space-y-6">
                {/* 总体进度 */}
                <Card>
                  <CardHeader>
                    <CardTitle className="flex items-center gap-2">
                      <Database className="w-5 h-5" />
                      刮削进度
                    </CardTitle>
                  </CardHeader>
                  <CardContent className="space-y-4">
                    <div className="flex justify-between text-sm">
                      <span>总进度</span>
                      <span>{stats.completed}/{stats.total} ({stats.successRate.toFixed(1)}%)</span>
                    </div>
                    <Progress value={stats.successRate} className="h-3" />
                    
                    <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mt-6">
                      <div className="p-4 bg-green-50 dark:bg-green-950/20 rounded-lg">
                        <div className="text-2xl font-bold text-green-600">{stats.completed}</div>
                        <div className="text-sm text-green-600/80">已完成</div>
                      </div>
                      <div className="p-4 bg-blue-50 dark:bg-blue-950/20 rounded-lg">
                        <div className="text-2xl font-bold text-blue-600">{stats.inProgress}</div>
                        <div className="text-sm text-blue-600/80">处理中</div>
                      </div>
                      <div className="p-4 bg-red-50 dark:bg-red-950/20 rounded-lg">
                        <div className="text-2xl font-bold text-red-600">{stats.failed}</div>
                        <div className="text-sm text-red-600/80">失败</div>
                      </div>
                      <div className="p-4 bg-gray-50 dark:bg-gray-950/20 rounded-lg">
                        <div className="text-2xl font-bold text-gray-600">{stats.total - stats.completed - stats.failed - stats.inProgress}</div>
                        <div className="text-sm text-gray-600/80">等待中</div>
                      </div>
                    </div>
                  </CardContent>
                </Card>

                {/* 实时统计 */}
                <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
                  <Card>
                    <CardHeader className="pb-3">
                      <CardTitle className="text-base flex items-center gap-2">
                        <Clock className="w-4 h-4" />
                        处理时间
                      </CardTitle>
                    </CardHeader>
                    <CardContent>
                      <div className="text-2xl font-bold">{(stats.averageTime / 1000).toFixed(1)}s</div>
                      <div className="text-sm text-muted-foreground">平均每项</div>
                    </CardContent>
                  </Card>

                  <Card>
                    <CardHeader className="pb-3">
                      <CardTitle className="text-base flex items-center gap-2">
                        <Zap className="w-4 h-4" />
                        估计剩余
                      </CardTitle>
                    </CardHeader>
                    <CardContent>
                      <div className="text-2xl font-bold">
                        {Math.floor(stats.estimatedTimeRemaining / 60000)}m {Math.floor((stats.estimatedTimeRemaining % 60000) / 1000)}s
                      </div>
                      <div className="text-sm text-muted-foreground">完成时间</div>
                    </CardContent>
                  </Card>

                  <Card>
                    <CardHeader className="pb-3">
                      <CardTitle className="text-base flex items-center gap-2">
                        <Brain className="w-4 h-4" />
                        成功率
                      </CardTitle>
                    </CardHeader>
                    <CardContent>
                      <div className="text-2xl font-bold text-green-600">{stats.successRate.toFixed(1)}%</div>
                      <div className="text-sm text-muted-foreground">识别准确率</div>
                    </CardContent>
                  </Card>
                </div>

                {/* 当前处理项目 */}
                {processingItems.length > 0 && (
                  <Card>
                    <CardHeader>
                      <CardTitle className="flex items-center gap-2">
                        <Download className="w-5 h-5 animate-pulse" />
                        正在处理
                      </CardTitle>
                    </CardHeader>
                    <CardContent>
                      <div className="space-y-3">
                        {processingItems.map((item) => (
                          <motion.div
                            key={item.id}
                            className="flex items-center justify-between p-3 bg-blue-50 dark:bg-blue-950/20 rounded-lg"
                            initial={{ opacity: 0, x: -20 }}
                            animate={{ opacity: 1, x: 0 }}
                          >
                            <div className="flex items-center gap-3">
                              <div className="w-2 h-2 bg-blue-500 rounded-full animate-pulse" />
                              <span className="font-medium">{item.title}</span>
                            </div>
                            <Badge variant="secondary">AI分析中...</Badge>
                          </motion.div>
                        ))}
                      </div>
                    </CardContent>
                  </Card>
                )}
              </TabsContent>

              <TabsContent value="progress" className="space-y-6">
                <div className="max-h-96 overflow-y-auto space-y-2">
                  {items.map((item) => (
                    <motion.div
                      key={item.id}
                      className="flex items-center justify-between p-3 border rounded-lg"
                      initial={{ opacity: 0 }}
                      animate={{ opacity: 1 }}
                      layout
                    >
                      <div className="flex items-center gap-3">
                        {item.status === 'completed' && <CheckCircle className="w-4 h-4 text-green-500" />}
                        {item.status === 'failed' && <AlertCircle className="w-4 h-4 text-red-500" />}
                        {item.status === 'processing' && <div className="w-4 h-4 border-2 border-blue-500 border-t-transparent rounded-full animate-spin" />}
                        {item.status === 'pending' && <Clock className="w-4 h-4 text-gray-400" />}
                        
                        <div>
                          <div className="font-medium">{item.title}</div>
                          {item.processingTime && (
                            <div className="text-sm text-muted-foreground">
                              处理时间: {(item.processingTime / 1000).toFixed(1)}s
                            </div>
                          )}
                        </div>
                      </div>
                      
                      <div className="flex items-center gap-2">
                        {item.method && (
                          <Badge variant="outline" className="text-xs">
                            {item.method === 'tmdb_exact' && '精确匹配'}
                            {item.method === 'tmdb_fuzzy' && '模糊搜索'}
                            {item.method === 'ai_enhanced' && 'AI增强'}
                            {item.method === 'web_search' && '网络搜索'}
                          </Badge>
                        )}
                        {item.confidence && (
                          <Badge variant="secondary" className="text-xs">
                            {(item.confidence * 100).toFixed(0)}%
                          </Badge>
                        )}
                        {item.status === 'failed' && (
                          <Button size="sm" variant="outline" onClick={() => handleRetryItem(item.id)}>
                            重试
                          </Button>
                        )}
                      </div>
                    </motion.div>
                  ))}
                </div>
              </TabsContent>

              <TabsContent value="completed" className="space-y-4">
                <div className="max-h-96 overflow-y-auto space-y-2">
                  {completedItems.map((item) => (
                    <motion.div
                      key={item.id}
                      className="flex items-center justify-between p-3 bg-green-50 dark:bg-green-950/20 border border-green-200 dark:border-green-800 rounded-lg"
                      initial={{ opacity: 0, y: 10 }}
                      animate={{ opacity: 1, y: 0 }}
                    >
                      <div className="flex items-center gap-3">
                        <CheckCircle className="w-4 h-4 text-green-500" />
                        <div>
                          <div className="font-medium">{item.title}</div>
                          <div className="text-sm text-muted-foreground">
                            {item.processingTime && `${(item.processingTime / 1000).toFixed(1)}s`}
                            {item.method && ` • ${item.method}`}
                          </div>
                        </div>
                      </div>
                      <div className="flex items-center gap-2">
                        {item.confidence && (
                          <Badge className="bg-green-600">
                            {(item.confidence * 100).toFixed(0)}% 匹配
                          </Badge>
                        )}
                      </div>
                    </motion.div>
                  ))}
                </div>
              </TabsContent>

              <TabsContent value="failed" className="space-y-4">
                <div className="max-h-96 overflow-y-auto space-y-2">
                  {failedItems.map((item) => (
                    <motion.div
                      key={item.id}
                      className="flex items-center justify-between p-3 bg-red-50 dark:bg-red-950/20 border border-red-200 dark:border-red-800 rounded-lg"
                      initial={{ opacity: 0, y: 10 }}
                      animate={{ opacity: 1, y: 0 }}
                    >
                      <div className="flex items-center gap-3">
                        <AlertCircle className="w-4 h-4 text-red-500" />
                        <div>
                          <div className="font-medium">{item.title}</div>
                          {item.error && (
                            <div className="text-sm text-red-600">{item.error}</div>
                          )}
                          {item.retries && item.retries > 0 && (
                            <div className="text-xs text-muted-foreground">
                              已重试 {item.retries} 次
                            </div>
                          )}
                        </div>
                      </div>
                      <Button size="sm" variant="outline" onClick={() => handleRetryItem(item.id)}>
                        重试
                      </Button>
                    </motion.div>
                  ))}
                </div>
              </TabsContent>
            </Tabs>
          </div>
        </motion.div>
      </motion.div>
    </AnimatePresence>
  )
}
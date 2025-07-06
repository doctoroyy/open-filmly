import React, { useEffect, useState } from 'react'
import { Loader2, CheckCircle, XCircle, Play, Square } from 'lucide-react'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
import {
  Popover,
  PopoverContent,
  PopoverTrigger,
} from '@/components/ui/popover'
import { Progress } from '@/components/ui/progress'
import { useToast } from '@/components/ui/use-toast'

interface ScanProgress {
  phase: 'connecting' | 'discovering' | 'processing' | 'scraping' | 'completed' | 'error'
  current: number
  total: number
  currentItem?: string
  error?: string
  startTime: Date
  estimatedTimeRemaining?: number
}

interface AutoScanStatus {
  isScanning: boolean
  isConnected: boolean
  scanProgress?: ScanProgress
  scrapeProgress?: ScanProgress
  currentPhase: string
  errors: string[]
}

export function AutoScanStatus() {
  const [status, setStatus] = useState<AutoScanStatus>({
    isScanning: false,
    isConnected: false,
    currentPhase: 'idle',
    errors: []
  })
  const [isOpen, setIsOpen] = useState(false)
  const { toast } = useToast()

  // 获取扫描状态
  const fetchStatus = async () => {
    try {
      if (window.electronAPI?.getScanStatus) {
        const result = await window.electronAPI.getScanStatus()
        if (result?.success) {
          setStatus(result.data)
        }
      }
    } catch (error) {
      console.error('Error fetching scan status:', error)
    }
  }

  // 开始自动扫描
  const startAutoScan = async () => {
    try {
      if (window.electronAPI?.startAutoScan) {
        const result = await window.electronAPI.startAutoScan({ force: false })
        if (result?.success) {
          toast({
            title: "自动扫描已启动",
            description: "正在后台扫描媒体文件...",
          })
        } else {
          toast({
            title: "启动失败",
            description: result?.error || "无法启动自动扫描",
            variant: "destructive"
          })
        }
      }
    } catch (error) {
      console.error('Error starting auto scan:', error)
      toast({
        title: "启动失败",
        description: "启动自动扫描时发生错误",
        variant: "destructive"
      })
    }
  }

  // 停止自动扫描
  const stopAutoScan = async () => {
    try {
      if (window.electronAPI?.stopAutoScan) {
        const result = await window.electronAPI.stopAutoScan()
        if (result?.success) {
          toast({
            title: "自动扫描已停止",
            description: "扫描已被用户终止",
          })
        }
      }
    } catch (error) {
      console.error('Error stopping auto scan:', error)
    }
  }

  // 监听扫描进度更新
  useEffect(() => {
    const handleProgressUpdate = (data: AutoScanStatus) => {
      setStatus(data)
    }

    const handleScanCompleted = (data: any) => {
      toast({
        title: "扫描完成",
        description: `共处理了 ${data.totalProcessed} 个媒体文件`,
      })
      
      // 触发页面数据重新加载
      window.dispatchEvent(new CustomEvent('scan-completed'))
    }

    const handleScanError = (data: any) => {
      toast({
        title: "扫描出错",
        description: data.error || "扫描过程中发生错误",
        variant: "destructive"
      })
    }

    // 注册IPC事件监听器
    if (window.electronAPI?.onScanProgressUpdate) {
      window.electronAPI.onScanProgressUpdate(handleProgressUpdate)
    }
    if (window.electronAPI?.onScanCompleted) {
      window.electronAPI.onScanCompleted(handleScanCompleted)
    }
    if (window.electronAPI?.onScanError) {
      window.electronAPI.onScanError(handleScanError)
    }

    // 初始状态获取
    fetchStatus()

    // 定期更新状态
    const interval = setInterval(fetchStatus, 5000)

    return () => {
      clearInterval(interval)
      // 清理事件监听器
      if (window.electronAPI?.removeAllListeners) {
        window.electronAPI.removeAllListeners('scan-progress-update')
        window.electronAPI.removeAllListeners('scan-completed')
        window.electronAPI.removeAllListeners('scan-error')
      }
    }
  }, [toast])

  // 根据状态渲染图标
  const renderStatusIcon = () => {
    if (status.isScanning) {
      return <Loader2 className="h-4 w-4 animate-spin" />
    }
    
    if (status.errors.length > 0) {
      return <XCircle className="h-4 w-4 text-red-500" />
    }
    
    if (status.currentPhase === 'completed') {
      return <CheckCircle className="h-4 w-4 text-green-500" />
    }
    
    return null
  }

  // 格式化进度文本
  const formatProgress = (progress?: ScanProgress) => {
    if (!progress) return null
    
    const percentage = progress.total > 0 ? Math.round((progress.current / progress.total) * 100) : 0
    return `${progress.current}/${progress.total} (${percentage}%)`
  }

  // 格式化阶段名称
  const formatPhase = (phase: string) => {
    const phaseNames: Record<string, string> = {
      connecting: '连接中',
      discovering: '发现文件',
      processing: '处理文件',
      scraping: '获取元数据',
      completed: '完成',
      error: '错误',
      idle: '空闲'
    }
    return phaseNames[phase] || phase
  }

  // 计算总体进度
  const calculateOverallProgress = () => {
    const scanProgress = status.scanProgress
    const scrapeProgress = status.scrapeProgress
    
    if (!scanProgress) return 0
    
    let progress = 0
    const scanWeight = 0.7  // 扫描占70%
    const scrapeWeight = 0.3  // 刮削占30%
    
    if (scanProgress.total > 0) {
      progress += (scanProgress.current / scanProgress.total) * scanWeight * 100
    }
    
    if (scrapeProgress && scrapeProgress.total > 0) {
      progress += (scrapeProgress.current / scrapeProgress.total) * scrapeWeight * 100
    }
    
    return Math.min(Math.round(progress), 100)
  }

  return (
    <Popover open={isOpen} onOpenChange={setIsOpen}>
      <PopoverTrigger asChild>
        <Button 
          variant="ghost" 
          size="sm" 
          className="relative"
          onClick={() => setIsOpen(true)}
        >
          {renderStatusIcon()}
          {status.isScanning && (
            <Badge 
              variant="secondary" 
              className="ml-2 text-xs"
            >
              {formatPhase(status.currentPhase)}
            </Badge>
          )}
        </Button>
      </PopoverTrigger>
      
      <PopoverContent className="w-80" align="end">
        <div className="space-y-4">
          <div className="flex items-center justify-between">
            <h4 className="font-semibold">自动扫描状态</h4>
            <div className="flex gap-2">
              {status.isScanning ? (
                <Button 
                  size="sm" 
                  variant="outline"
                  onClick={stopAutoScan}
                >
                  <Square className="h-3 w-3 mr-1" />
                  停止
                </Button>
              ) : (
                <Button 
                  size="sm" 
                  onClick={startAutoScan}
                >
                  <Play className="h-3 w-3 mr-1" />
                  开始扫描
                </Button>
              )}
            </div>
          </div>

          {status.isScanning && (
            <div className="space-y-3">
              {/* 总体进度 */}
              <div>
                <div className="flex justify-between text-sm mb-1">
                  <span>总体进度</span>
                  <span>{calculateOverallProgress()}%</span>
                </div>
                <Progress value={calculateOverallProgress()} className="h-2" />
              </div>

              {/* 扫描进度 */}
              {status.scanProgress && (
                <div>
                  <div className="flex justify-between text-sm mb-1">
                    <span>文件扫描</span>
                    <span>{formatProgress(status.scanProgress)}</span>
                  </div>
                  <Progress 
                    value={status.scanProgress.total > 0 ? 
                      (status.scanProgress.current / status.scanProgress.total) * 100 : 0
                    } 
                    className="h-2" 
                  />
                  {status.scanProgress.currentItem && (
                    <p className="text-xs text-muted-foreground mt-1 truncate">
                      {status.scanProgress.currentItem}
                    </p>
                  )}
                </div>
              )}

              {/* 刮削进度 */}
              {status.scrapeProgress && (
                <div>
                  <div className="flex justify-between text-sm mb-1">
                    <span>元数据获取</span>
                    <span>{formatProgress(status.scrapeProgress)}</span>
                  </div>
                  <Progress 
                    value={status.scrapeProgress.total > 0 ? 
                      (status.scrapeProgress.current / status.scrapeProgress.total) * 100 : 0
                    } 
                    className="h-2" 
                  />
                  {status.scrapeProgress.currentItem && (
                    <p className="text-xs text-muted-foreground mt-1 truncate">
                      {status.scrapeProgress.currentItem}
                    </p>
                  )}
                </div>
              )}
            </div>
          )}

          {/* 状态信息 */}
          <div className="text-sm space-y-1">
            <div className="flex justify-between">
              <span className="text-muted-foreground">连接状态:</span>
              <span className={status.isConnected ? "text-green-600" : "text-red-600"}>
                {status.isConnected ? "已连接" : "未连接"}
              </span>
            </div>
            <div className="flex justify-between">
              <span className="text-muted-foreground">当前阶段:</span>
              <span>{formatPhase(status.currentPhase)}</span>
            </div>
          </div>

          {/* 错误信息 */}
          {status.errors.length > 0 && (
            <div className="border-t pt-3">
              <h5 className="font-medium text-sm text-red-600 mb-2">错误信息</h5>
              <div className="space-y-1">
                {status.errors.slice(-3).map((error, index) => (
                  <p key={index} className="text-xs text-red-600 break-words">
                    {error}
                  </p>
                ))}
                {status.errors.length > 3 && (
                  <p className="text-xs text-muted-foreground">
                    还有 {status.errors.length - 3} 个错误...
                  </p>
                )}
              </div>
            </div>
          )}
        </div>
      </PopoverContent>
    </Popover>
  )
}
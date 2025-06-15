/**
 * 全局错误处理 Hook
 * 用于统一处理应用中的错误
 */

import { useEffect } from 'react'
import { useToast } from '@/components/ui/use-toast'

export function useErrorHandler() {
  const { toast } = useToast()

  useEffect(() => {
    // 全局错误处理
    const handleError = (event: ErrorEvent) => {
      console.error('[Global Error]:', event.error)
      
      // 避免显示过多错误提示
      if (!event.error?.message?.includes('ResizeObserver')) {
        toast({
          title: "应用错误",
          description: "应用遇到错误，请查看控制台获取详细信息",
          variant: "destructive",
        })
      }
    }

    // 未处理的Promise拒绝
    const handleUnhandledRejection = (event: PromiseRejectionEvent) => {
      console.error('[Unhandled Promise Rejection]:', event.reason)
      
      toast({
        title: "异步操作失败",
        description: "某个异步操作失败，请查看控制台获取详细信息",
        variant: "destructive",
      })
    }

    window.addEventListener('error', handleError)
    window.addEventListener('unhandledrejection', handleUnhandledRejection)

    return () => {
      window.removeEventListener('error', handleError)
      window.removeEventListener('unhandledrejection', handleUnhandledRejection)
    }
  }, [toast])

  // 手动错误报告函数
  const reportError = (error: Error, context?: string) => {
    console.error(`[${context || 'Manual'}]:`, error)
    
    toast({
      title: "操作失败",
      description: error.message || "操作时发生错误",
      variant: "destructive",
    })
  }

  return { reportError }
}
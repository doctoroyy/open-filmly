/**
 * 内置视频播放器组件
 * 支持SMB协议流媒体播放
 */

import React, { useRef, useEffect, useState, useCallback } from 'react'
import { Play, Pause, Volume2, VolumeX, Maximize, SkipBack, SkipForward, X } from 'lucide-react'
import { Button } from '@/components/ui/button'
import { Slider } from '@/components/ui/slider'
import { useToast } from '@/components/ui/use-toast'

interface VideoPlayerProps {
  src: string
  title: string
  onClose: () => void
  poster?: string
  autoPlay?: boolean
}

export function VideoPlayer({ src, title, onClose, poster, autoPlay = false }: VideoPlayerProps) {
  const videoRef = useRef<HTMLVideoElement>(null)
  const containerRef = useRef<HTMLDivElement>(null)
  const [isPlaying, setIsPlaying] = useState(false)
  const [isMuted, setIsMuted] = useState(false)
  const [volume, setVolume] = useState(100)
  const [currentTime, setCurrentTime] = useState(0)
  const [duration, setDuration] = useState(0)
  const [isFullscreen, setIsFullscreen] = useState(false)
  const [showControls, setShowControls] = useState(true)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const { toast } = useToast()

  // 控制栏自动隐藏
  const controlsTimeoutRef = useRef<NodeJS.Timeout>()

  const resetControlsTimeout = useCallback(() => {
    if (controlsTimeoutRef.current) {
      clearTimeout(controlsTimeoutRef.current)
    }
    
    setShowControls(true)
    
    if (isPlaying) {
      controlsTimeoutRef.current = setTimeout(() => {
        setShowControls(false)
      }, 3000)
    }
  }, [isPlaying])

  // 播放/暂停
  const togglePlay = useCallback(() => {
    if (!videoRef.current) return

    if (isPlaying) {
      videoRef.current.pause()
    } else {
      videoRef.current.play()
    }
  }, [isPlaying])

  // 静音/取消静音
  const toggleMute = useCallback(() => {
    if (!videoRef.current) return

    videoRef.current.muted = !isMuted
    setIsMuted(!isMuted)
  }, [isMuted])

  // 设置音量
  const handleVolumeChange = useCallback((value: number[]) => {
    if (!videoRef.current) return

    const newVolume = value[0]
    videoRef.current.volume = newVolume / 100
    setVolume(newVolume)
    
    if (newVolume === 0) {
      setIsMuted(true)
      videoRef.current.muted = true
    } else if (isMuted) {
      setIsMuted(false)
      videoRef.current.muted = false
    }
  }, [isMuted])

  // 跳转到指定时间
  const handleSeek = useCallback((value: number[]) => {
    if (!videoRef.current) return

    const newTime = value[0]
    videoRef.current.currentTime = newTime
    setCurrentTime(newTime)
  }, [])

  // 快进/快退
  const skipTime = useCallback((seconds: number) => {
    if (!videoRef.current) return

    const newTime = Math.max(0, Math.min(duration, currentTime + seconds))
    videoRef.current.currentTime = newTime
    setCurrentTime(newTime)
  }, [currentTime, duration])

  // 全屏切换
  const toggleFullscreen = useCallback(() => {
    if (!containerRef.current) return

    if (!isFullscreen) {
      if (containerRef.current.requestFullscreen) {
        containerRef.current.requestFullscreen()
      }
    } else {
      if (document.exitFullscreen) {
        document.exitFullscreen()
      }
    }
  }, [isFullscreen])

  // 格式化时间
  const formatTime = useCallback((time: number) => {
    const hours = Math.floor(time / 3600)
    const minutes = Math.floor((time % 3600) / 60)
    const seconds = Math.floor(time % 60)

    if (hours > 0) {
      return `${hours}:${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`
    } else {
      return `${minutes}:${seconds.toString().padStart(2, '0')}`
    }
  }, [])

  // 视频事件处理
  useEffect(() => {
    const video = videoRef.current
    if (!video) return

    const handleLoadStart = () => {
      setLoading(true)
      setError(null)
    }

    const handleLoadedData = () => {
      setLoading(false)
      setDuration(video.duration)
      console.log('[VideoPlayer] Video loaded, duration:', video.duration)
    }

    const handlePlay = () => {
      setIsPlaying(true)
      resetControlsTimeout()
    }

    const handlePause = () => {
      setIsPlaying(false)
      setShowControls(true)
      if (controlsTimeoutRef.current) {
        clearTimeout(controlsTimeoutRef.current)
      }
    }

    const handleTimeUpdate = () => {
      setCurrentTime(video.currentTime)
    }

    const handleVolumeChange = () => {
      setVolume(video.volume * 100)
      setIsMuted(video.muted)
    }

    const handleError = (e: any) => {
      console.error('[VideoPlayer] Video error:', e)
      setLoading(false)
      setError('视频加载失败，请检查文件格式或网络连接')
      toast({
        title: "播放错误",
        description: "视频加载失败，请检查文件格式或网络连接",
        variant: "destructive",
      })
    }

    const handleEnded = () => {
      setIsPlaying(false)
      setShowControls(true)
      toast({
        title: "播放完成",
        description: `《${title}》播放完成`,
      })
    }

    video.addEventListener('loadstart', handleLoadStart)
    video.addEventListener('loadeddata', handleLoadedData)
    video.addEventListener('play', handlePlay)
    video.addEventListener('pause', handlePause)
    video.addEventListener('timeupdate', handleTimeUpdate)
    video.addEventListener('volumechange', handleVolumeChange)
    video.addEventListener('error', handleError)
    video.addEventListener('ended', handleEnded)

    return () => {
      video.removeEventListener('loadstart', handleLoadStart)
      video.removeEventListener('loadeddata', handleLoadedData)
      video.removeEventListener('play', handlePlay)
      video.removeEventListener('pause', handlePause)
      video.removeEventListener('timeupdate', handleTimeUpdate)
      video.removeEventListener('volumechange', handleVolumeChange)
      video.removeEventListener('error', handleError)
      video.removeEventListener('ended', handleEnded)
    }
  }, [title, toast, resetControlsTimeout])

  // 全屏状态监听
  useEffect(() => {
    const handleFullscreenChange = () => {
      setIsFullscreen(!!document.fullscreenElement)
    }

    document.addEventListener('fullscreenchange', handleFullscreenChange)
    return () => {
      document.removeEventListener('fullscreenchange', handleFullscreenChange)
    }
  }, [])

  // 鼠标移动时显示控制栏
  useEffect(() => {
    const handleMouseMove = () => {
      resetControlsTimeout()
    }

    const container = containerRef.current
    if (container) {
      container.addEventListener('mousemove', handleMouseMove)
      return () => {
        container.removeEventListener('mousemove', handleMouseMove)
      }
    }
  }, [resetControlsTimeout])

  // 键盘快捷键
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      // 只有当播放器是焦点时才处理键盘事件
      const target = e.target as HTMLElement
      if (target.tagName === 'INPUT' || target.tagName === 'TEXTAREA') {
        return
      }

      switch (e.key) {
        case ' ':
          e.preventDefault()
          togglePlay()
          break
        case 'ArrowLeft':
          e.preventDefault()
          skipTime(-10)
          break
        case 'ArrowRight':
          e.preventDefault()
          skipTime(10)
          break
        case 'ArrowUp':
          e.preventDefault()
          handleVolumeChange([Math.min(100, volume + 10)])
          break
        case 'ArrowDown':
          e.preventDefault()
          handleVolumeChange([Math.max(0, volume - 10)])
          break
        case 'f':
        case 'F':
          e.preventDefault()
          toggleFullscreen()
          break
        case 'm':
        case 'M':
          e.preventDefault()
          toggleMute()
          break
        case 'Escape':
          e.preventDefault()
          if (isFullscreen) {
            toggleFullscreen()
          } else {
            onClose()
          }
          break
      }
    }

    document.addEventListener('keydown', handleKeyDown)
    return () => {
      document.removeEventListener('keydown', handleKeyDown)
    }
  }, [togglePlay, skipTime, handleVolumeChange, volume, toggleFullscreen, toggleMute, isFullscreen, onClose])

  // 自动播放
  useEffect(() => {
    if (autoPlay && videoRef.current && !loading) {
      videoRef.current.play().catch(console.error)
    }
  }, [autoPlay, loading])

  return (
    <div 
      ref={containerRef}
      className="fixed inset-0 bg-black z-50 flex items-center justify-center"
      onDoubleClick={toggleFullscreen}
    >
      {/* 视频元素 */}
      <video
        ref={videoRef}
        src={src}
        poster={poster}
        className="w-full h-full object-contain"
        onClick={togglePlay}
        preload="metadata"
      />

      {/* 加载指示器 */}
      {loading && (
        <div className="absolute inset-0 flex items-center justify-center bg-black bg-opacity-50">
          <div className="text-white text-center">
            <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-white mb-4 mx-auto"></div>
            <p>正在加载视频...</p>
          </div>
        </div>
      )}

      {/* 错误显示 */}
      {error && (
        <div className="absolute inset-0 flex items-center justify-center bg-black bg-opacity-50">
          <div className="text-white text-center max-w-md">
            <p className="text-red-400 mb-4">{error}</p>
            <Button onClick={onClose} variant="outline">
              关闭播放器
            </Button>
          </div>
        </div>
      )}

      {/* 控制栏 */}
      <div
        className={`absolute bottom-0 left-0 right-0 bg-gradient-to-t from-black to-transparent p-6 transition-opacity duration-300 ${
          showControls ? 'opacity-100' : 'opacity-0'
        }`}
      >
        {/* 进度条 */}
        <div className="mb-4">
          <Slider
            value={[currentTime]}
            max={duration || 0}
            step={1}
            onValueChange={handleSeek}
            className="w-full"
          />
          <div className="flex justify-between text-white text-sm mt-1">
            <span>{formatTime(currentTime)}</span>
            <span>{formatTime(duration)}</span>
          </div>
        </div>

        {/* 控制按钮 */}
        <div className="flex items-center justify-between">
          <div className="flex items-center space-x-4">
            <Button onClick={() => skipTime(-10)} variant="ghost" size="sm">
              <SkipBack className="h-5 w-5" />
            </Button>
            
            <Button onClick={togglePlay} variant="ghost" size="sm">
              {isPlaying ? (
                <Pause className="h-6 w-6" />
              ) : (
                <Play className="h-6 w-6" />
              )}
            </Button>
            
            <Button onClick={() => skipTime(10)} variant="ghost" size="sm">
              <SkipForward className="h-5 w-5" />
            </Button>

            <div className="flex items-center space-x-2">
              <Button onClick={toggleMute} variant="ghost" size="sm">
                {isMuted ? (
                  <VolumeX className="h-5 w-5" />
                ) : (
                  <Volume2 className="h-5 w-5" />
                )}
              </Button>
              
              <div className="w-24">
                <Slider
                  value={[volume]}
                  max={100}
                  step={1}
                  onValueChange={handleVolumeChange}
                />
              </div>
            </div>
          </div>

          <div className="text-white font-medium">
            {title}
          </div>

          <div className="flex items-center space-x-4">
            <Button onClick={toggleFullscreen} variant="ghost" size="sm">
              <Maximize className="h-5 w-5" />
            </Button>
            
            <Button onClick={onClose} variant="ghost" size="sm">
              <X className="h-5 w-5" />
            </Button>
          </div>
        </div>
      </div>
    </div>
  )
}
/**
 * MPV 播放器组件
 * 基于 mpv.js 提供更广泛的编解码器支持
 * 作为 HTML5 播放器的增强替代方案
 */

import React, { useRef, useEffect, useState, useCallback } from 'react'
import { Play, Pause, Volume2, VolumeX, Maximize, SkipBack, SkipForward, X } from 'lucide-react'
import { Button } from '@/components/ui/button'
import { Slider } from '@/components/ui/slider'
import { useToast } from '@/components/ui/use-toast'

// 导入 mpv.js 的 ReactMPV 组件
let ReactMPV: any = null
let mpvError: string | null = null

try {
  // 尝试动态导入 mpv.js
  const mpvModule = require('mpv.js')
  ReactMPV = mpvModule.ReactMPV || mpvModule.default?.ReactMPV
  
  if (!ReactMPV) {
    throw new Error('ReactMPV component not found in mpv.js module')
  }
  
  console.log('[MPVPlayer] mpv.js loaded successfully')
} catch (error) {
  mpvError = error instanceof Error ? error.message : String(error)
  console.warn('[MPVPlayer] mpv.js not available:', mpvError)
  
  // 检查是否是编译错误
  if (mpvError.includes('GLES2/gl2.h') || mpvError.includes('OpenGL')) {
    mpvError = 'MPV需要OpenGL ES支持，当前系统不支持'
  } else if (mpvError.includes('Cannot find module')) {
    mpvError = 'MPV模块未正确安装'
  }
}

interface MPVPlayerProps {
  src: string
  title: string
  onClose: () => void
  poster?: string
  autoPlay?: boolean
}

export function MPVPlayer({ src, title, onClose, poster, autoPlay = false }: MPVPlayerProps) {
  const mpvRef = useRef<any>(null)
  const containerRef = useRef<HTMLDivElement>(null)
  const [mpvReady, setMpvReady] = useState(false)
  const [isPlaying, setIsPlaying] = useState(false)
  const [isMuted, setIsMuted] = useState(false)
  const [volume, setVolume] = useState(100)
  const [currentTime, setCurrentTime] = useState(0)
  const [duration, setDuration] = useState(0)
  const [isFullscreen, setIsFullscreen] = useState(false)
  const [showControls, setShowControls] = useState(true)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [mpvAvailable, setMpvAvailable] = useState<boolean | null>(null)
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

  // MPV 就绪回调
  const handleMPVReady = useCallback((mpv: any) => {
    console.log('[MPVPlayer] MPV ready, setting up...', mpv)
    mpvRef.current = mpv
    setMpvReady(true)
    setLoading(false)

    // 设置 MPV 属性
    try {
      console.log('[MPVPlayer] Setting volume to:', volume)
      mpv.property('volume', volume)
      
      // 监听属性变化
      console.log('[MPVPlayer] Setting up property observers')
      mpv.observe('pause')
      mpv.observe('volume') 
      mpv.observe('time-pos')
      mpv.observe('duration')
      mpv.observe('mute')
      
      // 加载文件
      if (src) {
        console.log('[MPVPlayer] Loading file:', src)
        mpv.command('loadfile', src)
      }
      
      // 自动播放
      if (autoPlay) {
        console.log('[MPVPlayer] Starting autoplay')
        mpv.property('pause', false)
      }
      
      console.log('[MPVPlayer] MPV setup completed successfully')
    } catch (error) {
      console.error('[MPVPlayer] Error setting up MPV:', error)
      setError('播放器初始化失败: ' + (error instanceof Error ? error.message : String(error)))
    }
  }, [src, volume, autoPlay])

  // MPV 属性变化回调
  const handlePropertyChange = useCallback((name: string, value: any) => {
    console.log(`[MPVPlayer] Property changed: ${name} = ${value}`)
    
    switch (name) {
      case 'pause':
        setIsPlaying(!value)
        break
      case 'volume':
        setVolume(value)
        break
      case 'time-pos':
        if (typeof value === 'number') {
          setCurrentTime(value)
        }
        break
      case 'duration':
        if (typeof value === 'number') {
          setDuration(value)
        }
        break
      case 'mute':
        setIsMuted(value)
        break
    }
  }, [])

  // MPV 错误回调
  const handleMPVError = useCallback((error: any) => {
    console.error('[MPVPlayer] MPV error:', error)
    setError('播放失败，文件可能不支持或已损坏')
    setLoading(false)
    toast({
      title: "MPV播放失败",
      description: "编解码器不支持或文件损坏",
      variant: "destructive",
    })
  }, [toast])

  // 播放/暂停
  const togglePlay = useCallback(() => {
    if (!mpvRef.current) return

    try {
      const newPauseState = isPlaying
      mpvRef.current.property('pause', newPauseState)
      setIsPlaying(!newPauseState)
    } catch (error) {
      console.error('[MPVPlayer] Error toggling play:', error)
    }
  }, [isPlaying])

  // 静音/取消静音
  const toggleMute = useCallback(() => {
    if (!mpvRef.current) return

    try {
      mpvRef.current.property('mute', !isMuted)
      setIsMuted(!isMuted)
    } catch (error) {
      console.error('[MPVPlayer] Error toggling mute:', error)
    }
  }, [isMuted])

  // 设置音量
  const handleVolumeChange = useCallback((value: number[]) => {
    if (!mpvRef.current) return

    try {
      const newVolume = value[0]
      mpvRef.current.property('volume', newVolume)
      setVolume(newVolume)
      
      if (newVolume === 0) {
        mpvRef.current.property('mute', true)
        setIsMuted(true)
      } else if (isMuted) {
        mpvRef.current.property('mute', false)
        setIsMuted(false)
      }
    } catch (error) {
      console.error('[MPVPlayer] Error setting volume:', error)
    }
  }, [isMuted])

  // 跳转到指定时间
  const handleSeek = useCallback((value: number[]) => {
    if (!mpvRef.current) return

    try {
      const newTime = value[0]
      mpvRef.current.property('time-pos', newTime)
      setCurrentTime(newTime)
    } catch (error) {
      console.error('[MPVPlayer] Error seeking:', error)
    }
  }, [])

  // 快进/快退
  const skipTime = useCallback((seconds: number) => {
    if (!mpvRef.current) return

    try {
      mpvRef.current.command('seek', seconds, 'relative')
    } catch (error) {
      console.error('[MPVPlayer] Error skipping time:', error)
    }
  }, [])

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

  // 初始化MPV
  useEffect(() => {
    console.log('[MPVPlayer] Component mounted, ReactMPV available:', !!ReactMPV)
    console.log('[MPVPlayer] ReactMPV type:', typeof ReactMPV)
    console.log('[MPVPlayer] ReactMPV object:', ReactMPV)
    
    // 让组件状态保持在加载中，等待ReactMPV实际初始化
    if (ReactMPV) {
      console.log('[MPVPlayer] ReactMPV component loaded, waiting for ready callback')
      // 不要在这里就设置为loaded，等待handleMPVReady回调
    } else {
      // ReactMPV组件不可用
      setMpvAvailable(false)
      setError('MPV.js模块未正确加载')
      setLoading(false)
      console.error('[MPVPlayer] ReactMPV component not available')
    }
  }, [])

  // 清理资源
  useEffect(() => {
    return () => {
      if (controlsTimeoutRef.current) {
        clearTimeout(controlsTimeoutRef.current)
      }
    }
  }, [])

  // 检查 MPV 是否可用
  if (!ReactMPV) {
    return (
      <div className="fixed inset-0 bg-black z-50 flex items-center justify-center">
        <div className="text-white text-center max-w-md">
          <p className="text-red-400 mb-4">MPV播放器不可用</p>
          <p className="text-sm text-gray-300 mb-4">
            {mpvError || 'MPV.js组件无法加载，请检查安装'}
          </p>
          <p className="text-xs text-gray-400 mb-4">
            建议使用HTML5播放器作为替代方案
          </p>
          <Button onClick={onClose} variant="outline">
            关闭
          </Button>
        </div>
      </div>
    )
  }

  // 显示加载或错误状态
  if (loading || mpvAvailable === null) {
    return (
      <div className="fixed inset-0 bg-black z-50 flex items-center justify-center">
        <div className="text-white text-center max-w-md">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-white mb-4 mx-auto"></div>
          <p className="text-white mb-4">MPV播放器初始化中...</p>
          <p className="text-sm text-gray-300 mb-4">
            正在加载MPV播放器，请稍候...
          </p>
          <Button onClick={onClose} variant="outline">
            关闭
          </Button>
        </div>
      </div>
    )
  }

  // MPV不可用
  if (mpvAvailable === false) {
    return (
      <div className="fixed inset-0 bg-black z-50 flex items-center justify-center">
        <div className="text-white text-center max-w-md">
          <p className="text-red-400 mb-4">MPV播放器不可用</p>
          <p className="text-sm text-gray-300 mb-4">
            {error || 'MPV播放器初始化失败'}
          </p>
          <Button onClick={onClose} variant="outline">
            关闭
          </Button>
        </div>
      </div>
    )
  }

  return (
    <div 
      ref={containerRef}
      className="fixed inset-0 bg-black z-50 flex items-center justify-center"
      onDoubleClick={toggleFullscreen}
    >
      {/* MPV 播放器 */}
      <div className="w-full h-full relative">
        <ReactMPV
          className="w-full h-full"
          onReady={(mpv: any) => {
            console.log('[MPVPlayer] ReactMPV onReady callback triggered!', mpv)
            handleMPVReady(mpv)
          }}
          onPropertyChange={(name: string, value: any) => {
            console.log('[MPVPlayer] ReactMPV onPropertyChange callback triggered:', name, value)
            handlePropertyChange(name, value)
          }}
          onError={(error: any) => {
            console.log('[MPVPlayer] ReactMPV onError callback triggered:', error)
            handleMPVError(error)
          }}
          debug={true}
        />
      </div>

      {/* 加载指示器 */}
      {loading && (
        <div className="absolute inset-0 flex items-center justify-center bg-black bg-opacity-50">
          <div className="text-white text-center">
            <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-white mb-4 mx-auto"></div>
            <p>正在初始化MPV播放器...</p>
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

          <div className="text-white font-medium flex items-center">
            <span className="bg-purple-600 text-xs px-2 py-1 rounded mr-2">MPV</span>
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
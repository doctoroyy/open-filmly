import React from 'react'
import { ThemeProvider } from '@/components/theme-provider'
import { Toaster } from '@/components/ui/toaster'
import { VideoPlayerProvider, useVideoPlayer } from '@/contexts/video-player-context'
import { MPVPlayer } from '@/components/mpv-player'
import { ErrorBoundary } from '@/components/error-boundary'
import { useErrorHandler } from '@/hooks/use-error-handler'
import AppRouter from './router'

function AppContent() {
  const { playerState, closePlayer } = useVideoPlayer()
  
  // 全局错误处理
  useErrorHandler()
  
  return (
    <div className="app-wrapper">
      <AppRouter />
      <Toaster />
      
      {/* 全局MPV播放器 */}
      {playerState.isOpen && (
        <MPVPlayer
          src={playerState.src}
          title={playerState.title}
          poster={playerState.poster}
          onClose={closePlayer}
          autoPlay={true}
        />
      )}
    </div>
  )
}

function App() {
  console.log('App 组件正在渲染')
  
  return (
    <ErrorBoundary>
      <ThemeProvider attribute="class" defaultTheme="dark" enableSystem disableTransitionOnChange>
        <VideoPlayerProvider>
          <AppContent />
        </VideoPlayerProvider>
      </ThemeProvider>
    </ErrorBoundary>
  )
}

export default App
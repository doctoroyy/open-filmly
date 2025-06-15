/**
 * 视频播放器上下文
 * 管理全局的视频播放器状态
 */

import React, { createContext, useContext, useState, ReactNode } from 'react'

interface VideoPlayerState {
  isOpen: boolean
  src: string
  title: string
  poster?: string
}

interface VideoPlayerContextType {
  playerState: VideoPlayerState
  openPlayer: (src: string, title: string, poster?: string) => void
  closePlayer: () => void
}

const VideoPlayerContext = createContext<VideoPlayerContextType | undefined>(undefined)

export function VideoPlayerProvider({ children }: { children: ReactNode }) {
  const [playerState, setPlayerState] = useState<VideoPlayerState>({
    isOpen: false,
    src: '',
    title: '',
    poster: undefined
  })

  const openPlayer = (src: string, title: string, poster?: string) => {
    setPlayerState({
      isOpen: true,
      src,
      title,
      poster
    })
  }

  const closePlayer = () => {
    setPlayerState({
      isOpen: false,
      src: '',
      title: '',
      poster: undefined
    })
  }

  return (
    <VideoPlayerContext.Provider value={{ playerState, openPlayer, closePlayer }}>
      {children}
    </VideoPlayerContext.Provider>
  )
}

export function useVideoPlayer() {
  const context = useContext(VideoPlayerContext)
  if (context === undefined) {
    throw new Error('useVideoPlayer must be used within a VideoPlayerProvider')
  }
  return context
}
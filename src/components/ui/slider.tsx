/**
 * 简单的滑块组件
 */

import React, { useRef, useCallback } from 'react'

interface SliderProps {
  value: number[]
  max: number
  min?: number
  step?: number
  onValueChange: (value: number[]) => void
  className?: string
}

export function Slider({ 
  value, 
  max, 
  min = 0, 
  step = 1, 
  onValueChange, 
  className = '' 
}: SliderProps) {
  const sliderRef = useRef<HTMLDivElement>(null)

  const handleMouseDown = useCallback((e: React.MouseEvent) => {
    const updateValue = (clientX: number) => {
      if (!sliderRef.current) return

      const rect = sliderRef.current.getBoundingClientRect()
      const percentage = Math.max(0, Math.min(1, (clientX - rect.left) / rect.width))
      const newValue = min + percentage * (max - min)
      const steppedValue = Math.round(newValue / step) * step
      
      onValueChange([Math.max(min, Math.min(max, steppedValue))])
    }

    updateValue(e.clientX)

    const handleMouseMove = (e: MouseEvent) => {
      updateValue(e.clientX)
    }

    const handleMouseUp = () => {
      document.removeEventListener('mousemove', handleMouseMove)
      document.removeEventListener('mouseup', handleMouseUp)
    }

    document.addEventListener('mousemove', handleMouseMove)
    document.addEventListener('mouseup', handleMouseUp)
  }, [max, min, step, onValueChange])

  const percentage = max > 0 ? ((value[0] - min) / (max - min)) * 100 : 0

  return (
    <div
      ref={sliderRef}
      className={`relative h-2 bg-gray-300 rounded-full cursor-pointer ${className}`}
      onMouseDown={handleMouseDown}
    >
      {/* 进度条 */}
      <div
        className="absolute top-0 left-0 h-full bg-blue-500 rounded-full"
        style={{ width: `${percentage}%` }}
      />
      
      {/* 滑块把手 */}
      <div
        className="absolute top-1/2 w-4 h-4 bg-white border-2 border-blue-500 rounded-full transform -translate-y-1/2 cursor-pointer shadow-md"
        style={{ left: `calc(${percentage}% - 8px)` }}
      />
    </div>
  )
}
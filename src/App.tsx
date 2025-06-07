import React from 'react'
import { ThemeProvider } from '@/components/theme-provider'
import { Toaster } from '@/components/ui/toaster'
import AppRouter from './router'

function App() {
  console.log('App 组件正在渲染')
  
  return (
    <ThemeProvider attribute="class" defaultTheme="dark" enableSystem disableTransitionOnChange>
      <div className="app-wrapper">
        <AppRouter />
        <Toaster />
      </div>
    </ThemeProvider>
  )
}

export default App
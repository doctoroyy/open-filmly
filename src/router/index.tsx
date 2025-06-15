import React from 'react'
import { createBrowserRouter, RouterProvider } from 'react-router-dom'
import { generateRoutes } from './generator'

// 生成约定式路由
const routes = generateRoutes()

// 创建路由器，添加根级错误处理
const router = createBrowserRouter(routes, {
  future: {
    v7_normalizeFormMethod: true,
  },
})

// 路由提供者组件
export function AppRouter() {
  try {
    return <RouterProvider router={router} />
  } catch (error) {
    console.error('[AppRouter] Router error:', error)
    return (
      <div className="min-h-screen bg-background flex items-center justify-center p-8">
        <div className="text-center">
          <h1 className="text-2xl font-bold mb-4">路由错误</h1>
          <p className="text-muted-foreground mb-4">应用程序路由系统遇到错误</p>
          <button 
            onClick={() => window.location.reload()} 
            className="px-4 py-2 bg-primary text-primary-foreground rounded"
          >
            重新加载
          </button>
        </div>
      </div>
    )
  }
}

export default AppRouter
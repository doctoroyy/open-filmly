import React from 'react'
import { createBrowserRouter, RouterProvider } from 'react-router-dom'
import { generateRoutes } from './generator'

// 生成约定式路由
const routes = generateRoutes()

// 创建路由器
const router = createBrowserRouter(routes)

// 路由提供者组件
export function AppRouter() {
  return <RouterProvider router={router} />
}

export default AppRouter
import React from 'react'
import { RouteObject } from 'react-router-dom'

// 动态导入所有页面组件
const modules = import.meta.glob('../pages/**/*.tsx', { eager: true })

interface RouteModule {
  default: React.ComponentType<any>
}

function generateRoutes(): RouteObject[] {
  const routes: RouteObject[] = []
  
  Object.entries(modules).forEach(([path, module]) => {
    const routeModule = module as RouteModule
    
    // 转换文件路径为路由路径
    let routePath = path
      .replace('../pages', '')
      .replace(/\.tsx$/, '')
      .replace(/\/index$/, '')
      .replace(/\[(\w+)\]/g, ':$1') // [id] -> :id
    
    // 根路径处理
    if (routePath === '' || routePath === '/') {
      routePath = '/'
    }
    
    routes.push({
      path: routePath,
      element: React.createElement(routeModule.default)
    })
  })
  
  // 按路径长度排序，确保动态路由在后面
  routes.sort((a, b) => {
    const aPath = a.path || ''
    const bPath = b.path || ''
    
    // 静态路由优先于动态路由
    const aIsDynamic = aPath.includes(':')
    const bIsDynamic = bPath.includes(':')
    
    if (aIsDynamic && !bIsDynamic) return 1
    if (!aIsDynamic && bIsDynamic) return -1
    
    return aPath.length - bPath.length
  })
  
  return routes
}

export { generateRoutes }
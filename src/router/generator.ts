import React from 'react'
import { RouteObject } from 'react-router-dom'

// 动态导入所有页面组件
const modules = import.meta.glob('../pages/**/*.tsx', { eager: true })

interface RouteModule {
  default: React.ComponentType<any>
}

function generateRoutes(): RouteObject[] {
  const routes: RouteObject[] = []
  
  try {
    Object.entries(modules).forEach(([path, module]) => {
      try {
        const routeModule = module as RouteModule
        
        // 验证模块是否有默认导出
        if (!routeModule || !routeModule.default) {
          console.warn(`[Router] No default export found for: ${path}`)
          return
        }
        
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
        
        console.log(`[Router] Registering route: ${routePath} from ${path}`)
        
        routes.push({
          path: routePath,
          element: React.createElement(routeModule.default),
          errorElement: React.createElement('div', { 
            className: 'p-8 text-center' 
          }, 'Page failed to load')
        })
      } catch (error) {
        console.error(`[Router] Error processing route ${path}:`, error)
      }
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
    
    console.log(`[Router] Generated ${routes.length} routes:`, routes.map(r => r.path))
    
  } catch (error) {
    console.error('[Router] Error generating routes:', error)
  }
  
  return routes
}

export { generateRoutes }
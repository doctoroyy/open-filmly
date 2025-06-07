import { Hono } from 'hono'
import { serve } from '@hono/node-server'
import { serveStatic } from '@hono/node-server/serve-static'
import path from 'path'
import fs from 'fs'

export function createProductionServer(port: number = 3000) {
  const app = new Hono()
  
  // 静态文件服务 - 服务 dist/renderer 目录
  const staticPath = path.join(__dirname, '../renderer')
  
  // 服务静态资源
  app.use('/assets/*', serveStatic({ root: staticPath }))
  
  // 对于所有其他路由，返回 index.html (SPA 路由支持)
  app.get('*', async (c) => {
    const indexPath = path.join(staticPath, 'index.html')
    
    try {
      const html = fs.readFileSync(indexPath, 'utf-8')
      return c.html(html)
    } catch (error) {
      console.error('Failed to read index.html:', error)
      return c.text('Internal Server Error', 500)
    }
  })
  
  return {
    app,
    start: () => {
      return serve({
        fetch: app.fetch,
        port,
      })
    }
  }
}
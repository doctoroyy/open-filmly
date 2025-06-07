import React from 'react'

export default function TestPage() {
  return (
    <div className="min-h-screen bg-background p-8">
      <h1 className="text-4xl font-bold text-foreground">测试页面</h1>
      <p className="mt-4 text-lg text-muted-foreground">
        如果你能看到这个页面，说明路由系统正常工作！
      </p>
      <div className="mt-8 p-4 bg-card border rounded-lg">
        <h2 className="text-xl font-semibold mb-2">路由测试成功</h2>
        <p>约定式路由正常工作</p>
      </div>
    </div>
  )
}
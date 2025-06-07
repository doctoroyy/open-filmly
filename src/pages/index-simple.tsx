import React from 'react'
import { Link } from 'react-router-dom'

export default function SimpleHomePage() {
  return (
    <div className="min-h-screen bg-gray-900 text-white p-8">
      <h1 className="text-4xl font-bold mb-8">Open Filmly</h1>
      <div className="space-y-4">
        <div className="p-4 bg-gray-800 rounded-lg">
          <h2 className="text-xl font-semibold mb-2">应用已成功启动！</h2>
          <p>Vite + React Router 架构已完成</p>
        </div>
        
        <div className="flex gap-4">
          <Link to="/movies" className="px-4 py-2 bg-blue-600 rounded hover:bg-blue-700">
            电影页面
          </Link>
          <Link to="/tv" className="px-4 py-2 bg-green-600 rounded hover:bg-green-700">
            电视剧页面
          </Link>
          <Link to="/config" className="px-4 py-2 bg-purple-600 rounded hover:bg-purple-700">
            配置页面
          </Link>
          <Link to="/test" className="px-4 py-2 bg-yellow-600 rounded hover:bg-yellow-700">
            测试页面
          </Link>
        </div>
        
        <div className="mt-8 p-4 bg-gray-800 rounded-lg">
          <h3 className="text-lg font-semibold mb-2">技术栈</h3>
          <ul className="list-disc list-inside space-y-1">
            <li>React 18 + TypeScript</li>
            <li>Vite (构建工具)</li>
            <li>React Router v6 (约定式路由)</li>
            <li>Electron</li>
            <li>Tailwind CSS</li>
          </ul>
        </div>
      </div>
    </div>
  )
}
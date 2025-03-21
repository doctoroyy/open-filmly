"use client"

import type React from "react"

import { useState, useEffect } from "react"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from "@/components/ui/card"
import { useToast } from "@/components/ui/use-toast"
import { ArrowLeft } from "lucide-react"
import Link from "next/link"

interface SambaConfig {
  ip: string
  moviePath: string
  tvPath: string
}

export default function ConfigPage() {
  const [config, setConfig] = useState<SambaConfig>({
    ip: "",
    moviePath: "movies",
    tvPath: "tv",
  })
  const [loading, setLoading] = useState(false)
  const { toast } = useToast()

  useEffect(() => {
    // 获取当前配置
    const fetchConfig = async () => {
      try {
        const config = await window.electronAPI.getConfig()

        if (config) {
          setConfig({
            ip: config.ip || "",
            moviePath: config.moviePath || "movies",
            tvPath: config.tvPath || "tv",
          })
        }
      } catch (error) {
        console.error("Error fetching configuration:", error)
        toast({
          title: "加载失败",
          description: "无法加载配置",
          variant: "destructive",
        })
      }
    }

    fetchConfig()
  }, [])

  const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const { name, value } = e.target
    setConfig((prev) => ({ ...prev, [name]: value }))
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setLoading(true)

    try {
      const result = await window.electronAPI.saveConfig(config)

      if (result.success) {
        toast({
          title: "配置已更新",
          description: "Samba 连接配置已成功更新。",
        })
      } else {
        toast({
          title: "更新失败",
          description: result.error || "无法更新配置。",
          variant: "destructive",
        })
      }
    } catch (error) {
      console.error("Error updating configuration:", error)
      toast({
        title: "更新失败",
        description: "发生错误，无法更新配置。",
        variant: "destructive",
      })
    } finally {
      setLoading(false)
    }
  }

  return (
    <main className="min-h-screen bg-black text-white">
      <div className="container mx-auto px-4 py-8">
        <div className="flex items-center mb-8">
          <Link href="/">
            <Button variant="ghost" size="icon" className="mr-2">
              <ArrowLeft className="h-5 w-5" />
              <span className="sr-only">返回</span>
            </Button>
          </Link>
          <h1 className="text-3xl font-bold">配置</h1>
        </div>

        <Card className="w-full max-w-md mx-auto bg-gray-900 border-gray-800">
          <CardHeader>
            <CardTitle>Samba 连接配置</CardTitle>
            <CardDescription>配置您的 Samba 共享连接详情</CardDescription>
          </CardHeader>
          <form onSubmit={handleSubmit}>
            <CardContent className="space-y-4">
              <div className="space-y-2">
                <Label htmlFor="ip">Samba 服务器 IP</Label>
                <Input
                  id="ip"
                  name="ip"
                  placeholder="192.168.31.100"
                  value={config.ip}
                  onChange={handleChange}
                  required
                  className="bg-gray-800 border-gray-700"
                />
              </div>

              <div className="space-y-2">
                <Label htmlFor="moviePath">电影路径</Label>
                <Input
                  id="moviePath"
                  name="moviePath"
                  placeholder="movies"
                  value={config.moviePath}
                  onChange={handleChange}
                  className="bg-gray-800 border-gray-700"
                />
                <p className="text-sm text-gray-400">默认为 "movies"</p>
              </div>

              <div className="space-y-2">
                <Label htmlFor="tvPath">电视剧路径</Label>
                <Input
                  id="tvPath"
                  name="tvPath"
                  placeholder="tv"
                  value={config.tvPath}
                  onChange={handleChange}
                  className="bg-gray-800 border-gray-700"
                />
                <p className="text-sm text-gray-400">默认为 "tv"</p>
              </div>
            </CardContent>
            <CardFooter>
              <Button type="submit" disabled={loading} className="w-full">
                {loading ? "保存中..." : "保存配置"}
              </Button>
            </CardFooter>
          </form>
        </Card>
      </div>
    </main>
  )
}


"use client"

import type React from "react"

import { useState, useEffect } from "react"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from "@/components/ui/card"
import { toast } from "@/components/ui/use-toast"

interface SambaConfig {
  ip: string
  moviePath?: string
  tvPath?: string
}

export function ConfigForm() {
  const [config, setConfig] = useState<SambaConfig>({
    ip: "",
    moviePath: "movies",
    tvPath: "tv",
  })
  const [loading, setLoading] = useState(false)

  useEffect(() => {
    // 获取当前配置
    const fetchConfig = async () => {
      try {
        const response = await fetch("/api/config")
        const data = await response.json()

        setConfig((prev) => ({
          ...prev,
          ip: data.ip || "",
          moviePath: data.moviePath || "movies",
          tvPath: data.tvPath || "tv",
        }))
      } catch (error) {
        console.error("Error fetching configuration:", error)
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
      const response = await fetch("/api/config", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify(config),
      })

      const data = await response.json()

      if (data.success) {
        toast({
          title: "配置已更新",
          description: "Samba 连接配置已成功更新。",
        })
      } else {
        toast({
          title: "更新失败",
          description: data.error || "无法更新配置。",
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
    <Card className="w-full max-w-md mx-auto">
      <CardHeader>
        <CardTitle>Samba 连接配置</CardTitle>
        <CardDescription>配置您的 Samba 共享连接详情</CardDescription>
      </CardHeader>
      <form onSubmit={handleSubmit}>
        <CardContent className="space-y-4">
          <div className="space-y-2">
            <Label htmlFor="ip">Samba 服务器 IP</Label>
            <Input id="ip" name="ip" placeholder="192.168.31.100" value={config.ip} onChange={handleChange} required />
          </div>

          <div className="space-y-2">
            <Label htmlFor="moviePath">电影路径</Label>
            <Input
              id="moviePath"
              name="moviePath"
              placeholder="movies"
              value={config.moviePath}
              onChange={handleChange}
            />
            <p className="text-sm text-muted-foreground">默认为 "movies"</p>
          </div>

          <div className="space-y-2">
            <Label htmlFor="tvPath">电视剧路径</Label>
            <Input id="tvPath" name="tvPath" placeholder="tv" value={config.tvPath} onChange={handleChange} />
            <p className="text-sm text-muted-foreground">默认为 "tv"</p>
          </div>
        </CardContent>
        <CardFooter>
          <Button type="submit" disabled={loading}>
            {loading ? "保存中..." : "保存配置"}
          </Button>
        </CardFooter>
      </form>
    </Card>
  )
}


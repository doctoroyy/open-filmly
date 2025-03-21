"use client"

import { useState } from "react"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from "@/components/ui/card"
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert"
import { Info } from "lucide-react"

export function LocalNetworkInfo() {
  const [showDetails, setShowDetails] = useState(false)

  return (
    <Card className="w-full max-w-md mx-auto">
      <CardHeader>
        <CardTitle>本地网络访问</CardTitle>
        <CardDescription>关于访问本地网络上的Samba共享的信息</CardDescription>
      </CardHeader>
      <CardContent>
        <Alert className="bg-blue-50 border-blue-200 mb-4">
          <Info className="h-4 w-4 text-blue-600" />
          <AlertTitle className="text-blue-800">关于本地网络访问</AlertTitle>
          <AlertDescription className="text-blue-700">
            由于浏览器安全限制，网页无法直接访问本地网络上的Samba共享。
            但您可以通过点击海报来尝试使用系统默认的媒体播放器打开文件。
          </AlertDescription>
        </Alert>

        {showDetails && (
          <div className="space-y-4 mt-4">
            <div className="border rounded-md p-4">
              <h3 className="font-medium mb-2">如何播放媒体文件</h3>
              <ol className="text-sm text-muted-foreground space-y-2 ml-4 list-decimal">
                <li>点击您想要播放的电影或电视剧海报</li>
                <li>系统将尝试使用默认媒体播放器打开文件</li>
                <li>如果自动打开失败，您可能需要手动配置系统以处理SMB链接</li>
              </ol>
            </div>

            <div className="border rounded-md p-4">
              <h3 className="font-medium mb-2">配置SMB协议处理</h3>
              <p className="text-sm text-muted-foreground mb-2">不同操作系统配置SMB协议处理的方式不同：</p>
              <ul className="text-sm text-muted-foreground space-y-2 ml-4 list-disc">
                <li>
                  <strong>Windows:</strong> 通常已配置好SMB协议处理
                </li>
                <li>
                  <strong>macOS:</strong> 在Finder中使用"连接到服务器"(⌘K)并输入smb://您的IP地址
                </li>
                <li>
                  <strong>Linux:</strong> 安装并配置适当的SMB客户端，如smbclient或Nautilus的SMB支持
                </li>
              </ul>
            </div>
          </div>
        )}
      </CardContent>
      <CardFooter>
        <Button variant="outline" onClick={() => setShowDetails(!showDetails)} className="w-full">
          {showDetails ? "隐藏详细信息" : "显示详细信息"}
        </Button>
      </CardFooter>
    </Card>
  )
}


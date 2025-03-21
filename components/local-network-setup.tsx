"use client"

import { useState, useEffect } from "react"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from "@/components/ui/card"
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert"
import { AlertCircle, CheckCircle2, Download } from "lucide-react"

export function LocalNetworkSetup() {
  const [hasLocalApp, setHasLocalApp] = useState<boolean | null>(null)
  const [isChecking, setIsChecking] = useState(false)

  // 检查本地应用是否已安装
  const checkLocalApp = async () => {
    setIsChecking(true)

    try {
      // 在实际实现中，这里会检测本地应用是否可用
      // 例如，尝试连接到本地应用的WebSocket服务器

      // 模拟检测过程
      await new Promise((resolve) => setTimeout(resolve, 1000))

      // 随机结果，实际应用中应该是真实检测结果
      const isInstalled = false
      setHasLocalApp(isInstalled)
    } catch (error) {
      console.error("Error checking local app:", error)
      setHasLocalApp(false)
    } finally {
      setIsChecking(false)
    }
  }

  useEffect(() => {
    checkLocalApp()
  }, [])

  return (
    <Card className="w-full max-w-md mx-auto">
      <CardHeader>
        <CardTitle>本地网络访问</CardTitle>
        <CardDescription>要访问本地网络上的Samba共享，您需要安装本地桥接应用</CardDescription>
      </CardHeader>
      <CardContent>
        {hasLocalApp === null ? (
          <div className="flex justify-center py-4">
            <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary"></div>
          </div>
        ) : hasLocalApp ? (
          <Alert className="bg-green-50 border-green-200">
            <CheckCircle2 className="h-4 w-4 text-green-600" />
            <AlertTitle className="text-green-800">已安装本地应用</AlertTitle>
            <AlertDescription className="text-green-700">
              本地桥接应用已安装并正在运行。您可以访问本地网络上的Samba共享。
            </AlertDescription>
          </Alert>
        ) : (
          <>
            <Alert className="bg-amber-50 border-amber-200 mb-4">
              <AlertCircle className="h-4 w-4 text-amber-600" />
              <AlertTitle className="text-amber-800">需要安装本地应用</AlertTitle>
              <AlertDescription className="text-amber-700">
                要访问本地网络上的Samba共享，您需要安装我们的本地桥接应用。
              </AlertDescription>
            </Alert>

            <div className="space-y-4">
              <div className="border rounded-md p-4">
                <h3 className="font-medium mb-2">为什么需要本地应用？</h3>
                <p className="text-sm text-muted-foreground">
                  出于安全原因，Web浏览器不允许网页直接访问本地网络资源。
                  我们的本地桥接应用可以安全地连接您的浏览器和本地网络上的Samba共享。
                </p>
              </div>

              <div className="border rounded-md p-4">
                <h3 className="font-medium mb-2">如何安装</h3>
                <ol className="text-sm text-muted-foreground space-y-2 ml-4 list-decimal">
                  <li>下载适用于您操作系统的安装包</li>
                  <li>运行安装程序并按照提示操作</li>
                  <li>安装完成后，刷新此页面</li>
                </ol>
              </div>
            </div>
          </>
        )}
      </CardContent>
      <CardFooter className="flex justify-between">
        {!hasLocalApp && (
          <Button className="w-full">
            <Download className="mr-2 h-4 w-4" />
            下载本地桥接应用
          </Button>
        )}
        {hasLocalApp && (
          <Button variant="outline" onClick={checkLocalApp} disabled={isChecking}>
            {isChecking ? "检查中..." : "重新检查"}
          </Button>
        )}
      </CardFooter>
    </Card>
  )
}


"use client"

import type React from "react"

import { useState, useEffect } from "react"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from "@/components/ui/card"
import { useToast } from "@/components/ui/use-toast"
import { ArrowLeft, Check, Loader2, RefreshCw, Folder, X } from "lucide-react"
import Link from "next/link"
import { Checkbox } from "@/components/ui/checkbox"
import type { SambaConfig } from "@/types/electron"
import { SMBFileBrowser } from "@/components/ui/smb-file-browser"

interface ShareSelection {
  name: string
  selected: boolean
}

export default function ConfigPage() {
  const [step, setStep] = useState<"connect" | "select" | "complete">("connect")
  const [config, setConfig] = useState<SambaConfig>({
    ip: "",
    port: 445,
    username: "guest",
    password: "",
  })
  const [shares, setShares] = useState<ShareSelection[]>([])
  const [loading, setLoading] = useState(false)
  const [discoveringShares, setDiscoveringShares] = useState(false)
  const [manualShareInput, setManualShareInput] = useState(false)
  const [showFileBrowser, setShowFileBrowser] = useState(false)
  const [selectedFolders, setSelectedFolders] = useState<string[]>([])
  const [currentBrowsePath, setCurrentBrowsePath] = useState<string>("/")
  const { toast } = useToast()

  useEffect(() => {
    // 获取当前配置
    const fetchConfig = async () => {
      try {
        const config = await window.electronAPI?.getConfig()

        if (config) {
          setConfig({
            ip: config.ip || "",
            port: config.port || 445,
            username: config.username || "guest",
            password: config.password || "",
          })
          
          // 加载选定的文件夹
          if (config.selectedFolders && Array.isArray(config.selectedFolders)) {
            setSelectedFolders(config.selectedFolders);
          }
          
          // 如果已经有配置，显示连接页面
          if (config.ip) {
            setStep("connect")
          }
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
  
  const handleConnect = async (e: React.FormEvent) => {
    e.preventDefault()
    setLoading(true)

    try {
      // 连接到服务器
      const connectionResult = await window.electronAPI?.connectServer(config)

      if (connectionResult?.success) {
        // 检查是否需要选择共享
        if (connectionResult.needShareSelection && connectionResult.shares) {
          // 转换为选择列表
          const sharesList: ShareSelection[] = connectionResult.shares.map((share: string) => ({
            name: share,
            selected: false
          }))
          
          // 默认选择第一个共享
          if (sharesList.length > 0) {
            sharesList[0].selected = true
          }
          
          setShares(sharesList)
          setStep("select")
          
          toast({
            title: "连接成功",
            description: `已连接到服务器并发现 ${sharesList.length} 个共享`,
          })
        } else {
          // 未知情况
          toast({
            title: "连接成功",
            description: "已连接到服务器，但未能获取共享列表",
          })
          setStep("complete")
        }
      } else {
        // 连接失败
        toast({
          title: "连接失败",
          description: connectionResult?.error || "无法连接到服务器。",
          variant: "destructive",
        })
      }
    } catch (error) {
      console.error("Error connecting to server:", error)
      toast({
        title: "连接失败",
        description: "发生错误，无法连接到服务器。",
        variant: "destructive",
      })
    } finally {
      setLoading(false)
    }
  }
  
  const handleAutoSaveConfig = async () => {
    try {
      // 自动保存配置
      const result = await window.electronAPI?.saveConfig(config)

      if (result?.success) {
        toast({
          title: "配置已更新",
          description: "Samba 连接配置已成功更新。",
        })
        setStep("complete")
      } else {
        toast({
          title: "更新失败",
          description: result?.error || "无法更新配置。",
          variant: "destructive",
        })
      }
    } catch (error) {
      console.error("Error saving configuration:", error)
      toast({
        title: "更新失败",
        description: "发生错误，无法更新配置。",
        variant: "destructive",
      })
    }
  }
  
  const handleShareSelect = (index: number) => {
    setShares(prev => {
      const newShares = [...prev]
      
      // 取消其他所有选择
      newShares.forEach((share, i) => {
        newShares[i].selected = i === index
      })
      
      return newShares
    })
  }
  
  const handleFolderSelection = (paths: string[]) => {
    // 合并现有选择的文件夹和新选择的文件夹
    const newSelectedFolders = [...selectedFolders];
    
    paths.forEach(path => {
      if (!newSelectedFolders.includes(path)) {
        newSelectedFolders.push(path);
      }
    });
    
    setSelectedFolders(newSelectedFolders);
    setShowFileBrowser(false);
    
    toast({
      title: "文件夹已选择",
      description: `已选择 ${paths.length} 个文件夹`,
    });
  }
  
  const handleCancelFolderSelection = () => {
    setShowFileBrowser(false)
  }
  
  const openFileBrowser = () => {
    // 确保有选中的共享
    const selectedShare = shares.find(share => share.selected)
    if (!selectedShare) {
      toast({
        title: "请先选择共享",
        description: "请先选择一个共享后再浏览文件夹",
        variant: "destructive",
      })
      return
    }
    
    setCurrentBrowsePath("/")
    setShowFileBrowser(true)
  }
  
  const handleSaveWithFolders = async () => {
    setLoading(true)

    try {
      // 获取选中的共享
      const selectedShare = shares.find(share => share.selected)
      
      if (!selectedShare) {
        toast({
          title: "未选择共享",
          description: "请选择一个共享文件夹或手动输入共享名称。",
          variant: "destructive",
        })
        setLoading(false)
        return
      }
      
      // 更新配置
      const updatedConfig = {
        ...config,
        sharePath: selectedShare.name,
        selectedFolders: selectedFolders.length > 0 ? selectedFolders : undefined,
      }
      
      // 更新当前配置
      setConfig(updatedConfig)
      
      // 保存配置
      const result = await window.electronAPI?.saveConfig(updatedConfig)

      if (result?.success) {
        toast({
          title: "配置已更新",
          description: "Samba 连接配置已成功更新。",
        })
        setStep("complete")
      } else {
        toast({
          title: "更新失败",
          description: result?.error || "无法更新配置。",
          variant: "destructive",
        })
      }
    } catch (error) {
      console.error("Error saving configuration:", error)
      toast({
        title: "更新失败",
        description: "发生错误，无法更新配置。",
        variant: "destructive",
      })
    } finally {
      setLoading(false)
    }
  }
  
  const discoverShares = async () => {
    if (!config.ip || config.ip.trim() === "") {
      toast({
        title: "无法发现共享",
        description: "请先输入服务器IP地址",
        variant: "destructive",
      })
      return
    }
    
    setDiscoveringShares(true)
    
    try {
      // 连接服务器并获取共享列表
      const connectionResult = await window.electronAPI?.connectServer(config)
      
      if (connectionResult?.success && connectionResult.shares) {
        // 转换为选择列表
        const sharesList: ShareSelection[] = connectionResult.shares.map((share: string) => ({
          name: share,
          selected: false
        }))
        
        // 默认选择第一个共享
        if (sharesList.length > 0) {
          sharesList[0].selected = true
        }
        
        setShares(sharesList)
        setManualShareInput(false)
        
        toast({
          title: "发现共享",
          description: `已发现 ${sharesList.length} 个共享`,
        })
      } else {
        toast({
          title: "无法发现共享",
          description: connectionResult?.error || "服务器未返回共享列表",
          variant: "destructive",
        })
      }
    } catch (error) {
      console.error("Error discovering shares:", error)
      toast({
        title: "发现共享失败",
        description: "发生错误，无法发现共享",
        variant: "destructive",
      })
    } finally {
      setDiscoveringShares(false)
    }
  }
  
  const toggleManualShareInput = () => {
    setManualShareInput(!manualShareInput)
    if (!manualShareInput) {
      // 切换到手动输入模式，清除选择列表，添加一个手动输入项
      setShares([{ name: "", selected: true }])
    }
  }
  
  const handleManualShareNameChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const { value } = e.target
    setShares([{ name: value, selected: true }])
  }

  // 移除选定的文件夹
  const removeSelectedFolder = (folderToRemove: string) => {
    setSelectedFolders(prev => prev.filter(folder => folder !== folderToRemove));
    
    toast({
      title: "文件夹已移除",
      description: `已从选择列表中移除文件夹`,
    });
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

        {step === "connect" && (
          <Card className="w-full max-w-md mx-auto bg-gray-900 border-gray-800">
            <CardHeader>
              <CardTitle>Samba 连接配置</CardTitle>
              <CardDescription>配置您的 Samba 共享连接详情</CardDescription>
            </CardHeader>
            <form onSubmit={handleConnect}>
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
                  />
                </div>
                
                <div className="space-y-2">
                  <Label htmlFor="port">端口（可选）</Label>
                  <Input
                    id="port"
                    name="port"
                    type="number"
                    placeholder="445"
                    value={config.port}
                    onChange={handleChange}
                  />
                </div>
                
                <div className="space-y-2">
                  <Label htmlFor="username">用户名（可选）</Label>
                  <Input
                    id="username"
                    name="username"
                    placeholder="guest"
                    value={config.username}
                    onChange={handleChange}
                  />
                </div>
                
                <div className="space-y-2">
                  <Label htmlFor="password">密码（可选）</Label>
                  <Input
                    id="password"
                    name="password"
                    type="password"
                    placeholder="留空为无密码"
                    value={config.password}
                    onChange={handleChange}
                  />
                </div>
                
                <div className="space-y-2">
                  <Label htmlFor="domain">域（可选）</Label>
                  <Input
                    id="domain"
                    name="domain"
                    placeholder="留空为无域"
                    value={config.domain}
                    onChange={handleChange}
                  />
                </div>
                
                <p className="text-sm text-gray-400 mt-4">
                  输入服务器IP地址和凭据后，应用将自动发现可用的共享文件夹供您选择
                </p>

              </CardContent>
              <CardFooter>
                <Button type="submit" className="w-full" disabled={loading}>
                  {loading ? (
                    <>
                      <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                      连接中...
                    </>
                  ) : "连接并发现共享"}
                </Button>
              </CardFooter>
            </form>
          </Card>
        )}

        {step === "select" && (
          <Card className="w-full max-w-md mx-auto bg-gray-900 border-gray-800">
            <CardHeader>
              <CardTitle>选择媒体共享</CardTitle>
              <CardDescription>选择您要浏览的共享文件夹</CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
              {shares.length === 0 ? (
                <div className="text-center space-y-4">
                  <p className="text-gray-400">没有发现可用的共享</p>
                  <Button 
                    onClick={discoverShares} 
                    variant="outline"
                    disabled={discoveringShares}
                  >
                    {discoveringShares ? (
                      <>
                        <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                        发现中...
                      </>
                    ) : (
                      <>
                        <RefreshCw className="mr-2 h-4 w-4" />
                        重新发现共享
                      </>
                    )}
                  </Button>
                </div>
              ) : manualShareInput ? (
                <div className="space-y-4">
                  <div className="space-y-2">
                    <Label htmlFor="manualShareName">手动输入共享名称</Label>
                    <Input 
                      id="manualShareName"
                      placeholder="例如: wd, media, share 等"
                      value={shares[0]?.name || ""}
                      onChange={handleManualShareNameChange}
                    />
                  </div>
                  <Button 
                    variant="link" 
                    onClick={toggleManualShareInput}
                    className="p-0 h-auto"
                  >
                    使用发现的共享列表
                  </Button>
                </div>
              ) : (
                <div className="space-y-4">
                  {shares.map((share, index) => (
                    <div key={share.name || index} className="flex items-center space-x-2 p-3 border border-gray-800 rounded-md">
                      <Checkbox 
                        id={`share-${index}`} 
                        checked={share.selected}
                        onCheckedChange={() => handleShareSelect(index)}
                      />
                      <Label htmlFor={`share-${index}`} className="text-md font-medium">
                        {share.name || "未命名共享"}
                      </Label>
                    </div>
                  ))}
                  <Button 
                    variant="link" 
                    onClick={toggleManualShareInput}
                    className="p-0 h-auto"
                  >
                    手动输入共享名称
                  </Button>
                </div>
              )}
              <p className="text-sm text-gray-400 mt-4">
                应用将自动扫描共享中的媒体文件并根据文件特征进行分类。
              </p>
              
              {/* 文件夹选择按钮 */}
              <div className="mt-4">
                <Button
                  variant="outline"
                  type="button"
                  onClick={openFileBrowser}
                  disabled={shares.filter(s => s.selected).length === 0}
                  className="mb-2"
                >
                  浏览和选择文件夹
                </Button>
                
                {selectedFolders.length > 0 && (
                  <div className="mt-2 p-2 border rounded-md">
                    <p className="text-sm font-medium mb-1">已选择 {selectedFolders.length} 个文件夹:</p>
                    <div className="max-h-32 overflow-y-auto">
                      {selectedFolders.map((folder, index) => (
                        <div key={index} className="text-sm text-muted-foreground truncate">
                          {folder}
                        </div>
                      ))}
                    </div>
                  </div>
                )}
              </div>
            </CardContent>
            
            {/* 文件浏览器弹窗 */}
            {showFileBrowser && (
              <div className="fixed inset-0 z-50 bg-background/80 flex items-center justify-center">
                <div className="w-full max-w-3xl p-4">
                  <h3 className="text-lg font-medium mb-2">选择文件夹</h3>
                  <p className="text-sm text-muted-foreground mb-4">
                    选择要扫描的文件夹。您可以选择多个文件夹。
                  </p>
                  <SMBFileBrowser
                    initialPath="/"
                    selectionMode={true}
                    onSelect={handleFolderSelection}
                    onCancel={handleCancelFolderSelection}
                  />
                </div>
              </div>
            )}
            
            <CardFooter className="flex justify-between">
              <Button 
                variant="outline" 
                onClick={() => setStep("connect")}
                disabled={loading}
              >
                返回
              </Button>
              <Button 
                onClick={handleSaveWithFolders}
                disabled={loading || (shares.filter(s => s.selected).length === 0 && !manualShareInput) || (manualShareInput && (!shares[0] || !shares[0].name))}
              >
                {loading ? (
                  <>
                    <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                    保存中...
                  </>
                ) : "保存选择"}
              </Button>
            </CardFooter>
          </Card>
        )}
        
        {step === "complete" && (
          <Card className="w-full max-w-md mx-auto bg-gray-900 border-gray-800">
            <CardHeader>
              <CardTitle>配置完成</CardTitle>
              <CardDescription>您的媒体服务器已成功配置</CardDescription>
            </CardHeader>
            <CardContent className="py-6 flex flex-col items-center justify-center">
              <div className="w-12 h-12 rounded-full bg-green-500 flex items-center justify-center mb-4">
                <Check className="h-6 w-6 text-white" />
              </div>
              <p className="text-center mb-2">服务器连接已配置完成</p>
              <p className="text-sm text-gray-400 text-center mb-2">
                现在您可以返回首页开始导入和浏览您的媒体内容
              </p>
              <p className="text-sm text-gray-400 text-center">
                应用程序将自动扫描共享中的媒体文件并根据文件特征将其分类为电影、电视剧或未知类型
              </p>
            </CardContent>
            <CardFooter>
              <Link href="/" className="w-full">
                <Button className="w-full">
                  返回首页
                </Button>
              </Link>
            </CardFooter>
          </Card>
        )}
      </div>
    </main>
  )
}


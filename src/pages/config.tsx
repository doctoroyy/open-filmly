import React, { useState, useEffect } from "react"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from "@/components/ui/card"
import { useToast } from "@/components/ui/use-toast"
import { ArrowLeft, Check, Loader2, RefreshCw, X } from "lucide-react"
import { Link } from "react-router-dom"
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
  const [showFileBrowser, setShowFileBrowser] = useState(false)
  const [selectedFolders, setSelectedFolders] = useState<string[]>([])
  const [clearingCache, setClearingCache] = useState(false)
  const [tmdbApiKey, setTmdbApiKey] = useState<string>("")
  const [savingApiKey, setSavingApiKey] = useState(false)
  const [hasTmdbApiKey, setHasTmdbApiKey] = useState(false)
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

        // 检查TMDB API密钥状态
        checkTmdbApiKey();
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

  // 检查TMDB API密钥
  const checkTmdbApiKey = async () => {
    try {
      const result = await window.electronAPI?.checkTmdbApi();
      if (result?.success) {
        setHasTmdbApiKey(result.hasApiKey);
      }
    } catch (error) {
      console.error("Error checking TMDB API key:", error);
    }
  }

  // 设置TMDB API密钥
  const handleSaveTmdbApiKey = async () => {
    if (!tmdbApiKey) {
      toast({
        title: "请输入API密钥",
        description: "TMDB API密钥不能为空",
        variant: "destructive",
      });
      return;
    }

    setSavingApiKey(true);
    try {
      const result = await window.electronAPI?.setTmdbApiKey(tmdbApiKey);
      if (result?.success) {
        setHasTmdbApiKey(true);
        toast({
          title: "API密钥已保存",
          description: "TMDB API密钥已成功保存",
        });
      } else {
        toast({
          title: "保存失败",
          description: result?.error || "无法保存TMDB API密钥",
          variant: "destructive",
        });
      }
    } catch (error) {
      console.error("Error saving TMDB API key:", error);
      toast({
        title: "保存失败",
        description: "发生错误，无法保存TMDB API密钥",
        variant: "destructive",
      });
    } finally {
      setSavingApiKey(false);
    }
  };

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

  const handleClearCache = async () => {
    setClearingCache(true)
    try {
      const result = await window.electronAPI?.clearMediaCache()
      
      if (result?.success) {
        toast({
          title: "缓存已清空",
          description: "媒体库缓存已成功清空，下次扫描将重新获取所有媒体数据。",
        })
      } else {
        toast({
          title: "清空缓存失败",
          description: result?.error || "无法清空缓存。",
          variant: "destructive",
        })
      }
    } catch (error) {
      console.error("清空缓存失败:", error)
      toast({
        title: "清空缓存失败",
        description: "发生错误，无法清空缓存。",
        variant: "destructive",
      })
    } finally {
      setClearingCache(false)
    }
  }

  const handleSelectShare = (shareIndex: number) => {
    setShares(prev => prev.map((share, index) => ({
      ...share,
      selected: index === shareIndex
    })))
  }

  const handleFinishConfiguration = async () => {
    try {
      const selectedShare = shares.find(share => share.selected)
      if (!selectedShare) {
        toast({
          title: "请选择共享",
          description: "请选择一个共享文件夹",
          variant: "destructive",
        })
        return
      }

      // 构建完整配置
      const finalConfig = {
        ...config,
        sharePath: selectedShare.name,
        selectedFolders: selectedFolders
      }

      // 保存配置到数据库
      const result = await window.electronAPI?.saveConfig(finalConfig)
      if (result?.success) {
        toast({
          title: "配置已保存",
          description: "Samba配置已成功保存",
        })
        setStep("complete")
      } else {
        toast({
          title: "保存失败",
          description: result?.error || "无法保存配置",
          variant: "destructive",
        })
      }
    } catch (error) {
      console.error("Error saving configuration:", error)
      toast({
        title: "保存失败",
        description: "发生错误，无法保存配置",
        variant: "destructive",
      })
    }
  }

  // 设置临时共享路径，用于文件浏览器
  const handleSelectShareAndSetup = async (shareIndex: number) => {
    handleSelectShare(shareIndex)
    
    const selectedShare = shares[shareIndex]
    if (selectedShare) {
      // 延迟保存配置，以便文件浏览器可以工作
      // 改进的SMB客户端现在应该正确处理连接管理
      const tempConfig = {
        ...config,
        sharePath: selectedShare.name
      }
      
      try {
        // 使用现有的保存配置API，但现在SMB客户端会正确断开旧连接
        await window.electronAPI?.saveConfig(tempConfig)
      } catch (error) {
        console.error("Error setting temporary config:", error)
      }
    }
  }

  return (
    <main className="min-h-screen bg-black text-white">
      <div className="container mx-auto px-4 py-8">
        <div className="flex items-center mb-8">
          <Link to="/">
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
          <div className="w-full max-w-4xl mx-auto space-y-6">
            <Card className="bg-gray-900 border-gray-800">
              <CardHeader>
                <CardTitle>选择共享文件夹</CardTitle>
                <CardDescription>选择要用于媒体扫描的共享文件夹</CardDescription>
              </CardHeader>
              <CardContent className="space-y-4">
                <div className="space-y-3">
                  {shares.map((share, index) => (
                    <div 
                      key={share.name} 
                      className="flex items-center space-x-3 p-3 rounded-lg border border-gray-700 hover:border-gray-600 cursor-pointer"
                      onClick={() => handleSelectShareAndSetup(index)}
                    >
                      <Checkbox 
                        checked={share.selected} 
                        onChange={() => handleSelectShareAndSetup(index)}
                      />
                      <div className="flex-1">
                        <p className="font-medium">{share.name}</p>
                        <p className="text-sm text-gray-400">SMB共享文件夹</p>
                      </div>
                    </div>
                  ))}
                </div>
                
                <div className="mt-4 p-3 bg-gray-800 rounded-lg">
                  <p className="text-sm text-gray-300 mb-2">
                    配置信息：
                  </p>
                  <div className="text-xs text-gray-400 space-y-1">
                    <p>服务器: {config.ip}:{config.port}</p>
                    <p>用户名: {config.username || "guest"}</p>
                    <p>已发现 {shares.length} 个共享</p>
                  </div>
                </div>

                {shares.some(share => share.selected) && (
                  <div className="mt-4">
                    <div className="flex items-center justify-between mb-2">
                      <p className="text-sm text-gray-300">选择要扫描的文件夹（可选）：</p>
                      <Button 
                        variant="outline" 
                        size="sm"
                        onClick={() => setShowFileBrowser(!showFileBrowser)}
                      >
                        {showFileBrowser ? "隐藏" : "浏览文件夹"}
                      </Button>
                    </div>
                    
                    {selectedFolders.length > 0 && (
                      <div className="mb-3">
                        <p className="text-xs text-gray-400 mb-2">已选择的文件夹：</p>
                        <div className="flex flex-wrap gap-2">
                          {selectedFolders.map((folder, index) => (
                            <span 
                              key={index}
                              className="inline-flex items-center px-2 py-1 rounded text-xs bg-blue-500/20 text-blue-300"
                            >
                              {folder}
                              <button
                                className="ml-1 hover:text-red-300"
                                onClick={() => setSelectedFolders(prev => prev.filter((_, i) => i !== index))}
                              >
                                ×
                              </button>
                            </span>
                          ))}
                        </div>
                      </div>
                    )}
                  </div>
                )}
              </CardContent>
              <CardFooter className="flex gap-2">
                <Button 
                  variant="outline" 
                  onClick={() => setStep("connect")}
                  className="flex-1"
                >
                  返回
                </Button>
                <Button 
                  onClick={handleFinishConfiguration}
                  className="flex-1"
                >
                  完成配置
                </Button>
              </CardFooter>
            </Card>

            {showFileBrowser && shares.some(share => share.selected) && (
              <Card className="bg-gray-900 border-gray-800">
                <CardHeader>
                  <CardTitle>浏览共享文件夹</CardTitle>
                  <CardDescription>选择要扫描的具体文件夹</CardDescription>
                </CardHeader>
                <CardContent>
                  <SMBFileBrowser
                    initialPath="/"
                    selectionMode={true}
                    selectedFolders={selectedFolders}
                    onSelect={(selectedPaths) => {
                      setSelectedFolders(selectedPaths)
                      setShowFileBrowser(false)
                      toast({
                        title: "文件夹已选择",
                        description: `已选择 ${selectedPaths.length} 个文件夹`,
                      })
                    }}
                    onCancel={() => setShowFileBrowser(false)}
                  />
                </CardContent>
              </Card>
            )}
          </div>
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
              <p className="text-center mb-2">🎉 配置完成！自动扫描已启动</p>
              <p className="text-sm text-gray-400 text-center mb-2">
                系统将自动发现和整理您的媒体文件，无需手动操作
              </p>
              <p className="text-sm text-gray-400 text-center">
                ✨ 右上角的状态图标显示扫描进度<br/>
                📽️ 扫描完成后媒体将自动分类显示
              </p>
            </CardContent>
            <CardFooter>
              <Link to="/" className="w-full">
                <Button className="w-full">
                  返回首页
                </Button>
              </Link>
            </CardFooter>
          </Card>
        )}

        {/* 返回和重置部分 */}
        <div className="mt-12 mb-8">
          <div className="flex gap-4 items-center">
            <Link to="/">
              <Button variant="outline">
                <ArrowLeft className="mr-2 h-4 w-4" />
                返回首页
              </Button>
            </Link>
            
            <Button 
              variant="outline" 
              onClick={handleClearCache}
              disabled={clearingCache}
            >
              <RefreshCw className={`mr-2 h-4 w-4 ${clearingCache ? "animate-spin" : ""}`} />
              清空媒体缓存
            </Button>
          </div>
          {/* 清空缓存说明 */}
          <p className="text-sm text-muted-foreground mt-2">
            清空媒体缓存将移除所有已扫描的媒体记录，下次扫描时将重新索引所有媒体文件。这不会删除您的媒体文件。
          </p>
        </div>

        {/* TMDB API密钥配置 */}
        <Card className="w-full max-w-md mx-auto mt-8 mb-8 bg-gray-900 border-gray-800">
          <CardHeader>
            <CardTitle>TMDB API配置</CardTitle>
            <CardDescription>配置TMDB电影数据库API密钥，用于获取电影和电视剧的封面和详情</CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="space-y-2">
              <Label htmlFor="tmdbApiKey">TMDB API密钥</Label>
              <Input
                id="tmdbApiKey"
                placeholder="输入您的TMDB API密钥"
                value={tmdbApiKey}
                onChange={(e) => setTmdbApiKey(e.target.value)}
              />
              <p className="text-xs text-muted-foreground">
                {hasTmdbApiKey ? (
                  <span className="text-green-500 flex items-center">
                    <Check className="h-3 w-3 mr-1" /> API密钥已配置
                  </span>
                ) : (
                  <span className="text-yellow-500 flex items-center">
                    <X className="h-3 w-3 mr-1" /> API密钥未配置
                  </span>
                )}
              </p>
            </div>
            <p className="text-sm text-gray-400">
              访问 <a href="https://www.themoviedb.org/settings/api" target="_blank" rel="noopener noreferrer" className="text-blue-400 hover:underline">TMDB API设置</a> 获取您的API密钥。API密钥用于获取电影和电视剧的封面图片和详细信息。
            </p>
          </CardContent>
          <CardFooter>
            <Button 
              onClick={handleSaveTmdbApiKey} 
              disabled={savingApiKey || !tmdbApiKey} 
              className="w-full"
            >
              {savingApiKey ? (
                <>
                  <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                  保存中...
                </>
              ) : "保存API密钥"}
            </Button>
          </CardFooter>
        </Card>
      </div>
    </main>
  )
}
import React, { useState, useEffect } from "react"
import { 
  Settings, 
  Wifi, 
  WifiOff, 
  Server, 
  HardDrive, 
  Film, 
  Key, 
  Trash2, 
  RefreshCw, 
  CheckCircle2, 
  XCircle, 
  AlertCircle, 
  ExternalLink, 
  Monitor, 
  Database, 
  Folder,
  ArrowLeft,
  Save,
  TestTube,
  Users,
  Shield,
  Zap,
  Activity,
  FolderOpen,
  CheckSquare
} from "lucide-react"
import { Link } from "react-router-dom"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { Tooltip, TooltipContent, TooltipProvider, TooltipTrigger } from "@/components/ui/tooltip"
import { useToast } from "@/components/ui/use-toast"
import { cn } from "@/lib/utils"
import type { SambaConfig } from "@/types/electron"
import { SMBFileBrowser } from "@/components/ui/smb-file-browser"

interface ConnectionStatus {
  connected: boolean
  server?: string
  shares?: string[]
  lastConnected?: string
  error?: string
}

interface SystemStats {
  mediaCount: number
  cacheSize: string
  apiUsage: number
  lastScan?: string
}

export default function ConfigPage() {
  // Connection state
  const [connectionStatus, setConnectionStatus] = useState<ConnectionStatus>({ connected: false })
  const [config, setConfig] = useState<SambaConfig>({
    host: "",
    port: 445,
    username: "guest", 
    password: "",
  })
  const [shares, setShares] = useState<string[]>([])
  const [selectedShares, setSelectedShares] = useState<string[]>([])
  const [selectedFolders, setSelectedFolders] = useState<string[]>([])
  
  // API state
  const [tmdbApiKey, setTmdbApiKey] = useState<string>("")
  const [hasTmdbApiKey, setHasTmdbApiKey] = useState(false)
  const [tmdbConnected, setTmdbConnected] = useState(false)
  
  // UI state
  const [connecting, setConnecting] = useState(false)
  const [savingConfig, setSavingConfig] = useState(false)
  const [savingApiKey, setSavingApiKey] = useState(false)
  const [testingApi, setTestingApi] = useState(false)
  const [clearingCache, setClearingCache] = useState(false)
  const [showFileBrowser, setShowFileBrowser] = useState(false)
  
  // System stats
  const [systemStats, setSystemStats] = useState<SystemStats>({
    mediaCount: 0,
    cacheSize: "0 MB",
    apiUsage: 0
  })
  
  const { toast } = useToast()

  useEffect(() => {
    loadCurrentConfig()
    loadSystemStats()
    checkTmdbStatus()
  }, [])

  const loadCurrentConfig = async () => {
    try {
      const config = await window.electronAPI?.getConfig()
      if (config) {
        setConfig({
          host: config.host || "",
          port: config.port || 445,
          username: config.username || "guest",
          password: config.password || "",
        })
        
        if (config.selectedFolders && Array.isArray(config.selectedFolders)) {
          setSelectedFolders(config.selectedFolders)
        }
        
        if (config.sharePaths && Array.isArray(config.sharePaths)) {
          setSelectedShares(config.sharePaths)
        } else if (config.sharePath) {
          // 兼容旧版本单个共享配置
          setSelectedShares([config.sharePath])
        }
        
        // Check connection status only if we have sufficient config
        if (config.host && config.host.trim() !== '') {
          // 只有在有主机地址配置时才尝试连接测试
          checkConnectionStatus(config).catch(error => {
            console.log("Initial connection check failed:", error)
            // 初始检查失败是正常的，不显示错误
          })
        }
      }
    } catch (error) {
      console.error("Error loading configuration:", error)
    }
  }

  const loadSystemStats = async () => {
    try {
      // 获取真实的媒体数量
      const mediaResult = await window.electronAPI?.getMedia("all")
      const mediaCount = Array.isArray(mediaResult) ? mediaResult.length : 0
      
      // 获取真实的缓存大小（这里需要实现一个API）
      // 暂时设为0，等待真实API
      const cacheSize = "0 MB"
      
      setSystemStats({
        mediaCount: mediaCount,
        cacheSize: cacheSize,
        apiUsage: 0, // 真实的API使用情况需要TMDB统计
        lastScan: "Unknown" // 需要从数据库获取上次扫描时间
      })
    } catch (error) {
      console.error("Error loading system stats:", error)
      // 失败时设置为0，不显示假数据
      setSystemStats({
        mediaCount: 0,
        cacheSize: "0 MB",
        apiUsage: 0,
        lastScan: "Unknown"
      })
    }
  }

  const checkTmdbStatus = async () => {
    try {
      const keyResult = await window.electronAPI?.getTmdbApiKey()
      if (keyResult?.success && keyResult.data?.apiKey) {
        setTmdbApiKey(keyResult.data.apiKey)
        setHasTmdbApiKey(true)
        
        // 真实测试API连接
        await testTmdbConnection(keyResult.data.apiKey)
      } else {
        setHasTmdbApiKey(false)
        setTmdbConnected(false)
      }
    } catch (error) {
      console.error("Error checking TMDB status:", error)
      setTmdbConnected(false)
    }
  }

  const testTmdbConnection = async (apiKey?: string) => {
    const keyToTest = apiKey || tmdbApiKey
    if (!keyToTest) return

    try {
      // 使用TMDB API测试端点进行真实连接测试
      const response = await fetch(`https://api.themoviedb.org/3/configuration?api_key=${keyToTest}`)
      if (response.ok) {
        setTmdbConnected(true)
      } else {
        setTmdbConnected(false)
      }
    } catch (error) {
      console.error("TMDB API test failed:", error)
      setTmdbConnected(false)
    }
  }

  const checkConnectionStatus = async (testConfig?: SambaConfig) => {
    const configToTest = testConfig || config
    try {
      // 使用真实的API调用来检查连接状态和获取共享列表
      const result = await window.electronAPI?.connectServer(configToTest)
      
      if (result?.success) {
        setConnectionStatus({
          connected: true,
          server: `${configToTest.host}:${configToTest.port}`,
          shares: result.shares || [],
          lastConnected: "Just now"
        })
        
        if (result.shares) {
          setShares(result.shares)
        }
      } else {
        setConnectionStatus({
          connected: false,
          error: result?.error || "Connection failed"
        })
      }
    } catch (error) {
      setConnectionStatus({
        connected: false,
        error: "Connection failed"
      })
    }
  }

  const handleDiscoverShares = async () => {
    setConnecting(true)
    try {
      console.log('使用Go SMB发现共享...')
      const result = await window.electronAPI?.goDiscoverShares(config)
      
      if (result?.success) {
        setConnectionStatus({
          connected: true,
          server: `${config.host}:${config.port}`,
          shares: result.shares || [],
          lastConnected: "Just now"
        })
        
        if (result.shares) {
          setShares(result.shares)
        }
        
        toast({
          title: "SMB发现成功",
          description: `发现了 ${result.shares?.length || 0} 个真实共享`,
        })
      } else {
        setConnectionStatus({
          connected: false,
          error: result?.error || "SMB发现失败"
        })
        
        toast({
          title: "SMB发现失败",
          description: result?.error || "无法发现共享",
          variant: "destructive",
        })

        // 如果是二进制文件不可用，显示详细信息
        if (result?.errorType === "binary_not_found" && result?.systemInfo) {
          console.error("Go SMB二进制文件信息:", result.systemInfo)
        }
      }
    } catch (error: any) {
      setConnectionStatus({
        connected: false,
        error: "网络错误"
      })
      
      toast({
        title: "连接错误", 
        description: "发生网络错误",
        variant: "destructive",
      })
    } finally {
      setConnecting(false)
    }
  }

  const handleBrowseShare = async () => {
    if (selectedShares.length === 0) {
      toast({
        title: "No Shares Selected",
        description: "Please select at least one share first before browsing",
        variant: "destructive",
      })
      return
    }

    // 配置SMB客户端使用选定的共享（兼容旧版本，使用第一个共享）
    const shareConfig = {
      ...config,
      sharePaths: selectedShares,
      sharePath: selectedShares[0]
    }

    try {
      // 保存配置到SMB客户端
      const result = await window.electronAPI?.saveConfig(shareConfig)
      if (result?.success) {
        setShowFileBrowser(!showFileBrowser)
      } else {
        toast({
          title: "Configuration Failed",
          description: "Failed to configure share path",
          variant: "destructive",
        })
      }
    } catch (error) {
      toast({
        title: "Configuration Error",
        description: "Error configuring share path",
        variant: "destructive",
      })
    }
  }

  const handleSaveConfig = async () => {
    setSavingConfig(true)
    try {
      const finalConfig = {
        ...config,
        sharePaths: selectedShares,
        // 兼容旧版本
        sharePath: selectedShares[0] || "",
        selectedFolders: selectedFolders
      }
      
      const result = await window.electronAPI?.saveConfig(finalConfig)
      if (result?.success) {
        toast({
          title: "Configuration Saved",
          description: "SMB configuration has been saved successfully",
        })
      } else {
        throw new Error(result?.error || "Failed to save configuration")
      }
    } catch (error) {
      toast({
        title: "Save Failed",
        description: error instanceof Error ? error.message : "Failed to save configuration",
        variant: "destructive",
      })
    } finally {
      setSavingConfig(false)
    }
  }

  const handleTestTmdbApi = async () => {
    if (!tmdbApiKey) return
    
    setTestingApi(true)
    try {
      await testTmdbConnection(tmdbApiKey)
      if (tmdbConnected) {
        toast({
          title: "API Test Successful",
          description: "TMDB API key is working correctly",
        })
      } else {
        toast({
          title: "API Test Failed",
          description: "Invalid or expired API key",
          variant: "destructive",
        })
      }
    } catch (error) {
      setTmdbConnected(false)
      toast({
        title: "API Test Failed", 
        description: "Failed to connect to TMDB API",
        variant: "destructive",
      })
    } finally {
      setTestingApi(false)
    }
  }

  const handleSaveTmdbApiKey = async () => {
    if (!tmdbApiKey) {
      toast({
        title: "API Key Required",
        description: "Please enter your TMDB API key",
        variant: "destructive",
      })
      return
    }

    setSavingApiKey(true)
    try {
      const result = await window.electronAPI?.setTmdbApiKey(tmdbApiKey)
      if (result?.success) {
        setHasTmdbApiKey(true)
        setTmdbConnected(true)
        toast({
          title: "API Key Saved",
          description: "TMDB API key has been saved successfully",
        })
      } else {
        throw new Error(result?.error || "Failed to save API key")
      }
    } catch (error) {
      toast({
        title: "Save Failed",
        description: error instanceof Error ? error.message : "Failed to save API key",
        variant: "destructive",
      })
    } finally {
      setSavingApiKey(false)
    }
  }

  const handleClearCache = async () => {
    setClearingCache(true)
    try {
      const result = await window.electronAPI?.clearMediaCache()
      
      if (result?.success) {
        toast({
          title: "Cache Cleared",
          description: "Media cache has been cleared successfully",
        })
        // Reload system stats
        loadSystemStats()
      } else {
        throw new Error(result?.error || "Failed to clear cache")
      }
    } catch (error) {
      toast({
        title: "Clear Failed",
        description: error instanceof Error ? error.message : "Failed to clear cache",
        variant: "destructive",
      })
    } finally {
      setClearingCache(false)
    }
  }

  const getStatusColor = (connected: boolean, error?: string) => {
    if (error) return "text-red-400"
    if (connected) return "text-green-400"
    return "text-gray-400"
  }

  const getStatusIcon = (connected: boolean, error?: string) => {
    if (error) return <XCircle className="h-4 w-4" />
    if (connected) return <CheckCircle2 className="h-4 w-4" />
    return <AlertCircle className="h-4 w-4" />
  }

  return (
    <TooltipProvider>
      <main className="min-h-screen bg-gradient-to-br from-gray-950 via-gray-900 to-black text-white">
        <div className="container mx-auto px-6 py-8">
          {/* Header */}
          <div className="flex items-center justify-between mb-8">
            <div className="flex items-center gap-4">
              <Link to="/">
                <Button variant="ghost" size="icon" className="hover:bg-white/10">
                  <ArrowLeft className="h-5 w-5" />
                </Button>
              </Link>
              <div>
                <h1 className="text-3xl font-bold bg-gradient-to-r from-white to-gray-300 bg-clip-text text-transparent">
                  Configuration Center
                </h1>
                <p className="text-gray-400 mt-1">Manage your media server settings</p>
              </div>
            </div>
            
            {/* Quick Actions */}
            <div className="flex items-center gap-3">
              <Tooltip>
                <TooltipTrigger asChild>
                  <Button 
                    variant="outline" 
                    size="icon" 
                    onClick={() => window.location.reload()}
                    className="border-gray-700 hover:border-gray-600"
                  >
                    <RefreshCw className="h-4 w-4" />
                  </Button>
                </TooltipTrigger>
                <TooltipContent>Refresh configuration</TooltipContent>
              </Tooltip>
              
              <Button onClick={handleSaveConfig} disabled={savingConfig} className="bg-blue-600 hover:bg-blue-700">
                <Save className="mr-2 h-4 w-4" />
                {savingConfig ? "Saving..." : "Save All"}
              </Button>
            </div>
          </div>

          {/* System Status Overview */}
          <div className="grid grid-cols-1 md:grid-cols-4 gap-4 mb-8">
            <Card className="bg-gray-800/50 border-gray-700 backdrop-blur-sm">
              <CardContent className="p-4">
                <div className="flex items-center gap-3">
                  <div className={cn("p-2 rounded-lg", connectionStatus.connected ? "bg-green-500/20" : "bg-red-500/20")}>
                    {connectionStatus.connected ? <Wifi className="h-4 w-4 text-green-400" /> : <WifiOff className="h-4 w-4 text-red-400" />}
                  </div>
                  <div>
                    <p className="text-sm text-gray-400">SMB Connection</p>
                    <p className={cn("font-medium", getStatusColor(connectionStatus.connected, connectionStatus.error))}>
                      {connectionStatus.connected ? "Connected" : "Disconnected"}
                    </p>
                  </div>
                </div>
              </CardContent>
            </Card>

            <Card className="bg-gray-800/50 border-gray-700 backdrop-blur-sm">
              <CardContent className="p-4">
                <div className="flex items-center gap-3">
                  <div className={cn("p-2 rounded-lg", tmdbConnected ? "bg-green-500/20" : "bg-yellow-500/20")}>
                    <Key className={cn("h-4 w-4", tmdbConnected ? "text-green-400" : "text-yellow-400")} />
                  </div>
                  <div>
                    <p className="text-sm text-gray-400">TMDB API</p>
                    <p className={cn("font-medium", tmdbConnected ? "text-green-400" : "text-yellow-400")}>
                      {tmdbConnected ? "Connected" : "Not Set"}
                    </p>
                  </div>
                </div>
              </CardContent>
            </Card>

            <Card className="bg-gray-800/50 border-gray-700 backdrop-blur-sm">
              <CardContent className="p-4">
                <div className="flex items-center gap-3">
                  <div className="p-2 bg-blue-500/20 rounded-lg">
                    <Film className="h-4 w-4 text-blue-400" />
                  </div>
                  <div>
                    <p className="text-sm text-gray-400">Media Library</p>
                    <p className="font-medium text-white">{systemStats.mediaCount} items</p>
                  </div>
                </div>
              </CardContent>
            </Card>

            <Card className="bg-gray-800/50 border-gray-700 backdrop-blur-sm">
              <CardContent className="p-4">
                <div className="flex items-center gap-3">
                  <div className="p-2 bg-purple-500/20 rounded-lg">
                    <Database className="h-4 w-4 text-purple-400" />
                  </div>
                  <div>
                    <p className="text-sm text-gray-400">Cache Size</p>
                    <p className="font-medium text-white">{systemStats.cacheSize}</p>
                  </div>
                </div>
              </CardContent>
            </Card>
          </div>

          {/* Main Configuration Tabs */}
          <Tabs defaultValue="network" className="w-full">
            <TabsList className="grid w-full grid-cols-4 bg-gray-800/50 border border-gray-700">
              <TabsTrigger value="network" className="data-[state=active]:bg-blue-600">
                <Server className="mr-2 h-4 w-4" />
                Network
              </TabsTrigger>
              <TabsTrigger value="media" className="data-[state=active]:bg-blue-600">
                <HardDrive className="mr-2 h-4 w-4" />
                Media
              </TabsTrigger>
              <TabsTrigger value="api" className="data-[state=active]:bg-blue-600">
                <Key className="mr-2 h-4 w-4" />
                APIs
              </TabsTrigger>
              <TabsTrigger value="system" className="data-[state=active]:bg-blue-600">
                <Settings className="mr-2 h-4 w-4" />
                System
              </TabsTrigger>
            </TabsList>

            {/* Network Configuration */}
            <TabsContent value="network" className="space-y-6">
              <Card className="bg-gray-800/30 border-gray-700 backdrop-blur-sm">
                <CardHeader>
                  <div className="flex items-center justify-between">
                    <div>
                      <CardTitle className="flex items-center gap-2">
                        <Server className="h-5 w-5" />
                        SMB/CIFS Connection
                      </CardTitle>
                      <CardDescription>Configure your network storage connection</CardDescription>
                    </div>
                    <div className="flex items-center gap-2">
                      {getStatusIcon(connectionStatus.connected, connectionStatus.error)}
                      <span className={cn("text-sm font-medium", getStatusColor(connectionStatus.connected, connectionStatus.error))}>
                        {connectionStatus.connected ? "Connected" : connectionStatus.error || "Not Connected"}
                      </span>
                    </div>
                  </div>
                </CardHeader>
                <CardContent className="space-y-6">
                  <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                    <div className="space-y-4">
                      <div className="space-y-2">
                        <Label htmlFor="ip" className="flex items-center gap-2">
                          <Monitor className="h-4 w-4" />
                          Server Host Address
                        </Label>
                        <Input
                          id="host"
                          placeholder="192.168.1.100 or server.local"
                          value={config.host}
                          onChange={(e) => setConfig(prev => ({ ...prev, host: e.target.value }))}
                          className="bg-gray-900/50 border-gray-600 focus:border-blue-500"
                        />
                      </div>
                      
                      <div className="space-y-2">
                        <Label htmlFor="port" className="flex items-center gap-2">
                          <Zap className="h-4 w-4" />
                          Port
                        </Label>
                        <Input
                          id="port"
                          type="number"
                          placeholder="445"
                          value={config.port}
                          onChange={(e) => setConfig(prev => ({ ...prev, port: parseInt(e.target.value) || 445 }))}
                          className="bg-gray-900/50 border-gray-600 focus:border-blue-500"
                        />
                      </div>
                    </div>
                    
                    <div className="space-y-4">
                      <div className="space-y-2">
                        <Label htmlFor="username" className="flex items-center gap-2">
                          <Users className="h-4 w-4" />
                          Username
                        </Label>
                        <Input
                          id="username"
                          placeholder="guest"
                          value={config.username}
                          onChange={(e) => setConfig(prev => ({ ...prev, username: e.target.value }))}
                          className="bg-gray-900/50 border-gray-600 focus:border-blue-500"
                        />
                      </div>
                      
                      <div className="space-y-2">
                        <Label htmlFor="password" className="flex items-center gap-2">
                          <Shield className="h-4 w-4" />
                          Password
                        </Label>
                        <Input
                          id="password"
                          type="password"
                          placeholder="Leave empty for no password"
                          value={config.password}
                          onChange={(e) => setConfig(prev => ({ ...prev, password: e.target.value }))}
                          className="bg-gray-900/50 border-gray-600 focus:border-blue-500"
                        />
                      </div>
                    </div>
                  </div>
                  
                  {connectionStatus.connected && connectionStatus.shares && (
                    <div className="space-y-4 pt-4 border-t border-gray-700">
                      <Label className="flex items-center gap-2">
                        <FolderOpen className="h-4 w-4" />
                        Available Shares (可多选)
                      </Label>
                      <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
                        {connectionStatus.shares.map((share) => (
                          <Card 
                            key={share}
                            className={cn(
                              "cursor-pointer transition-all border-2",
                              selectedShares.includes(share)
                                ? "border-blue-500 bg-blue-500/10" 
                                : "border-gray-700 bg-gray-800/30 hover:border-gray-600"
                            )}
                            onClick={() => {
                              setSelectedShares(prev => 
                                prev.includes(share)
                                  ? prev.filter(s => s !== share)
                                  : [...prev, share]
                              )
                            }}
                          >
                            <CardContent className="p-4">
                              <div className="flex items-center gap-3">
                                {selectedShares.includes(share) ? (
                                  <CheckSquare className="h-5 w-5 text-blue-400" />
                                ) : (
                                  <Folder className="h-5 w-5 text-blue-400" />
                                )}
                                <div>
                                  <p className="font-medium">{share}</p>
                                  <p className="text-sm text-gray-400">SMB Share</p>
                                </div>
                              </div>
                            </CardContent>
                          </Card>
                        ))}
                      </div>
                      {selectedShares.length > 0 && (
                        <div className="mt-4 p-3 bg-blue-500/10 rounded-lg border border-blue-500/20">
                          <p className="text-sm text-blue-300">
                            已选择 {selectedShares.length} 个共享: {selectedShares.join(', ')}
                          </p>
                        </div>
                      )}
                    </div>
                  )}
                </CardContent>
                <CardFooter>
                  <div className="flex gap-2 flex-wrap">
                    <Button 
                      onClick={handleDiscoverShares} 
                      disabled={connecting || !config.host}
                      className="bg-blue-600 hover:bg-blue-700"
                      title="使用Go语言编写的高性能SMB发现工具"
                    >
                      <Activity className="mr-2 h-4 w-4" />
                      {connecting ? "发现中..." : "发现共享"}
                    </Button>
                  </div>
                </CardFooter>
              </Card>
            </TabsContent>

            {/* Media Configuration */}
            <TabsContent value="media" className="space-y-6">
              <Card className="bg-gray-800/30 border-gray-700 backdrop-blur-sm">
                <CardHeader>
                  <CardTitle className="flex items-center gap-2">
                    <HardDrive className="h-5 w-5" />
                    Media Library Settings
                  </CardTitle>
                  <CardDescription>Configure media scanning and organization</CardDescription>
                </CardHeader>
                <CardContent className="space-y-6">
                  {!connectionStatus.connected || selectedShares.length === 0 ? (
                    <div className="text-center p-8 bg-yellow-500/10 rounded-lg border border-yellow-500/20">
                      <HardDrive className="h-12 w-12 mx-auto mb-4 text-yellow-400" />
                      <h3 className="text-lg font-semibold mb-2 text-yellow-300">需要先连接SMB服务器</h3>
                      <p className="text-yellow-400/80 mb-4">
                        请先在Network选项卡中连接到SMB服务器并选择共享文件夹
                      </p>
                      <Button 
                        variant="outline" 
                        className="border-yellow-500/30 text-yellow-300 hover:bg-yellow-500/20"
                        onClick={() => {
                          // Switch to network tab
                          const networkTab = document.querySelector('[data-value="network"]') as HTMLElement
                          networkTab?.click()
                        }}
                      >
                        前往Network配置
                      </Button>
                    </div>
                  ) : (
                    <>
                      {selectedFolders.length > 0 && (
                        <div className="space-y-3">
                          <Label>Selected Folders</Label>
                          <div className="flex flex-wrap gap-2">
                            {selectedFolders.map((folder, index) => (
                              <Badge 
                                key={index}
                                variant="secondary" 
                                className="bg-blue-500/20 text-blue-300 border-blue-500/30"
                              >
                                {folder}
                                <button
                                  className="ml-2 hover:text-red-300"
                                  onClick={() => setSelectedFolders(prev => prev.filter((_, i) => i !== index))}
                                >
                                  ×
                                </button>
                              </Badge>
                            ))}
                          </div>
                        </div>
                      )}
                      
                      <div className="bg-blue-500/10 rounded-lg border border-blue-500/20 p-4">
                        <div className="flex items-start gap-3">
                          <FolderOpen className="h-5 w-5 text-blue-400 mt-0.5" />
                          <div>
                            <p className="text-sm font-medium text-blue-300">
                              当前共享 ({selectedShares.length}个): {selectedShares.join(', ')}
                            </p>
                            <p className="text-xs text-blue-400/80 mt-1">
                              点击下方按钮浏览共享中的文件夹并选择要扫描的目录
                            </p>
                          </div>
                        </div>
                      </div>
                      
                      <Button 
                        variant="outline" 
                        onClick={handleBrowseShare}
                        disabled={selectedShares.length === 0}
                        className="border-gray-600 hover:border-gray-500 disabled:opacity-50"
                      >
                        <FolderOpen className="mr-2 h-4 w-4" />
                        {showFileBrowser ? "Hide" : "Browse"} Folders
                      </Button>
                      
                      {showFileBrowser && selectedShares.length > 0 && (
                        <Card className="bg-gray-900/50 border-gray-600">
                          <CardHeader>
                            <CardTitle className="text-lg">
                              Browse Shares: {selectedShares.join(', ')}
                            </CardTitle>
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
                                  title: "Folders Selected",
                                  description: `Selected ${selectedPaths.length} folders for scanning`,
                                })
                              }}
                              onCancel={() => setShowFileBrowser(false)}
                            />
                          </CardContent>
                        </Card>
                      )}
                    </>
                  )}
                </CardContent>
              </Card>
            </TabsContent>

            {/* API Configuration */}
            <TabsContent value="api" className="space-y-6">
              <Card className="bg-gray-800/30 border-gray-700 backdrop-blur-sm">
                <CardHeader>
                  <div className="flex items-center justify-between">
                    <div>
                      <CardTitle className="flex items-center gap-2">
                        <Key className="h-5 w-5" />
                        TMDB API Configuration
                      </CardTitle>
                      <CardDescription>Configure The Movie Database API for metadata</CardDescription>
                    </div>
                    <div className="flex items-center gap-2">
                      {tmdbConnected ? (
                        <Badge className="bg-green-500/20 text-green-300 border-green-500/30">
                          <CheckCircle2 className="mr-1 h-3 w-3" />
                          Connected
                        </Badge>
                      ) : (
                        <Badge variant="secondary" className="bg-yellow-500/20 text-yellow-300 border-yellow-500/30">
                          <AlertCircle className="mr-1 h-3 w-3" />
                          Not Connected
                        </Badge>
                      )}
                    </div>
                  </div>
                </CardHeader>
                <CardContent className="space-y-6">
                  <div className="space-y-2">
                    <Label htmlFor="tmdbApiKey">API Key</Label>
                    <Input
                      id="tmdbApiKey"
                      placeholder="Enter your TMDB API key"
                      value={tmdbApiKey}
                      onChange={(e) => setTmdbApiKey(e.target.value)}
                      className="bg-gray-900/50 border-gray-600 focus:border-blue-500"
                    />
                  </div>
                  
                  <div className="flex items-center gap-4 p-4 bg-blue-500/10 rounded-lg border border-blue-500/20">
                    <ExternalLink className="h-5 w-5 text-blue-400" />
                    <div className="flex-1">
                      <p className="text-sm font-medium text-blue-300">Get your API key</p>
                      <p className="text-xs text-blue-400/80">Visit TMDB to create a free API account</p>
                    </div>
                    <Button
                      variant="outline"
                      size="sm"
                      onClick={() => window.open("https://www.themoviedb.org/settings/api", "_blank")}
                      className="border-blue-500/30 text-blue-300 hover:bg-blue-500/20"
                    >
                      Open TMDB
                    </Button>
                  </div>
                  
                  {systemStats.apiUsage > 0 && (
                    <div className="space-y-2">
                      <div className="flex justify-between text-sm">
                        <span className="text-gray-400">API Usage Today</span>
                        <span className="text-white">{systemStats.apiUsage}%</span>
                      </div>
                      <div className="w-full bg-gray-700 rounded-full h-2">
                        <div 
                          className="bg-blue-500 h-2 rounded-full transition-all"
                          style={{ width: `${systemStats.apiUsage}%` }}
                        />
                      </div>
                    </div>
                  )}
                </CardContent>
                <CardFooter className="flex gap-3">
                  <Button 
                    variant="outline"
                    onClick={handleTestTmdbApi}
                    disabled={testingApi || !tmdbApiKey}
                    className="border-gray-600 hover:border-gray-500"
                  >
                    <TestTube className="mr-2 h-4 w-4" />
                    {testingApi ? "Testing..." : "Test API"}
                  </Button>
                  <Button 
                    onClick={handleSaveTmdbApiKey}
                    disabled={savingApiKey || !tmdbApiKey}
                    className="bg-blue-600 hover:bg-blue-700"
                  >
                    <Save className="mr-2 h-4 w-4" />
                    {savingApiKey ? "Saving..." : "Save API Key"}
                  </Button>
                </CardFooter>
              </Card>
            </TabsContent>

            {/* System Configuration */}
            <TabsContent value="system" className="space-y-6">
              <Card className="bg-gray-800/30 border-gray-700 backdrop-blur-sm">
                <CardHeader>
                  <CardTitle className="flex items-center gap-2">
                    <Settings className="h-5 w-5" />
                    System Maintenance
                  </CardTitle>
                  <CardDescription>Manage cache, database, and system settings</CardDescription>
                </CardHeader>
                <CardContent className="space-y-6">
                  <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                    <div className="space-y-4">
                      <h4 className="font-medium">Cache Management</h4>
                      <div className="space-y-3">
                        <div className="flex justify-between items-center p-3 bg-gray-800/50 rounded-lg">
                          <div>
                            <p className="text-sm font-medium">Media Cache</p>
                            <p className="text-xs text-gray-400">{systemStats.cacheSize}</p>
                          </div>
                          <Button
                            variant="outline"
                            size="sm"
                            onClick={handleClearCache}
                            disabled={clearingCache}
                            className="border-red-500/30 text-red-300 hover:bg-red-500/20"
                          >
                            <Trash2 className="mr-2 h-3 w-3" />
                            {clearingCache ? "Clearing..." : "Clear"}
                          </Button>
                        </div>
                      </div>
                    </div>
                    
                    <div className="space-y-4">
                      <h4 className="font-medium">Library Statistics</h4>
                      <div className="space-y-3">
                        <div className="flex justify-between items-center p-3 bg-gray-800/50 rounded-lg">
                          <span className="text-sm">Total Media Items</span>
                          <Badge variant="secondary">{systemStats.mediaCount}</Badge>
                        </div>
                        <div className="flex justify-between items-center p-3 bg-gray-800/50 rounded-lg">
                          <span className="text-sm">Last Scan</span>
                          <Badge variant="secondary">{systemStats.lastScan || "Never"}</Badge>
                        </div>
                      </div>
                    </div>
                  </div>
                  
                  <div className="p-4 bg-yellow-500/10 rounded-lg border border-yellow-500/20">
                    <div className="flex items-start gap-3">
                      <AlertCircle className="h-5 w-5 text-yellow-400 mt-0.5" />
                      <div>
                        <p className="text-sm font-medium text-yellow-300">Cache Clearing Warning</p>
                        <p className="text-xs text-yellow-400/80 mt-1">
                          Clearing the cache will remove all downloaded metadata and require re-scanning your media library.
                          This process may take a significant amount of time depending on your library size.
                        </p>
                      </div>
                    </div>
                  </div>
                </CardContent>
              </Card>
            </TabsContent>
          </Tabs>
        </div>
      </main>
    </TooltipProvider>
  )
}
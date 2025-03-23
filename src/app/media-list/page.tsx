"use client"

import { useState, useEffect } from 'react'
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Loader2, Search, ArrowLeft, RefreshCw } from "lucide-react"
import Link from "next/link"
import type { Media } from "@/types/electron"

export default function MediaListPage() {
  const [mediaItems, setMediaItems] = useState<Media[]>([]);
  const [filteredItems, setFilteredItems] = useState<Media[]>([]);
  const [searchTerm, setSearchTerm] = useState("");
  const [loading, setLoading] = useState(true);
  const [loadingMetadata, setLoadingMetadata] = useState<Record<string, boolean>>({});
  const [logs, setLogs] = useState<string[]>([]);

  // 添加日志函数
  const addLog = (message: string) => {
    const timestamp = new Date().toISOString().split('T')[1].substring(0, 8);
    const logMessage = `[${timestamp}] ${message}`;
    console.log(logMessage);
    setLogs(prev => [logMessage, ...prev]);
  };

  // 获取所有媒体
  const fetchAllMedia = async () => {
    setLoading(true);
    addLog("正在获取所有媒体...");
    
    try {
      // 获取电影
      const movies = await window.electronAPI?.getMedia("movie") || [];
      addLog(`获取到 ${movies.length} 部电影`);
      
      // 获取电视剧
      const tvShows = await window.electronAPI?.getMedia("tv") || [];
      addLog(`获取到 ${tvShows.length} 部电视剧`);
      
      // 获取未知类型媒体
      const unknownMedia = await window.electronAPI?.getMedia("unknown") || [];
      addLog(`获取到 ${unknownMedia.length} 个未知类型媒体`);
      
      // 合并所有媒体
      const allMedia = [...movies, ...tvShows, ...unknownMedia];
      setMediaItems(allMedia);
      setFilteredItems(allMedia);
      addLog(`共加载 ${allMedia.length} 个媒体项`);
    } catch (error) {
      addLog(`获取媒体出错: ${error instanceof Error ? error.message : String(error)}`);
    } finally {
      setLoading(false);
    }
  };

  // 获取单个媒体的元数据
  const fetchMetadata = async (mediaId: string) => {
    setLoadingMetadata(prev => ({ ...prev, [mediaId]: true }));
    addLog(`正在获取媒体ID: ${mediaId} 的元数据...`);
    
    try {
      // 使用fetchPosters API, 这个API实际上会同时获取海报和元数据
      const result = await window.electronAPI?.fetchPosters([mediaId]);
      
      if (result?.success) {
        addLog(`成功获取媒体ID: ${mediaId} 的元数据和海报`);
        
        // 刷新该媒体项
        const updatedMedia = await window.electronAPI?.getMediaById(mediaId);
        if (updatedMedia) {
          // 更新媒体列表中的项
          setMediaItems(prev => 
            prev.map(item => 
              item.id === mediaId ? updatedMedia : item
            )
          );
          setFilteredItems(prev => 
            prev.map(item => 
              item.id === mediaId ? updatedMedia : item
            )
          );
        }
      } else {
        addLog(`获取媒体ID: ${mediaId} 的元数据失败: ${result?.error || '未知错误'}`);
      }
    } catch (error) {
      addLog(`获取元数据时出错: ${error instanceof Error ? error.message : String(error)}`);
    } finally {
      setLoadingMetadata(prev => ({ ...prev, [mediaId]: false }));
    }
  };

  // 获取所有媒体的元数据
  const fetchAllMetadata = async () => {
    addLog("正在获取所有媒体的元数据...");
    
    try {
      const mediaIds = mediaItems.map(item => item.id);
      
      // 先设置所有项为加载中
      const loadingObj: Record<string, boolean> = {};
      mediaIds.forEach(id => { loadingObj[id] = true; });
      setLoadingMetadata(loadingObj);
      
      // 使用fetchPosters API获取所有媒体的元数据
      const result = await window.electronAPI?.fetchPosters(mediaIds);
      
      if (result?.success) {
        addLog(`成功获取所有媒体的元数据和海报`);
        
        // 刷新媒体列表
        await fetchAllMedia();
      } else {
        addLog(`获取所有媒体的元数据失败: ${result?.error || '未知错误'}`);
      }
    } catch (error) {
      addLog(`获取所有元数据时出错: ${error instanceof Error ? error.message : String(error)}`);
    } finally {
      // 重置所有加载状态
      setLoadingMetadata({});
    }
  };

  // 搜索媒体
  const handleSearch = (term: string) => {
    setSearchTerm(term);
    
    if (!term.trim()) {
      setFilteredItems(mediaItems);
      return;
    }
    
    addLog(`正在搜索: "${term}"`);
    const lowerTerm = term.toLowerCase();
    
    const filtered = mediaItems.filter(media => 
      media.title.toLowerCase().includes(lowerTerm) || 
      (media.path && media.path.toLowerCase().includes(lowerTerm)) ||
      (media.year && media.year.toLowerCase().includes(lowerTerm))
    );
    
    setFilteredItems(filtered);
    addLog(`搜索结果: 找到 ${filtered.length} 个媒体项`);
  };

  // 初始加载
  useEffect(() => {
    fetchAllMedia();
  }, []);

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
          <h1 className="text-3xl font-bold">媒体列表</h1>
        </div>

        <div className="mb-6 flex flex-col md:flex-row gap-4">
          <div className="relative flex-1">
            <Search className="absolute left-3 top-3 h-4 w-4 text-gray-500" />
            <Input
              value={searchTerm}
              onChange={(e) => handleSearch(e.target.value)}
              placeholder="搜索媒体标题、年份或路径..."
              className="pl-10 bg-gray-900 border-gray-700 w-full"
            />
          </div>
          <Button 
            onClick={fetchAllMedia}
            disabled={loading}
          >
            <RefreshCw className={`mr-2 h-4 w-4 ${loading ? "animate-spin" : ""}`} />
            刷新
          </Button>
          <Button 
            onClick={fetchAllMetadata}
            disabled={loading || Object.keys(loadingMetadata).length > 0}
          >
            <RefreshCw className={`mr-2 h-4 w-4 ${Object.keys(loadingMetadata).length > 0 ? "animate-spin" : ""}`} />
            获取所有元数据
          </Button>
        </div>

        {loading ? (
          <div className="flex justify-center items-center h-64">
            <Loader2 className="h-12 w-12 animate-spin text-gray-400" />
          </div>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div className="space-y-4">
              <Card className="bg-gray-900 border-gray-800">
                <CardHeader>
                  <CardTitle>媒体列表 ({filteredItems.length} 项)</CardTitle>
                </CardHeader>
                <CardContent>
                  <div className="space-y-4 max-h-[600px] overflow-y-auto pr-2">
                    {filteredItems.length === 0 ? (
                      <p className="text-gray-500 text-center py-4">未找到媒体</p>
                    ) : (
                      filteredItems.map(media => (
                        <div key={media.id} className="p-4 bg-gray-800 rounded-lg">
                          <div className="flex justify-between items-start mb-2">
                            <div>
                              <h3 className="font-medium text-white">
                                {media.title} {media.year && `(${media.year})`}
                              </h3>
                              <p className="text-sm text-gray-400">ID: {media.id}</p>
                              <p className="text-sm text-gray-400">
                                类型: {
                                  media.type === "movie" ? "电影" : 
                                  media.type === "tv" ? "电视剧" : 
                                  "未知"
                                }
                              </p>
                              {media.path && (
                                <p className="text-xs text-gray-500 truncate" title={media.path}>
                                  路径: {media.path}
                                </p>
                              )}
                              {media.details && (
                                <p className="text-xs text-gray-500 mt-2">
                                  详情: {JSON.stringify(JSON.parse(media.details), null, 2)}
                                </p>
                              )}
                            </div>
                            <Button
                              variant="outline"
                              size="sm"
                              onClick={() => fetchMetadata(media.id)}
                              disabled={loadingMetadata[media.id]}
                            >
                              {loadingMetadata[media.id] ? (
                                <Loader2 className="h-4 w-4 animate-spin" />
                              ) : (
                                "获取元数据"
                              )}
                            </Button>
                          </div>
                        </div>
                      ))
                    )}
                  </div>
                </CardContent>
              </Card>
            </div>

            <div>
              <Card className="bg-gray-900 border-gray-800">
                <CardHeader>
                  <CardTitle>操作日志</CardTitle>
                </CardHeader>
                <CardContent>
                  <div className="bg-gray-950 p-4 rounded h-[600px] overflow-y-auto font-mono text-sm">
                    {logs.length === 0 ? (
                      <p className="text-gray-500">尚无日志数据</p>
                    ) : (
                      logs.map((log, index) => (
                        <div key={index} className="mb-1 text-gray-300">
                          {log}
                        </div>
                      ))
                    )}
                  </div>
                </CardContent>
              </Card>
            </div>
          </div>
        )}
      </div>
    </main>
  );
} 
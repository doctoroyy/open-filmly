"use client"

import { useState, useEffect } from "react"
import { Folder, File, ArrowLeft, FolderOpen, CheckSquare, Square, RefreshCw, AlertCircle, Grid, List } from "lucide-react"
import { Button } from "@/components/ui/button"
import { Card, CardContent } from "@/components/ui/card"
import { useToast } from "@/components/ui/use-toast"
import { Toggle } from "@/components/ui/toggle"

interface FileItem {
  name: string
  isDirectory: boolean
  size?: number
  modifiedTime?: string
}

interface SMBFileBrowserProps {
  initialPath?: string
  selectionMode?: boolean
  onSelect?: (selectedPaths: string[]) => void
  onCancel?: () => void
  selectedFolders?: string[] // Allow showing previously selected folders
  allowFileAddition?: boolean // Allow adding individual files directly
  onFileAdded?: (mediaInfo: any) => void // Callback when a file is added directly
}

export function SMBFileBrowser({
  initialPath = "/",
  selectionMode = false,
  onSelect,
  onCancel,
  selectedFolders = [],
  allowFileAddition = false,
  onFileAdded
}: SMBFileBrowserProps) {
  const [currentPath, setCurrentPath] = useState<string>(initialPath)
  const [pathHistory, setPathHistory] = useState<string[]>([])
  const [items, setItems] = useState<FileItem[]>([])
  const [selectedItems, setSelectedItems] = useState<{[path: string]: boolean}>({})
  const [loading, setLoading] = useState<boolean>(true)
  const [error, setError] = useState<string | null>(null)
  const [viewMode, setViewMode] = useState<"grid" | "list">("grid")
  const { toast } = useToast()

  // Initialize selected items from props
  useEffect(() => {
    if (selectedFolders.length > 0) {
      const initialSelected: {[path: string]: boolean} = {};
      selectedFolders.forEach(folder => {
        initialSelected[folder] = true;
      });
      setSelectedItems(initialSelected);
    }
  }, [selectedFolders]);

  // 加载当前目录内容
  const loadDirectoryContents = async (path: string) => {
    setLoading(true)
    setError(null)
    try {
      const result = await window.electronAPI?.getDirContents(path)
      
      if (result?.success && result.items) {
        setItems(result.items)
      } else {
        setError(result?.error || "无法加载目录内容")
        toast({
          title: "加载失败",
          description: result?.error || "无法加载目录内容",
          variant: "destructive",
        })
      }
    } catch (error) {
      console.error("Error loading directory contents:", error)
      setError("加载目录内容时出错")
      toast({
        title: "加载失败",
        description: "加载目录内容时出错",
        variant: "destructive",
      })
    } finally {
      setLoading(false)
    }
  }

  // 第一次加载
  useEffect(() => {
    loadDirectoryContents(initialPath)
  }, [initialPath])

  // 导航到特定路径
  const navigateTo = (path: string) => {
    // 保存当前路径到历史
    setPathHistory(prev => [...prev, currentPath])
    // 设置新路径
    setCurrentPath(path)
    // 加载新目录内容
    loadDirectoryContents(path)
  }

  // 返回上一级
  const goBack = () => {
    if (pathHistory.length > 0) {
      // 从历史中获取上一个路径
      const previousPath = pathHistory[pathHistory.length - 1]
      // 更新历史
      setPathHistory(prev => prev.slice(0, -1))
      // 设置当前路径
      setCurrentPath(previousPath)
      // 加载目录内容
      loadDirectoryContents(previousPath)
    } else if (currentPath !== "/") {
      // 如果没有历史但当前不是根目录，回到上一级
      const parentPath = currentPath.substring(0, currentPath.lastIndexOf("/"))
      const normalizedParentPath = parentPath || "/"
      setCurrentPath(normalizedParentPath)
      loadDirectoryContents(normalizedParentPath)
    }
  }

  // 刷新当前目录
  const refreshDirectory = () => {
    loadDirectoryContents(currentPath)
  }

  // 处理点击项目
  const handleItemClick = (item: FileItem) => {
    if (item.isDirectory) {
      // 如果是目录，导航到该目录
      const newPath = currentPath === "/" 
        ? `/${item.name}` 
        : `${currentPath}/${item.name}`
      navigateTo(newPath)
    } else if (allowFileAddition && !selectionMode) {
      // 如果允许添加文件，且不是选择模式，处理文件添加
      handleAddFile(item);
    }
  }

  // 处理添加单个文件
  const handleAddFile = async (file: FileItem) => {
    try {
      const filePath = currentPath === "/" 
        ? `/${file.name}` 
        : `${currentPath}/${file.name}`;
      
      setLoading(true);
      const result = await window.electronAPI?.addSingleMedia(filePath);
      
      if (result?.success) {
        toast({
          title: "文件已添加",
          description: `已将文件添加到媒体库: ${file.name}`,
        });
        
        // 调用回调
        if (onFileAdded) {
          onFileAdded(result.media);
        }
      } else {
        toast({
          title: "添加失败",
          description: result?.error || "无法添加文件",
          variant: "destructive",
        });
      }
    } catch (error) {
      console.error("Error adding file:", error);
      toast({
        title: "添加失败",
        description: "添加文件时发生错误",
        variant: "destructive",
      });
    } finally {
      setLoading(false);
    }
  };

  // 切换目录选择状态
  const toggleDirectorySelection = (dirName: string) => {
    const dirPath = currentPath === "/" 
      ? `/${dirName}` 
      : `${currentPath}/${dirName}`
      
    setSelectedItems(prev => {
      const newSelected = { ...prev }
      if (newSelected[dirPath]) {
        delete newSelected[dirPath]
      } else {
        newSelected[dirPath] = true
      }
      return newSelected
    })
  }

  // 确认选择
  const confirmSelection = () => {
    if (onSelect) {
      onSelect(Object.keys(selectedItems))
    }
  }

  // 取消选择
  const cancelSelection = () => {
    if (onCancel) {
      onCancel()
    }
  }

  // 格式化文件大小
  const formatFileSize = (bytes?: number): string => {
    if (bytes === undefined) return "未知"
    
    if (bytes < 1024) return `${bytes} B`
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`
    if (bytes < 1024 * 1024 * 1024) return `${(bytes / (1024 * 1024)).toFixed(1)} MB`
    return `${(bytes / (1024 * 1024 * 1024)).toFixed(1)} GB`
  }

  // 渲染网格视图
  const renderGridView = () => (
    <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-2">
      {items.filter(item => selectionMode ? item.isDirectory : true).map((item) => (
        <div 
          key={item.name}
          className={`
            flex items-center p-2 rounded-md cursor-pointer hover:bg-muted
            ${selectionMode && item.isDirectory && (
              selectedItems[`${currentPath === "/" ? "" : currentPath}/${item.name}`] ? 
              'bg-primary/10' : ''
            )}
            ${!item.isDirectory ? 'opacity-70' : ''}
          `}
          onClick={() => handleItemClick(item)}
        >
          {selectionMode && item.isDirectory && (
            <div className="mr-1" onClick={(e) => {
              e.stopPropagation();
              toggleDirectorySelection(item.name);
            }}>
              {selectedItems[`${currentPath === "/" ? "" : currentPath}/${item.name}`] ? 
                <CheckSquare className="w-5 h-5 text-primary" /> : 
                <Square className="w-5 h-5" />
              }
            </div>
          )}
          
          {item.isDirectory ? (
            item.isDirectory ? 
              selectedItems[`${currentPath === "/" ? "" : currentPath}/${item.name}`] ? 
                <FolderOpen className="w-5 h-5 mr-2 text-blue-500" /> : 
                <Folder className="w-5 h-5 mr-2 text-blue-500" /> 
              : <File className="w-5 h-5 mr-2" />
          ) : (
            <File className="w-5 h-5 mr-2" />
          )}
          
          <div className="truncate flex-1">{item.name}</div>
          
          {allowFileAddition && !selectionMode && !item.isDirectory && (
            <Button 
              variant="ghost" 
              size="sm"
              className="ml-2 h-6 px-2"
              onClick={(e) => {
                e.stopPropagation();
                handleAddFile(item);
              }}
            >
              添加
            </Button>
          )}
        </div>
      ))}
    </div>
  )

  // 渲染列表视图
  const renderListView = () => (
    <div className="flex flex-col gap-1">
      {items.filter(item => selectionMode ? item.isDirectory : true).map((item) => (
        <div 
          key={item.name}
          className={`
            flex items-center p-2 rounded-md cursor-pointer hover:bg-muted
            ${selectionMode && item.isDirectory && (
              selectedItems[`${currentPath === "/" ? "" : currentPath}/${item.name}`] ? 
              'bg-primary/10' : ''
            )}
            ${!item.isDirectory ? 'opacity-70' : ''}
          `}
          onClick={() => handleItemClick(item)}
        >
          {selectionMode && item.isDirectory && (
            <div className="mr-1" onClick={(e) => {
              e.stopPropagation();
              toggleDirectorySelection(item.name);
            }}>
              {selectedItems[`${currentPath === "/" ? "" : currentPath}/${item.name}`] ? 
                <CheckSquare className="w-5 h-5 text-primary" /> : 
                <Square className="w-5 h-5" />
              }
            </div>
          )}
          
          {item.isDirectory ? (
            item.isDirectory ? 
              selectedItems[`${currentPath === "/" ? "" : currentPath}/${item.name}`] ? 
                <FolderOpen className="w-5 h-5 mr-2 text-blue-500" /> : 
                <Folder className="w-5 h-5 mr-2 text-blue-500" /> 
              : <File className="w-5 h-5 mr-2" />
          ) : (
            <File className="w-5 h-5 mr-2" />
          )}
          
          <div className="truncate flex-1">{item.name}</div>
          
          <div className="text-xs text-muted-foreground ml-4 flex-shrink-0">
            {item.size !== undefined && formatFileSize(item.size)}
          </div>
          
          {item.modifiedTime && (
            <div className="text-xs text-muted-foreground ml-4 flex-shrink-0">
              {new Date(item.modifiedTime).toLocaleDateString()}
            </div>
          )}
          
          {allowFileAddition && !selectionMode && !item.isDirectory && (
            <Button 
              variant="ghost" 
              size="sm"
              className="ml-2 h-6 px-2"
              onClick={(e) => {
                e.stopPropagation();
                handleAddFile(item);
              }}
            >
              添加
            </Button>
          )}
        </div>
      ))}
    </div>
  )

  return (
    <Card className="w-full">
      <CardContent className="p-4">
        {/* 导航栏 */}
        <div className="flex items-center mb-4 space-x-2">
          <Button 
            variant="outline" 
            size="sm" 
            onClick={goBack}
            disabled={currentPath === "/" && pathHistory.length === 0}
          >
            <ArrowLeft className="w-4 h-4 mr-1" />
            返回
          </Button>
          
          <Button 
            variant="outline" 
            size="sm"
            onClick={refreshDirectory}
            disabled={loading}
          >
            <RefreshCw className={`w-4 h-4 mr-1 ${loading ? 'animate-spin' : ''}`} />
            刷新
          </Button>
          
          <div className="flex-1 px-3 py-1 border rounded-md truncate">
            {currentPath}
          </div>

          <Toggle
            aria-label="Toggle view mode"
            pressed={viewMode === "list"}
            onPressedChange={() => setViewMode(viewMode === "grid" ? "list" : "grid")}
          >
            {viewMode === "grid" ? 
              <List className="w-4 h-4" /> : 
              <Grid className="w-4 h-4" />
            }
          </Toggle>
        </div>
        
        {/* 文件浏览区域 */}
        <div className="h-[400px] rounded-md border p-2 overflow-auto">
          {loading ? (
            <div className="flex items-center justify-center h-full">
              <RefreshCw className="w-6 h-6 animate-spin mr-2" />
              加载中...
            </div>
          ) : error ? (
            <div className="flex flex-col items-center justify-center h-full text-destructive">
              <AlertCircle className="w-8 h-8 mb-2" />
              <p>{error}</p>
              <Button 
                variant="outline" 
                size="sm" 
                className="mt-2"
                onClick={refreshDirectory}
              >
                重试
              </Button>
            </div>
          ) : items.length === 0 ? (
            <div className="flex items-center justify-center h-full text-muted-foreground">
              此目录为空
            </div>
          ) : (
            viewMode === "grid" ? renderGridView() : renderListView()
          )}
        </div>
        
        {/* 底部操作栏 */}
        {selectionMode && (
          <div className="flex justify-end space-x-2 mt-4">
            <Button variant="outline" onClick={cancelSelection}>
              取消
            </Button>
            <Button onClick={confirmSelection}>
              确认选择 ({Object.keys(selectedItems).length})
            </Button>
          </div>
        )}
      </CardContent>
    </Card>
  )
} 
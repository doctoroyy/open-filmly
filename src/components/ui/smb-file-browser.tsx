"use client"

import { useState, useEffect } from "react"
import { Folder, File, ArrowLeft, FolderOpen, CheckSquare, Square, RefreshCw, AlertCircle, Grid, List, Home, ChevronRight } from "lucide-react"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { useToast } from "@/components/ui/use-toast"
import { Toggle } from "@/components/ui/toggle"
import { Badge } from "@/components/ui/badge"

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
  selectedFolders?: string[]
  allowFileAddition?: boolean
  onFileAdded?: (mediaInfo: any) => void
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

  // Load directory contents - backend handles both shares and regular directories
  const loadDirectoryContents = async (path: string, retryCount: number = 0) => {
    setLoading(true)
    setError(null)
    
    const maxRetries = 2
    
    try {
      console.log(`Loading directory: path="${path}"`)
      
      // Use the unified API that handles both root (shares) and regular directories
      const result = await window.electronAPI?.getDirContents(path)
      
      if (result?.success && result.items) {
        setItems(result.items)
      } else {
        const errorMessage = result?.error || "Unable to load directory contents"
        
        // Enhanced error handling with specific error types
        if (errorMessage.includes("STATUS_OBJECT_NAME_NOT_FOUND") || errorMessage.includes("not found")) {
          setError(`Directory not found: ${path}. The path may have been moved or deleted.`)
        } else if (errorMessage.includes("access denied") || errorMessage.includes("permission")) {
          setError("Access denied. Please check your SMB credentials and permissions.")
        } else if (errorMessage.includes("network") || errorMessage.includes("connection")) {
          setError("Network connection error. Please check your SMB server connection.")
        } else if (errorMessage.includes("binary not found")) {
          setError("SMB client binary not found. Please check your installation.")
        } else {
          setError(errorMessage)
        }
        
        // Auto-retry for certain error types
        if (retryCount < maxRetries && (
          errorMessage.includes("network") || 
          errorMessage.includes("timeout") ||
          errorMessage.includes("connection")
        )) {
          console.log(`Retrying directory load (attempt ${retryCount + 1}/${maxRetries})...`)
          setTimeout(() => {
            loadDirectoryContents(path, retryCount + 1)
          }, 1000 * (retryCount + 1))
          return
        }
        
        toast({
          title: "Load Failed",
          description: error || errorMessage,
          variant: "destructive",
        })
      }
    } catch (error) {
      console.error("Error loading directory contents:", error)
      const errorMessage = `Error loading directory contents: ${path}`
      setError(errorMessage)
      
      // Auto-retry for network errors
      if (retryCount < maxRetries) {
        console.log(`Retrying directory load due to exception (attempt ${retryCount + 1}/${maxRetries})...`)
        setTimeout(() => {
          loadDirectoryContents(path, retryCount + 1)
        }, 1000 * (retryCount + 1))
        return
      }
      
      toast({
        title: "Load Failed",
        description: errorMessage,
        variant: "destructive",
      })
    } finally {
      setLoading(false)
    }
  }

  // Initial load
  useEffect(() => {
    loadDirectoryContents(initialPath)
  }, [initialPath])

  // Navigate to specific path
  const navigateTo = (path: string, addToHistory: boolean = true) => {
    if (addToHistory) {
      setPathHistory(prev => [...prev, currentPath])
    }
    setCurrentPath(path)
    loadDirectoryContents(path)
  }

  // Go back in navigation
  const goBack = () => {
    if (pathHistory.length > 0) {
      const previousPath = pathHistory[pathHistory.length - 1]
      setPathHistory(prev => prev.slice(0, -1))
      setCurrentPath(previousPath)
      loadDirectoryContents(previousPath)
    } else if (currentPath !== "/") {
      const parentPath = currentPath.substring(0, currentPath.lastIndexOf("/"))
      const normalizedParentPath = parentPath || "/"
      setCurrentPath(normalizedParentPath)
      loadDirectoryContents(normalizedParentPath)
    }
  }

  // Go to root
  const goToRoot = () => {
    setPathHistory([])
    setCurrentPath("/")
    loadDirectoryContents("/")
  }

  // Refresh current directory
  const refreshDirectory = () => {
    loadDirectoryContents(currentPath)
  }

  // Handle item clicks - unified interaction
  const handleItemClick = (item: FileItem, event: React.MouseEvent) => {
    // Check if clicked on checkbox area - for selection
    const target = event.target as HTMLElement
    if (target.closest('.checkbox-area')) {
      if (selectionMode && item.isDirectory) {
        toggleDirectorySelection(item.name)
      }
      return
    }
    
    // Clicked outside checkbox - for navigation or file action
    if (item.isDirectory) {
      // Navigate into directory
      const newPath = currentPath === "/" 
        ? `/${item.name}` 
        : `${currentPath}/${item.name}`
      navigateTo(newPath)
    } else if (allowFileAddition && !item.isDirectory) {
      // Handle file addition
      handleAddFile(item)
    }
  }

  // Handle adding single file
  const handleAddFile = async (file: FileItem) => {
    try {
      const filePath = currentPath === "/" 
        ? `/${file.name}` 
        : `${currentPath}/${file.name}`
      
      setLoading(true)
      const result = await window.electronAPI?.addSingleMedia(filePath)
      
      if (result?.success) {
        toast({
          title: "File Added",
          description: `Added file to media library: ${file.name}`,
        })
        
        if (onFileAdded) {
          onFileAdded(result.media)
        }
      } else {
        toast({
          title: "Add Failed",
          description: result?.error || "Unable to add file",
          variant: "destructive",
        })
      }
    } catch (error) {
      console.error("Error adding file:", error)
      toast({
        title: "Add Failed",
        description: "Error adding file",
        variant: "destructive",
      })
    } finally {
      setLoading(false)
    }
  }

  // Toggle directory selection
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

  // Confirm selection
  const confirmSelection = () => {
    if (onSelect) {
      onSelect(Object.keys(selectedItems))
    }
  }

  // Toggle select all directories
  const toggleSelectAll = () => {
    const allDirectories = items.filter(item => item.isDirectory)
    const allSelected = allDirectories.every(dir => {
      const dirPath = currentPath === "/" ? `/${dir.name}` : `${currentPath}/${dir.name}`
      return selectedItems[dirPath]
    })

    if (allSelected) {
      const newSelected = { ...selectedItems }
      allDirectories.forEach(dir => {
        const dirPath = currentPath === "/" ? `/${dir.name}` : `${currentPath}/${dir.name}`
        delete newSelected[dirPath]
      })
      setSelectedItems(newSelected)
    } else {
      const newSelected = { ...selectedItems }
      allDirectories.forEach(dir => {
        const dirPath = currentPath === "/" ? `/${dir.name}` : `${currentPath}/${dir.name}`
        newSelected[dirPath] = true
      })
      setSelectedItems(newSelected)
    }
  }

  // Cancel selection
  const cancelSelection = () => {
    if (onCancel) {
      onCancel()
    }
  }

  // Format file size
  const formatFileSize = (bytes?: number): string => {
    if (bytes === undefined) return "Unknown"
    
    if (bytes < 1024) return `${bytes} B`
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`
    if (bytes < 1024 * 1024 * 1024) return `${(bytes / (1024 * 1024)).toFixed(1)} MB`
    return `${(bytes / (1024 * 1024 * 1024)).toFixed(1)} GB`
  }

  // Generate breadcrumb navigation
  const getBreadcrumbs = () => {
    if (currentPath === "/") return [{ name: "Root", path: "/" }]
    
    const parts = currentPath.split("/").filter(Boolean)
    const breadcrumbs = [{ name: "Root", path: "/" }]
    
    let accumulatedPath = ""
    parts.forEach(part => {
      accumulatedPath += `/${part}`
      breadcrumbs.push({ name: part, path: accumulatedPath })
    })
    
    return breadcrumbs
  }

  // Render grid view with unified interaction
  const renderGridView = () => (
    <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-2">
      {items.map((item) => (
        <div 
          key={item.name}
          className={`
            flex items-center p-2 rounded-md cursor-pointer transition-colors relative
            hover:bg-blue-50 dark:hover:bg-blue-900/20
            ${selectionMode && item.isDirectory && (
              selectedItems[`${currentPath === "/" ? "" : currentPath}/${item.name}`] ? 
              'bg-blue-100 dark:bg-blue-900/30' : ''
            )}
            ${!item.isDirectory ? 'opacity-70' : ''}
          `}
          onClick={(e) => handleItemClick(item, e)}
        >
          {selectionMode && item.isDirectory && (
            <div 
              className="checkbox-area mr-2 p-1 rounded hover:bg-gray-200 dark:hover:bg-gray-700" 
              onClick={(e) => {
                e.stopPropagation()
                toggleDirectorySelection(item.name)
              }}
            >
              {selectedItems[`${currentPath === "/" ? "" : currentPath}/${item.name}`] ? 
                <CheckSquare className="w-4 h-4 text-blue-600" /> : 
                <Square className="w-4 h-4 text-gray-400" />
              }
            </div>
          )}
          
          {item.isDirectory ? (
            selectedItems[`${currentPath === "/" ? "" : currentPath}/${item.name}`] ? 
              <FolderOpen className="w-5 h-5 mr-2 text-blue-600" /> : 
              <Folder className="w-5 h-5 mr-2 text-blue-500" /> 
          ) : (
            <File className="w-5 h-5 mr-2 text-gray-500" />
          )}
          
          <div className="truncate flex-1">{item.name}</div>
          
          {allowFileAddition && !item.isDirectory && (
            <Button 
              variant="ghost" 
              size="sm"
              className="ml-2 h-6 px-2"
              onClick={(e) => {
                e.stopPropagation()
                handleAddFile(item)
              }}
            >
              Add
            </Button>
          )}
        </div>
      ))}
    </div>
  )

  // Render list view with unified interaction
  const renderListView = () => (
    <div className="flex flex-col gap-1">
      {items.map((item) => (
        <div 
          key={item.name}
          className={`
            flex items-center p-2 rounded-md cursor-pointer transition-colors relative
            hover:bg-blue-50 dark:hover:bg-blue-900/20
            ${selectionMode && item.isDirectory && (
              selectedItems[`${currentPath === "/" ? "" : currentPath}/${item.name}`] ? 
              'bg-blue-100 dark:bg-blue-900/30' : ''
            )}
            ${!item.isDirectory ? 'opacity-70' : ''}
          `}
          onClick={(e) => handleItemClick(item, e)}
        >
          {selectionMode && item.isDirectory && (
            <div 
              className="checkbox-area mr-2 p-1 rounded hover:bg-gray-200 dark:hover:bg-gray-700"
              onClick={(e) => {
                e.stopPropagation()
                toggleDirectorySelection(item.name)
              }}
            >
              {selectedItems[`${currentPath === "/" ? "" : currentPath}/${item.name}`] ? 
                <CheckSquare className="w-4 h-4 text-blue-600" /> : 
                <Square className="w-4 h-4 text-gray-400" />
              }
            </div>
          )}
          
          {item.isDirectory ? (
            selectedItems[`${currentPath === "/" ? "" : currentPath}/${item.name}`] ? 
              <FolderOpen className="w-5 h-5 mr-2 text-blue-600" /> : 
              <Folder className="w-5 h-5 mr-2 text-blue-500" /> 
          ) : (
            <File className="w-5 h-5 mr-2 text-gray-500" />
          )}
          
          <div className="truncate flex-1">{item.name}</div>
          
          <div className="text-xs text-gray-500 ml-4 flex-shrink-0">
            {item.size !== undefined && formatFileSize(item.size)}
          </div>
          
          {item.modifiedTime && (
            <div className="text-xs text-gray-500 ml-4 flex-shrink-0">
              {new Date(item.modifiedTime).toLocaleDateString()}
            </div>
          )}
          
          {allowFileAddition && !item.isDirectory && (
            <Button 
              variant="ghost" 
              size="sm"
              className="ml-2 h-6 px-2"
              onClick={(e) => {
                e.stopPropagation()
                handleAddFile(item)
              }}
            >
              Add
            </Button>
          )}
        </div>
      ))}
    </div>
  )

  return (
    <Card className="w-full">
      <CardHeader className="pb-3">
        <div className="flex items-center justify-between">
          <CardTitle className="text-lg">SMB File Browser</CardTitle>
          <div className="flex items-center gap-2">
            {/* View Mode Toggle */}
            <Toggle
              pressed={viewMode === "list"}
              onPressedChange={() => setViewMode(viewMode === "grid" ? "list" : "grid")}
              className="h-8 w-8"
            >
              {viewMode === "grid" ? 
                <List className="w-4 h-4" /> : 
                <Grid className="w-4 h-4" />
              }
            </Toggle>
          </div>
        </div>
      </CardHeader>
      
      <CardContent className="space-y-4">
        {/* Navigation Bar */}
        <div className="flex items-center space-x-2">
          <Button 
            variant="outline" 
            size="sm" 
            onClick={goBack}
            disabled={currentPath === "/" && pathHistory.length === 0}
            className="h-8"
          >
            <ArrowLeft className="w-4 h-4 mr-1" />
            Back
          </Button>
          
          <Button 
            variant="outline" 
            size="sm"
            onClick={goToRoot}
            disabled={currentPath === "/"}
            className="h-8"
          >
            <Home className="w-4 h-4 mr-1" />
            Root
          </Button>
          
          <Button 
            variant="outline" 
            size="sm"
            onClick={refreshDirectory}
            disabled={loading}
            className="h-8"
          >
            <RefreshCw className={`w-4 h-4 mr-1 ${loading ? 'animate-spin' : ''}`} />
            Refresh
          </Button>

          {selectionMode && (
            <Button 
              variant="outline" 
              size="sm"
              onClick={toggleSelectAll}
              disabled={items.filter(item => item.isDirectory).length === 0}
              className="h-8"
            >
              {items.filter(item => item.isDirectory).every(dir => {
                const dirPath = currentPath === "/" ? `/${dir.name}` : `${currentPath}/${dir.name}`
                return selectedItems[dirPath]
              }) && items.filter(item => item.isDirectory).length > 0 ? "Deselect All" : "Select All"}
            </Button>
          )}
        </div>

        {/* Breadcrumb Navigation */}
        <div className="flex items-center space-x-1 text-sm text-gray-600 dark:text-gray-400 bg-gray-50 dark:bg-gray-800 rounded-md px-3 py-2">
          {getBreadcrumbs().map((crumb, index) => (
            <div key={crumb.path} className="flex items-center">
              {index > 0 && <ChevronRight className="w-4 h-4 mx-1" />}
              <button
                onClick={() => navigateTo(crumb.path, false)}
                className="hover:text-blue-600 dark:hover:text-blue-400 transition-colors"
              >
                {crumb.name}
              </button>
            </div>
          ))}
        </div>
        
        {/* File Browser Area */}
        <div className="h-[400px] rounded-md border border-gray-200 dark:border-gray-700 p-3 overflow-auto bg-white dark:bg-gray-900">
          {loading ? (
            <div className="flex items-center justify-center h-full">
              <RefreshCw className="w-6 h-6 animate-spin mr-2" />
              Loading...
            </div>
          ) : error ? (
            <div className="flex flex-col items-center justify-center h-full text-red-600 dark:text-red-400">
              <AlertCircle className="w-8 h-8 mb-2" />
              <p className="text-center">{error}</p>
              <Button 
                variant="outline" 
                size="sm" 
                className="mt-3"
                onClick={refreshDirectory}
              >
                Retry
              </Button>
            </div>
          ) : items.length === 0 ? (
            <div className="flex items-center justify-center h-full text-gray-500 dark:text-gray-400">
              This directory is empty
            </div>
          ) : (
            viewMode === "grid" ? renderGridView() : renderListView()
          )}
        </div>
        
        {/* Selection Footer */}
        {selectionMode && (
          <div className="flex items-center justify-between p-3 bg-blue-50 dark:bg-blue-900/20 rounded-md border border-blue-200 dark:border-blue-800">
            <div className="text-sm text-blue-700 dark:text-blue-300">
              Selected {Object.keys(selectedItems).length} folders
              {Object.keys(selectedItems).length > 0 && (
                <div className="mt-1 flex flex-wrap gap-1">
                  {Object.keys(selectedItems).slice(0, 3).map(path => (
                    <Badge key={path} variant="secondary" className="text-xs">
                      {path.split('/').pop()}
                    </Badge>
                  ))}
                  {Object.keys(selectedItems).length > 3 && (
                    <Badge variant="secondary" className="text-xs">
                      +{Object.keys(selectedItems).length - 3} more
                    </Badge>
                  )}
                </div>
              )}
            </div>
            <div className="flex space-x-2">
              <Button 
                variant="outline" 
                size="sm" 
                onClick={cancelSelection}
              >
                Cancel
              </Button>
              <Button 
                size="sm" 
                onClick={confirmSelection}
                disabled={Object.keys(selectedItems).length === 0}
                className="bg-blue-600 hover:bg-blue-700"
              >
                Confirm ({Object.keys(selectedItems).length})
              </Button>
            </div>
          </div>
        )}
      </CardContent>
    </Card>
  )
} 
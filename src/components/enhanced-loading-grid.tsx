import { motion } from "framer-motion"
import { cn } from "@/lib/utils"
import { Skeleton } from "@/components/ui/skeleton"

interface EnhancedLoadingGridProps {
  variant?: 'default' | 'compact' | 'detailed' | 'grid'
  columns?: number
  rows?: number
  className?: string
  showProgress?: boolean
  loadingText?: string
}

export function EnhancedLoadingGrid({ 
  variant = 'default',
  columns = 6,
  rows = 2,
  className,
  showProgress = false,
  loadingText = "正在加载媒体..."
}: EnhancedLoadingGridProps) {
  const totalItems = columns * rows

  // 生成加载项
  const loadingItems = Array.from({ length: totalItems }, (_, index) => index)

  // 动画变体
  const containerVariants = {
    hidden: { opacity: 0 },
    visible: {
      opacity: 1,
      transition: {
        staggerChildren: 0.1,
        delayChildren: 0.2
      }
    }
  }

  const itemVariants = {
    hidden: { 
      opacity: 0, 
      y: 20,
      scale: 0.9
    },
    visible: { 
      opacity: 1, 
      y: 0,
      scale: 1,
      transition: {
        type: "spring",
        stiffness: 100,
        damping: 10
      }
    }
  }

  if (variant === 'compact') {
    return (
      <motion.div 
        className={cn("space-y-3", className)}
        initial="hidden"
        animate="visible"
        variants={containerVariants}
      >
        {loadingItems.map((index) => (
          <motion.div
            key={index}
            variants={itemVariants}
            className="flex items-center p-3 rounded-lg bg-muted/50"
          >
            <Skeleton className="w-16 h-24 rounded-md flex-shrink-0" />
            <div className="ml-4 flex-1 space-y-2">
              <Skeleton className="h-4 w-3/4" />
              <div className="flex items-center gap-2">
                <Skeleton className="h-3 w-12" />
                <Skeleton className="h-3 w-16" />
                <Skeleton className="h-3 w-8" />
              </div>
            </div>
            <Skeleton className="w-8 h-8 rounded-full" />
          </motion.div>
        ))}
      </motion.div>
    )
  }

  if (variant === 'detailed') {
    return (
      <motion.div 
        className={cn("grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6", className)}
        initial="hidden"
        animate="visible"
        variants={containerVariants}
      >
        {loadingItems.slice(0, 6).map((index) => (
          <motion.div
            key={index}
            variants={itemVariants}
            className="relative bg-muted/50 rounded-xl overflow-hidden"
          >
            <Skeleton className="w-full aspect-[16/9]" />
            <div className="absolute bottom-4 left-4 right-4 space-y-2">
              <Skeleton className="h-6 w-3/4" />
              <div className="flex items-center gap-2">
                <Skeleton className="h-4 w-16" />
                <Skeleton className="h-4 w-12" />
                <Skeleton className="h-4 w-20" />
              </div>
              <Skeleton className="h-3 w-full" />
              <Skeleton className="h-3 w-2/3" />
            </div>
          </motion.div>
        ))}
      </motion.div>
    )
  }

  // 默认网格布局
  return (
    <motion.div 
      className={cn("space-y-8", className)}
      initial="hidden"
      animate="visible"
      variants={containerVariants}
    >
      {/* 加载指示器 */}
      <div className="flex items-center justify-center space-x-3">
        <div className="flex space-x-1">
          {[0, 1, 2].map((i) => (
            <motion.div
              key={i}
              className="w-2 h-2 bg-primary rounded-full"
              animate={{
                scale: [1, 1.2, 1],
                opacity: [0.7, 1, 0.7]
              }}
              transition={{
                duration: 1,
                repeat: Infinity,
                delay: i * 0.2
              }}
            />
          ))}
        </div>
        <span className="text-sm text-muted-foreground">{loadingText}</span>
      </div>

      {/* 网格骨架 */}
      <motion.div 
        className={`grid gap-6 grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-${columns} xl:grid-cols-${Math.min(columns + 1, 8)}`}
        variants={containerVariants}
      >
        {loadingItems.map((index) => (
          <motion.div
            key={index}
            variants={itemVariants}
            className="group"
          >
            {/* 海报骨架 */}
            <div className="relative aspect-[2/3] rounded-xl overflow-hidden bg-muted/50">
              <Skeleton className="w-full h-full" />
              
              {/* 模拟评分徽章 */}
              <div className="absolute top-3 left-3">
                <Skeleton className="w-12 h-6 rounded-full" />
              </div>
              
              {/* 模拟播放按钮 */}
              <div className="absolute inset-0 flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity">
                <Skeleton className="w-12 h-12 rounded-full" />
              </div>
              
              {/* 模拟进度条 */}
              {showProgress && (
                <div className="absolute bottom-0 left-0 right-0">
                  <Skeleton className="w-full h-1" />
                </div>
              )}
            </div>

            {/* 标题和信息骨架 */}
            <div className="mt-3 space-y-2">
              <Skeleton className="h-4 w-full" />
              <Skeleton className="h-4 w-3/4" />
              <div className="flex items-center justify-between">
                <div className="flex items-center space-x-2">
                  <Skeleton className="h-3 w-12" />
                  <Skeleton className="h-3 w-16" />
                </div>
                <Skeleton className="h-5 w-8 rounded-full" />
              </div>
            </div>
          </motion.div>
        ))}
      </motion.div>

      {/* 加载统计 */}
      {showProgress && (
        <motion.div 
          className="text-center space-y-2"
          initial={{ opacity: 0, y: 10 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 1 }}
        >
          <div className="w-full bg-muted rounded-full h-2">
            <motion.div
              className="bg-primary h-2 rounded-full"
              initial={{ width: "0%" }}
              animate={{ width: "60%" }}
              transition={{ duration: 2, ease: "easeInOut" }}
            />
          </div>
          <p className="text-sm text-muted-foreground">
            正在处理媒体文件...
          </p>
        </motion.div>
      )}
    </motion.div>
  )
}

// 专门的搜索加载组件
export function SearchLoadingGrid({ query, className }: { query: string, className?: string }) {
  return (
    <motion.div
      className={cn("flex flex-col items-center justify-center py-12 space-y-4", className)}
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      transition={{ duration: 0.5 }}
    >
      {/* 搜索动画 */}
      <div className="relative">
        <motion.div
          className="w-16 h-16 border-4 border-primary/20 border-t-primary rounded-full"
          animate={{ rotate: 360 }}
          transition={{ duration: 1, repeat: Infinity, ease: "linear" }}
        />
        <motion.div
          className="absolute inset-0 w-16 h-16 border-4 border-transparent border-r-primary/40 rounded-full"
          animate={{ rotate: -360 }}
          transition={{ duration: 2, repeat: Infinity, ease: "linear" }}
        />
      </div>

      {/* 搜索文本 */}
      <div className="text-center space-y-2">
        <h3 className="text-lg font-semibold">正在搜索</h3>
        <p className="text-muted-foreground">
          正在查找 "<span className="font-medium">{query}</span>" 的相关内容...
        </p>
      </div>

      {/* 搜索提示 */}
      <motion.div
        className="grid grid-cols-2 md:grid-cols-4 gap-4 mt-8"
        initial="hidden"
        animate="visible"
        variants={{
          hidden: { opacity: 0 },
          visible: {
            opacity: 1,
            transition: {
              staggerChildren: 0.1
            }
          }
        }}
      >
        {[1, 2, 3, 4].map((i) => (
          <motion.div
            key={i}
            className="w-20 h-30 bg-muted/50 rounded-lg"
            variants={{
              hidden: { opacity: 0, scale: 0.8 },
              visible: { opacity: 1, scale: 1 }
            }}
          >
            <Skeleton className="w-full h-full rounded-lg" />
          </motion.div>
        ))}
      </motion.div>
    </motion.div>
  )
}

// 空状态组件
export function EmptyStateGrid({ 
  title = "暂无内容", 
  description = "没有找到任何媒体文件",
  action,
  className 
}: { 
  title?: string
  description?: string
  action?: React.ReactNode
  className?: string 
}) {
  return (
    <motion.div
      className={cn("flex flex-col items-center justify-center py-12 space-y-4", className)}
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.5 }}
    >
      {/* 空状态图标 */}
      <motion.div
        className="w-24 h-24 bg-muted/50 rounded-full flex items-center justify-center"
        initial={{ scale: 0 }}
        animate={{ scale: 1 }}
        transition={{ delay: 0.2, type: "spring", stiffness: 100 }}
      >
        <svg className="w-12 h-12 text-muted-foreground" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M7 4V2a1 1 0 011-1h8a1 1 0 011 1v2m-9 4v10a2 2 0 002 2h6a2 2 0 002-2V8M7 8h10M9 12h6m-6 4h6" />
        </svg>
      </motion.div>

      {/* 文本内容 */}
      <div className="text-center space-y-2">
        <h3 className="text-lg font-semibold">{title}</h3>
        <p className="text-muted-foreground max-w-md">{description}</p>
      </div>

      {/* 操作按钮 */}
      {action && (
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ delay: 0.4 }}
        >
          {action}
        </motion.div>
      )}
    </motion.div>
  )
}
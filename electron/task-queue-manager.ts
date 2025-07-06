import { EventEmitter } from 'events'

export interface Task {
  id: string
  type: 'scan' | 'scrape' | 'download'
  priority: 'high' | 'medium' | 'low'
  data: any
  retries: number
  maxRetries: number
  createdAt: Date
}

export interface TaskProgress {
  taskId: string
  phase: string
  current: number
  total: number
  currentItem?: string
  error?: string
}

export class TaskQueueManager extends EventEmitter {
  private tasks: Map<string, Task> = new Map()
  private runningTasks: Set<string> = new Set()
  private maxConcurrency: number
  private isRunning: boolean = false

  constructor(maxConcurrency: number = 3) {
    super()
    this.maxConcurrency = maxConcurrency
  }

  addTask(task: Omit<Task, 'id' | 'createdAt'>): string {
    const taskId = `${task.type}-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`
    const fullTask: Task = {
      ...task,
      id: taskId,
      createdAt: new Date()
    }
    
    this.tasks.set(taskId, fullTask)
    console.log(`[TaskQueue] Added task ${taskId} of type ${task.type}`)
    
    if (this.isRunning) {
      this.processNextTask()
    }
    
    return taskId
  }

  removeTask(taskId: string): boolean {
    if (this.runningTasks.has(taskId)) {
      console.log(`[TaskQueue] Cannot remove running task ${taskId}`)
      return false
    }
    
    const removed = this.tasks.delete(taskId)
    if (removed) {
      console.log(`[TaskQueue] Removed task ${taskId}`)
    }
    return removed
  }

  start(): void {
    if (this.isRunning) {
      console.log('[TaskQueue] Already running')
      return
    }
    
    this.isRunning = true
    console.log('[TaskQueue] Started')
    this.processQueue()
  }

  stop(): void {
    this.isRunning = false
    console.log('[TaskQueue] Stopped')
  }

  updateProgress(taskId: string, progress: TaskProgress): void {
    this.emit('task:progress', { ...progress })
  }

  completeTask(taskId: string, result: any): void {
    this.runningTasks.delete(taskId)
    this.tasks.delete(taskId)
    
    console.log(`[TaskQueue] Completed task ${taskId}`)
    this.emit('task:completed', { taskId, result })
    
    // 处理下一个任务
    this.processNextTask()
  }

  failTask(taskId: string, error: Error): void {
    const task = this.tasks.get(taskId)
    if (!task) return

    task.retries++
    
    if (task.retries >= task.maxRetries) {
      // 任务失败，移除
      this.runningTasks.delete(taskId)
      this.tasks.delete(taskId)
      console.error(`[TaskQueue] Task ${taskId} failed permanently:`, error.message)
      this.emit('task:failed', { taskId, error: error.message })
    } else {
      // 重试任务
      this.runningTasks.delete(taskId)
      console.log(`[TaskQueue] Retrying task ${taskId} (attempt ${task.retries + 1}/${task.maxRetries})`)
      setTimeout(() => this.processNextTask(), 1000)
    }
    
    // 处理下一个任务
    this.processNextTask()
  }

  getQueueStatus(): {
    totalTasks: number
    runningTasks: number
    pendingTasks: number
    isRunning: boolean
  } {
    return {
      totalTasks: this.tasks.size,
      runningTasks: this.runningTasks.size,
      pendingTasks: this.tasks.size - this.runningTasks.size,
      isRunning: this.isRunning
    }
  }

  getRunningTasks(): Task[] {
    return Array.from(this.runningTasks)
      .map(id => this.tasks.get(id))
      .filter(task => task !== undefined) as Task[]
  }

  private processQueue(): void {
    while (this.isRunning && this.runningTasks.size < this.maxConcurrency) {
      if (!this.processNextTask()) {
        break
      }
    }
  }

  private processNextTask(): boolean {
    if (!this.isRunning || this.runningTasks.size >= this.maxConcurrency) {
      return false
    }

    // 获取下一个待处理的任务（按优先级排序）
    const nextTask = this.getNextTask()
    if (!nextTask) {
      return false
    }

    // 标记任务为运行中
    this.runningTasks.add(nextTask.id)
    console.log(`[TaskQueue] Starting task ${nextTask.id} of type ${nextTask.type}`)
    
    // 发出任务开始事件
    this.emit('task:started', nextTask)
    
    return true
  }

  private getNextTask(): Task | null {
    const pendingTasks = Array.from(this.tasks.values())
      .filter(task => !this.runningTasks.has(task.id))
    
    if (pendingTasks.length === 0) {
      return null
    }

    // 按优先级和创建时间排序
    pendingTasks.sort((a, b) => {
      // 优先级权重
      const priorityWeight = { high: 3, medium: 2, low: 1 }
      const aPriority = priorityWeight[a.priority]
      const bPriority = priorityWeight[b.priority]
      
      if (aPriority !== bPriority) {
        return bPriority - aPriority // 高优先级在前
      }
      
      // 同优先级按创建时间排序
      return a.createdAt.getTime() - b.createdAt.getTime()
    })

    return pendingTasks[0]
  }

  clearAllTasks(): void {
    this.tasks.clear()
    this.runningTasks.clear()
    console.log('[TaskQueue] Cleared all tasks')
  }
}
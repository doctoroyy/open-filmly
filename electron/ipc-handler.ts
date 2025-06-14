/**
 * 类型安全的IPC处理器
 * 提供统一的错误处理和调试功能
 */

import { ipcMain, IpcMainInvokeEvent } from 'electron'
import { IPCChannels, IPCChannelName, IPCResponse, AllIPCTypes } from './ipc-channels'

// 调试模式标志
const DEBUG_IPC = process.env.NODE_ENV === 'development'

// IPC处理器的类型定义
type IPCHandler<T extends IPCChannelName> = (
  event: IpcMainInvokeEvent,
  ...args: any[]
) => Promise<any>

// 注册的处理器映射
const registeredHandlers = new Map<IPCChannelName, Function>()

/**
 * 注册IPC处理器
 * @param channel 通道名称
 * @param handler 处理函数
 */
export function registerIPCHandler<T extends IPCChannelName>(
  channel: T,
  handler: IPCHandler<T>
): void {
  if (registeredHandlers.has(channel)) {
    console.warn(`IPC handler for channel "${channel}" is already registered. Overwriting...`)
  }

  // 包装处理器以添加调试和错误处理
  const wrappedHandler = async (event: IpcMainInvokeEvent, ...args: any[]) => {
    const startTime = Date.now()
    
    if (DEBUG_IPC) {
      console.log(`[IPC] → ${channel}`, args.length > 0 ? args : '(no args)')
    }

    try {
      const result = await handler(event, ...args)
      
      if (DEBUG_IPC) {
        const duration = Date.now() - startTime
        console.log(`[IPC] ← ${channel} (${duration}ms)`, result)
      }
      
      return result
    } catch (error) {
      const duration = Date.now() - startTime
      console.error(`[IPC] ✗ ${channel} (${duration}ms)`, error)
      
      // 返回标准化的错误响应
      return {
        success: false,
        error: error instanceof Error ? error.message : String(error),
        errorType: error instanceof Error && 'code' in error ? (error as any).code : 'unknown'
      } as IPCResponse
    }
  }

  // 注册到electron的ipcMain
  ipcMain.handle(channel, wrappedHandler)
  registeredHandlers.set(channel, wrappedHandler)
  
  if (DEBUG_IPC) {
    console.log(`[IPC] Registered handler for channel: ${channel}`)
  }
}

/**
 * 批量注册IPC处理器
 * @param handlers 处理器映射对象
 */
export function registerIPCHandlers(handlers: Record<string, Function>): void {
  Object.entries(handlers).forEach(([channel, handler]) => {
    registerIPCHandler(channel as IPCChannelName, handler as any)
  })
}

/**
 * 取消注册IPC处理器
 * @param channel 通道名称
 */
export function unregisterIPCHandler(channel: IPCChannelName): void {
  if (registeredHandlers.has(channel)) {
    ipcMain.removeHandler(channel)
    registeredHandlers.delete(channel)
    
    if (DEBUG_IPC) {
      console.log(`[IPC] Unregistered handler for channel: ${channel}`)
    }
  }
}

/**
 * 获取所有已注册的处理器
 */
export function getRegisteredHandlers(): IPCChannelName[] {
  return Array.from(registeredHandlers.keys())
}

/**
 * 清理所有IPC处理器
 */
export function cleanup(): void {
  for (const channel of registeredHandlers.keys()) {
    ipcMain.removeHandler(channel)
  }
  registeredHandlers.clear()
  
  if (DEBUG_IPC) {
    console.log('[IPC] All handlers cleaned up')
  }
}
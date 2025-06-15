/**
 * 错误边界组件
 * 用于捕获和显示React错误
 */

import React from 'react'
import { Button } from '@/components/ui/button'
import { AlertCircle, RefreshCw } from 'lucide-react'

interface ErrorBoundaryState {
  hasError: boolean
  error: Error | null
  errorInfo: React.ErrorInfo | null
}

interface ErrorBoundaryProps {
  children: React.ReactNode
}

export class ErrorBoundary extends React.Component<ErrorBoundaryProps, ErrorBoundaryState> {
  constructor(props: ErrorBoundaryProps) {
    super(props)
    this.state = {
      hasError: false,
      error: null,
      errorInfo: null
    }
  }

  static getDerivedStateFromError(error: Error): Partial<ErrorBoundaryState> {
    return {
      hasError: true,
      error
    }
  }

  componentDidCatch(error: Error, errorInfo: React.ErrorInfo) {
    console.error('[ErrorBoundary] Caught an error:', error, errorInfo)
    this.setState({
      error,
      errorInfo
    })
  }

  handleReload = () => {
    window.location.reload()
  }

  handleReset = () => {
    this.setState({
      hasError: false,
      error: null,
      errorInfo: null
    })
  }

  render() {
    if (this.state.hasError) {
      return (
        <div className="min-h-screen bg-background flex items-center justify-center p-8">
          <div className="max-w-md w-full bg-card border rounded-lg p-6 text-center">
            <AlertCircle className="h-12 w-12 text-destructive mx-auto mb-4" />
            
            <h1 className="text-2xl font-bold mb-2">出现错误</h1>
            
            <p className="text-muted-foreground mb-4">
              应用程序遇到了一个意外错误。我们已经记录了此错误。
            </p>

            {this.state.error && (
              <div className="bg-muted p-3 rounded text-left mb-4">
                <p className="text-sm font-medium">错误详情：</p>
                <p className="text-xs text-muted-foreground mt-1 break-all">
                  {this.state.error.message}
                </p>
              </div>
            )}

            <div className="flex gap-2 justify-center">
              <Button onClick={this.handleReset} variant="outline">
                重试
              </Button>
              
              <Button onClick={this.handleReload}>
                <RefreshCw className="h-4 w-4 mr-2" />
                重新加载
              </Button>
            </div>

            {process.env.NODE_ENV === 'development' && this.state.errorInfo && (
              <details className="mt-4 text-left">
                <summary className="text-sm font-medium cursor-pointer">
                  技术详情 (开发模式)
                </summary>
                <pre className="text-xs bg-muted p-2 rounded mt-2 overflow-auto">
                  {this.state.errorInfo.componentStack}
                </pre>
              </details>
            )}
          </div>
        </div>
      )
    }

    return this.props.children
  }
}
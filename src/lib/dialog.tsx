import React, { createContext, useContext, useState, ReactNode } from 'react'
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
  DialogFooter,
} from "@/components/ui/dialog"
import { Button } from "@/components/ui/button"

interface DialogOptions {
  title: string
  content: ReactNode
  description?: string
  confirmText?: string
  cancelText?: string
  onConfirm?: () => void
  onCancel?: () => void
}

interface DialogContextType {
  open: (options: DialogOptions) => void
  close: () => void
}

const DialogContext = createContext<DialogContextType>({
  open: () => {},
  close: () => {},
})

export const useDialog = () => useContext(DialogContext)

export const DialogProvider: React.FC<{ children: ReactNode }> = ({ children }) => {
  const [isOpen, setIsOpen] = useState(false)
  const [options, setOptions] = useState<DialogOptions>({
    title: '',
    content: null,
  })

  const open = (dialogOptions: DialogOptions) => {
    setOptions(dialogOptions)
    setIsOpen(true)
  }

  const close = () => {
    setIsOpen(false)
  }

  const handleConfirm = () => {
    if (options.onConfirm) {
      options.onConfirm()
    }
    close()
  }

  const handleCancel = () => {
    if (options.onCancel) {
      options.onCancel()
    }
    close()
  }

  return (
    <DialogContext.Provider value={{ open, close }}>
      {children}
      <Dialog open={isOpen} onOpenChange={setIsOpen}>
        <DialogContent className="bg-gray-900 border-gray-800">
          <DialogHeader>
            <DialogTitle>{options.title}</DialogTitle>
            {options.description && (
              <DialogDescription>{options.description}</DialogDescription>
            )}
          </DialogHeader>
          <div>{options.content}</div>
          <DialogFooter>
            {(options.onCancel || options.cancelText) && (
              <Button variant="outline" onClick={handleCancel}>
                {options.cancelText || '取消'}
              </Button>
            )}
            {(options.onConfirm || options.confirmText) && (
              <Button onClick={handleConfirm}>
                {options.confirmText || '确认'}
              </Button>
            )}
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </DialogContext.Provider>
  )
}

// Export a singleton instance for direct use
export const dialog: DialogContextType = {
  open: () => {
    console.warn('DialogProvider not mounted. Make sure it is mounted at the root of your app.')
  },
  close: () => {
    console.warn('DialogProvider not mounted. Make sure it is mounted at the root of your app.')
  },
}

// Set the real implementation when the provider is mounted
export const initializeDialog = (contextValue: DialogContextType) => {
  dialog.open = contextValue.open
  dialog.close = contextValue.close
} 
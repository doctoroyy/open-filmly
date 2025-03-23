import type React from "react"
import "./globals.css"
import type { Metadata } from "next"
import { ThemeProvider } from "@/components/theme-provider"


export const metadata: Metadata = {
  title: "Open Filmly (Beta)",
  description: "Open Filmly is a media management platform similar to Plex, Emby, or Jellyfin that helps you organize and stream your media library with automatic categorization, poster fetching, and metadata retrieval. Currently in beta - some features under development.",
  metadataBase: new URL('file://'),
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="zh-CN" suppressHydrationWarning>
      <body>
        <ThemeProvider attribute="class" defaultTheme="dark" enableSystem disableTransitionOnChange>
          {children}
        </ThemeProvider>
      </body>
    </html>
  )
}


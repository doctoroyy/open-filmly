import Link from "next/link"
import { Suspense } from "react"
import { Settings } from "lucide-react"
import { MediaGrid } from "@/components/media-grid"
import { LoadingGrid } from "@/components/loading-grid"
import { Button } from "@/components/ui/button"

export default function HomePage() {
  return (
    <main className="min-h-screen bg-black text-white">
      <div className="container mx-auto px-4 py-8">
        <div className="flex justify-between items-center mb-8">
          <h1 className="text-3xl font-bold">我的媒体库</h1>
          <Link href="/config">
            <Button variant="outline" size="icon">
              <Settings className="h-5 w-5" />
              <span className="sr-only">设置</span>
            </Button>
          </Link>
        </div>

        <div className="mb-6">
          <div className="flex items-center space-x-4 mb-4">
            <h2 className="text-2xl font-semibold">电影</h2>
            <div className="flex-1 h-px bg-gray-800"></div>
          </div>
          <Suspense fallback={<LoadingGrid />}>
            <MediaGrid type="movie" />
          </Suspense>
        </div>

        <div className="mb-6">
          <div className="flex items-center space-x-4 mb-4">
            <h2 className="text-2xl font-semibold">电视剧</h2>
            <div className="flex-1 h-px bg-gray-800"></div>
          </div>
          <Suspense fallback={<LoadingGrid />}>
            <MediaGrid type="tv" />
          </Suspense>
        </div>
      </div>
    </main>
  )
}


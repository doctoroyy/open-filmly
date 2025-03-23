import { Card, CardContent } from "@/components/ui/card"

export function LoadingGrid() {
  return (
    <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-6 gap-4">
      {Array.from({ length: 12 }).map((_, index) => (
        <Card key={index} className="overflow-hidden h-full bg-gray-900 border-gray-800">
          <div className="relative aspect-[2/3] w-full">
            <div className="absolute inset-0 bg-gray-800 animate-pulse" />
          </div>
          <CardContent className="p-3">
            <div className="h-4 bg-gray-800 rounded animate-pulse mb-2" />
            <div className="h-3 bg-gray-800 rounded animate-pulse w-1/2" />
          </CardContent>
        </Card>
      ))}
    </div>
  )
}


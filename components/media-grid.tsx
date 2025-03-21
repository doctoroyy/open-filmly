import { getMediaFromSamba } from "@/lib/samba-client"
import { MediaCard } from "./media-card"

interface MediaGridProps {
  type: "movie" | "tv"
}

export async function MediaGrid({ type }: MediaGridProps) {
  const media = await getMediaFromSamba(type)

  return (
    <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-6 gap-4">
      {media.map((item) => (
        <MediaCard key={item.id} media={item} />
      ))}
    </div>
  )
}


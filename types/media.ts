export interface MediaItem {
  id: string
  title: string
  year: string
  posterUrl: string
  path: string
  rating?: string
}

export interface Media {
  id: string
  title: string
  year: string
  type: "movie" | "tv"
  path: string
  posterPath?: string | null
  rating?: string
  dateAdded: string
  lastUpdated: string
}


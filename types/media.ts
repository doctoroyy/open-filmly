export interface MediaItem {
  id: string
  title: string
  year: string
  posterUrl: string
  path: string
  rating?: string
  type?: "movie" | "tv"
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

export interface DataSource {
  id: string
  name: string
  ip: string
  path: string
  username?: string
  password?: string
  dateAdded: string
  lastScanned?: string
}


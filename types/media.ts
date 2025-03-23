export interface MediaItem {
  id: string
  title: string
  year: string
  posterUrl: string
  path: string
  fullPath?: string
  rating?: string
  type?: "movie" | "tv" | "unknown"
}

export interface MediaEpisode {
  path: string
  name: string
  season: number
  episode: number
}

export interface Media {
  id: string
  title: string
  year: string
  type: "movie" | "tv" | "unknown"
  path: string
  fullPath?: string
  posterPath?: string | null
  rating?: string
  details?: string
  dateAdded: string
  lastUpdated: string
  episodeCount?: number
  episodes?: MediaEpisode[]
  seasons?: number[]
  overview?: string
  backdropPath?: string
  releaseDate?: string
  genres?: string[]
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


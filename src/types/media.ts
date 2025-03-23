export interface MediaEpisode {
  path: string
  name: string
  season: number
  episode: number
}

export interface Media {
  id: string
  title: string
  originalTitle?: string
  year?: string
  type: 'movie' | 'tv' | 'unknown'
  posterPath?: string
  backdropPath?: string
  overview?: string
  releaseDate?: string
  genres?: string[]
  rating?: number
  filePath?: string
  path?: string
  fileSize?: number
  lastModified?: number
  dateAdded?: string
  lastUpdated?: string
  details?: string
  
  // TV series specific fields
  episodeCount?: number
  episodes?: MediaEpisode[]
  seasons?: number[]
} 
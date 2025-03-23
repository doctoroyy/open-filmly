export interface Media {
  id: string
  title: string
  originalTitle?: string
  year?: string
  type: 'movie' | 'tv'
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
} 
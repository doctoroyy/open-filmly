import axios from 'axios';

// Create a base axios instance for TMDB API
const tmdbApi = axios.create({
  baseURL: 'https://api.themoviedb.org/3',
  params: {
    language: 'zh-CN',  // Set to Chinese language
  },
});

// Add API key to requests dynamically
const getApiKey = async (): Promise<string> => {
  try {
    console.log('[API] Attempting to get TMDB API key...');
    
    // First try to get from electron store (primary source)
    if (window.electronAPI?.getTmdbApiKey) {
      const result = await window.electronAPI.getTmdbApiKey();
      console.log('[API] Electron API result:', result);
      
      if (result?.success && result.data?.apiKey) {
        console.log(`[API] Got API key from Electron: ${result.data.apiKey.substring(0, 5)}...`);
        return result.data.apiKey;
      }
    }

    // Fallback to environment variable for development
    const envApiKey = (import.meta as any).env?.VITE_TMDB_API_KEY;
    if (envApiKey) {
      console.log(`[API] Got API key from environment: ${envApiKey.substring(0, 5)}...`);
      return envApiKey;
    }
    
    console.log('[API] No API key found');
    return '';
  } catch (error) {
    console.error('[API] Error getting API key:', error);
    return '';
  }
};

// Add request interceptor to include API key
tmdbApi.interceptors.request.use(async (config) => {
  const apiKey = await getApiKey();
  if (apiKey) {
    config.params = {
      ...config.params,
      api_key: apiKey,
    };
    console.log(`[API] Request to ${config.url} with API key: ${apiKey.substring(0, 5)}...`);
  } else {
    console.warn(`[API] Request to ${config.url} without API key!`);
  }
  return config;
});

// Get trending movies
export const getTrendingMovies = async () => {
  try {
    const response = await tmdbApi.get('/trending/movie/week');
    return response.data.results;
  } catch (error) {
    console.error('Error fetching trending movies:', error);
    return [];
  }
};

// Get trending TV shows
export const getTrendingTVShows = async () => {
  try {
    const response = await tmdbApi.get('/trending/tv/week');
    return response.data.results;
  } catch (error) {
    console.error('Error fetching trending TV shows:', error);
    return [];
  }
};

// Search for movies
export const searchMovies = async (query: string) => {
  try {
    const response = await tmdbApi.get('/search/movie', {
      params: { query }
    });
    return response.data.results;
  } catch (error) {
    console.error('Error searching movies:', error);
    return [];
  }
};

// Search for TV shows
export const searchTVShows = async (query: string) => {
  try {
    const response = await tmdbApi.get('/search/tv', {
      params: { query }
    });
    return response.data.results;
  } catch (error) {
    console.error('Error searching TV shows:', error);
    return [];
  }
};

// Get movie details
export const getMovieDetails = async (id: number) => {
  try {
    const response = await tmdbApi.get(`/movie/${id}`, {
      params: { append_to_response: 'credits,videos,images' }
    });
    return response.data;
  } catch (error) {
    console.error('Error fetching movie details:', error);
    return null;
  }
};

// Get TV show details
export const getTVShowDetails = async (id: number) => {
  try {
    const response = await tmdbApi.get(`/tv/${id}`, {
      params: { append_to_response: 'credits,videos,images' }
    });
    return response.data;
  } catch (error) {
    console.error('Error fetching TV show details:', error);
    return null;
  }
};

// Find TMDB item by title and year
export const searchTMDBByTitleAndYear = async (title: string, year: string, type: 'movie' | 'tv') => {
  try {
    console.log(`[API] Searching TMDB for ${type}: "${title}" (${year})`)
    
    // Generate search variations for better matching
    const searchTitles = [title]
    
    // If title seems incomplete (less than 3 words and doesn't end with common words)
    if (title.split(' ').length < 3 && !title.match(/\b(the|of|in|and|or|for|to)\b$/i)) {
      // Try some common completions
      searchTitles.push(title + ' Nation') // For "Hated in the" -> "Hated in the Nation"
      searchTitles.push(title + ' City')
      searchTitles.push(title + ' World')
    }
    
    // For TV shows, also try searching for series names extracted from path
    if (type === 'tv') {
      // Extract potential series names from common patterns
      const pathBasedTitles = extractSeriesNamesFromTitle(title)
      searchTitles.push(...pathBasedTitles)
    }
    
    // Remove duplicates
    const uniqueTitles = [...new Set(searchTitles)]
    
    let bestMatch = null
    let allResults: any[] = []
    
    // Try each title variation
    for (const searchTitle of uniqueTitles) {
      console.log(`[API] Trying search with: "${searchTitle}"`)
      
      let searchResults = []
      if (type === 'movie') {
        searchResults = await searchMovies(searchTitle)
      } else {
        searchResults = await searchTVShows(searchTitle)
      }
      
      allResults.push(...searchResults)
      
      if (searchResults.length > 0) {
        // Find best match by title and year
        let currentBest = searchResults[0] // Default to first result
        
        // Try to find exact match by year if provided
        if (year && year !== '未知') {
          const yearMatch = searchResults.find((item: any) => {
            const itemYear = type === 'movie' 
              ? item.release_date?.substring(0, 4)
              : item.first_air_date?.substring(0, 4)
            return itemYear === year
          })
          if (yearMatch) {
            currentBest = yearMatch
          }
        }
        
        // Use this as best match if we haven't found one yet
        if (!bestMatch) {
          bestMatch = currentBest
        }
        
        // If this search was more specific (exact title match), prefer it
        if (searchTitle === title) {
          bestMatch = currentBest
          break
        }
      }
    }
    
    if (!bestMatch && allResults.length > 0) {
      bestMatch = allResults[0]
    }
    
    if (!bestMatch) {
      console.log('[API] No search results found for any title variation')
      return null
    }
    
    console.log(`[API] Best match found: ${bestMatch.title || bestMatch.name} (ID: ${bestMatch.id})`)
    
    // Get detailed information with cast
    if (type === 'movie') {
      return await getMovieDetails(bestMatch.id)
    } else {
      return await getTVShowDetails(bestMatch.id)
    }
  } catch (error) {
    console.error('[API] Error searching TMDB:', error)
    return null
  }
}

// Helper function to extract series names from title
const extractSeriesNamesFromTitle = (title: string): string[] => {
  const variations = []
  
  // Common series name patterns
  if (title.includes('Black Mirror') || title.includes('黑镜')) {
    variations.push('Black Mirror')
  }
  if (title.includes('Witcher')) {
    variations.push('The Witcher')
  }
  if (title.includes('Game of Thrones') || title.includes('权力的游戏')) {
    variations.push('Game of Thrones')
  }
  
  return variations
}

// Map TMDB data to our Media type
export const mapTMDBToMedia = (item: any, type: 'movie' | 'tv') => {
  return {
    id: item.id.toString(),
    title: type === 'movie' ? item.title : item.name,
    originalTitle: type === 'movie' ? item.original_title : item.original_name,
    year: type === 'movie' 
      ? item.release_date ? item.release_date.substring(0, 4) : ''
      : item.first_air_date ? item.first_air_date.substring(0, 4) : '',
    type,
    posterPath: item.poster_path ? `https://image.tmdb.org/t/p/w500${item.poster_path}` : undefined,
    backdropPath: item.backdrop_path ? `https://image.tmdb.org/t/p/original${item.backdrop_path}` : undefined,
    overview: item.overview,
    releaseDate: type === 'movie' ? item.release_date : item.first_air_date,
    genres: item.genres ? item.genres.map((g: any) => g.name) : [],
    rating: item.vote_average,
    filePath: '', // This would come from your local database
    cast: item.credits?.cast ? item.credits.cast.slice(0, 10).map((actor: any) => ({
      id: actor.id,
      name: actor.name,
      character: actor.character,
      profile_path: actor.profile_path ? `https://image.tmdb.org/t/p/w185${actor.profile_path}` : undefined,
      order: actor.order
    })) : [],
    crew: item.credits?.crew ? item.credits.crew.filter((member: any) => 
      ['Director', 'Producer', 'Writer', 'Screenplay'].includes(member.job)
    ).map((member: any) => ({
      id: member.id,
      name: member.name,
      job: member.job,
      department: member.department,
      profile_path: member.profile_path ? `https://image.tmdb.org/t/p/w185${member.profile_path}` : undefined
    })) : []
  };
}; 
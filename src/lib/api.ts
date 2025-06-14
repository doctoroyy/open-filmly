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
  };
}; 
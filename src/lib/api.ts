import axios from 'axios';

// Create a base axios instance for TMDB API
const tmdbApi = axios.create({
  baseURL: 'https://api.themoviedb.org/3',
  params: {
    api_key: process.env.NEXT_PUBLIC_TMDB_API_KEY || '',  // TMDB API key should be added to your .env file
    language: 'zh-CN',  // Set to Chinese language
  },
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
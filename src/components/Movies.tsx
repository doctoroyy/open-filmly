import React, { useEffect, useState } from 'react'
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'

interface Movie {
  id: number
  title: string
  year: string
  rating: string
  poster: string
  plot: string
}

const Movies: React.FC = () => {
  const [movies, setMovies] = useState<Movie[]>([])
  const [loading, setLoading] = useState<boolean>(true)
  const [searchTerm, setSearchTerm] = useState<string>('')

  useEffect(() => {
    // Mock data for now, would be replaced with API call
    const mockMovies: Movie[] = [
      {
        id: 1,
        title: "The Shawshank Redemption",
        year: "1994",
        rating: "9.3",
        poster: "https://m.media-amazon.com/images/M/MV5BNDE3ODcxYzMtY2YzZC00NmNlLWJiNDMtZDViZWM2MzIxZDYwXkEyXkFqcGdeQXVyNjAwNDUxODI@._V1_SX300.jpg",
        plot: "Two imprisoned men bond over a number of years, finding solace and eventual redemption through acts of common decency."
      },
      {
        id: 2,
        title: "The Godfather",
        year: "1972",
        rating: "9.2",
        poster: "https://m.media-amazon.com/images/M/MV5BM2MyNjYxNmUtYTAwNi00MTYxLWJmNWYtYzZlODY3ZTk3OTFlXkEyXkFqcGdeQXVyNzkwMjQ5NzM@._V1_SX300.jpg",
        plot: "The aging patriarch of an organized crime dynasty transfers control of his clandestine empire to his reluctant son."
      },
      {
        id: 3,
        title: "The Dark Knight",
        year: "2008",
        rating: "9.0",
        poster: "https://m.media-amazon.com/images/M/MV5BMTMxNTMwODM0NF5BMl5BanBnXkFtZTcwODAyMTk2Mw@@._V1_SX300.jpg",
        plot: "When the menace known as the Joker wreaks havoc and chaos on the people of Gotham, Batman must accept one of the greatest psychological and physical tests of his ability to fight injustice."
      }
    ]

    setTimeout(() => {
      setMovies(mockMovies)
      setLoading(false)
    }, 1000)
  }, [])

  const filteredMovies = movies.filter(movie => 
    movie.title.toLowerCase().includes(searchTerm.toLowerCase())
  )

  return (
    <div className="container mx-auto py-8">
      <h1 className="text-3xl font-bold mb-8 text-center">Filmly</h1>
      
      <div className="mb-6">
        <Input
          type="text"
          placeholder="Search movies..."
          value={searchTerm}
          onChange={(e) => setSearchTerm(e.target.value)}
          className="max-w-md mx-auto"
        />
      </div>

      {loading ? (
        <div className="text-center">Loading movies...</div>
      ) : filteredMovies.length > 0 ? (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {filteredMovies.map((movie) => (
            <Card key={movie.id} className="h-full flex flex-col">
              <CardHeader>
                <CardTitle>{movie.title}</CardTitle>
                <CardDescription>{movie.year} • Rating: {movie.rating}</CardDescription>
              </CardHeader>
              <CardContent className="flex-grow">
                <div className="flex flex-col items-center mb-4">
                  <img 
                    src={movie.poster} 
                    alt={`${movie.title} poster`} 
                    className="h-64 object-cover rounded-md shadow-md"
                  />
                </div>
                <p className="text-sm">{movie.plot}</p>
              </CardContent>
              <CardFooter>
                <Button className="w-full">View Details</Button>
              </CardFooter>
            </Card>
          ))}
        </div>
      ) : (
        <div className="text-center">No movies found. Try a different search term.</div>
      )}
    </div>
  )
}

export default Movies 
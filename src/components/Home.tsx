import React from 'react'
import Movies from './Movies'

const Home: React.FC = () => {
  return (
    <div className="min-h-screen bg-gradient-to-b from-gray-100 to-gray-200 dark:from-gray-800 dark:to-gray-900">
      <div className="container mx-auto px-4">
        <Movies />
      </div>
    </div>
  )
}

export default Home 
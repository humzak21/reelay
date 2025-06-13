//
//  Statistics.swift
//  reelay
//
//  Created by Humza Khalil on 6/11/25.
//

struct DashboardStats: Codable {
    let totalFilms: Int
    let uniqueFilms: Int
    let avgRating: Double
    let totalRatings: Int
    let filmsThisYear: Int
    let topGenre: String?
    let topDirector: String?
    let favoriteDay: String?
    
    enum CodingKeys: String, CodingKey {
        case totalFilms = "total_films"
        case uniqueFilms = "unique_films"
        case avgRating = "avg_rating"
        case totalRatings = "total_ratings"
        case filmsThisYear = "films_this_year"
        case topGenre = "top_genre"
        case topDirector = "top_director"
        case favoriteDay = "favorite_day"
    }
}

struct RatingDistribution: Codable {
    let ratingValue: Double
    let countFilms: Int
    let percentage: Double
    
    enum CodingKeys: String, CodingKey {
        case ratingValue = "rating_value"
        case countFilms = "count_films"
        case percentage
    }
}

struct GenreStats: Codable {
    let genreName: String
    let filmCount: Int
    let percentage: Double
    
    enum CodingKeys: String, CodingKey {
        case genreName = "genre_name"
        case filmCount = "film_count"
        case percentage
    }
}

struct FilmsPerYear: Codable {
    let year: Int
    let filmCount: Int
    let uniqueFilms: Int
    
    enum CodingKeys: String, CodingKey {
        case year
        case filmCount = "film_count"
        case uniqueFilms = "unique_films"
    }
}

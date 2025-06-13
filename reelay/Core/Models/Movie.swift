//
//  Movie.swift
//  reelay
//
//  Created by Humza Khalil on 6/11/25.
//

import Foundation

struct Movie: Codable, Identifiable {
    let id: Int
    let title: String
    let rating: Double?
    let detailedRating: Double?
    let watchDate: Date?
    let isRewatch: Bool
    let notes: String?
    let tags: [String]?
    let releaseDate: Date?
    let releaseYear: Int?
    let runtime: Int?
    let overview: String?
    let posterURL: String?
    let backdropURL: String?
    let voteAverage: Double?
    let tmdbID: Int?
    let director: String?
    let genres: [Genre]?
    let reviews: String?
    
    enum CodingKeys: String, CodingKey {
        case id, title, rating, notes, tags, overview, director, genres, reviews
        case detailedRating = "detailed_rating"
        case watchDate = "watch_date"
        case isRewatch = "is_rewatch"
        case releaseDate = "release_date"
        case releaseYear = "release_year"
        case runtime, posterURL = "poster_url"
        case backdropURL = "backdrop_url"
        case voteAverage = "vote_average"
        case tmdbID = "tmdb_id"
    }
    
    // Manual initializer for creating Movie instances
    init(id: Int, title: String, rating: Double? = nil, detailedRating: Double? = nil, 
         watchDate: Date? = nil, isRewatch: Bool = false, notes: String? = nil, 
         tags: [String]? = nil, releaseDate: Date? = nil, releaseYear: Int? = nil, 
         runtime: Int? = nil, overview: String? = nil, posterURL: String? = nil, 
         backdropURL: String? = nil, voteAverage: Double? = nil, tmdbID: Int? = nil, 
         director: String? = nil, genres: [Genre]? = nil, reviews: String? = nil) {
        self.id = id
        self.title = title
        self.rating = rating
        self.detailedRating = detailedRating
        self.watchDate = watchDate
        self.isRewatch = isRewatch
        self.notes = notes
        self.tags = tags
        self.releaseDate = releaseDate
        self.releaseYear = releaseYear
        self.runtime = runtime
        self.overview = overview
        self.posterURL = posterURL
        self.backdropURL = backdropURL
        self.voteAverage = voteAverage
        self.tmdbID = tmdbID
        self.director = director
        self.genres = genres
        self.reviews = reviews
    }
    
    // Custom initializer to handle tags field
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(Int.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        rating = try container.decodeIfPresent(Double.self, forKey: .rating)
        detailedRating = try container.decodeIfPresent(Double.self, forKey: .detailedRating)
        isRewatch = try container.decode(Bool.self, forKey: .isRewatch)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        releaseYear = try container.decodeIfPresent(Int.self, forKey: .releaseYear)
        runtime = try container.decodeIfPresent(Int.self, forKey: .runtime)
        overview = try container.decodeIfPresent(String.self, forKey: .overview)
        posterURL = try container.decodeIfPresent(String.self, forKey: .posterURL)
        backdropURL = try container.decodeIfPresent(String.self, forKey: .backdropURL)
        voteAverage = try container.decodeIfPresent(Double.self, forKey: .voteAverage)
        tmdbID = try container.decodeIfPresent(Int.self, forKey: .tmdbID)
        director = try container.decodeIfPresent(String.self, forKey: .director)
        genres = try container.decodeIfPresent([Genre].self, forKey: .genres)
        reviews = try container.decodeIfPresent(String.self, forKey: .reviews)
        
        // Create date formatter for API date strings
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        // Handle watchDate with proper date decoding
        if let watchDateString = try container.decodeIfPresent(String.self, forKey: .watchDate) {
            watchDate = dateFormatter.date(from: watchDateString)
        } else {
            watchDate = nil
        }
        
        // Handle releaseDate with proper date decoding
        if let releaseDateString = try container.decodeIfPresent(String.self, forKey: .releaseDate) {
            releaseDate = dateFormatter.date(from: releaseDateString)
        } else {
            releaseDate = nil
        }
        
        // Custom handling for tags field - can be string or null
        if let tagsString = try container.decodeIfPresent(String.self, forKey: .tags) {
            // Split comma-separated string into array, trim whitespace
            tags = tagsString.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        } else {
            tags = nil
        }
    }
}

struct Genre: Codable, Identifiable {
    let id: Int?
    let name: String
}

struct MovieResponse: Codable {
    let success: Bool
    let data: [Movie]
    let pagination: Pagination?
}

struct Pagination: Codable {
    let page: Int
    let limit: Int
    let total: Int
    let totalPages: Int
    let hasNextPage: Bool
    let hasPreviousPage: Bool
}

// MARK: - TMDB Models
struct TMDBMovie: Codable, Identifiable {
    let id: Int
    let title: String
    let overview: String?
    let releaseDate: String?
    let posterPath: String?
    let backdropPath: String?
    let voteAverage: Double
    let voteCount: Int
    let genreIds: [Int]?
    
    enum CodingKeys: String, CodingKey {
        case id, title, overview
        case releaseDate = "release_date"
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case voteAverage = "vote_average"
        case voteCount = "vote_count"
        case genreIds = "genre_ids"
    }
    
    var fullPosterURL: String? {
        guard let posterPath = posterPath else { return nil }
        return "https://image.tmdb.org/t/p/w500\(posterPath)"
    }
    
    var fullBackdropURL: String? {
        guard let backdropPath = backdropPath else { return nil }
        return "https://image.tmdb.org/t/p/w1280\(backdropPath)"
    }
    
    var releaseYear: Int? {
        guard let releaseDate = releaseDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: releaseDate)?.year
    }
}

struct TMDBSearchResponse: Codable {
    let page: Int
    let results: [TMDBMovie]
    let totalPages: Int
    let totalResults: Int
    
    enum CodingKeys: String, CodingKey {
        case page, results
        case totalPages = "total_pages"
        case totalResults = "total_results"
    }
}

struct TMDBMovieDetails: Codable {
    let id: Int
    let title: String
    let overview: String?
    let releaseDate: String?
    let runtime: Int?
    let posterPath: String?
    let backdropPath: String?
    let voteAverage: Double
    let genres: [TMDBGenre]
    let credits: TMDBCredits?
    
    enum CodingKeys: String, CodingKey {
        case id, title, overview, runtime, genres, credits
        case releaseDate = "release_date"
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case voteAverage = "vote_average"
    }
    
    var director: String? {
        return credits?.crew.first { $0.job == "Director" }?.name
    }
    
    var fullPosterURL: String? {
        guard let posterPath = posterPath else { return nil }
        return "https://image.tmdb.org/t/p/w500\(posterPath)"
    }
    
    var fullBackdropURL: String? {
        guard let backdropPath = backdropPath else { return nil }
        return "https://image.tmdb.org/t/p/w1280\(backdropPath)"
    }
    
    var releaseYear: Int? {
        guard let releaseDate = releaseDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: releaseDate)?.year
    }
}

struct TMDBGenre: Codable {
    let id: Int
    let name: String
}

struct TMDBCredits: Codable {
    let crew: [TMDBCrewMember]
}

struct TMDBCrewMember: Codable {
    let id: Int
    let name: String
    let job: String
}

// MARK: - Extensions
extension Date {
    var year: Int {
        return Calendar.current.component(.year, from: self)
    }
}

//
//  StatisticsModels.swift
//  reelay2
//
//  Created by Humza Khalil on 7/31/25.
//

import Foundation

// MARK: - Dashboard Statistics
struct DashboardStats: Codable, Sendable {
    let totalMovies: Int
    let totalRewatches: Int
    let averageRating: Double?
    let moviesThisYear: Int
    let favoriteGenre: String?
    let totalWatchTime: Int?
    
    enum CodingKeys: String, CodingKey {
        case totalMovies = "total_movies"
        case totalRewatches = "total_rewatches"
        case averageRating = "average_rating"
        case moviesThisYear = "movies_this_year"
        case favoriteGenre = "favorite_genre"
        case totalWatchTime = "total_watch_time"
    }
}

// MARK: - Rating Statistics
struct RatingDistribution: Codable, Sendable {
    let rating: String
    let count: Int
}

struct RatingStats: Codable, Sendable {
    let averageRating: Double?
    let medianRating: Double?
    let mostCommonRating: Double?
    let totalRated: Int
    
    enum CodingKeys: String, CodingKey {
        case averageRating = "average_rating"
        case medianRating = "median_rating"
        case mostCommonRating = "most_common_rating"
        case totalRated = "total_rated"
    }
}

// MARK: - Time-based Statistics
struct FilmsPerYear: Codable, Sendable {
    let year: String
    let count: Int
}

struct FilmsPerMonth: Codable, Sendable {
    let month: String
    let count: Int
}

struct DailyWatchCount: Codable, Sendable {
    let date: String
    let count: Int
}

struct DayOfWeekPattern: Codable, Sendable {
    let dayOfWeek: String
    let count: Int
    
    enum CodingKeys: String, CodingKey {
        case dayOfWeek = "day_of_week"
        case count
    }
}

struct SeasonalPattern: Codable, Sendable {
    let season: String
    let count: Int
}

struct FilmsByDecade: Codable, Sendable {
    let decade: String
    let count: Int
}

// MARK: - Genre Statistics
struct GenreStats: Codable, Sendable {
    let genre: String
    let count: Int
    let averageRating: Double?
    
    enum CodingKeys: String, CodingKey {
        case genre
        case count
        case averageRating = "average_rating"
    }
}

// MARK: - Director Statistics
struct DirectorStats: Codable, Sendable {
    let director: String
    let count: Int
    let averageRating: Double?
    
    enum CodingKeys: String, CodingKey {
        case director
        case count
        case averageRating = "average_rating"
    }
}

// MARK: - Runtime Statistics
struct RuntimeDistribution: Codable, Sendable {
    let runtimeRange: String
    let count: Int
    
    enum CodingKeys: String, CodingKey {
        case runtimeRange = "runtime_range"
        case count
    }
}

struct RuntimeStats: Codable, Sendable {
    let averageRuntime: Double?
    let totalRuntime: Int?
    let longestMovie: String?
    let shortestMovie: String?
    
    enum CodingKeys: String, CodingKey {
        case averageRuntime = "average_runtime"
        case totalRuntime = "total_runtime"
        case longestMovie = "longest_movie"
        case shortestMovie = "shortest_movie"
    }
}

// MARK: - Release Year Analysis
struct ReleaseYearAnalysis: Codable, Sendable {
    let releaseYear: Int
    let count: Int
    let averageRating: Double?
    
    enum CodingKeys: String, CodingKey {
        case releaseYear = "release_year"
        case count
        case averageRating = "average_rating"
    }
}

// MARK: - Rewatch Statistics
struct RewatchStats: Codable, Sendable {
    let totalRewatches: Int
    let rewatchPercentage: Double?
    let mostRewatchedMovie: String?
    
    enum CodingKeys: String, CodingKey {
        case totalRewatches = "total_rewatches"
        case rewatchPercentage = "rewatch_percentage"
        case mostRewatchedMovie = "most_rewatched_movie"
    }
}

// MARK: - Viewing Session Statistics
struct ViewingSessions: Codable, Sendable {
    let totalSessions: Int
    let averageSessionLength: Double?
    
    enum CodingKeys: String, CodingKey {
        case totalSessions = "total_sessions"
        case averageSessionLength = "average_session_length"
    }
}

// MARK: - Film Count Statistics
struct UniqueFilmsCount: Codable, Sendable {
    let uniqueFilms: Int
    let totalEntries: Int
    
    enum CodingKeys: String, CodingKey {
        case uniqueFilms = "unique_films"
        case totalEntries = "total_entries"
    }
}

// MARK: - Watch Span
struct WatchSpan: Codable, Sendable {
    let firstWatch: String?
    let lastWatch: String?
    let spanDays: Int?
    
    enum CodingKeys: String, CodingKey {
        case firstWatch = "first_watch"
        case lastWatch = "last_watch"
        case spanDays = "span_days"
    }
}

// MARK: - Earliest and Latest Films
struct EarliestLatestFilms: Codable, Sendable {
    let earliestFilm: String?
    let earliestYear: Int?
    let latestFilm: String?
    let latestYear: Int?
    
    enum CodingKeys: String, CodingKey {
        case earliestFilm = "earliest_film"
        case earliestYear = "earliest_year"
        case latestFilm = "latest_film"
        case latestYear = "latest_year"
    }
}

// MARK: - Logging Period Statistics
struct FilmsLoggedPeriod: Codable, Sendable {
    let date: String
    let count: Int
}

// MARK: - Watching Gaps Analysis
struct WatchingGap: Codable, Sendable {
    let gapStart: String
    let gapEnd: String
    let gapDays: Int
    
    enum CodingKeys: String, CodingKey {
        case gapStart = "gap_start"
        case gapEnd = "gap_end"
        case gapDays = "gap_days"
    }
}
//
//  StatisticsModels.swift
//  reelay2
//
//  Created by Humza Khalil on 7/31/25.
//

import Foundation

// MARK: - Simplified Dashboard Statistics
struct DashboardStats: Codable, Sendable {
    let totalFilms: Int
    let uniqueFilms: Int
    let averageRating: Double?
    let filmsThisYear: Int
    let topGenre: String?
    let topDirector: String?
    let favoriteDay: String?
    
    enum CodingKeys: String, CodingKey {
        case totalFilms = "total_films"
        case uniqueFilms = "unique_films"
        case averageRating = "average_rating"
        case filmsThisYear = "films_this_year"
        case topGenre = "top_genre"
        case topDirector = "top_director"
        case favoriteDay = "favorite_day"
    }
}

// MARK: - Simple Rating Distribution
struct RatingDistribution: Codable, Sendable {
    let ratingValue: Double
    let countFilms: Int
    let percentage: Double
    
    enum CodingKeys: String, CodingKey {
        case ratingValue = "rating_value"
        case countFilms = "count_films"
        case percentage
    }
    
    // Computed properties for chart display
    var rating: String {
        return String(format: "%.0f", ratingValue)
    }
    
    var count: Int {
        return countFilms
    }
}

// MARK: - Detailed Rating Distribution (0-100)
struct DetailedRatingDistribution: Codable, Sendable {
    let ratingValue: Int
    let countFilms: Int

    enum CodingKeys: String, CodingKey {
        case ratingValue = "rating_value"
        case countFilms = "count_films"
    }

    var count: Int {
        return countFilms
    }
}

struct LocationMapPoint: Codable, Identifiable, Sendable {
    let location_id: Int
    let location_name: String
    let latitude: Double
    let longitude: Double
    let entry_count: Int

    var id: Int { location_id }
    var count: Int { entry_count }
}

struct LocationCountRow: Codable, Identifiable, Sendable {
    let label: String
    let entry_count: Int

    var id: String { label }
    var count: Int { entry_count }
}

// MARK: - Simple Rating Stats
struct RatingStats: Codable, Sendable {
    let averageRating: Double?
    let medianRating: Double?
    let modeRating: Int?
    let standardDeviation: Double?
    let totalRated: Int
    let fiveStarPercentage: Double?
    
    enum CodingKeys: String, CodingKey {
        case averageRating = "average_rating"
        case medianRating = "median_rating"
        case modeRating = "mode_rating"
        case standardDeviation = "standard_deviation"
        case totalRated = "total_rated"
        case fiveStarPercentage = "five_star_percentage"
    }
}

// MARK: - Simple Films Per Year
struct FilmsPerYear: Codable, Sendable {
    let year: Int
    let filmCount: Int
    let uniqueFilms: Int
    
    enum CodingKeys: String, CodingKey {
        case year
        case filmCount = "film_count"
        case uniqueFilms = "unique_films"
    }
    
    // Computed property for chart display
    var count: Int {
        return filmCount
    }
}

// MARK: - Films by Release Year
struct FilmsByReleaseYear: Codable, Sendable {
    let releaseYear: Int
    let filmCount: Int
    let percentage: Double
    
    enum CodingKeys: String, CodingKey {
        case releaseYear = "release_year"
        case filmCount = "film_count"
        case percentage
    }
    
    // Computed properties for chart display
    var year: Int { releaseYear }
    var count: Int { filmCount }
}

// MARK: - Simple Films by Decade
struct FilmsByDecade: Codable, Sendable {
    let decade: Int
    let filmCount: Int
    let percentage: Double
    
    enum CodingKeys: String, CodingKey {
        case decade
        case filmCount = "film_count"
        case percentage
    }
    
    // Computed property for chart display
    var count: Int {
        return filmCount
    }
}

// MARK: - Simple Runtime Statistics
struct RuntimeStats: Codable, Sendable {
    let totalRuntime: Int?
    let averageRuntime: Double?
    let medianRuntime: Double?
    let longestRuntime: Int?
    let longestTitle: String?
    let shortestRuntime: Int?
    let shortestTitle: String?
    
    enum CodingKeys: String, CodingKey {
        case totalRuntime = "total_runtime"
        case averageRuntime = "average_runtime"
        case medianRuntime = "median_runtime"
        case longestRuntime = "longest_runtime"
        case longestTitle = "longest_title"
        case shortestRuntime = "shortest_runtime"
        case shortestTitle = "shortest_title"
    }
}

// MARK: - Basic Statistics Models for Additional Features
struct FilmsPerMonth: Codable, Sendable {
    let year: Int
    let month: Int
    let monthName: String
    let filmCount: Int
    
    enum CodingKeys: String, CodingKey {
        case year
        case month
        case monthName = "month_name"
        case filmCount = "film_count"
    }
    
    var count: Int {
        return filmCount
    }
}

struct DailyWatchCount: Codable, Sendable {
    let watchDate: String
    let filmCount: Int
    let isBingeDay: Bool
    
    enum CodingKeys: String, CodingKey {
        case watchDate = "watch_date"
        case filmCount = "film_count"
        case isBingeDay = "is_binge_day"
    }
    
    var date: String { watchDate }
    var count: Int { filmCount }
}

struct DayOfWeekPattern: Codable, Sendable {
    let dayOfWeek: String
    let dayNumber: Int
    let filmCount: Int
    let percentage: Double
    
    enum CodingKeys: String, CodingKey {
        case dayOfWeek = "day_of_week"
        case dayNumber = "day_number"
        case filmCount = "film_count"
        case percentage
    }
    
    var count: Int { filmCount }
}

struct SeasonalPattern: Codable, Sendable {
    let seasonName: String
    let filmCount: Int
    let averageRating: Double?
    let percentage: Double
    
    enum CodingKeys: String, CodingKey {
        case seasonName = "season_name"
        case filmCount = "film_count"
        case averageRating = "avg_rating"
        case percentage
    }
    
    var season: String { seasonName }
    var count: Int { filmCount }
}

struct GenreStats: Codable, Sendable {
    let genreName: String
    let filmCount: Int
    let averageRating: Double?
    let percentage: Double
    
    enum CodingKeys: String, CodingKey {
        case genreName = "genre_name"
        case filmCount = "film_count"
        case averageRating = "average_rating"
        case percentage
    }
    
    var genre: String { genreName }
    var count: Int { filmCount }
}

struct DirectorStats: Codable, Sendable {
    let directorName: String
    let filmCount: Int
    let averageRating: Double?
    let uniqueFilms: Int
    
    enum CodingKeys: String, CodingKey {
        case directorName = "director_name"
        case filmCount = "film_count"
        case averageRating = "average_rating"
        case uniqueFilms = "unique_films"
    }
    
    var director: String { directorName }
    var count: Int { filmCount }
}

struct RuntimeDistribution: Codable, Sendable {
    let runtimeBin: String
    let filmCount: Int
    let percentage: Double
    
    enum CodingKeys: String, CodingKey {
        case runtimeBin = "runtime_bin"
        case filmCount = "film_count"
        case percentage
    }
    
    var runtimeRange: String { runtimeBin }
    var count: Int { filmCount }
}

struct ReleaseYearAnalysis: Codable, Sendable {
    let averageReleaseYear: Double?
    let medianReleaseYear: Int?
    let oldestYear: Int?
    let oldestTitle: String?
    let newestYear: Int?
    let newestTitle: String?
    
    enum CodingKeys: String, CodingKey {
        case averageReleaseYear = "average_release_year"
        case medianReleaseYear = "median_release_year"
        case oldestYear = "oldest_year"
        case oldestTitle = "oldest_title"
        case newestYear = "newest_year"
        case newestTitle = "newest_title"
    }
    
    var releaseYear: Int { medianReleaseYear ?? 0 }
    var count: Int { 1 }
}

struct RewatchStats: Codable, Sendable {
    let totalRewatches: Int
    let totalFilms: Int
    let nonRewatches: Int
    let rewatchPercentage: Double?
    let uniqueFilmsRewatched: Int
    let topRewatchedMovie: String?
    
    enum CodingKeys: String, CodingKey {
        case totalRewatches = "total_rewatches"
        case totalFilms = "total_films"
        case nonRewatches = "non_rewatches"
        case rewatchPercentage = "rewatch_percentage"
        case uniqueFilmsRewatched = "unique_films_rewatched"
        case topRewatchedMovie = "top_rewatched"
    }
    
    var mostRewatchedMovie: String? { topRewatchedMovie }
}

struct ViewingSessions: Codable, Sendable {
    let totalSessions: Int
    let averageSessionLength: Double?
    
    enum CodingKeys: String, CodingKey {
        case totalSessions = "total_sessions"
        case averageSessionLength = "average_session_length"
    }
}

struct UniqueFilmsCount: Codable, Sendable {
    let uniqueFilms: Int
    let totalEntries: Int
    
    enum CodingKeys: String, CodingKey {
        case uniqueFilms = "unique_films"
        case totalEntries = "total_entries"
    }
}

struct WatchSpan: Codable, Sendable {
    let firstWatchDate: String?
    let lastWatchDate: String?
    let watchSpan: String?
    let totalDays: Int?
    
    enum CodingKeys: String, CodingKey {
        case firstWatchDate = "first_watch_date"
        case lastWatchDate = "last_watch_date"
        case watchSpan = "watch_span"
        case totalDays = "total_days"
    }
    
    var firstWatch: String? { firstWatchDate }
    var lastWatch: String? { lastWatchDate }
    var spanDays: Int? { totalDays }
}

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

struct FilmsLoggedPeriod: Codable, Sendable {
    let date: String
    let count: Int
}

struct WatchingGap: Codable, Sendable {
    let averageGapDays: Double?
    let medianGapDays: Int?
    let longestGapDays: Int?
    let longestGapStart: String?
    let longestGapEnd: String?
    let shortestGapDays: Int?
    
    enum CodingKeys: String, CodingKey {
        case averageGapDays = "average_gap_days"
        case medianGapDays = "median_gap_days"
        case longestGapDays = "longest_gap_days"
        case longestGapStart = "longest_gap_start_date"
        case longestGapEnd = "longest_gap_end_date"
        case shortestGapDays = "shortest_gap_days"
    }
    
    var gapStart: String { longestGapStart ?? "" }
    var gapEnd: String { longestGapEnd ?? "" }
    var gapDays: Int { longestGapDays ?? 0 }
}

struct StreakStats: Codable, Sendable {
    let longestStreakDays: Int
    let longestStreakStartDate: String?
    let longestStreakEndDate: String?
    let longestStreakStartTitle: String?
    let longestStreakStartPoster: String?
    let longestStreakEndTitle: String?
    let longestStreakEndPoster: String?
    let currentStreakDays: Int
    let currentStreakStartDate: String?
    let currentStreakEndDate: String?
    let currentStreakStartTitle: String?
    let currentStreakStartPoster: String?
    let currentStreakEndTitle: String?
    let currentStreakEndPoster: String?
    let isCurrentStreakActive: Bool
    
    enum CodingKeys: String, CodingKey {
        case longestStreakDays = "longest_streak_days"
        case longestStreakStartDate = "longest_streak_start_date"
        case longestStreakEndDate = "longest_streak_end_date"
        case longestStreakStartTitle = "longest_streak_start_title"
        case longestStreakStartPoster = "longest_streak_start_poster"
        case longestStreakEndTitle = "longest_streak_end_title"
        case longestStreakEndPoster = "longest_streak_end_poster"
        case currentStreakDays = "current_streak_days"
        case currentStreakStartDate = "current_streak_start_date"
        case currentStreakEndDate = "current_streak_end_date"
        case currentStreakStartTitle = "current_streak_start_title"
        case currentStreakStartPoster = "current_streak_start_poster"
        case currentStreakEndTitle = "current_streak_end_title"
        case currentStreakEndPoster = "current_streak_end_poster"
        case isCurrentStreakActive = "is_current_streak_active"
    }
    
    // Computed properties for UI display
    var longestStreak: Int { longestStreakDays }
    var currentStreak: Int { currentStreakDays }
    var longestStart: String { longestStreakStartDate ?? "" }
    var longestEnd: String { longestStreakEndDate ?? "" }
    var currentStart: String { currentStreakStartDate ?? "" }
    var currentEnd: String { currentStreakEndDate ?? "" }
    var isActive: Bool { isCurrentStreakActive }
}

// MARK: - Weekly Streak Statistics
struct WeeklyStreakStats: Codable, Sendable {
    let longestWeeklyStreakWeeks: Int
    let longestWeeklyStreakStartDate: String?
    let longestWeeklyStreakEndDate: String?
    let currentWeeklyStreakWeeks: Int
    let currentWeeklyStreakStartDate: String?
    let currentWeeklyStreakEndDate: String?
    let isCurrentWeeklyStreakActive: Bool
    
    enum CodingKeys: String, CodingKey {
        case longestWeeklyStreakWeeks = "longest_weekly_streak_weeks"
        case longestWeeklyStreakStartDate = "longest_weekly_streak_start_date"
        case longestWeeklyStreakEndDate = "longest_weekly_streak_end_date"
        case currentWeeklyStreakWeeks = "current_weekly_streak_weeks"
        case currentWeeklyStreakStartDate = "current_weekly_streak_start_date"
        case currentWeeklyStreakEndDate = "current_weekly_streak_end_date"
        case isCurrentWeeklyStreakActive = "is_current_weekly_streak_active"
    }
    
    // Computed properties for UI display
    var longestStreak: Int { longestWeeklyStreakWeeks }
    var currentStreak: Int { currentWeeklyStreakWeeks }
    var longestStartDate: String { longestWeeklyStreakStartDate ?? "" }
    var longestEndDate: String { longestWeeklyStreakEndDate ?? "" }
    var currentStartDate: String { currentWeeklyStreakStartDate ?? "" }
    var currentEndDate: String { currentWeeklyStreakEndDate ?? "" }
    var isActive: Bool { isCurrentWeeklyStreakActive }
}

// MARK: - Weekly Films Data
struct WeeklyFilmsData: Codable, Sendable {
    let year: Int
    let weekNumber: Int
    let weekStartDate: String
    let weekEndDate: String
    let filmCount: Int
    
    enum CodingKeys: String, CodingKey {
        case year
        case weekNumber = "week_number"
        case weekStartDate = "week_start_date"
        case weekEndDate = "week_end_date"
        case filmCount = "film_count"
    }
    
    var count: Int { filmCount }
    var weekLabel: String { "Week \(weekNumber)" }
}

// MARK: - Year Release Date Statistics
struct YearReleaseStats: Codable, Sendable {
    let totalFilms: Int
    let filmsFromYear: Int
    let filmsFromOtherYears: Int
    let yearPercentage: Double?
    let otherYearsPercentage: Double?
    
    enum CodingKeys: String, CodingKey {
        case totalFilms = "total_films"
        case filmsFromYear = "films_from_year"
        case filmsFromOtherYears = "films_from_other_years"
        case yearPercentage = "year_percentage"
        case otherYearsPercentage = "other_years_percentage"
    }
}

// MARK: - Top Watched Films
struct TopWatchedFilm: Codable, Sendable {
    let title: String
    let posterUrl: String?
    let watchCount: Int
    let tmdbId: Int?
    let lastWatchedDate: String?
    
    enum CodingKeys: String, CodingKey {
        case title
        case posterUrl = "poster_url"
        case watchCount = "watch_count"
        case tmdbId = "tmdb_id"
        case lastWatchedDate = "last_watched_date"
    }
}

// MARK: - Advanced Film Journey Statistics

struct AdvancedFilmJourneyStats: Codable, Sendable {
    let daysWith2PlusFilms: Int
    let averageMoviesPerYear: Double
    let mustWatchCompletion: MustWatchCompletion?
    let unique5StarFilms: Int
    let mostMoviesInDay: [MostMoviesInDayStat]?
    let highestMonthlyAverage: [HighestMonthlyAverage]?
    
    enum CodingKeys: String, CodingKey {
        case daysWith2PlusFilms = "days_with_2plus_films"
        case averageMoviesPerYear = "average_movies_per_year"
        case mustWatchCompletion = "must_watch_completion"
        case unique5StarFilms = "unique_5star_films"
        case mostMoviesInDay = "most_movies_in_day"
        case highestMonthlyAverage = "highest_monthly_average"
    }
}

struct HighestMonthlyAverage: Codable, Sendable, Identifiable {
    var id: String { "\(year)-\(month)" }
    let year: Int
    let month: Int
    let monthName: String
    let averageRating: Double
    let filmCount: Int
    
    enum CodingKeys: String, CodingKey {
        case year
        case month
        case monthName = "month_name"
        case averageRating = "average_rating"
        case filmCount = "film_count"
    }
}

// MARK: - Year-Filtered Advanced Film Journey Statistics

struct YearFilteredAdvancedJourneyStats: Codable, Sendable {
    let daysWith2PlusFilms: Int
    let mustWatchCompletion: MustWatchCompletion?
    let unique5StarFilms: Int
    let mostMoviesInDay: [MostMoviesInDayStat]?
    let highestMonthlyAverage: [HighestMonthlyAverage]?
    
    enum CodingKeys: String, CodingKey {
        case daysWith2PlusFilms = "days_with_2plus_films"
        case mustWatchCompletion = "must_watch_completion"
        case unique5StarFilms = "unique_5star_films"
        case mostMoviesInDay = "most_movies_in_day"
        case highestMonthlyAverage = "highest_monthly_average"
    }
}

struct MustWatchCompletion: Codable, Sendable {
    let listName: String
    let totalFilms: Int
    let watchedFilms: Int
    let completionPercentage: Double
    let unwatchedFilms: Int
    
    enum CodingKeys: String, CodingKey {
        case listName = "list_name"
        case totalFilms = "total_films"
        case watchedFilms = "watched_films"
        case completionPercentage = "completion_percentage"
        case unwatchedFilms = "unwatched_films"
    }
}

struct MostMoviesInDayStat: Codable, Sendable, Identifiable {
    var id: String { watchDate }
    let watchDate: String
    let filmCount: Int
    
    enum CodingKeys: String, CodingKey {
        case watchDate = "watch_date"
        case filmCount = "film_count"
    }
}

// MARK: - Average Rating Per Year Models

struct AverageStarRatingPerYear: Codable, Sendable {
    let year: Int
    let averageStarRating: Double
    let filmCount: Int
    
    enum CodingKeys: String, CodingKey {
        case year
        case averageStarRating = "average_star_rating"
        case filmCount = "film_count"
    }
    
    var averageRating: Double { averageStarRating }
    var count: Int { filmCount }
}

struct AverageDetailedRatingPerYear: Codable, Sendable {
    let year: Int
    let averageDetailedRating: Double
    let filmCount: Int
    
    enum CodingKeys: String, CodingKey {
        case year
        case averageDetailedRating = "average_detailed_rating"
        case filmCount = "film_count"
    }
    
    var averageRating: Double { averageDetailedRating }
    var count: Int { filmCount }
}

// MARK: - On Pace Chart Models

/// Projection method for current year pace estimation
enum PaceProjectionMethod: String, CaseIterable, Identifiable {
    case linear = "Linear"
    case seasonal = "Seasonal"
    
    var id: String { rawValue }
    
    var description: String {
        switch self {
        case .linear:
            return "Projects based on daily average"
        case .seasonal:
            return "Adjusts for monthly patterns"
        }
    }
}

/// Monthly cumulative film count for tracking pace
struct MonthlyPaceData: Codable, Sendable, Identifiable {
    let month: Int              // 1-12
    let monthName: String
    let filmCount: Int          // Films watched in this month
    let cumulativeCount: Int    // Total films from Jan through this month
    
    var id: Int { month }
    
    enum CodingKeys: String, CodingKey {
        case month
        case monthName = "month_name"
        case filmCount = "film_count"
        case cumulativeCount = "cumulative_count"
    }
}

/// Complete pace statistics for a year with projections
struct YearlyPaceStats: Codable, Sendable {
    let year: Int
    let isCurrentYear: Bool
    let monthlyData: [MonthlyPaceData]              // Actual monthly data
    let projectedLinear: [MonthlyPaceData]?         // Linear projection (current year only)
    let projectedSeasonal: [MonthlyPaceData]?       // Seasonal projection (current year only)
    let historicalAverage: [MonthlyPaceData]        // Historical average cumulative per month
    let projectedEndOfYearLinear: Int?              // Projected films by Dec 31 (linear)
    let projectedEndOfYearSeasonal: Int?            // Projected films by Dec 31 (seasonal)
    
    enum CodingKeys: String, CodingKey {
        case year
        case isCurrentYear = "is_current_year"
        case monthlyData = "monthly_data"
        case projectedLinear = "projected_linear"
        case projectedSeasonal = "projected_seasonal"
        case historicalAverage = "historical_average"
        case projectedEndOfYearLinear = "projected_end_of_year_linear"
        case projectedEndOfYearSeasonal = "projected_end_of_year_seasonal"
    }
}

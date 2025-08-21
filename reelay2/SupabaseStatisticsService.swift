//
//  SupabaseStatisticsService.swift
//  reelay2
//
//  Created by Humza Khalil on 1/1/25.
//

import Foundation
import Supabase
import Combine

class SupabaseStatisticsService: ObservableObject {
    static let shared = SupabaseStatisticsService()
    
    private let supabase: SupabaseClient
    
    private init() {
        guard let supabaseURL = URL(string: Config.supabaseURL) else {
            fatalError("Missing Supabase URL configuration")
        }
        
        let supabaseKey = Config.supabaseAnonKey
        
        self.supabase = SupabaseClient(
            supabaseURL: supabaseURL,
            supabaseKey: supabaseKey
        )
    }
    
    // MARK: - Year Management
    
    /// Test database structure and connection
    nonisolated func testDatabaseStructure() async throws -> String {
        do {
            let response = try await supabase.rpc("test_database_structure").execute()
            
            let responseString = String(data: response.data, encoding: .utf8) ?? "Unable to decode response"
            return responseString
            
        } catch {
            return "Error: \(error.localizedDescription)"
        }
    }
    
    /// Test simple year retrieval
    nonisolated func testGetYears() async throws -> [Int] {
        do {
            let response = try await supabase.rpc("test_get_years").execute()
            
            let responseString = String(data: response.data, encoding: .utf8) ?? "Unable to decode response"
            
            struct YearValue: Codable {
                let year_value: Int
            }
            
            let years = try JSONDecoder().decode([YearValue].self, from: response.data)
            return years.map { $0.year_value }
            
        } catch {
            return []
        }
    }
    
    /// Debug year filtering logic
    nonisolated func debugYearFiltering(year: Int) async throws -> String {
        do {
            let response = try await supabase.rpc("debug_year_filtering", params: ["target_year": year]).execute()
            
            let responseString = String(data: response.data, encoding: .utf8) ?? "Unable to decode response"
            return responseString
            
        } catch {
            return "Error: \(error.localizedDescription)"
        }
    }
    
    /// Debug dashboard stats for specific year
    nonisolated func debugDashboardStats(year: Int) async throws -> String {
        do {
            let response = try await supabase.rpc("debug_dashboard_stats", params: ["target_year": year]).execute()
            
            let responseString = String(data: response.data, encoding: .utf8) ?? "Unable to decode response"
            return responseString
            
        } catch {
            return "Error: \(error.localizedDescription)"
        }
    }
    
    /// Debug runtime data for specific year
    nonisolated func debugRuntimeData(year: Int) async throws -> String {
        do {
            let response = try await supabase.rpc("debug_runtime_data", params: ["target_year": year]).execute()
            
            let responseString = String(data: response.data, encoding: .utf8) ?? "Unable to decode response"
            return responseString
            
        } catch {
            return "Error: \(error.localizedDescription)"
        }
    }
    
    /// Debug rewatch data for specific year
    nonisolated func debugRewatchData(year: Int) async throws -> String {
        do {
            let response = try await supabase.rpc("debug_rewatch_data", params: ["target_year": year]).execute()
            
            let responseString = String(data: response.data, encoding: .utf8) ?? "Unable to decode response"
            return responseString
            
        } catch {
            return "Error: \(error.localizedDescription)"
        }
    }
    
    /// Debug rewatch field values for specific year
    nonisolated func debugRewatchField(year: Int) async throws -> String {
        do {
            let response = try await supabase.rpc("debug_rewatch_field", params: ["target_year": year]).execute()
            
            let responseString = String(data: response.data, encoding: .utf8) ?? "Unable to decode response"
            return responseString
            
        } catch {
            return "Error: \(error.localizedDescription)"
        }
    }
    
    
    /// Get all years that have logged films
    nonisolated func getLoggedYears() async throws -> [Int] {
        do {
            let response = try await supabase.rpc("get_logged_years").execute()
            
            
            // Parse the response as an array of objects with year property
            struct YearResponse: Codable {
                let year: Int
            }
            
            let years = try JSONDecoder().decode([YearResponse].self, from: response.data)
            return years.map { $0.year }
            
        } catch {
            return []
        }
    }
    
    // MARK: - Dashboard Statistics
    
    /// Get dashboard stats (total movies, average rating, etc.)
    nonisolated func getDashboardStats(year: Int? = nil) async throws -> DashboardStats {
        do {
            let response = if let year = year {
                try await supabase.rpc("get_dashboard_stats_by_year", params: ["target_year": year]).execute()
            } else {
                try await supabase.rpc("get_dashboard_stats").execute()
            }
            
            
            // Try to decode as array first
            if let stats = try? JSONDecoder().decode([DashboardStats].self, from: response.data),
               let dashboardStats = stats.first {
                return dashboardStats
            }
            
            // Try to decode as single object
            if let dashboardStats = try? JSONDecoder().decode(DashboardStats.self, from: response.data) {
                return dashboardStats
            }
            
            // Return mock data if database function doesn't exist
            return DashboardStats(
                totalFilms: 0,
                uniqueFilms: 0,
                averageRating: 0.0,
                filmsThisYear: 0,
                topGenre: nil,
                topDirector: nil,
                favoriteDay: nil
            )
            
        } catch {
            // Return mock data instead of throwing error
            return DashboardStats(
                totalFilms: 0,
                uniqueFilms: 0,
                averageRating: 0.0,
                filmsThisYear: 0,
                topGenre: nil,
                topDirector: nil,
                favoriteDay: nil
            )
        }
    }
    
    // MARK: - Rating Statistics
    
    /// Get rating distribution data
    nonisolated func getRatingDistribution(year: Int? = nil) async throws -> [RatingDistribution] {
        do {
            let response = if let year = year {
                try await supabase.rpc("get_rating_distribution_by_year", params: ["target_year": year]).execute()
            } else {
                try await supabase.rpc("get_rating_distribution").execute()
            }
            
            
            let distribution: [RatingDistribution] = try JSONDecoder().decode([RatingDistribution].self, from: response.data)
            return distribution
            
        } catch {
            // Return empty array instead of throwing error
            return []
        }
    }
    
    /// Get detailed rating statistics
    nonisolated func getRatingStats(year: Int? = nil) async throws -> RatingStats {
        do {
            let response = if let year = year {
                try await supabase.rpc("get_rating_stats_by_year", params: ["target_year": year]).execute()
            } else {
                try await supabase.rpc("get_rating_stats").execute()
            }
            
            
            // Try to decode as array first
            if let stats = try? JSONDecoder().decode([RatingStats].self, from: response.data),
               let ratingStats = stats.first {
                return ratingStats
            }
            
            // Try to decode as single object
            if let ratingStats = try? JSONDecoder().decode(RatingStats.self, from: response.data) {
                return ratingStats
            }
            
            // Return mock data if database function doesn't exist
            return RatingStats(
                averageRating: 0.0,
                medianRating: 0.0,
                modeRating: 0,
                standardDeviation: 0.0,
                totalRated: 0,
                fiveStarPercentage: 0.0
            )
            
        } catch {
            // Return mock data instead of throwing error
            return RatingStats(
                averageRating: 0.0,
                medianRating: 0.0,
                modeRating: 0,
                standardDeviation: 0.0,
                totalRated: 0,
                fiveStarPercentage: 0.0
            )
        }
    }
    
    /// Get average star rating per year (all-time only)
    nonisolated func getAverageStarRatingPerYear() async throws -> [AverageStarRatingPerYear] {
        do {
            let response = try await supabase.rpc("get_average_star_rating_per_year").execute()
            
            let averageRatings = try JSONDecoder().decode([AverageStarRatingPerYear].self, from: response.data)
            return averageRatings
            
        } catch {
            // Return empty array instead of throwing error
            return []
        }
    }
    
    /// Get average detailed rating per year (all-time only)
    nonisolated func getAverageDetailedRatingPerYear() async throws -> [AverageDetailedRatingPerYear] {
        do {
            let response = try await supabase.rpc("get_average_detailed_rating_per_year").execute()
            
            let averageRatings = try JSONDecoder().decode([AverageDetailedRatingPerYear].self, from: response.data)
            return averageRatings
            
        } catch {
            // Return empty array instead of throwing error
            return []
        }
    }
    
    // MARK: - Time-based Statistics
    
    /// Get films per year data
    nonisolated func getFilmsPerYear(year: Int? = nil) async throws -> [FilmsPerYear] {
        do {
            let response = if let year = year {
                try await supabase.rpc("get_films_per_year_by_year", params: ["target_year": year]).execute()
            } else {
                try await supabase.rpc("get_films_per_year").execute()
            }
            
            
            let filmsPerYear: [FilmsPerYear] = try JSONDecoder().decode([FilmsPerYear].self, from: response.data)
            return filmsPerYear
            
        } catch {
            // Return empty array instead of throwing error
            return []
        }
    }
    
    /// Get films by decade data
    nonisolated func getFilmsByDecade(year: Int? = nil) async throws -> [FilmsByDecade] {
        do {
            let response = if let year = year {
                try await supabase.rpc("get_films_by_decade_by_year", params: ["target_year": year]).execute()
            } else {
                try await supabase.rpc("get_films_by_decade").execute()
            }
            
            
            let filmsByDecade: [FilmsByDecade] = try JSONDecoder().decode([FilmsByDecade].self, from: response.data)
            return filmsByDecade
            
        } catch {
            // Return empty array instead of throwing error
            return []
        }
    }
    
    /// Get daily watch counts
    nonisolated func getDailyWatchCounts() async throws -> [DailyWatchCount] {
        let response = try await supabase.rpc("get_daily_watch_counts").execute()
        
        let dailyCounts: [DailyWatchCount] = try JSONDecoder().decode([DailyWatchCount].self, from: response.data)
        return dailyCounts
    }
    
    /// Get films per month data
    nonisolated func getFilmsPerMonth(year: Int? = nil) async throws -> [FilmsPerMonth] {
        do {
            let response = if let year = year {
                try await supabase.rpc("get_films_per_month_by_year", params: ["target_year": year]).execute()
            } else {
                try await supabase.rpc("get_films_per_month_by_year").execute()
            }
            
            
            let filmsPerMonth: [FilmsPerMonth] = try JSONDecoder().decode([FilmsPerMonth].self, from: response.data)
            return filmsPerMonth
            
        } catch {
            // Return empty array instead of throwing error
            return []
        }
    }
    
    /// Get weekly films data for a specific year
    nonisolated func getWeeklyFilmsData(year: Int) async throws -> [WeeklyFilmsData] {
        do {
            let response = try await supabase.rpc("get_films_per_week_by_year", params: ["target_year": year]).execute()
            
            
            let weeklyData: [WeeklyFilmsData] = try JSONDecoder().decode([WeeklyFilmsData].self, from: response.data)
            
            return weeklyData
            
        } catch {
            // Return empty array instead of throwing error
            return []
        }
    }
    
    /// Get day of week patterns
    nonisolated func getDayOfWeekPatterns(year: Int? = nil) async throws -> [DayOfWeekPattern] {
        do {
            let response = if let year = year {
                try await supabase.rpc("get_day_of_week_patterns_by_year", params: ["target_year": year]).execute()
            } else {
                try await supabase.rpc("get_day_of_week_patterns").execute()
            }
            
            
            let patterns: [DayOfWeekPattern] = try JSONDecoder().decode([DayOfWeekPattern].self, from: response.data)
            return patterns
            
        } catch {
            // Return empty array instead of throwing error
            return []
        }
    }
    
    /// Get seasonal patterns
    nonisolated func getSeasonalPatterns() async throws -> [SeasonalPattern] {
        let response = try await supabase.rpc("get_seasonal_patterns").execute()
        
        let patterns: [SeasonalPattern] = try JSONDecoder().decode([SeasonalPattern].self, from: response.data)
        return patterns
    }
    
    // MARK: - Runtime Statistics
    
    /// Get runtime statistics
    nonisolated func getRuntimeStats(year: Int? = nil) async throws -> RuntimeStats {
        do {
            let response = if let year = year {
                try await supabase.rpc("get_runtime_stats_by_year", params: ["target_year": year]).execute()
            } else {
                try await supabase.rpc("get_runtime_stats").execute()
            }
            
            
            // Try to decode as array first
            if let stats = try? JSONDecoder().decode([RuntimeStats].self, from: response.data),
               let runtimeStats = stats.first {
                return runtimeStats
            }
            
            // Try to decode as single object
            if let runtimeStats = try? JSONDecoder().decode(RuntimeStats.self, from: response.data) {
                return runtimeStats
            }
            
            // Return mock data if database function doesn't exist
            return RuntimeStats(
                totalRuntime: 0,
                averageRuntime: 0.0,
                medianRuntime: 0.0,
                longestRuntime: 0,
                longestTitle: nil,
                shortestRuntime: 0,
                shortestTitle: nil
            )
            
        } catch {
            // Return mock data instead of throwing error
            return RuntimeStats(
                totalRuntime: 0,
                averageRuntime: 0.0,
                medianRuntime: 0.0,
                longestRuntime: 0,
                longestTitle: nil,
                shortestRuntime: 0,
                shortestTitle: nil
            )
        }
    }
    
    /// Get runtime distribution
    nonisolated func getRuntimeDistribution() async throws -> [RuntimeDistribution] {
        let response = try await supabase.rpc("get_runtime_distribution").execute()
        
        let distribution: [RuntimeDistribution] = try JSONDecoder().decode([RuntimeDistribution].self, from: response.data)
        return distribution
    }
    
    // MARK: - Genre and Director Statistics
    
    /// Get genre statistics
    nonisolated func getGenreStats() async throws -> [GenreStats] {
        let response = try await supabase.rpc("get_genre_stats").execute()
        
        let stats: [GenreStats] = try JSONDecoder().decode([GenreStats].self, from: response.data)
        return stats
    }
    
    /// Get director statistics
    nonisolated func getDirectorStats() async throws -> [DirectorStats] {
        let response = try await supabase.rpc("get_director_stats").execute()
        
        let stats: [DirectorStats] = try JSONDecoder().decode([DirectorStats].self, from: response.data)
        return stats
    }
    
    // MARK: - Unique Films and Counts
    
    /// Get unique films count
    nonisolated func getUniqueFilmsCount(year: Int? = nil) async throws -> Int {
        do {
            let response = if let year = year {
                try await supabase.rpc("get_unique_films_count_by_year", params: ["target_year": year]).execute()
            } else {
                try await supabase.rpc("get_unique_films_count").execute()
            }
            
            
            // The function returns an integer directly
            if let dataString = String(data: response.data, encoding: .utf8),
               let count = Int(dataString.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)) {
                return count
            }
            
            return 0 // Return 0 if can't parse
            
        } catch {
            return 0 // Return 0 instead of throwing error
        }
    }
    
    /// Get total viewing sessions
    nonisolated func getTotalViewingSessions() async throws -> Int {
        let response = try await supabase.rpc("get_total_viewing_sessions").execute()
        
        // The function returns an integer directly
        if let dataString = String(data: response.data, encoding: .utf8),
           let count = Int(dataString.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return count
        }
        
        throw StatisticsError.invalidDataFormat
    }
    
    // MARK: - Rewatch Statistics
    
    /// Get rewatch statistics
    nonisolated func getRewatchStats(year: Int? = nil) async throws -> RewatchStats {
        do {
            let response = if let year = year {
                try await supabase.rpc("get_rewatch_stats_by_year", params: ["target_year": year]).execute()
            } else {
                try await supabase.rpc("get_rewatch_stats").execute()
            }
            
            
            // Try to decode as array first
            if let stats = try? JSONDecoder().decode([RewatchStats].self, from: response.data),
               let rewatchStats = stats.first {
                return rewatchStats
            }
            
            // Try to decode as single object
            if let rewatchStats = try? JSONDecoder().decode(RewatchStats.self, from: response.data) {
                return rewatchStats
            }
            
            // Return mock data if database function doesn't exist
            return RewatchStats(
                totalRewatches: 0,
                totalFilms: 0,
                nonRewatches: 0,
                rewatchPercentage: 0.0,
                uniqueFilmsRewatched: 0,
                topRewatchedMovie: nil
            )
            
        } catch {
            // Return mock data instead of throwing error
            return RewatchStats(
                totalRewatches: 0,
                totalFilms: 0,
                nonRewatches: 0,
                rewatchPercentage: 0.0,
                uniqueFilmsRewatched: 0,
                topRewatchedMovie: nil
            )
        }
    }
    
    // MARK: - Watch Span and Time Analysis
    
    /// Get watch span data
    nonisolated func getWatchSpan(year: Int? = nil) async throws -> WatchSpan {
        do {
            let response = if let year = year {
                try await supabase.rpc("get_watch_span_by_year", params: ["target_year": year]).execute()
            } else {
                try await supabase.rpc("get_watch_span").execute()
            }
            
            
            // Try to decode as array first
            if let spans = try? JSONDecoder().decode([WatchSpan].self, from: response.data),
               let watchSpan = spans.first {
                return watchSpan
            }
            
            // Try to decode as single object
            if let watchSpan = try? JSONDecoder().decode(WatchSpan.self, from: response.data) {
                return watchSpan
            }
            
            // Return mock data if database function doesn't exist
            return WatchSpan(
                firstWatchDate: nil,
                lastWatchDate: nil,
                watchSpan: nil,
                totalDays: 0
            )
            
        } catch {
            // Return mock data instead of throwing error
            return WatchSpan(
                firstWatchDate: nil,
                lastWatchDate: nil,
                watchSpan: nil,
                totalDays: 0
            )
        }
    }
    
    /// Get earliest and latest films
    nonisolated func getEarliestLatestFilms() async throws -> EarliestLatestFilms {
        let response = try await supabase.rpc("get_earliest_latest_films").execute()
        
        let films: [EarliestLatestFilms] = try JSONDecoder().decode([EarliestLatestFilms].self, from: response.data)
        guard let earliestLatest = films.first else {
            throw StatisticsError.noDataReturned
        }
        
        return earliestLatest
    }
    
    // MARK: - Release Year Analysis
    
    /// Get release year analysis
    nonisolated func getReleaseYearAnalysis() async throws -> [ReleaseYearAnalysis] {
        let response = try await supabase.rpc("get_release_year_analysis").execute()
        
        let analysis: [ReleaseYearAnalysis] = try JSONDecoder().decode([ReleaseYearAnalysis].self, from: response.data)
        return analysis
    }
    
    // MARK: - Films Logged by Period
    
    /// Get films logged in a specific period (default: year)
    nonisolated func getFilmsLoggedPeriod(period: String = "year") async throws -> Int {
        let response = try await supabase.rpc("get_films_logged_period").execute()
        
        // The function returns an integer directly
        if let dataString = String(data: response.data, encoding: .utf8),
           let count = Int(dataString.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return count
        }
        
        throw StatisticsError.invalidDataFormat
    }
    
    // MARK: - Watching Gaps Analysis
    
    /// Get watching gaps analysis
    nonisolated func getWatchingGapsAnalysis() async throws -> [WatchingGap] {
        let response = try await supabase.rpc("get_watching_gaps_analysis").execute()
        
        let gaps: [WatchingGap] = try JSONDecoder().decode([WatchingGap].self, from: response.data)
        return gaps
    }
    
    // MARK: - Streak Statistics
    
    /// Get streak statistics for a specific year (NULL for all time)
    nonisolated func getStreakStats(year: Int? = nil) async throws -> StreakStats {
        do {
            let response = if let year = year {
                try await supabase.rpc("get_streak_stats", params: ["target_year": year]).execute()
            } else {
                try await supabase.rpc("get_streak_stats", params: ["target_year": Optional<Int>.none]).execute()
            }
            
            // Try to decode as array first
            if let stats = try? JSONDecoder().decode([StreakStats].self, from: response.data),
               let streakStats = stats.first {
                return streakStats
            }
            
            // Try to decode as single object
            if let streakStats = try? JSONDecoder().decode(StreakStats.self, from: response.data) {
                return streakStats
            }
            
            // Return mock data if database function doesn't exist
            return StreakStats(
                longestStreakDays: 0,
                longestStreakStartDate: nil,
                longestStreakEndDate: nil,
                longestStreakStartTitle: nil,
                longestStreakStartPoster: nil,
                longestStreakEndTitle: nil,
                longestStreakEndPoster: nil,
                currentStreakDays: 0,
                currentStreakStartDate: nil,
                currentStreakEndDate: nil,
                currentStreakStartTitle: nil,
                currentStreakStartPoster: nil,
                currentStreakEndTitle: nil,
                currentStreakEndPoster: nil,
                isCurrentStreakActive: false
            )
            
        } catch {
            // Return mock data instead of throwing error
            return StreakStats(
                longestStreakDays: 0,
                longestStreakStartDate: nil,
                longestStreakEndDate: nil,
                longestStreakStartTitle: nil,
                longestStreakStartPoster: nil,
                longestStreakEndTitle: nil,
                longestStreakEndPoster: nil,
                currentStreakDays: 0,
                currentStreakStartDate: nil,
                currentStreakEndDate: nil,
                currentStreakStartTitle: nil,
                currentStreakStartPoster: nil,
                currentStreakEndTitle: nil,
                currentStreakEndPoster: nil,
                isCurrentStreakActive: false
            )
        }
    }
    
    // MARK: - Year Release Date Statistics
    
    /// Get year release date statistics for a specific year
    nonisolated func getYearReleaseStats(year: Int) async throws -> YearReleaseStats {
        do {
            let response = try await supabase.rpc("get_year_release_stats", params: ["target_year": year]).execute()
            
            
            // Try to decode as array first
            if let stats = try? JSONDecoder().decode([YearReleaseStats].self, from: response.data),
               let yearReleaseStats = stats.first {
                return yearReleaseStats
            }
            
            // Try to decode as single object
            if let yearReleaseStats = try? JSONDecoder().decode(YearReleaseStats.self, from: response.data) {
                return yearReleaseStats
            }
            
            // Return mock data if database function doesn't exist
            return YearReleaseStats(
                totalFilms: 0,
                filmsFromYear: 0,
                filmsFromOtherYears: 0,
                yearPercentage: 0.0,
                otherYearsPercentage: 0.0
            )
            
        } catch {
            // Return mock data instead of throwing error
            return YearReleaseStats(
                totalFilms: 0,
                filmsFromYear: 0,
                filmsFromOtherYears: 0,
                yearPercentage: 0.0,
                otherYearsPercentage: 0.0
            )
        }
    }
    
    // MARK: - Top Watched Films
    
    /// Get top 6 most watched films (all-time only)
    nonisolated func getTopWatchedFilms() async throws -> [TopWatchedFilm] {
        do {
            let response = try await supabase.rpc("get_top_watched_films").execute()
            
            
            let topFilms: [TopWatchedFilm] = try JSONDecoder().decode([TopWatchedFilm].self, from: response.data)
            return topFilms
            
        } catch {
            // Return empty array instead of throwing error
            return []
        }
    }
    
    // MARK: - Advanced Film Journey Statistics
    
    /// Get days with 2+ films count (all-time only)
    nonisolated func getDaysWith2PlusFilms() async throws -> Int {
        do {
            let response = try await supabase.rpc("get_days_with_2plus_films").execute()
            
            
            // The function returns an integer directly
            if let dataString = String(data: response.data, encoding: .utf8),
               let count = Int(dataString.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)) {
                return count
            }
            
            return 0
            
        } catch {
            return 0
        }
    }
    
    /// Get average movies per year (all-time only)
    nonisolated func getAverageMoviesPerYear() async throws -> Double {
        do {
            let response = try await supabase.rpc("get_average_movies_per_year").execute()
            
            
            // The function returns a numeric directly
            if let dataString = String(data: response.data, encoding: .utf8),
               let average = Double(dataString.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)) {
                return average
            }
            
            return 0.0
            
        } catch {
            return 0.0
        }
    }
    
    /// Get unique 5-star films count (all-time only)
    nonisolated func getUnique5StarFilms() async throws -> Int {
        do {
            let response = try await supabase.rpc("get_unique_5star_films").execute()
            
            
            // The function returns an integer directly
            if let dataString = String(data: response.data, encoding: .utf8),
               let count = Int(dataString.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)) {
                return count
            }
            
            return 0
            
        } catch {
            return 0
        }
    }
    
    /// Get highest monthly average rating (all-time only)
    nonisolated func getHighestMonthlyAverage() async throws -> HighestMonthlyAverage? {
        do {
            let response = try await supabase.rpc("get_highest_monthly_average_rating").execute()
            
            
            let monthlyAverages: [HighestMonthlyAverage] = try JSONDecoder().decode([HighestMonthlyAverage].self, from: response.data)
            return monthlyAverages.first
            
        } catch {
            return nil
        }
    }
    
    // MARK: - Year-Filtered Advanced Journey Statistics
    
    /// Get days with 2+ films count for specific year
    nonisolated func getDaysWith2PlusFilmsByYear(year: Int) async throws -> Int {
        do {
            let response = try await supabase.rpc("get_days_with_2plus_films_by_year", params: ["target_year": year]).execute()
            
            
            // The function returns an integer directly
            if let dataString = String(data: response.data, encoding: .utf8),
               let count = Int(dataString.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)) {
                return count
            }
            
            return 0
            
        } catch {
            return 0
        }
    }
    
    /// Get must watch completion percentage for specific year
    nonisolated func getMustWatchCompletionByYear(year: Int) async throws -> MustWatchCompletion? {
        do {
            let response = try await supabase.rpc("get_must_watch_completion_by_year", params: ["target_year": year]).execute()
            
            
            let completions: [MustWatchCompletion] = try JSONDecoder().decode([MustWatchCompletion].self, from: response.data)
            return completions.first
            
        } catch {
            return nil
        }
    }
    
    /// Get unique 5-star films count for specific year (based on first rating date)
    nonisolated func getUnique5StarFilmsByYear(year: Int) async throws -> Int {
        do {
            let response = try await supabase.rpc("get_unique_5star_films_by_year", params: ["target_year": year]).execute()
            
            
            // The function returns an integer directly
            if let dataString = String(data: response.data, encoding: .utf8),
               let count = Int(dataString.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)) {
                return count
            }
            
            return 0
            
        } catch {
            return 0
        }
    }
    
    /// Get highest monthly average rating for specific year (minimum 2 films)
    nonisolated func getHighestMonthlyAverageByYear(year: Int) async throws -> HighestMonthlyAverage? {
        do {
            let response = try await supabase.rpc("get_highest_monthly_average_rating_by_year", params: ["target_year": year]).execute()
            
            
            let monthlyAverages: [HighestMonthlyAverage] = try JSONDecoder().decode([HighestMonthlyAverage].self, from: response.data)
            return monthlyAverages.first
            
        } catch {
            return nil
        }
    }
}

// MARK: - Statistics Error Types

enum StatisticsError: LocalizedError {
    case noDataReturned
    case invalidDataFormat
    case fetchFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .noDataReturned:
            return "No statistics data returned from server"
        case .invalidDataFormat:
            return "Invalid data format received from server"
        case .fetchFailed(let error):
            return "Failed to fetch statistics: \(error.localizedDescription)"
        }
    }
}

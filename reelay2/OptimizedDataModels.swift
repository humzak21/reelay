//
//  OptimizedDataModels.swift
//  reelay2
//
//  Response models for optimized database functions
//

import Foundation
import SwiftUI
import Combine

// MARK: - Response from get_lists_with_summary

struct ListWithSummaryDb: Codable {
    let id: String
    let userId: String
    let name: String
    let description: String?
    let createdAt: String
    let updatedAt: String
    let pinned: Bool
    let ranked: Bool
    let tags: String?
    let themedMonthDate: String?
    let itemCount: Int
    let watchedCount: Int
    let firstItemPosterUrl: String?
    let firstItemBackdropPath: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case description
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case pinned
        case ranked
        case tags
        case themedMonthDate = "themed_month_date"
        case itemCount = "item_count"
        case watchedCount = "watched_count"
        case firstItemPosterUrl = "first_item_poster_url"
        case firstItemBackdropPath = "first_item_backdrop_path"
    }
    
    /// Convert to MovieList with summary data
    func toMovieList() -> MovieList {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        return MovieList(
            id: UUID(uuidString: id) ?? UUID(),
            userId: UUID(uuidString: userId) ?? UUID(),
            name: name,
            description: description,
            createdAt: MovieList.parseDate(createdAt) ?? Date(),
            updatedAt: MovieList.parseDate(updatedAt) ?? Date(),
            itemCount: itemCount,
            pinned: pinned,
            ranked: ranked,
            tags: tags,
            themedMonthDate: themedMonthDate != nil ? MovieList.parseDate(themedMonthDate!) : nil
        )
    }
}

// MARK: - Response from get_first_watch_dates

struct FirstWatchDate: Codable {
    let tmdbId: Int
    let firstWatchDate: String?
    let firstWatchYear: Int?
    
    enum CodingKeys: String, CodingKey {
        case tmdbId = "tmdb_id"
        case firstWatchDate = "first_watch_date"
        case firstWatchYear = "first_watch_year"
    }
}

// MARK: - Response from get_goals_data

struct GoalListData: Codable {
    let listType: String
    let listId: String
    let listName: String
    let totalItems: Int
    let watchedCount: Int
    let items: String // JSON string, decode separately
    
    enum CodingKeys: String, CodingKey {
        case listType = "list_type"
        case listId = "list_id"
        case listName = "list_name"
        case totalItems = "total_items"
        case watchedCount = "watched_count"
        case items
    }
    
    /// Parse the items JSON string into GoalItem array
    func parseItems() -> [GoalItem] {
        guard let data = items.data(using: .utf8) else { return [] }
        do {
            return try JSONDecoder().decode([GoalItem].self, from: data)
        } catch {
            print("Error parsing goal items: \(error)")
            return []
        }
    }
}

struct GoalItem: Codable {
    let tmdbId: Int
    let title: String
    let posterUrl: String?
    let isWatched: Bool
    
    enum CodingKeys: String, CodingKey {
        case tmdbId = "tmdb_id"
        case title
        case posterUrl = "poster_url"
        case isWatched = "is_watched"
    }
}

// MARK: - Response from get_must_watches_mapping

struct MustWatchesMapping: Codable {
    let tmdbId: Int
    let years: [Int]
    
    enum CodingKeys: String, CodingKey {
        case tmdbId = "tmdb_id"
        case years
    }
}

// MARK: - Response from get_list_items_with_watched

struct ListItemWithWatched: Codable {
    let id: Int64
    let listId: String
    let tmdbId: Int
    let movieTitle: String
    let moviePosterUrl: String?
    let movieBackdropPath: String?
    let movieYear: Int?
    let movieReleaseDate: String?
    let addedAt: String
    let sortOrder: Int
    let isWatched: Bool
    let diaryEntryId: Int?
    let rating: Double?
    let ratings100: Double?
    
    enum CodingKeys: String, CodingKey {
        case id
        case listId = "list_id"
        case tmdbId = "tmdb_id"
        case movieTitle = "movie_title"
        case moviePosterUrl = "movie_poster_url"
        case movieBackdropPath = "movie_backdrop_path"
        case movieYear = "movie_year"
        case movieReleaseDate = "movie_release_date"
        case addedAt = "added_at"
        case sortOrder = "sort_order"
        case isWatched = "is_watched"
        case diaryEntryId = "diary_entry_id"
        case rating
        case ratings100
    }
    
    /// Convert to standard ListItem
    func toListItem() -> ListItem {
        return ListItem(
            id: id,
            listId: UUID(uuidString: listId) ?? UUID(),
            tmdbId: tmdbId,
            movieTitle: movieTitle,
            moviePosterUrl: moviePosterUrl,
            movieBackdropPath: movieBackdropPath,
            movieYear: movieYear,
            movieReleaseDate: movieReleaseDate,
            addedAt: MovieList.parseDate(addedAt) ?? Date(),
            sortOrder: sortOrder
        )
    }
}

// MARK: - Rewatch Color Enum

enum RewatchColor: String {
    case grey
    case yellow
    case orange
    case none
    
    var swiftUIColor: SwiftUI.Color {
        switch self {
        case .grey: return .gray
        case .yellow: return .yellow
        case .orange: return .orange
        case .none: return .clear
        }
    }
}

// MARK: - First Watch Date Cache

/// Cache for first watch dates to avoid repeated queries
@MainActor
class FirstWatchDateCache: ObservableObject {
    static let shared = FirstWatchDateCache()
    
    /// Map of tmdbId -> (firstWatchDate, firstWatchYear)
    @Published private(set) var cache: [Int: (date: Date?, year: Int?)] = [:]
    
    /// Last time the cache was refreshed
    private var lastRefreshTime: Date?
    
    /// Cache validity duration (5 minutes)
    private let cacheValidityDuration: TimeInterval = 300
    
    private init() {}
    
    /// Check if cache needs refresh
    var needsRefresh: Bool {
        guard let lastRefresh = lastRefreshTime else { return true }
        return Date().timeIntervalSince(lastRefresh) > cacheValidityDuration
    }
    
    /// Update cache with new data
    func update(with firstWatchDates: [FirstWatchDate]) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        for item in firstWatchDates {
            let date = item.firstWatchDate != nil ? dateFormatter.date(from: item.firstWatchDate!) : nil
            cache[item.tmdbId] = (date: date, year: item.firstWatchYear)
        }
        lastRefreshTime = Date()
    }
    
    /// Get first watch info for a tmdbId
    func getFirstWatch(for tmdbId: Int) -> (date: Date?, year: Int?)? {
        return cache[tmdbId]
    }
    
    /// Clear the cache
    func clear() {
        cache.removeAll()
        lastRefreshTime = nil
    }
}

// MARK: - Must Watches Cache

/// Cache for must watches mapping to avoid repeated queries
@MainActor
class MustWatchesCache: ObservableObject {
    static let shared = MustWatchesCache()
    
    /// Map of tmdbId -> years it appears in Must Watches lists
    @Published private(set) var cache: [Int: [Int]] = [:]
    
    /// Last time the cache was refreshed
    private var lastRefreshTime: Date?
    
    /// Cache validity duration (5 minutes)
    private let cacheValidityDuration: TimeInterval = 300
    
    private init() {}
    
    /// Check if cache needs refresh
    var needsRefresh: Bool {
        guard let lastRefresh = lastRefreshTime else { return true }
        return Date().timeIntervalSince(lastRefresh) > cacheValidityDuration
    }
    
    /// Update cache with new data
    func update(with mappings: [MustWatchesMapping]) {
        cache.removeAll()
        for mapping in mappings {
            cache[mapping.tmdbId] = mapping.years
        }
        lastRefreshTime = Date()
    }
    
    /// Check if a movie is on must watches list for a given year
    func isOnMustWatches(tmdbId: Int, year: Int) -> Bool {
        guard let years = cache[tmdbId] else { return false }
        return years.contains(year)
    }
    
    /// Get all years a movie appears in Must Watches
    func getYears(for tmdbId: Int) -> [Int] {
        return cache[tmdbId] ?? []
    }
    
    /// Clear the cache
    func clear() {
        cache.removeAll()
        lastRefreshTime = nil
    }
}

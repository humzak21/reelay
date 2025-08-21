//
//  ListModels.swift
//  reelay2
//
//  Created by Humza Khalil on 8/4/25.
//

import Foundation
import SwiftData

struct MovieList: Codable, Identifiable, @unchecked Sendable {
    let id: UUID
    let userId: UUID
    let name: String
    let description: String?
    let createdAt: Date
    let updatedAt: Date
    let itemCount: Int
    let pinned: Bool
    let ranked: Bool
    
    init(id: UUID = UUID(), userId: UUID, name: String, description: String? = nil, createdAt: Date = Date(), updatedAt: Date = Date(), itemCount: Int = 0, pinned: Bool = false, ranked: Bool = false) {
        self.id = id
        self.userId = userId
        self.name = name
        self.description = description
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.itemCount = itemCount
        self.pinned = pinned
        self.ranked = ranked
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case description
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case itemCount = "item_count"
        case pinned
        case ranked
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        if let uuidString = try? container.decode(String.self, forKey: .id),
           let uuid = UUID(uuidString: uuidString) {
            id = uuid
        } else {
            id = UUID()
        }
        
        if let userIdString = try? container.decode(String.self, forKey: .userId),
           let userUuid = UUID(uuidString: userIdString) {
            userId = userUuid
        } else {
            userId = UUID()
        }
        
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        
        // Handle date decoding with multiple formatters
        if let createdAtString = try? container.decode(String.self, forKey: .createdAt) {
            createdAt = Self.parseDate(createdAtString) ?? Date()
        } else {
            createdAt = Date()
        }
        
        if let updatedAtString = try? container.decode(String.self, forKey: .updatedAt) {
            updatedAt = Self.parseDate(updatedAtString) ?? Date()
        } else {
            updatedAt = Date()
        }
        
        itemCount = try container.decodeIfPresent(Int.self, forKey: .itemCount) ?? 0
        pinned = try container.decodeIfPresent(Bool.self, forKey: .pinned) ?? false
        ranked = try container.decodeIfPresent(Bool.self, forKey: .ranked) ?? false
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id.uuidString, forKey: .id)
        try container.encode(userId.uuidString, forKey: .userId)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encode(ISO8601DateFormatter().string(from: createdAt), forKey: .createdAt)
        try container.encode(ISO8601DateFormatter().string(from: updatedAt), forKey: .updatedAt)
        try container.encode(itemCount, forKey: .itemCount)
        try container.encode(pinned, forKey: .pinned)
        try container.encode(ranked, forKey: .ranked)
    }
    
    // Helper method to parse dates from various formats
    static func parseDate(_ dateString: String) -> Date? {
        // Try ISO8601 with fractional seconds first
        let iso8601Formatter = ISO8601DateFormatter()
        iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso8601Formatter.date(from: dateString) {
            return date
        }
        
        // Try ISO8601 without fractional seconds
        iso8601Formatter.formatOptions = [.withInternetDateTime]
        if let date = iso8601Formatter.date(from: dateString) {
            return date
        }
        
        // Try custom format for the exact format we see: 2025-07-12T15:19:52.838477+00:00
        let customFormatter = DateFormatter()
        customFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSXXXXX"
        if let date = customFormatter.date(from: dateString) {
            return date
        }
        
        // Try without microseconds
        customFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssXXXXX"
        if let date = customFormatter.date(from: dateString) {
            return date
        }
        
        // Try PostgreSQL timestamp format
        customFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSSSSSXXXXX"
        if let date = customFormatter.date(from: dateString) {
            return date
        }
        
        // If all parsing attempts fail, return nil and let the caller handle it
        return nil
    }
}

// Synthetic Watchlist presentation in UI
extension MovieList {
    static func watchlistPlaceholder(userId: UUID) -> MovieList {
        return MovieList(
            id: SupabaseWatchlistService.watchlistListId,
            userId: userId,
            name: "Watchlist",
            description: "Movies you plan to watch",
            createdAt: Date(),
            updatedAt: Date(),
            itemCount: 0,
            pinned: false,
            ranked: false
        )
    }
}

struct ListItem: Codable, Identifiable, @unchecked Sendable {
    let id: Int64
    let listId: UUID
    let tmdbId: Int
    let movieTitle: String
    let moviePosterUrl: String?
    let movieBackdropPath: String?
    let movieYear: Int?
    let movieReleaseDate: String?
    let addedAt: Date
    let sortOrder: Int
    
    init(id: Int64, listId: UUID, tmdbId: Int, movieTitle: String, moviePosterUrl: String? = nil, movieBackdropPath: String? = nil, movieYear: Int? = nil, movieReleaseDate: String? = nil, addedAt: Date = Date(), sortOrder: Int = 0) {
        self.id = id
        self.listId = listId
        self.tmdbId = tmdbId
        self.movieTitle = movieTitle
        self.moviePosterUrl = moviePosterUrl
        self.movieBackdropPath = movieBackdropPath
        self.movieYear = movieYear
        self.movieReleaseDate = movieReleaseDate
        self.addedAt = addedAt
        self.sortOrder = sortOrder
    }
    
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
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(Int64.self, forKey: .id)
        
        if let listIdString = try? container.decode(String.self, forKey: .listId),
           let listUuid = UUID(uuidString: listIdString) {
            listId = listUuid
        } else {
            listId = UUID()
        }
        
        tmdbId = try container.decode(Int.self, forKey: .tmdbId)
        movieTitle = try container.decode(String.self, forKey: .movieTitle)
        moviePosterUrl = try container.decodeIfPresent(String.self, forKey: .moviePosterUrl)
        movieBackdropPath = try container.decodeIfPresent(String.self, forKey: .movieBackdropPath)
        movieYear = try container.decodeIfPresent(Int.self, forKey: .movieYear)
        movieReleaseDate = try container.decodeIfPresent(String.self, forKey: .movieReleaseDate)
        
        if let addedAtString = try? container.decode(String.self, forKey: .addedAt) {
            addedAt = MovieList.parseDate(addedAtString) ?? Date()
        } else {
            addedAt = Date()
        }
        
        sortOrder = try container.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(listId.uuidString, forKey: .listId)
        try container.encode(tmdbId, forKey: .tmdbId)
        try container.encode(movieTitle, forKey: .movieTitle)
        try container.encodeIfPresent(moviePosterUrl, forKey: .moviePosterUrl)
        try container.encodeIfPresent(movieBackdropPath, forKey: .movieBackdropPath)
        try container.encodeIfPresent(movieYear, forKey: .movieYear)
        try container.encodeIfPresent(movieReleaseDate, forKey: .movieReleaseDate)
        try container.encode(ISO8601DateFormatter().string(from: addedAt), forKey: .addedAt)
        try container.encode(sortOrder, forKey: .sortOrder)
    }
}

// MARK: - ListItem Extensions
extension ListItem {
    var backdropURL: URL? {
        guard let urlString = movieBackdropPath, !urlString.isEmpty else { return nil }
        
        // If it's already a full URL, use it
        if urlString.hasPrefix("http") {
            return URL(string: urlString)
        }
        
        // If it's a relative path, construct the full TMDB URL
        if urlString.hasPrefix("/") {
            return URL(string: "https://image.tmdb.org/t/p/w1280\(urlString)")
        }
        
        // Fallback: try to use as-is
        return URL(string: urlString)
    }
    
    var posterURL: URL? {
        guard let urlString = moviePosterUrl, !urlString.isEmpty else { return nil }
        return URL(string: urlString)
    }
}

// MARK: - SwiftData Models for Local Storage

@Model
class PersistentMovieList {
    @Attribute(.unique) var id: String
    var userId: String
    var name: String
    var listDescription: String?
    var createdAt: Date
    var updatedAt: Date
    var itemCount: Int
    var pinned: Bool
    var ranked: Bool
    
    init(id: String, userId: String, name: String, listDescription: String? = nil, createdAt: Date = Date(), updatedAt: Date = Date(), itemCount: Int = 0, pinned: Bool = false, ranked: Bool = false) {
        self.id = id
        self.userId = userId
        self.name = name
        self.listDescription = listDescription
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.itemCount = itemCount
        self.pinned = pinned
        self.ranked = ranked
    }
    
    convenience init(from movieList: MovieList) {
        self.init(
            id: movieList.id.uuidString,
            userId: movieList.userId.uuidString,
            name: movieList.name,
            listDescription: movieList.description,
            createdAt: movieList.createdAt,
            updatedAt: movieList.updatedAt,
            itemCount: movieList.itemCount,
            pinned: movieList.pinned,
            ranked: movieList.ranked
        )
    }
    
    func toMovieList() -> MovieList {
        return MovieList(
            id: UUID(uuidString: id) ?? UUID(),
            userId: UUID(uuidString: userId) ?? UUID(),
            name: name,
            description: listDescription,
            createdAt: createdAt,
            updatedAt: updatedAt,
            itemCount: itemCount,
            pinned: pinned,
            ranked: ranked
        )
    }
    
    func update(from movieList: MovieList) {
        self.id = movieList.id.uuidString
        self.userId = movieList.userId.uuidString
        self.name = movieList.name
        self.listDescription = movieList.description
        self.createdAt = movieList.createdAt
        self.updatedAt = movieList.updatedAt
        self.itemCount = movieList.itemCount
        self.pinned = movieList.pinned
        self.ranked = movieList.ranked
    }
}

@Model
class PersistentListItem {
    @Attribute(.unique) var id: Int64
    var listId: String
    var tmdbId: Int
    var movieTitle: String
    var moviePosterUrl: String?
    var movieBackdropPath: String?
    var movieYear: Int?
    var movieReleaseDate: String?
    var addedAt: Date
    var sortOrder: Int
    
    init(id: Int64, listId: String, tmdbId: Int, movieTitle: String, moviePosterUrl: String? = nil, movieBackdropPath: String? = nil, movieYear: Int? = nil, movieReleaseDate: String? = nil, addedAt: Date = Date(), sortOrder: Int = 0) {
        self.id = id
        self.listId = listId
        self.tmdbId = tmdbId
        self.movieTitle = movieTitle
        self.moviePosterUrl = moviePosterUrl
        self.movieBackdropPath = movieBackdropPath
        self.movieYear = movieYear
        self.movieReleaseDate = movieReleaseDate
        self.addedAt = addedAt
        self.sortOrder = sortOrder
    }
    
    convenience init(from listItem: ListItem) {
        self.init(
            id: listItem.id,
            listId: listItem.listId.uuidString,
            tmdbId: listItem.tmdbId,
            movieTitle: listItem.movieTitle,
            moviePosterUrl: listItem.moviePosterUrl,
            movieBackdropPath: listItem.movieBackdropPath,
            movieYear: listItem.movieYear,
            movieReleaseDate: listItem.movieReleaseDate,
            addedAt: listItem.addedAt,
            sortOrder: listItem.sortOrder
        )
    }
    
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
            addedAt: addedAt,
            sortOrder: sortOrder
        )
    }
    
    func update(from listItem: ListItem) {
        self.id = listItem.id
        self.listId = listItem.listId.uuidString
        self.tmdbId = listItem.tmdbId
        self.movieTitle = listItem.movieTitle
        self.moviePosterUrl = listItem.moviePosterUrl
        self.movieBackdropPath = listItem.movieBackdropPath
        self.movieYear = listItem.movieYear
        self.movieReleaseDate = listItem.movieReleaseDate
        self.addedAt = listItem.addedAt
        self.sortOrder = listItem.sortOrder
    }
}

// MARK: - Supporting Types

struct Genre: Codable {
    let id: Int
    let name: String
}

// MARK: - Create/Update Request Models

struct CreateListRequest: Codable {
    let name: String
    let description: String?
    let userId: String
    let ranked: Bool
    
    enum CodingKeys: String, CodingKey {
        case name
        case description
        case userId = "user_id"
        case ranked
    }
}

struct UpdateListRequest: Codable {
    let name: String?
    let description: String?
    let ranked: Bool?
    
    init(name: String? = nil, description: String? = nil, ranked: Bool? = nil) {
        self.name = name
        self.description = description
        self.ranked = ranked
    }
}

// MARK: - Helper Extensions

extension MovieList {
    /// Checks if the list name or description contains ranking-related words
    static func shouldAutoEnableRanking(name: String, description: String?) -> Bool {
        let rankingKeywords = ["rank", "ranking", "ranks", "ranked", "top", "best", "tier", "order"]
        
        let separatorSet = CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters)
        let nameWords = name.lowercased().components(separatedBy: separatorSet)
        let descriptionWords = (description?.lowercased().components(separatedBy: separatorSet)) ?? []
        
        let allWords = Set(nameWords + descriptionWords).filter { !$0.isEmpty }
        
        return rankingKeywords.contains { keyword in
            allWords.contains { word in
                word.contains(keyword) || keyword.contains(word)
            }
        }
    }
}
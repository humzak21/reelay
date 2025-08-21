//
//  SupabaseWatchlistService.swift
//  reelay2
//
//  Created by Humza Khalil on 8/8/25.
//

import Foundation
import Supabase
import Combine
import Auth

@MainActor
class SupabaseWatchlistService: ObservableObject {
    static let shared = SupabaseWatchlistService()

    // Stable synthetic UUID used to represent the single Watchlist as a MovieList in UI
    nonisolated static let watchlistListId: UUID = UUID(uuidString: "00000000-0000-4000-8000-000000000001")!

    private let supabaseClient: SupabaseClient

    private init() {
        // Use the authenticated client from SupabaseMovieService to ensure RLS policies apply with user context
        self.supabaseClient = SupabaseMovieService.shared.client
    }

    // MARK: - Models
    struct WatchlistItem: Codable, Identifiable, @unchecked Sendable {
        let id: Int64
        let userId: UUID
        let tmdbId: Int
        let movieTitle: String
        let moviePosterUrl: String?
        let movieBackdropPath: String?
        let movieYear: Int?
        let movieReleaseDate: String?
        let addedAt: Date

        enum CodingKeys: String, CodingKey {
            case id
            case userId = "user_id"
            case tmdbId = "tmdb_id"
            case movieTitle = "movie_title"
            case moviePosterUrl = "movie_poster_url"
            case movieBackdropPath = "movie_backdrop_path"
            case movieYear = "movie_year"
            case movieReleaseDate = "movie_release_date"
            case addedAt = "added_at"
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try c.decode(Int64.self, forKey: .id)
            if let uidString = try? c.decode(String.self, forKey: .userId), let uid = UUID(uuidString: uidString) {
                userId = uid
            } else {
                userId = UUID()
            }
            tmdbId = try c.decode(Int.self, forKey: .tmdbId)
            movieTitle = try c.decode(String.self, forKey: .movieTitle)
            moviePosterUrl = try c.decodeIfPresent(String.self, forKey: .moviePosterUrl)
            movieBackdropPath = try c.decodeIfPresent(String.self, forKey: .movieBackdropPath)
            movieYear = try c.decodeIfPresent(Int.self, forKey: .movieYear)
            movieReleaseDate = try c.decodeIfPresent(String.self, forKey: .movieReleaseDate)
            if let addedAtString = try? c.decode(String.self, forKey: .addedAt) {
                addedAt = MovieList.parseDate(addedAtString) ?? Date()
            } else {
                addedAt = Date()
            }
        }
    }

    struct WatchlistInsert: Codable {
        let user_id: String
        let tmdb_id: Int
        let movie_title: String
        let movie_poster_url: String?
        let movie_backdrop_path: String?
        let movie_year: Int?
        let movie_release_date: String?
        let added_at: String?
    }

    struct WatchlistUpdatePayload: Codable {
        let movie_title: String?
        let movie_poster_url: String?
        let movie_backdrop_path: String?
        let movie_year: Int?
        let movie_release_date: String?
        let added_at: String?
    }

    // MARK: - API
    func fetchAll() async throws -> [WatchlistItem] {
        guard let userId = SupabaseMovieService.shared.currentUser?.id.uuidString else { return [] }
        
        // First, try without any limit to see if server enforces 1000 row limit
        var allItems: [WatchlistItem] = []
        var offset = 0
        let pageSize = 1000
        
        while true {
            let response = try await supabaseClient
                .from("watchlist")
                .select()
                .eq("user_id", value: userId)
                .order("added_at", ascending: false)
                .range(from: offset, to: offset + pageSize - 1)
                .execute()
            
            if response.data.isEmpty { break }
            
            let items = try JSONDecoder().decode([WatchlistItem].self, from: response.data)
            if items.isEmpty { break }
            
            allItems.append(contentsOf: items)
            
            // If we got fewer items than the page size, we've reached the end
            if items.count < pageSize { break }
            
            offset += pageSize
            
            // Safety check to prevent infinite loops
            if offset > 10000 { break }
        }
        
        return allItems
    }

    func count() async -> Int {
        do {
            return try await fetchAll().count
        } catch {
            return 0
        }
    }

    func deleteItem(tmdbId: Int) async throws {
        guard let user = SupabaseMovieService.shared.currentUser else {
            throw ListServiceError.authenticationRequired
        }
        try await supabaseClient
            .from("watchlist")
            .delete()
            .eq("user_id", value: user.id.uuidString)
            .eq("tmdb_id", value: tmdbId)
            .execute()
    }

    func upsertItem(tmdbId: Int, title: String, posterUrl: String?, backdropPath: String?, year: Int?, releaseDate: String?, addedAt: Date = Date()) async throws {
        guard let user = SupabaseMovieService.shared.currentUser else {
            throw ListServiceError.authenticationRequired
        }
        
        
        let payload = WatchlistInsert(
            user_id: user.id.uuidString,
            tmdb_id: tmdbId,
            movie_title: title,
            movie_poster_url: posterUrl,
            movie_backdrop_path: backdropPath,
            movie_year: year,
            movie_release_date: releaseDate,
            added_at: ISO8601DateFormatter().string(from: addedAt)
        )

        // Prefer upsert if available; fallback to insert with conflict handling
        do {
            let response = try await supabaseClient
                .from("watchlist")
                .upsert(payload)
                .select()
                .execute()
        } catch {
            // Fallback: try insert, ignoring unique violation by updating existing
            do {
                let response = try await supabaseClient
                    .from("watchlist")
                    .insert(payload)
                    .select()
                    .execute()
            } catch let insertError {
                // Try update existing row with typed payload
                let updatePayload = WatchlistUpdatePayload(
                    movie_title: title,
                    movie_poster_url: posterUrl,
                    movie_backdrop_path: backdropPath,
                    movie_year: year,
                    movie_release_date: releaseDate,
                    added_at: ISO8601DateFormatter().string(from: addedAt)
                )
                do {
                    let response = try await supabaseClient
                        .from("watchlist")
                        .update(updatePayload)
                        .eq("user_id", value: user.id.uuidString)
                        .eq("tmdb_id", value: tmdbId)
                        .execute()
                } catch let updateError {
                    // Bubble up the original insert error if both fail for easier debugging
                    throw updateError.localizedDescription.isEmpty ? insertError : updateError
                }
            }
        }
    }

    // Mapping to ListItem for use in UI
    func mapToListItems(_ watchlistItems: [WatchlistItem]) -> [ListItem] {
        var sortCounter = 1
        let mapped: [ListItem] = watchlistItems.map { item in
            defer { sortCounter += 1 }
            return ListItem(
                id: item.id,
                listId: Self.watchlistListId,
                tmdbId: item.tmdbId,
                movieTitle: item.movieTitle,
                moviePosterUrl: item.moviePosterUrl,
                movieBackdropPath: item.movieBackdropPath,
                movieYear: item.movieYear,
                movieReleaseDate: item.movieReleaseDate,
                addedAt: item.addedAt,
                sortOrder: sortCounter
            )
        }
        return mapped
    }
}



//
//  SupabaseTelevisionService.swift
//  reelay2
//
//  Created by Humza Khalil on 9/1/25.
//

import Foundation
import Supabase
import Combine

class SupabaseTelevisionService: ObservableObject {
    static let shared = SupabaseTelevisionService()
    
    private let supabase: SupabaseClient
    
    private init() {
        // Reuse the existing Supabase client from SupabaseMovieService
        self.supabase = SupabaseMovieService.shared.client
    }
    
    // MARK: - CRUD Operations
    
    /// Get all TV shows with optional filtering and sorting
    nonisolated func getTelevisionShows(
        searchQuery: String? = nil,
        sortBy: TVSortField = .name,
        ascending: Bool = true,
        limit: Int = 3000,
        offset: Int = 0
    ) async throws -> [Television] {
        
        var query = supabase
            .from("television")
            .select()
        
        // Apply search filter
        if let searchQuery = searchQuery, !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty {
            query = query.or("name.ilike.%\(searchQuery)%,overview.ilike.%\(searchQuery)%,original_name.ilike.%\(searchQuery)%")
        }
        
        // Apply sorting and pagination
        let sortColumn = sortBy.supabaseColumn
        let finalQuery = query.order(sortColumn, ascending: ascending)
                             .range(from: offset, to: offset + limit - 1)
        
        let response = try await finalQuery.execute()
        
        if response.data.isEmpty {
            return []
        }
        
        let responseString = String(data: response.data, encoding: .utf8) ?? ""
        
        // If response is just [], the table is empty
        if responseString.trimmingCharacters(in: .whitespacesAndNewlines) == "[]" {
            return []
        }
        
        let shows: [Television] = try JSONDecoder().decode([Television].self, from: response.data)
        return shows
    }
    
    /// Get TV shows by status
    nonisolated func getTelevisionByStatus(_ status: WatchingStatus) async throws -> [Television] {
        let response = try await supabase
            .from("television")
            .select()
            .eq("status", value: status.rawValue)
            .order("name", ascending: true)
            .execute()
        
        if response.data.isEmpty {
            return []
        }
        
        let shows: [Television] = try JSONDecoder().decode([Television].self, from: response.data)
        return shows
    }
    
    /// Add a new TV show
    nonisolated func addTelevision(_ tvData: AddTelevisionRequest) async throws -> Television {
        let response = try await supabase
            .from("television")
            .insert(tvData)
            .select()
            .execute()
        
        let shows: [Television] = try JSONDecoder().decode([Television].self, from: response.data)
        guard let show = shows.first else {
            throw SupabaseTelevisionError.noShowReturned
        }
        
        return show
    }
    
    /// Update an existing TV show
    nonisolated func updateTelevision(id: Int, with tvData: UpdateTelevisionRequest) async throws -> Television {
        let response = try await supabase
            .from("television")
            .update(tvData)
            .eq("id", value: id)
            .select()
            .execute()
        
        let shows: [Television] = try JSONDecoder().decode([Television].self, from: response.data)
        guard let show = shows.first else {
            throw SupabaseTelevisionError.updateFailed
        }
        
        return show
    }
    
    /// Delete a TV show
    nonisolated func deleteTelevision(id: Int) async throws {
        try await supabase
            .from("television")
            .delete()
            .eq("id", value: id)
            .execute()
    }
    
    /// Check if a TV show exists by TMDB ID
    nonisolated func televisionExists(tmdbId: Int) async throws -> Television? {
        let response = try await supabase
            .from("television")
            .select()
            .eq("tmdb_id", value: tmdbId)
            .execute()
        
        let shows: [Television] = try JSONDecoder().decode([Television].self, from: response.data)
        return shows.first
    }
    
    /// Get TV shows by TMDB ID
    nonisolated func getTelevisionByTmdbId(tmdbId: Int) async throws -> [Television] {
        let response = try await supabase
            .from("television")
            .select()
            .eq("tmdb_id", value: tmdbId)
            .execute()
        
        let shows: [Television] = try JSONDecoder().decode([Television].self, from: response.data)
        return shows
    }
    
    /// Update viewing progress (season and episode)
    nonisolated func updateProgress(id: Int, season: Int, episode: Int) async throws -> Television {
        let updateData = UpdateProgressRequest(
            current_season: season,
            current_episode: episode,
            updated_at: ISO8601DateFormatter().string(from: Date())
        )
        
        let response = try await supabase
            .from("television")
            .update(updateData)
            .eq("id", value: id)
            .select()
            .execute()
        
        let shows: [Television] = try JSONDecoder().decode([Television].self, from: response.data)
        guard let show = shows.first else {
            throw SupabaseTelevisionError.updateFailed
        }
        
        return show
    }
    
    /// Update watching status
    nonisolated func updateStatus(id: Int, status: WatchingStatus) async throws -> Television {
        let updateData = UpdateStatusRequest(
            status: status.rawValue,
            updated_at: ISO8601DateFormatter().string(from: Date())
        )
        
        let response = try await supabase
            .from("television")
            .update(updateData)
            .eq("id", value: id)
            .select()
            .execute()
        
        let shows: [Television] = try JSONDecoder().decode([Television].self, from: response.data)
        guard let show = shows.first else {
            throw SupabaseTelevisionError.updateFailed
        }
        
        return show
    }
    
    /// Update episode information for a TV show
    nonisolated func updateEpisodeInfo(
        id: Int,
        episodeName: String?,
        episodeOverview: String?,
        episodeAirDate: String?,
        episodeStillPath: String?,
        episodeRuntime: Int?,
        episodeVoteAverage: Double?
    ) async throws -> Television {
        let updateData = UpdateEpisodeInfoRequest(
            current_episode_name: episodeName,
            current_episode_overview: episodeOverview,
            current_episode_air_date: episodeAirDate,
            current_episode_still_path: episodeStillPath,
            current_episode_runtime: episodeRuntime,
            current_episode_vote_average: episodeVoteAverage,
            updated_at: ISO8601DateFormatter().string(from: Date())
        )
        
        let response = try await supabase
            .from("television")
            .update(updateData)
            .eq("id", value: id)
            .select()
            .execute()
        
        let shows: [Television] = try JSONDecoder().decode([Television].self, from: response.data)
        guard let show = shows.first else {
            throw SupabaseTelevisionError.updateFailed
        }
        
        return show
    }
    
    /// Update progress and episode information together
    nonisolated func updateProgressWithEpisodeInfo(
        id: Int,
        season: Int,
        episode: Int,
        episodeName: String?,
        episodeOverview: String?,
        episodeAirDate: String?,
        episodeStillPath: String?,
        episodeRuntime: Int?,
        episodeVoteAverage: Double?
    ) async throws -> Television {
        let updateData = UpdateTelevisionRequest(
            name: nil,
            first_air_year: nil,
            first_air_date: nil,
            last_air_date: nil,
            overview: nil,
            poster_url: nil,
            backdrop_path: nil,
            vote_average: nil,
            vote_count: nil,
            popularity: nil,
            original_language: nil,
            original_name: nil,
            tagline: nil,
            series_status: nil,
            homepage: nil,
            genres: nil,
            networks: nil,
            created_by: nil,
            episode_run_time: nil,
            in_production: nil,
            number_of_episodes: nil,
            number_of_seasons: nil,
            origin_country: nil,
            type: nil,
            status: nil,
            current_season: season,
            current_episode: episode,
            total_seasons: nil,
            total_episodes: nil,
            rating: nil,
            detailed_rating: nil,
            review: nil,
            tags: nil,
            current_episode_name: episodeName,
            current_episode_overview: episodeOverview,
            current_episode_air_date: episodeAirDate,
            current_episode_still_path: episodeStillPath,
            current_episode_runtime: episodeRuntime,
            current_episode_vote_average: episodeVoteAverage,
            updated_at: ISO8601DateFormatter().string(from: Date())
        )
        
        let response = try await supabase
            .from("television")
            .update(updateData)
            .eq("id", value: id)
            .select()
            .execute()
        
        let shows: [Television] = try JSONDecoder().decode([Television].self, from: response.data)
        guard let show = shows.first else {
            throw SupabaseTelevisionError.updateFailed
        }
        
        return show
    }
}

// MARK: - Request Models

struct AddTelevisionRequest: Codable {
    let name: String
    let tmdb_id: Int?
    let first_air_year: Int?
    let first_air_date: String?
    let last_air_date: String?
    let overview: String?
    let poster_url: String?
    let backdrop_path: String?
    let vote_average: Double?
    let vote_count: Int?
    let popularity: Double?
    let original_language: String?
    let original_name: String?
    let tagline: String?
    let series_status: String?
    let homepage: String?
    let genres: [String]?
    let networks: [String]?
    let created_by: [String]?
    let episode_run_time: [Int]?
    let in_production: Bool?
    let number_of_episodes: Int?
    let number_of_seasons: Int?
    let origin_country: [String]?
    let type: String?
    let status: String?
    let current_season: Int?
    let current_episode: Int?
    let total_seasons: Int?
    let total_episodes: Int?
    let rating: Double?
    let detailed_rating: Double?
    let review: String?
    let tags: String?
    let current_episode_name: String?
    let current_episode_overview: String?
    let current_episode_air_date: String?
    let current_episode_still_path: String?
    let current_episode_runtime: Int?
    let current_episode_vote_average: Double?
    let created_at: String?
}

struct UpdateTelevisionRequest: Codable {
    let name: String?
    let first_air_year: Int?
    let first_air_date: String?
    let last_air_date: String?
    let overview: String?
    let poster_url: String?
    let backdrop_path: String?
    let vote_average: Double?
    let vote_count: Int?
    let popularity: Double?
    let original_language: String?
    let original_name: String?
    let tagline: String?
    let series_status: String?
    let homepage: String?
    let genres: [String]?
    let networks: [String]?
    let created_by: [String]?
    let episode_run_time: [Int]?
    let in_production: Bool?
    let number_of_episodes: Int?
    let number_of_seasons: Int?
    let origin_country: [String]?
    let type: String?
    let status: String?
    let current_season: Int?
    let current_episode: Int?
    let total_seasons: Int?
    let total_episodes: Int?
    let rating: Double?
    let detailed_rating: Double?
    let review: String?
    let tags: String?
    let current_episode_name: String?
    let current_episode_overview: String?
    let current_episode_air_date: String?
    let current_episode_still_path: String?
    let current_episode_runtime: Int?
    let current_episode_vote_average: Double?
    let updated_at: String?
}

struct UpdateProgressRequest: Codable {
    let current_season: Int
    let current_episode: Int
    let updated_at: String
}

struct UpdateEpisodeInfoRequest: Codable {
    let current_episode_name: String?
    let current_episode_overview: String?
    let current_episode_air_date: String?
    let current_episode_still_path: String?
    let current_episode_runtime: Int?
    let current_episode_vote_average: Double?
    let updated_at: String
}

struct UpdateStatusRequest: Codable {
    let status: String
    let updated_at: String
}

// MARK: - Sort Fields
enum TVSortField: String, CaseIterable {
    case name = "name"
    case firstAirDate = "first_air_date"
    case rating = "rating"
    case status = "status"
    case createdAt = "created_at"
    case updatedAt = "updated_at"
    
    var displayName: String {
        switch self {
        case .name:
            return "Name"
        case .firstAirDate:
            return "First Air Date"
        case .rating:
            return "Rating"
        case .status:
            return "Status"
        case .createdAt:
            return "Date Added"
        case .updatedAt:
            return "Last Updated"
        }
    }
    
    var supabaseColumn: String {
        switch self {
        case .name:
            return "name"
        case .firstAirDate:
            return "first_air_date"
        case .rating:
            return "rating"
        case .status:
            return "status"
        case .createdAt:
            return "created_at"
        case .updatedAt:
            return "updated_at"
        }
    }
}

// MARK: - Errors
enum SupabaseTelevisionError: LocalizedError {
    case noShowReturned
    case updateFailed
    case deleteFailed
    case invalidData
    
    var errorDescription: String? {
        switch self {
        case .noShowReturned:
            return "No TV show was returned from the database"
        case .updateFailed:
            return "Failed to update TV show"
        case .deleteFailed:
            return "Failed to delete TV show"
        case .invalidData:
            return "Invalid TV show data"
        }
    }
}
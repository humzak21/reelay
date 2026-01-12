//
//  SupabaseMovieService.swift
//  reelay2
//
//  Created by Humza Khalil on 7/31/25.
//

import Foundation
import Supabase
import Combine

class SupabaseMovieService: ObservableObject {
    static let shared = SupabaseMovieService()
    
    private let supabase: SupabaseClient
    @Published var isLoggedIn = false
    @Published var currentUser: User?
    
    // Expose the authenticated client so other services (e.g., Watchlist) share the same auth/session
    var client: SupabaseClient { supabase }
    
    private init() {
        guard let supabaseURL = URL(string: Config.supabaseURL) else {
            fatalError("Missing Supabase URL configuration")
        }
        
        let supabaseKey = Config.supabaseAnonKey
        
        self.supabase = SupabaseClient(
            supabaseURL: supabaseURL,
            supabaseKey: supabaseKey
        )
        
        // Check current auth state
        Task {
            await checkAuthState()
        }
    }
    
    // MARK: - Authentication
    
    @MainActor
    private func checkAuthState() async {
        do {
            let session = try await supabase.auth.session
            currentUser = session.user
            isLoggedIn = true
        } catch {
            currentUser = nil
            isLoggedIn = false
        }
    }
    
    @MainActor
    func signUp(email: String, password: String) async throws {
        let response = try await supabase.auth.signUp(
            email: email,
            password: password
        )
        
        currentUser = response.user
        isLoggedIn = true
    }
    
    @MainActor
    func signIn(email: String, password: String) async throws {
        let response = try await supabase.auth.signIn(
            email: email,
            password: password
        )
        
        currentUser = response.user
        isLoggedIn = true
    }
    
    @MainActor
    func signOut() async throws {
        try await supabase.auth.signOut()
        
        currentUser = nil
        isLoggedIn = false
    }
    
    // MARK: - CRUD Operations
    
    /// Get all movies with optional filtering and sorting
    nonisolated func getMovies(
        searchQuery: String? = nil,
        sortBy: MovieSortField = .watchDate,
        ascending: Bool = false,
        limit: Int = 3000,
        offset: Int = 0
    ) async throws -> [Movie] {
        
        var query = supabase
            .from("diary")
            .select()
        
        // Apply search filter
        if let searchQuery = searchQuery, !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty {
            query = query.or("title.ilike.%\(searchQuery)%,director.ilike.%\(searchQuery)%,overview.ilike.%\(searchQuery)%")
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
        
        let movies: [Movie] = try JSONDecoder().decode([Movie].self, from: response.data)
        return movies
    }
    
    /// Add a new movie to the diary
    nonisolated func addMovie(_ movieData: AddMovieRequest) async throws -> Movie {
        let response = try await supabase
            .from("diary")
            .insert(movieData)
            .select()
            .execute()
        
        let movies: [Movie] = try JSONDecoder().decode([Movie].self, from: response.data)
        guard let movie = movies.first else {
            throw SupabaseMovieError.noMovieReturned
        }
        
        // Automatically remove from watchlist after successfully adding to diary
        if let tmdbId = movieData.tmdb_id {
            Task { @MainActor in
                do {
                    try await SupabaseWatchlistService.shared.deleteItem(tmdbId: tmdbId)
                    // Refresh the watchlist data to update the UI
                    await DataManager.shared.refreshWatchlist()
                } catch {
                    // Don't throw - the movie was successfully added to diary
                }
            }
        }
        
        return movie
    }
    
    /// Update an existing movie
    nonisolated func updateMovie(id: Int, with movieData: UpdateMovieRequest) async throws -> Movie {
        let response = try await supabase
            .from("diary")
            .update(movieData)
            .eq("id", value: id)
            .select()
            .execute()
        
        let movies: [Movie] = try JSONDecoder().decode([Movie].self, from: response.data)
        guard let movie = movies.first else {
            throw SupabaseMovieError.noMovieReturned
        }
        
        return movie
    }
    
    /// Delete a movie
    nonisolated func deleteMovie(id: Int) async throws {
        try await supabase
            .from("diary")
            .delete()
            .eq("id", value: id)
            .execute()
    }
    
    /// Check if a movie with the given TMDB ID already exists
    nonisolated func movieExists(tmdbId: Int) async throws -> Movie? {
        let response = try await supabase
            .from("diary")
            .select()
            .eq("tmdb_id", value: tmdbId)
            .limit(1)
            .execute()
        
        let movies: [Movie] = try JSONDecoder().decode([Movie].self, from: response.data)
        return movies.first
    }
    
    /// Get all movies with the given TMDB ID (for finding previous watches)
    nonisolated func getMoviesByTmdbId(tmdbId: Int) async throws -> [Movie] {
        let response = try await supabase
            .from("diary")
            .select()
            .eq("tmdb_id", value: tmdbId)
            .order("watched_date", ascending: false)
            .execute()
        
        let movies: [Movie] = try JSONDecoder().decode([Movie].self, from: response.data)
        return movies
    }
    
    /// Update poster URL for all movies with the given TMDB ID
    nonisolated func updatePosterForTmdbId(tmdbId: Int, newPosterUrl: String) async throws {
        try await supabase
            .from("diary")
            .update(["poster_url": newPosterUrl])
            .eq("tmdb_id", value: tmdbId)
            .execute()
    }
    
    /// Update backdrop URL for all movies with the given TMDB ID
    nonisolated func updateBackdropForTmdbId(tmdbId: Int, newBackdropUrl: String) async throws {
        try await supabase
            .from("diary")
            .update(["backdrop_path": newBackdropUrl])
            .eq("tmdb_id", value: tmdbId)
            .execute()
    }
    
    /// Get movies with detailed ratings in the specified range
    nonisolated func getMoviesInRatingRange(minRating: Double, maxRating: Double, limit: Int = 3000) async throws -> [Movie] {
        let response = try await supabase
            .from("diary")
            .select()
            .gte("ratings100", value: minRating)
            .lte("ratings100", value: maxRating)
            .not("ratings100", operator: .is, value: AnyJSON.null)
            .order("ratings100", ascending: false)
            .limit(limit)
            .execute()
        
        let movies: [Movie] = try JSONDecoder().decode([Movie].self, from: response.data)
        return movies
    }
    
    /// Get watched movie count for multiple TMDB IDs (batch query for efficiency)
    nonisolated func getWatchedCountForTmdbIds(tmdbIds: [Int]) async throws -> [Int: Int] {
        guard !tmdbIds.isEmpty else { return [:] }
        
        let response = try await supabase
            .from("diary")
            .select("tmdb_id")
            .in("tmdb_id", values: tmdbIds)
            .execute()
        
        struct TmdbIdResult: Codable {
            let tmdb_id: Int
        }
        
        let results: [TmdbIdResult] = try JSONDecoder().decode([TmdbIdResult].self, from: response.data)
        
        // Count occurrences of each TMDB ID
        var counts: [Int: Int] = [:]
        for result in results {
            counts[result.tmdb_id, default: 0] += 1
        }
        
        return counts
    }
    
    /// Check which TMDB IDs have watched entries (batch query for efficiency)
    nonisolated func checkWatchedStatusForTmdbIds(tmdbIds: [Int]) async throws -> Set<Int> {
        guard !tmdbIds.isEmpty else { return Set() }
        
        let response = try await supabase
            .from("diary")
            .select("tmdb_id")
            .in("tmdb_id", values: tmdbIds)
            .execute()
        
        struct TmdbIdResult: Codable {
            let tmdb_id: Int
        }
        
        let results: [TmdbIdResult] = try JSONDecoder().decode([TmdbIdResult].self, from: response.data)
        
        // Return unique TMDB IDs that have entries
        return Set(results.map { $0.tmdb_id })
    }
    
    // MARK: - Favorite Functions
    
    nonisolated func toggleMovieFavorite(movieId: Int) async throws -> Movie {
        print("🔥 DEBUG SERVICE: toggleMovieFavorite called with movieId: \(movieId)")
        
        do {
            // First, fetch the current movie to get its favorite status
            print("🔥 DEBUG SERVICE: Fetching current movie state")
            let currentMovie: Movie = try await supabase
                .from("diary")
                .select()
                .eq("id", value: movieId)
                .single()
                .execute()
                .value
            
            print("🔥 DEBUG SERVICE: Current movie favorited field: \(currentMovie.favorited ?? false)")
            print("🔥 DEBUG SERVICE: Current movie isFavorited: \(currentMovie.isFavorited)")
            
            // Toggle the favorite status
            let newFavoriteStatus = !(currentMovie.favorited ?? false)
            print("🔥 DEBUG SERVICE: Setting favorited to: \(newFavoriteStatus)")
            
            let response: Movie = try await supabase
                .from("diary")
                .update([
                    "favorited": newFavoriteStatus
                ])
                .eq("id", value: movieId)
                .single()
                .execute()
                .value
            
            print("🔥 DEBUG SERVICE: Supabase response received")
            print("🔥 DEBUG SERVICE: Response movie ID: \(response.id)")
            print("🔥 DEBUG SERVICE: Response favorited field: \(response.favorited ?? false)")
            print("🔥 DEBUG SERVICE: Response isFavorited computed: \(response.isFavorited)")
            
            return response
        } catch {
            print("🔥 DEBUG SERVICE ERROR: Supabase update failed: \(error.localizedDescription)")
            print("🔥 DEBUG SERVICE ERROR: Full error: \(error)")
            throw SupabaseMovieError.updateFailed(error)
        }
    }
    
    nonisolated func setMovieFavorite(movieId: Int, isFavorite: Bool) async throws -> Movie {
        do {
            let response: Movie = try await supabase
                .from("diary")
                .update([
                    "favorited": isFavorite
                ])
                .eq("id", value: movieId)
                .single()
                .execute()
                .value
            
            return response
        } catch {
            throw SupabaseMovieError.updateFailed(error)
        }
    }
    
    nonisolated func getFavoriteMovies() async throws -> [Movie] {
        do {
            let movies: [Movie] = try await supabase
                .from("diary")
                .select()
                .eq("favorited", value: true)
                .order("created_at", ascending: false)
                .execute()
                .value
                
            return movies
        } catch {
            throw SupabaseMovieError.fetchFailed(error)
        }
    }
    
    // MARK: - Optimized Database Functions
    
    /// Fetch first watch dates for multiple TMDB IDs in a single batch query
    /// Uses the get_first_watch_dates database function
    nonisolated func getFirstWatchDatesBatch(tmdbIds: [Int]) async throws -> [FirstWatchDate] {
        guard !tmdbIds.isEmpty else { return [] }
        
        let response = try await supabase
            .rpc("get_first_watch_dates", params: ["tmdb_ids": tmdbIds])
            .execute()
        
        let firstWatchDates = try JSONDecoder().decode([FirstWatchDate].self, from: response.data)
        return firstWatchDates
    }
    
    /// Fetch must watches mapping for the current user
    /// Uses the get_must_watches_mapping database function
    nonisolated func getMustWatchesMapping(userId: UUID) async throws -> [MustWatchesMapping] {
        let response = try await supabase
            .rpc("get_must_watches_mapping", params: ["user_id_param": userId.uuidString])
            .execute()
        
        let mappings = try JSONDecoder().decode([MustWatchesMapping].self, from: response.data)
        return mappings
    }
    
    /// Fetch goals data (Must Watches, Looking Forward, Themed Month) in a single query
    /// Uses the get_goals_data database function
    nonisolated func getGoalsData(userId: UUID, targetYear: Int, currentMonth: Int) async throws -> [GoalListData] {
        // Create properly typed parameters
        struct GoalsDataParams: Encodable {
            let user_id_param: String
            let target_year: Int
            let current_month: Int
        }
        
        let params = GoalsDataParams(
            user_id_param: userId.uuidString,
            target_year: targetYear,
            current_month: currentMonth
        )
        
        let response = try await supabase
            .rpc("get_goals_data", params: params)
            .execute()
        
        let goalsData = try JSONDecoder().decode([GoalListData].self, from: response.data)
        return goalsData
    }
}

// MARK: - Supporting Types

struct AddMovieRequest: Codable, @unchecked Sendable {
    let title: String
    let release_year: Int?
    let release_date: String?
    let rating: Double?
    let ratings100: Double?
    let reviews: String?
    let tags: String?
    let watched_date: String?
    let rewatch: String?
    let tmdb_id: Int?
    let overview: String?
    let poster_url: String?
    let backdrop_path: String?
    let director: String?
    let runtime: Int?
    let vote_average: Double?
    let vote_count: Int?
    let popularity: Double?
    let original_language: String?
    let original_title: String?
    let tagline: String?
    let status: String?
    let budget: Int?
    let revenue: Int?
    let imdb_id: String?
    let homepage: String?
    let genres: [String]?
}

struct UpdateMovieRequest: Codable, @unchecked Sendable {
    let title: String?
    let release_year: Int?
    let release_date: String?
    let rating: Double?
    let ratings100: Double?
    let reviews: String?
    let tags: String?
    let watched_date: String?
    let rewatch: String?
    let tmdb_id: Int?
    let overview: String?
    let poster_url: String?
    let backdrop_path: String?
    let director: String?
    let runtime: Int?
    let vote_average: Double?
    let vote_count: Int?
    let popularity: Double?
    let original_language: String?
    let original_title: String?
    let tagline: String?
    let status: String?
    let budget: Int?
    let revenue: Int?
    let imdb_id: String?
    let homepage: String?
    let genres: [String]?
}

enum MovieSortField: String, CaseIterable {
    case title = "title"
    case watchDate = "watched_date"
    case releaseDate = "release_year"
    case rating = "rating"
    case detailedRating = "ratings100"
    case dateAdded = "created_at"
    
    var displayName: String {
        switch self {
        case .title: return "Title"
        case .watchDate: return "Date Watched"
        case .releaseDate: return "Release Year"
        case .rating: return "Your Rating"
        case .detailedRating: return "Detailed Rating"
        case .dateAdded: return "Date Added"
        }
    }
    
    nonisolated var supabaseColumn: String {
        return self.rawValue
    }
}

enum SupabaseMovieError: LocalizedError {
    case insertFailed(Error)
    case fetchFailed(Error)
    case updateFailed(Error)
    case deleteFailed(Error)
    case noMovieReturned
    
    var errorDescription: String? {
        switch self {
        case .insertFailed(let error):
            return "Failed to add movie: \(error.localizedDescription)"
        case .fetchFailed(let error):
            return "Failed to fetch movies: \(error.localizedDescription)"
        case .updateFailed(let error):
            return "Failed to update movie: \(error.localizedDescription)"
        case .deleteFailed(let error):
            return "Failed to delete movie: \(error.localizedDescription)"
        case .noMovieReturned:
            return "No movie data returned from server"
        }
    }
}

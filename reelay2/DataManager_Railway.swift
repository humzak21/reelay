//
//  DataManager.swift
//  reelay2
//
//  Created by Humza Khalil on 8/4/25.
//

import Foundation
import SwiftUI
import Combine
import Auth

@MainActor
class DataManagerRailway: ObservableObject {
    static let shared = DataManagerRailway()
    
    // Movie data
    @Published var allMovies: [Movie] = []
    
    // List data
    @Published var movieLists: [MovieList] = []
    @Published var listItems: [UUID: [ListItem]] = [:]
    
    private var listService: SupabaseListService
    private var movieService: SupabaseMovieService
    private var watchlistService: SupabaseWatchlistService
    private var railwayService = RailwayService()
    private var cancellables = Set<AnyCancellable>()
    private var watchlistRefreshTask: Task<Void, Never>?
    private var backgroundRefreshTimer: Timer?
    
    private init() {
        self.listService = SupabaseListService.shared
        self.movieService = SupabaseMovieService.shared
        self.watchlistService = SupabaseWatchlistService.shared
        
        // Subscribe to list service updates and merge Watchlist into visible lists
        listService.$movieLists
            .sink { [weak self] lists in
                guard let self = self else { return }
                self.movieLists = self.mergeWatchlist(into: lists)
            }
            .store(in: &cancellables)

        listService.$listItems
            .sink { [weak self] baseItems in
                guard let self = self else { return }
                var combined = baseItems
                let watchlistId = SupabaseWatchlistService.watchlistListId
                if let wlItems = self.listItems[watchlistId] {
                    combined[watchlistId] = wlItems
                }
                self.listItems = combined
            }
            .store(in: &cancellables)
    }
    
    // MARK: - List Operations
    
    func createList(name: String, description: String? = nil, ranked: Bool = false) async throws -> MovieList {
        return try await listService.createList(name: name, description: description, ranked: ranked)
    }
    
    func updateList(_ list: MovieList, name: String? = nil, description: String? = nil, ranked: Bool? = nil) async throws -> MovieList {
        return try await listService.updateList(list, name: name, description: description, ranked: ranked)
    }
    
    func deleteList(_ list: MovieList) async throws {
        try await listService.deleteList(list)
    }
    
    func pinList(_ list: MovieList) async throws {
        try await listService.pinList(list)
    }
    
    func unpinList(_ list: MovieList) async throws {
        try await listService.unpinList(list)
    }
    
    func addMovieToList(tmdbId: Int, title: String, posterUrl: String? = nil, backdropPath: String? = nil, year: Int? = nil, listId: UUID) async throws {
        try await listService.addMovieToList(tmdbId: tmdbId, title: title, posterUrl: posterUrl, backdropPath: backdropPath, year: year, listId: listId)
    }
    
    func removeMovieFromList(tmdbId: Int, listId: UUID) async throws {
        if listId == SupabaseWatchlistService.watchlistListId {
            try await watchlistService.deleteItem(tmdbId: tmdbId)
            await refreshWatchlist()
            return
        }
        try await listService.removeMovieFromList(tmdbId: tmdbId, listId: listId)
    }
    
    func reorderListItems(_ listId: UUID, items: [ListItem]) async throws {
        try await listService.reorderListItems(listId, items: items)
    }
    
    func getItemsForList(_ listId: UUID) async throws -> [ListItem] {
        if listId == SupabaseWatchlistService.watchlistListId {
            await refreshWatchlist()
            return listItems[listId] ?? []
        }
        return try await listService.getItemsForList(listId)
    }
    
    func reloadItemsForList(_ listId: UUID) async throws -> [ListItem] {
        if listId == SupabaseWatchlistService.watchlistListId {
            await refreshWatchlist()
            return listItems[listId] ?? []
        }
        return try await listService.reloadItemsForList(listId)
    }
    
    func getListItems(_ list: MovieList) -> [ListItem] {
        if list.id == SupabaseWatchlistService.watchlistListId {
            return listItems[list.id] ?? []
        }
        if let cached = listItems[list.id] { return cached }
        return listService.getListItems(list)
    }
    
    func getMoviesByTmdbId(tmdbId: Int) async throws -> [Movie] {
        return try await movieService.getMoviesByTmdbId(tmdbId: tmdbId)
    }
    
    func getWatchedCountForTmdbIds(tmdbIds: [Int]) async throws -> [Int: Int] {
        return try await movieService.getWatchedCountForTmdbIds(tmdbIds: tmdbIds)
    }
    
    func checkWatchedStatusForTmdbIds(tmdbIds: [Int]) async throws -> Set<Int> {
        return try await movieService.checkWatchedStatusForTmdbIds(tmdbIds: tmdbIds)
    }
    
    func refreshLists() async {
        await listService.syncListsFromSupabase()
        await refreshWatchlist()
        movieLists = mergeWatchlist(into: movieLists)
    }

    // MARK: - Watchlist Operations

    func refreshWatchlist() async {
        // Cancel any existing refresh task to prevent concurrent requests
        watchlistRefreshTask?.cancel()
        
        watchlistRefreshTask = Task {
            do {
                let items = try await watchlistService.fetchAll()
                
                // Check if task was cancelled
                guard !Task.isCancelled else {
                    print("ℹ️ Watchlist refresh was cancelled")
                    return
                }
                
                let mapped = watchlistService.mapToListItems(items)
                listItems[SupabaseWatchlistService.watchlistListId] = mapped
                movieLists = mergeWatchlist(into: movieLists)
            } catch {
                // Don't log cancellation errors as they are expected behavior
                if (error as NSError).code != NSURLErrorCancelled {
                    print("❌ DataManager.refreshWatchlist failed: \(error)")
                    print("❌ Error details: \(error.localizedDescription)")
                }
            }
        }
        
        await watchlistRefreshTask?.value
    }

    private func mergeWatchlist(into lists: [MovieList]) -> [MovieList] {
        guard let user = movieService.currentUser else { return lists }
        let watchlistId = SupabaseWatchlistService.watchlistListId
        let count = listItems[watchlistId]?.count ?? 0
        let wl = MovieList(
            id: watchlistId,
            userId: UUID(uuidString: user.id.uuidString) ?? UUID(),
            name: "Watchlist",
            description: "Movies you plan to watch",
            createdAt: Date(),
            updatedAt: Date(),
            itemCount: count,
            pinned: false,
            ranked: false
        )
        var combined = lists.filter { $0.id != watchlistId }
        combined.insert(wl, at: 0)
        return combined
    }
    
    // MARK: - Railway Cache Integration
    
    func loadMoviesFromCache() async {
        let startTime = Date()
        print("🚂 [MOVIES] Starting Railway cache fetch at \(startTime)")
        print("🚂 [MOVIES] Attempting to fetch movies from Railway PostgreSQL + Redis cache")
        
        do {
            let cachedMovies = try await railwayService.fetchMovies()
            let duration = Date().timeIntervalSince(startTime)
            
            await MainActor.run {
                self.allMovies = cachedMovies
            }
            
            railwayService.logCacheOperation("FETCH", endpoint: "movies", startTime: startTime, success: true, cacheHit: nil)
            print("✅ [MOVIES] SUCCESS: Loaded \(cachedMovies.count) movies from Railway cache")
            print("⚡ [MOVIES] Cache fetch completed in \(String(format: "%.3f", duration))s")
            print("🎯 [MOVIES] Data source: Railway (PostgreSQL + Redis)")
            print("📊 [MOVIES] Cache performance: OPTIMAL - No Supabase fallback needed")
            
        } catch let railwayError as RailwayCacheError {
            let duration = Date().timeIntervalSince(startTime)
            railwayService.logCacheOperation("FETCH", endpoint: "movies", startTime: startTime, success: false)
            
            print("❌ [MOVIES] CACHE FAILURE after \(String(format: "%.3f", duration))s")
            switch railwayError {
            case .serverError(let code, let message):
                print("🔥 [MOVIES] Railway server error (HTTP \(code)): \(message)")
                print("🔥 [MOVIES] This indicates Railway PostgreSQL connection issues")
            case .htmlError(let html):
                print("🔥 [MOVIES] Railway returned HTML error page (likely 500/503)")
                print("🔥 [MOVIES] HTML snippet: \(String(html.prefix(200)))...")
            case .decodingError(let message):
                print("🔥 [MOVIES] Railway JSON decoding failed: \(message)")
                print("🔥 [MOVIES] This suggests data corruption or API changes")
            case .invalidData(let message):
                print("🔥 [MOVIES] Railway invalid data: \(message)")
            }
            print("⚠️ [MOVIES] FALLBACK: Switching to direct Supabase due to Railway failure")
            await loadMoviesFromSupabase()
            
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            railwayService.logCacheOperation("FETCH", endpoint: "movies", startTime: startTime, success: false)
            print("❌ [MOVIES] UNEXPECTED ERROR after \(String(format: "%.3f", duration))s: \(error)")
            print("❌ [MOVIES] Error type: \(type(of: error))")
            print("❌ [MOVIES] Error details: \(error.localizedDescription)")
            print("⚠️ [MOVIES] FALLBACK: Switching to direct Supabase due to unexpected error")
            await loadMoviesFromSupabase()
        }
    }
    
    func loadMoviesFromSupabase() async {
        do {
            let movies = try await movieService.getMovies()
            await MainActor.run {
                self.allMovies = movies
            }
            print("✅ Loaded \(movies.count) movies from Supabase")
        } catch {
            print("❌ Failed to load movies from Supabase: \(error)")
        }
    }
    
    func loadListsFromCache() async {
        guard let user = movieService.currentUser else { return }
        let startTime = Date()
        let endpoint = "lists/\(user.id.uuidString)"
        
        do {
            let cachedLists = try await railwayService.fetchMovieLists(userId: user.id.uuidString)
            await MainActor.run {
                self.movieLists = self.mergeWatchlist(into: cachedLists)
            }
            railwayService.logCacheOperation("FETCH", endpoint: endpoint, startTime: startTime, success: true)
            print("✅ Loaded \(cachedLists.count) lists from Railway cache")
        } catch let railwayError as RailwayCacheError {
            railwayService.logCacheOperation("FETCH", endpoint: endpoint, startTime: startTime, success: false)
            switch railwayError {
            case .serverError(let code, _):
                print("⚠️ Railway server error (\(code)) for lists - falling back to Supabase")
            case .htmlError(_):
                print("⚠️ Railway returned HTML error page for lists - falling back to Supabase")
            case .decodingError(let message):
                print("⚠️ Railway lists JSON decoding failed: \(message) - falling back to Supabase")
            case .invalidData(let message):
                print("⚠️ Railway lists invalid data: \(message) - falling back to Supabase")
            }
            await refreshLists()
        } catch {
            railwayService.logCacheOperation("FETCH", endpoint: endpoint, startTime: startTime, success: false)
            print("⚠️ Failed to load lists from Railway cache, falling back to direct Supabase: \(error)")
            await refreshLists()
        }
    }
    
    func loadStatisticsFromCache(userId: String) async throws -> DashboardStats {
        let startTime = Date()
        let endpoint = "statistics/\(userId)"
        
        do {
            let stats = try await railwayService.fetchStatistics(userId: userId)
            railwayService.logCacheOperation("FETCH", endpoint: endpoint, startTime: startTime, success: true)
            print("✅ Loaded statistics from Railway cache")
            return stats
        } catch let railwayError as RailwayCacheError {
            railwayService.logCacheOperation("FETCH", endpoint: endpoint, startTime: startTime, success: false)
            switch railwayError {
            case .serverError(let code, _):
                print("⚠️ Railway server error (\(code)) for statistics - falling back to Supabase")
            case .htmlError(_):
                print("⚠️ Railway returned HTML error page for statistics - falling back to Supabase")
            case .decodingError(let message):
                print("⚠️ Railway statistics JSON decoding failed: \(message) - falling back to Supabase")
            case .invalidData(let message):
                print("⚠️ Railway statistics invalid data: \(message) - falling back to Supabase")
            }
            throw railwayError
        } catch {
            railwayService.logCacheOperation("FETCH", endpoint: endpoint, startTime: startTime, success: false)
            print("⚠️ Failed to load statistics from Railway cache, falling back to direct Supabase: \(error)")
            throw error
        }
    }
    
    func loadUserProfileFromCache(userId: String) async throws -> UserProfile {
        let startTime = Date()
        let endpoint = "profile/\(userId)"
        
        do {
            let profile = try await railwayService.fetchUserProfile(userId: userId)
            railwayService.logCacheOperation("FETCH", endpoint: endpoint, startTime: startTime, success: true)
            print("✅ Loaded user profile from Railway cache")
            return profile
        } catch let railwayError as RailwayCacheError {
            railwayService.logCacheOperation("FETCH", endpoint: endpoint, startTime: startTime, success: false)
            switch railwayError {
            case .serverError(let code, _):
                print("⚠️ Railway server error (\(code)) for profile - falling back to Supabase")
            case .htmlError(_):
                print("⚠️ Railway returned HTML error page for profile - falling back to Supabase")
            case .decodingError(let message):
                print("⚠️ Railway profile JSON decoding failed: \(message) - falling back to Supabase")
            case .invalidData(let message):
                print("⚠️ Railway profile invalid data: \(message) - falling back to Supabase")
            }
            throw railwayError
        } catch {
            railwayService.logCacheOperation("FETCH", endpoint: endpoint, startTime: startTime, success: false)
            print("⚠️ Failed to load user profile from Railway cache, falling back to direct Supabase: \(error)")
            throw error
        }
    }
    
    // MARK: - Cache Invalidation Enhanced Methods
    
    func createListWithCacheInvalidation(name: String, description: String? = nil, ranked: Bool = false) async throws -> MovieList {
        let result = try await listService.createList(name: name, description: description, ranked: ranked)
        
        // Clear cache after creating list
        if let user = movieService.currentUser {
            await railwayService.clearListsCache(userId: user.id.uuidString)
        }
        
        return result
    }
    
    func addMovieToListWithCacheInvalidation(tmdbId: Int, title: String, posterUrl: String? = nil, backdropPath: String? = nil, year: Int? = nil, listId: UUID) async throws {
        try await listService.addMovieToList(tmdbId: tmdbId, title: title, posterUrl: posterUrl, backdropPath: backdropPath, year: year, listId: listId)
        
        // Clear relevant caches
        await railwayService.clearMovieCache()
        if let user = movieService.currentUser {
            await railwayService.clearListsCache(userId: user.id.uuidString)
            await railwayService.clearStatisticsCache(userId: user.id.uuidString)
        }
    }
    
    func removeMovieFromListWithCacheInvalidation(tmdbId: Int, listId: UUID) async throws {
        if listId == SupabaseWatchlistService.watchlistListId {
            try await watchlistService.deleteItem(tmdbId: tmdbId)
            await refreshWatchlist()
        } else {
            try await listService.removeMovieFromList(tmdbId: tmdbId, listId: listId)
        }
        
        // Clear relevant caches
        if let user = movieService.currentUser {
            await railwayService.clearListsCache(userId: user.id.uuidString)
            await railwayService.clearStatisticsCache(userId: user.id.uuidString)
        }
    }
    
    // MARK: - Background Refresh (Step 7.2)
    
    func scheduleBackgroundRefresh() {
        backgroundRefreshTimer?.invalidate()
        backgroundRefreshTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { [weak self] in
                await self?.refreshCacheInBackground()
            }
        }
    }
    
    func stopBackgroundRefresh() {
        backgroundRefreshTimer?.invalidate()
        backgroundRefreshTimer = nil
    }
    
    @MainActor
    private func refreshCacheInBackground() async {
        guard let user = movieService.currentUser else { return }
        
        print("🔄 Starting background cache refresh...")
        
        // Refresh different data types in sequence to avoid overwhelming the server
        await loadMoviesFromCache()
        await loadListsFromCache()
        
        // Refresh statistics silently
        let _ = try? await loadStatisticsFromCache(userId: user.id.uuidString)
        
        print("✅ Background cache refresh completed")
    }
    
    deinit {
        backgroundRefreshTimer?.invalidate()
    }
    
    // MARK: - Cache Health & Monitoring
    
    func testCacheHealth() async -> CacheHealthStatus {
        print("🔍 Testing Railway cache health...")
        let status = await railwayService.checkCacheHealth()
        print("🏥 Cache Health: \(status.message)")
        return status
    }
    
    func runCachePerformanceTest() async -> CachePerformanceReport? {
        guard let user = movieService.currentUser else {
            print("❌ Cannot run cache test: No user logged in")
            return nil
        }
        
        print("⚡ Running comprehensive cache performance test...")
        let report = await railwayService.testCachePerformance(userId: user.id.uuidString)
        
        // Additional app-specific tests
        await testAppSpecificCacheBehavior()
        
        return report
    }
    
    private func testAppSpecificCacheBehavior() async {
        print("🎬 Testing app-specific cache behavior...")
        
        // Test sequential requests to see cache hits
        await loadMoviesFromCache()
        await loadMoviesFromCache() // Second call should be faster if cached
        
        if movieService.currentUser != nil {
            await loadListsFromCache()
            await loadListsFromCache() // Second call should be faster if cached
        }
    }
    
    func enableDetailedLogging() {
        print("📝 Detailed Railway cache logging enabled")
        // This can be expanded to toggle verbose logging
    }
    
    func getCacheStats() async -> String {
        guard movieService.currentUser != nil else {
            return "No user logged in for cache stats"
        }
        
        let health = await testCacheHealth()
        let performance = await runCachePerformanceTest()
        
        var stats = """
        🚂 Railway Cache Statistics:
        
        Health: \(health.isConnected ? "✅ Connected" : "❌ Disconnected")
        Response Time: \(String(format: "%.3f", health.responseTime))s
        Message: \(health.message)
        """
        
        if let perf = performance {
            stats += """
            
            Performance:
            Average Response: \(String(format: "%.3f", perf.averageResponseTime))s
            Cache Hit Rate: \(String(format: "%.1f", perf.cacheHitRate * 100))%
            Data Transferred: \(perf.totalDataTransferred) bytes
            """
        }
        
        return stats
    }

    func updatePosterForTmdbId(tmdbId: Int, newPosterUrl: String) async throws {
        try await listService.updateListItemPoster(tmdbId: tmdbId, newPosterUrl: newPosterUrl)
    }
    
    func updateBackdropForTmdbId(tmdbId: Int, newBackdropUrl: String) async throws {
        try await listService.updateListItemBackdrop(tmdbId: tmdbId, newBackdropUrl: newBackdropUrl)
    }
}

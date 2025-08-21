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
class DataManager: ObservableObject {
    static let shared = DataManager()
    
    // Movie data
    @Published var allMovies: [Movie] = []
    
    // List data
    @Published var movieLists: [MovieList] = []
    @Published var listItems: [UUID: [ListItem]] = [:]
    
    private var listService: SupabaseListService
    private var movieService: SupabaseMovieService
    private var watchlistService: SupabaseWatchlistService
    private var cancellables = Set<AnyCancellable>()
    private var watchlistRefreshTask: Task<Void, Never>?
    
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
}
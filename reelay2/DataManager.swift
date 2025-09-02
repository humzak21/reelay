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
    
    // Television data
    @Published var allTelevision: [Television] = []
    
    // Album data
    @Published var allAlbums: [Album] = []
    
    // List data
    @Published var movieLists: [MovieList] = []
    @Published var listItems: [UUID: [ListItem]] = [:]
    
    // Goals data
    @Published var yearlyFilmGoal: Int = 0
    
    private var listService: SupabaseListService
    private var movieService: SupabaseMovieService
    private var televisionService: SupabaseTelevisionService
    private var watchlistService: SupabaseWatchlistService
    private var albumService: SupabaseAlbumService
    private var cancellables = Set<AnyCancellable>()
    private var watchlistRefreshTask: Task<Void, Never>?
    
    private init() {
        self.listService = SupabaseListService.shared
        self.movieService = SupabaseMovieService.shared
        self.televisionService = SupabaseTelevisionService.shared
        self.watchlistService = SupabaseWatchlistService.shared
        self.albumService = SupabaseAlbumService.shared
        
        // Load goals from UserDefaults
        loadGoals()
        
        // Subscribe to login status and load data when logged in
        movieService.$isLoggedIn
            .sink { [weak self] isLoggedIn in
                guard let self = self else { return }
                if isLoggedIn {
                    Task {
                        await self.loadMovies()
                        await self.loadTelevision()
                        await self.loadAlbums()
                    }
                } else {
                    // Clear data when logged out
                    self.allMovies = []
                    self.allTelevision = []
                    self.allAlbums = []
                }
            }
            .store(in: &cancellables)
        
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
    
    func createList(name: String, description: String? = nil, ranked: Bool = false, tags: [String] = [], themedMonthDate: Date? = nil) async throws -> MovieList {
        return try await listService.createList(name: name, description: description, ranked: ranked, tags: tags, themedMonthDate: themedMonthDate)
    }
    
    func updateList(_ list: MovieList, name: String? = nil, description: String? = nil, ranked: Bool? = nil, tags: [String]? = nil, themedMonthDate: Date? = nil, updateThemedMonthDate: Bool = false) async throws -> MovieList {
        return try await listService.updateList(list, name: name, description: description, ranked: ranked, tags: tags, themedMonthDate: themedMonthDate, updateThemedMonthDate: updateThemedMonthDate)
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
            ranked: false,
            tags: nil,
            themedMonthDate: nil
        )
        var combined = lists.filter { $0.id != watchlistId }
        combined.insert(wl, at: 0)
        return combined
    }
    
    func updatePosterForTmdbId(tmdbId: Int, newPosterUrl: String) async throws {
        try await listService.updateListItemPoster(tmdbId: tmdbId, newPosterUrl: newPosterUrl)
    }
    
    func updateBackdropForTmdbId(tmdbId: Int, newBackdropUrl: String) async throws {
        try await listService.updateListItemBackdrop(tmdbId: tmdbId, newBackdropUrl: newBackdropUrl)
    }
    
    // MARK: - Movie Data Management
    
    func loadMovies() async {
        do {
            let movies = try await movieService.getMovies(sortBy: .dateAdded, ascending: false)
            await MainActor.run {
                self.allMovies = movies
            }
        } catch {
            print("Error loading movies in DataManager: \(error)")
        }
    }
    
    func refreshMovies() async {
        await loadMovies()
    }
    
    // MARK: - Television Operations
    
    func loadTelevision() async {
        do {
            let television = try await televisionService.getTelevisionShows(sortBy: .name, ascending: true)
            await MainActor.run {
                self.allTelevision = television
            }
        } catch {
            print("Error loading television in DataManager: \(error)")
        }
    }
    
    func refreshTelevision() async {
        await loadTelevision()
    }
    
    func getTelevisionByStatus(_ status: WatchingStatus) -> [Television] {
        return allTelevision.filter { $0.watchingStatus == status }
    }
    
    func getCurrentlyWatchingShows() -> [Television] {
        return allTelevision.filter { $0.isCurrentlyWatching }
    }
    
    func updateTelevisionProgress(id: Int, season: Int, episode: Int) async throws {
        _ = try await televisionService.updateProgress(id: id, season: season, episode: episode)
        await refreshTelevision()
    }
    
    func updateTelevisionStatus(id: Int, status: WatchingStatus) async throws {
        _ = try await televisionService.updateStatus(id: id, status: status)
        await refreshTelevision()
    }
    
    // MARK: - Album Operations
    
    func loadAlbums() async {
        do {
            let albums = try await albumService.getAlbums(sortBy: .createdAt, ascending: false)
            await MainActor.run {
                self.allAlbums = albums
            }
        } catch {
            print("Error loading albums in DataManager: \(error)")
        }
    }
    
    func refreshAlbums() async {
        await loadAlbums()
    }
    
    func getAlbumsByStatus(_ status: AlbumStatus) -> [Album] {
        return allAlbums.filter { $0.albumStatus == status }
    }
    
    func getWantToListenAlbums() -> [Album] {
        return allAlbums.filter { $0.albumStatus == .wantToListen }
    }
    
    func getListenedAlbums() -> [Album] {
        return allAlbums.filter { $0.albumStatus == .listened }
    }
    
    func updateAlbumStatus(id: Int, status: AlbumStatus, listenedDate: Date? = nil) async throws {
        let updateRequest = UpdateAlbumRequest(
            status: status.rawValue,
            listened_date: status == .listened ? (listenedDate ?? Date()) : nil
        )
        _ = try await albumService.updateAlbum(id: id, with: updateRequest)
        await refreshAlbums()
    }
    
    func deleteAlbum(id: Int) async throws {
        try await albumService.deleteAlbum(id: id)
        await refreshAlbums()
    }
    
    func addAlbum(_ albumRequest: AddAlbumRequest) async throws -> Album {
        let album = try await albumService.addAlbum(albumRequest)
        await refreshAlbums()
        return album
    }
    
    // MARK: - Goals Management
    
    private func loadGoals() {
        yearlyFilmGoal = UserDefaults.standard.integer(forKey: "yearlyFilmGoal")
    }
    
    func saveYearlyFilmGoal(_ goal: Int) {
        UserDefaults.standard.set(goal, forKey: "yearlyFilmGoal")
        yearlyFilmGoal = goal
    }
    
    func getCurrentYearWatchedMoviesCount() -> Int {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        
        // Create date range for current year (Jan 1 to Dec 31)
        var startDateComponents = DateComponents()
        startDateComponents.year = currentYear
        startDateComponents.month = 1
        startDateComponents.day = 1
        
        var endDateComponents = DateComponents()
        endDateComponents.year = currentYear
        endDateComponents.month = 12
        endDateComponents.day = 31
        
        guard let startOfYear = calendar.date(from: startDateComponents),
              let endOfYear = calendar.date(from: endDateComponents) else {
            return 0
        }
        
        return allMovies.filter { movie in
            guard let watchDateString = movie.watch_date,
                  !watchDateString.isEmpty else {
                return false
            }
            
            // Try multiple date formats to parse the watch date
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            
            if let watchDate = dateFormatter.date(from: watchDateString) {
                return watchDate >= startOfYear && watchDate <= endOfYear
            }
            
            // Try ISO8601 format as fallback
            if let watchDate = ISO8601DateFormatter().date(from: watchDateString) {
                return watchDate >= startOfYear && watchDate <= endOfYear
            }
            
            return false
        }.count
    }
    
    func getMustWatchesProgress(for year: Int) -> (watched: Int, total: Int) {
        let mustWatchesListName = "Must Watches for \(year)"
        guard let mustWatchesList = movieLists.first(where: { $0.name == mustWatchesListName }),
              let mustWatchesItems = listItems[mustWatchesList.id] else {
            return (0, 0)
        }
        
        // Count how many items from the list have been logged as watched movies
        let watchedCount = mustWatchesItems.filter { item in
            allMovies.contains { movie in
                guard let movieTmdbId = movie.tmdb_id,
                      let watchDate = movie.watch_date else { return false }
                return movieTmdbId == item.tmdbId && !watchDate.isEmpty
            }
        }.count
        
        return (watchedCount, mustWatchesItems.count)
    }
    
    func getLookingForwardProgress(for year: Int) -> (watched: Int, total: Int) {
        let lookingForwardListName = "Looking Forward in \(year)"
        guard let lookingForwardList = movieLists.first(where: { $0.name == lookingForwardListName }),
              let lookingForwardItems = listItems[lookingForwardList.id] else {
            return (0, 0)
        }
        
        // Count how many items from the list have been logged as watched movies
        let watchedCount = lookingForwardItems.filter { item in
            allMovies.contains { movie in
                guard let movieTmdbId = movie.tmdb_id,
                      let watchDate = movie.watch_date else { return false }
                return movieTmdbId == item.tmdbId && !watchDate.isEmpty
            }
        }.count
        
        return (watchedCount, lookingForwardItems.count)
    }
    
    func getThemedLists() -> [MovieList] {
        return getThemedLists(for: Date())
    }
    
    func getThemedLists(for date: Date) -> [MovieList] {
        let calendar = Calendar.current
        let targetComponents = calendar.dateComponents([.year, .month], from: date)
        
        return movieLists.filter { list in
            guard let themedMonthDate = list.themedMonthDate else { return false }
            let listComponents = calendar.dateComponents([.year, .month], from: themedMonthDate)
            return targetComponents.year == listComponents.year && targetComponents.month == listComponents.month
        }
        .sorted { $0.name < $1.name }
    }
    
    func getAllThemedLists() -> [MovieList] {
        return movieLists.filter { list in
            list.themedMonthDate != nil
        }
        .sorted { $0.name < $1.name }
    }
    
    func getThemedListProgress(for list: MovieList) -> (watched: Int, total: Int) {
        guard let themedListItems = listItems[list.id], !themedListItems.isEmpty else {
            return (0, 0)
        }
        
        // Count how many items from the list have been logged as watched movies
        let watchedCount = themedListItems.filter { item in
            allMovies.contains { movie in
                guard let movieTmdbId = movie.tmdb_id,
                      let watchDate = movie.watch_date else { return false }
                return movieTmdbId == item.tmdbId && !watchDate.isEmpty
            }
        }.count
        
        return (watchedCount, themedListItems.count)
    }
    
    func getListsContainingMovie(tmdbId: Int) -> [MovieList] {
        return movieLists.filter { list in
            guard let items = listItems[list.id] else { return false }
            return items.contains { $0.tmdbId == tmdbId }
        }
    }
}
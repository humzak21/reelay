//
//  SupabaseListService.swift
//  reelay2
//
//  Created by Humza Khalil on 8/4/25.
//

import Foundation
import Supabase
import SwiftData
import Combine

@MainActor
class SupabaseListService: ObservableObject {
    static let shared = SupabaseListService()
    
    private let supabaseClient: SupabaseClient
    private var modelContext: ModelContext
    
    @Published var movieLists: [MovieList] = []
    @Published var listItems: [UUID: [ListItem]] = [:]
    @Published var isLoading = false
    @Published var error: Error?
    
    private init() {
        guard let supabaseURL = URL(string: Config.supabaseURL) else {
            fatalError("Missing Supabase URL configuration")
        }
        
        self.supabaseClient = SupabaseClient(
            supabaseURL: supabaseURL,
            supabaseKey: Config.supabaseAnonKey
        )
        
        // Use shared model container
        self.modelContext = ModelContainerManager.shared.modelContainer.mainContext
        
        Task {
            await loadLocalLists()
            await syncListsFromSupabase()
        }
    }
    
    // MARK: - List Operations
    
    func createList(name: String, description: String? = nil, ranked: Bool = false, tags: [String] = [], themedMonthDate: Date? = nil) async throws -> MovieList {
        isLoading = true
        error = nil
        
        defer { isLoading = false }
        
        do {
            guard let currentUserId = getCurrentUserId() else {
                throw ListServiceError.authenticationRequired
            }
            
            let tagsString = tags.isEmpty ? nil : tags.joined(separator: ", ")
            let requestBody = CreateListRequest(
                name: name,
                description: description,
                userId: currentUserId.uuidString,
                ranked: ranked,
                tags: tagsString,
                themedMonthDate: themedMonthDate
            )
            
            let response = try await supabaseClient
                .from("lists")
                .insert(requestBody)
                .select()
                .single()
                .execute()
            
            let newList = try JSONDecoder().decode(MovieList.self, from: response.data)
            
            // Save locally
            try saveListLocally(newList)
            
            // Update in-memory data
            movieLists.insert(newList, at: 0)
            listItems[newList.id] = []
            
            return newList
            
        } catch {
            self.error = error
            throw error
        }
    }
    
    func updateList(_ list: MovieList, name: String? = nil, description: String? = nil, ranked: Bool? = nil, tags: [String]? = nil, themedMonthDate: Date? = nil, updateThemedMonthDate: Bool = false) async throws -> MovieList {
        isLoading = true
        error = nil
        
        defer { isLoading = false }
        
        do {
            let tagsString = tags?.isEmpty == false ? tags?.joined(separator: ", ") : nil
            
            // For themed month date, we need to handle the special case where we want to explicitly set to null
            // Only set alwaysUpdateThemedMonthDate to true if we're explicitly updating the themed month date
            let requestBody = UpdateListRequest(
                name: name,
                description: description,
                ranked: ranked,
                tags: tagsString,
                themedMonthDate: themedMonthDate,
                alwaysUpdateThemedMonthDate: updateThemedMonthDate
            )
            
            let response = try await supabaseClient
                .from("lists")
                .update(requestBody)
                .eq("id", value: list.id.uuidString)
                .select()
                .single()
                .execute()
            
            let updatedList = try JSONDecoder().decode(MovieList.self, from: response.data)
            
            // Save locally
            try saveListLocally(updatedList)
            
            // Update in-memory data
            if let index = movieLists.firstIndex(where: { $0.id == updatedList.id }) {
                movieLists[index] = updatedList
            }
            
            // Re-sort lists
            sortLists()
            
            return updatedList
            
        } catch {
            self.error = error
            throw error
        }
    }
    
    func deleteList(_ list: MovieList) async throws {
        isLoading = true
        error = nil
        
        defer { isLoading = false }
        
        do {
            // Delete from Supabase (cascade will handle list_items)
            try await supabaseClient
                .from("lists")
                .delete()
                .eq("id", value: list.id.uuidString)
                .execute()
            
            // Delete locally
            try deleteListLocally(id: list.id)
            try deleteListItemsLocally(listId: list.id)
            
            // Update in-memory data
            movieLists.removeAll { $0.id == list.id }
            listItems.removeValue(forKey: list.id)
            
        } catch {
            self.error = error
            throw error
        }
    }
    
    func pinList(_ list: MovieList) async throws {
        let updatedList = MovieList(
            id: list.id,
            userId: list.userId,
            name: list.name,
            description: list.description,
            createdAt: list.createdAt,
            updatedAt: list.updatedAt,
            itemCount: list.itemCount,
            pinned: true,
            ranked: list.ranked,
            tags: list.tags,
            themedMonthDate: list.themedMonthDate
        )
        
        _ = try await updateListPinnedStatus(updatedList, pinned: true)
    }
    
    func unpinList(_ list: MovieList) async throws {
        let updatedList = MovieList(
            id: list.id,
            userId: list.userId,
            name: list.name,
            description: list.description,
            createdAt: list.createdAt,
            updatedAt: list.updatedAt,
            itemCount: list.itemCount,
            pinned: false,
            ranked: list.ranked,
            tags: list.tags,
            themedMonthDate: list.themedMonthDate
        )
        
        _ = try await updateListPinnedStatus(updatedList, pinned: false)
    }
    
    private func updateListPinnedStatus(_ list: MovieList, pinned: Bool) async throws -> MovieList {
        isLoading = true
        error = nil
        
        defer { isLoading = false }
        
        do {
            let now = Date()
            struct UpdatePinnedPayload: Codable {
                let pinned: Bool
                let updated_at: String
            }
            // Update pinned and bump updated_at in a single typed payload
            try await supabaseClient
                .from("lists")
                .update(UpdatePinnedPayload(pinned: pinned, updated_at: ISO8601DateFormatter().string(from: now)))
                .eq("id", value: list.id.uuidString)
                .execute()
            
            let updatedList = MovieList(
                id: list.id,
                userId: list.userId,
                name: list.name,
                description: list.description,
                createdAt: list.createdAt,
                updatedAt: now,
                itemCount: list.itemCount,
                pinned: pinned,
                ranked: list.ranked,
                tags: list.tags,
                themedMonthDate: list.themedMonthDate
            )
            
            // Update local data
            try saveListLocally(updatedList)
            
            if let index = movieLists.firstIndex(where: { $0.id == list.id }) {
                movieLists[index] = updatedList
            }
            
            sortLists()
            
            return updatedList
            
        } catch {
            self.error = error
            throw error
        }
    }
    
    // MARK: - List Item Operations
    
    func addMovieToList(tmdbId: Int, title: String, posterUrl: String? = nil, backdropPath: String? = nil, year: Int? = nil, listId: UUID) async throws {
        isLoading = true
        error = nil
        
        defer { isLoading = false }
        
        do {
            // Check if movie is already in the list
            let currentItems = try await getItemsForList(listId)
            if currentItems.contains(where: { $0.tmdbId == tmdbId }) {
                throw ListServiceError.itemAlreadyExists
            }
            
            // Get the next sort order
            let nextSortOrder = (currentItems.map(\.sortOrder).max() ?? 0) + 1
            
            // Auto-fetch release date from TMDB when adding to a list
            var fetchedReleaseDate: String? = nil
            do {
                let details = try await TMDBService.shared.getMovieDetails(movieId: tmdbId)
                fetchedReleaseDate = details.releaseDate
            } catch {
                // Non-fatal: if TMDB lookup fails, continue without a release date
                fetchedReleaseDate = nil
            }
            
            let insertData = AddListItemInsert(
                listId: listId.uuidString,
                tmdbId: tmdbId,
                movieTitle: title,
                moviePosterUrl: posterUrl,
                movieBackdropPath: backdropPath,
                movieYear: year,
                movieReleaseDate: fetchedReleaseDate,
                sortOrder: nextSortOrder
            )
            
            let response = try await supabaseClient
                .from("list_items")
                .insert(insertData)
                .select()
                .single()
                .execute()
            
            let newItem = try JSONDecoder().decode(ListItem.self, from: response.data)
            
            // Save locally
            try saveListItemLocally(newItem)
            
            // Update in-memory data
            if listItems[listId] == nil {
                listItems[listId] = []
            }
            listItems[listId]?.append(newItem)
            listItems[listId]?.sort { $0.sortOrder < $1.sortOrder }
            
            // Update the list's item count and bump updated_at
            await refreshListItemCount(listId)
            await touchListUpdatedAt(listId)
            
        } catch {
            self.error = error
            throw error
        }
    }
    
    func removeMovieFromList(tmdbId: Int, listId: UUID) async throws {
        isLoading = true
        error = nil
        
        defer { isLoading = false }
        
        do {
            // Find the item to remove
            guard let currentItems = listItems[listId],
                  let itemToRemove = currentItems.first(where: { $0.tmdbId == tmdbId }) else {
                throw ListServiceError.itemNotFound
            }
            
            // Delete from Supabase
            try await supabaseClient
                .from("list_items")
                .delete()
                .eq("id", value: String(itemToRemove.id))
                .execute()
            
            // Delete locally
            try deleteListItemLocally(id: itemToRemove.id)
            
            // Update in-memory data
            listItems[listId]?.removeAll { $0.id == itemToRemove.id }
            
            // Update the list's item count and bump updated_at
            await refreshListItemCount(listId)
            await touchListUpdatedAt(listId)
            
        } catch {
            self.error = error
            throw error
        }
    }
    
    func reorderListItems(_ listId: UUID, items: [ListItem]) async throws {
        isLoading = true
        error = nil
        
        defer { isLoading = false }
        
        do {
            // Create update requests for each item with new sort order
            for (index, item) in items.enumerated() {
                // Renumber sort_order to be 1-based and contiguous
                let newSortOrder = index + 1
                let updatedItem = ListItem(
                    id: item.id,
                    listId: item.listId,
                    tmdbId: item.tmdbId,
                    movieTitle: item.movieTitle,
                    moviePosterUrl: item.moviePosterUrl,
                    movieBackdropPath: item.movieBackdropPath,
                    movieYear: item.movieYear,
                    movieReleaseDate: item.movieReleaseDate,
                    addedAt: item.addedAt,
                    sortOrder: newSortOrder
                )
                
                // Update in Supabase
                try await supabaseClient
                    .from("list_items")
                    .update(["sort_order": newSortOrder])
                    .eq("id", value: String(item.id))
                    .execute()
                
                // Update locally
                try saveListItemLocally(updatedItem)
            }
            
            // Update in-memory data
            listItems[listId] = items.enumerated().map { index, item in
                let newSortOrder = index + 1
                return ListItem(
                    id: item.id,
                    listId: item.listId,
                    tmdbId: item.tmdbId,
                    movieTitle: item.movieTitle,
                    moviePosterUrl: item.moviePosterUrl,
                    movieBackdropPath: item.movieBackdropPath,
                    movieYear: item.movieYear,
                    movieReleaseDate: item.movieReleaseDate,
                    addedAt: item.addedAt,
                    sortOrder: newSortOrder
                )
            }
            // Bump list updated_at and resort
            await touchListUpdatedAt(listId)
        } catch {
            self.error = error
            throw error
        }
    }
    
    func updateListItemTMDBData(currentTmdbId: Int, newTmdbId: Int, newTitle: String, newReleaseYear: Int?, newPosterUrl: String?, newBackdropUrl: String?) async throws {
        isLoading = true
        error = nil
        
        defer { isLoading = false }
        
        do {
            // Find all list items with the current TMDB ID
            var affectedLists: Set<UUID> = Set()
            
            for (listId, items) in listItems {
                for item in items {
                    if item.tmdbId == currentTmdbId {
                        affectedLists.insert(listId)
                        
                        // Update in Supabase
                        struct UpdateData: Codable {
                            let tmdbId: Int
                            let movieTitle: String
                            let movieYear: Int?
                            let moviePosterUrl: String?
                            let movieBackdropPath: String?
                            
                            enum CodingKeys: String, CodingKey {
                                case tmdbId = "tmdb_id"
                                case movieTitle = "movie_title"
                                case movieYear = "movie_year"
                                case moviePosterUrl = "movie_poster_url"
                                case movieBackdropPath = "movie_backdrop_path"
                            }
                        }
                        
                        let updateData = UpdateData(
                            tmdbId: newTmdbId,
                            movieTitle: newTitle,
                            movieYear: newReleaseYear,
                            moviePosterUrl: newPosterUrl,
                            movieBackdropPath: newBackdropUrl
                        )
                        
                        try await supabaseClient
                            .from("list_items")
                            .update(updateData)
                            .eq("id", value: String(item.id))
                            .execute()
                        
                        // Update locally
                        let updatedItem = ListItem(
                            id: item.id,
                            listId: item.listId,
                            tmdbId: newTmdbId,
                            movieTitle: newTitle,
                            moviePosterUrl: newPosterUrl,
                            movieBackdropPath: newBackdropUrl,
                            movieYear: newReleaseYear,
                            movieReleaseDate: item.movieReleaseDate,
                            addedAt: item.addedAt,
                            sortOrder: item.sortOrder
                        )
                        
                        try saveListItemLocally(updatedItem)
                        
                        // Update in-memory data
                        if let itemIndex = listItems[listId]?.firstIndex(where: { $0.id == item.id }) {
                            listItems[listId]?[itemIndex] = updatedItem
                        }
                    }
                }
            }
            
            // Touch updated_at for all affected lists
            for listId in affectedLists {
                await touchListUpdatedAt(listId)
            }
            
        } catch {
            self.error = error
            throw error
        }
    }
    
    func updateListItemPoster(tmdbId: Int, newPosterUrl: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Update in Supabase
            try await supabaseClient
                .from("list_items")
                .update(["movie_poster_url": newPosterUrl])
                .eq("tmdb_id", value: tmdbId)
                .execute()
            
            // Update in-memory data
            for (listId, items) in listItems {
                for (index, item) in items.enumerated() {
                    if item.tmdbId == tmdbId {
                        let updatedItem = ListItem(
                            id: item.id,
                            listId: item.listId,
                            tmdbId: item.tmdbId,
                            movieTitle: item.movieTitle,
                            moviePosterUrl: newPosterUrl,
                            movieBackdropPath: item.movieBackdropPath,
                            movieYear: item.movieYear,
                            movieReleaseDate: item.movieReleaseDate,
                            addedAt: item.addedAt,
                            sortOrder: item.sortOrder
                        )
                        
                        listItems[listId]?[index] = updatedItem
                        
                        // Save to local storage
                        try saveListItemLocally(updatedItem)
                        
                        // Touch the list's updated_at timestamp
                        await touchListUpdatedAt(listId)
                    }
                }
            }
        } catch {
            self.error = error
            throw error
        }
    }
    
    func updateListItemBackdrop(tmdbId: Int, newBackdropUrl: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Update in Supabase
            try await supabaseClient
                .from("list_items")
                .update(["movie_backdrop_path": newBackdropUrl])
                .eq("tmdb_id", value: tmdbId)
                .execute()
            
            // Update in-memory data
            for (listId, items) in listItems {
                for (index, item) in items.enumerated() {
                    if item.tmdbId == tmdbId {
                        let updatedItem = ListItem(
                            id: item.id,
                            listId: item.listId,
                            tmdbId: item.tmdbId,
                            movieTitle: item.movieTitle,
                            moviePosterUrl: item.moviePosterUrl,
                            movieBackdropPath: newBackdropUrl,
                            movieYear: item.movieYear,
                            movieReleaseDate: item.movieReleaseDate,
                            addedAt: item.addedAt,
                            sortOrder: item.sortOrder
                        )
                        
                        listItems[listId]?[index] = updatedItem
                        
                        // Save to local storage
                        try saveListItemLocally(updatedItem)
                        
                        // Touch the list's updated_at timestamp
                        await touchListUpdatedAt(listId)
                    }
                }
            }
        } catch {
            self.error = error
            throw error
        }
    }
    
    func getItemsForList(_ listId: UUID) async throws -> [ListItem] {
        // Check cache first
        if let cachedItems = listItems[listId] {
            return cachedItems
        }
        
        // Fetch from Supabase
        let response = try await supabaseClient
            .from("list_items")
            .select()
            .eq("list_id", value: listId.uuidString)
            .order("sort_order", ascending: true)
            .execute()
        
        let items = try JSONDecoder().decode([ListItem].self, from: response.data)
        
        // Cache the results
        listItems[listId] = items
        
        // Save locally
        for item in items {
            try? saveListItemLocally(item)
        }
        
        return items
    }

    /// Force reload items for a list from Supabase, bypassing cache
    func reloadItemsForList(_ listId: UUID) async throws -> [ListItem] {
        let response = try await supabaseClient
            .from("list_items")
            .select()
            .eq("list_id", value: listId.uuidString)
            .order("sort_order", ascending: true)
            .execute()
        
        let items = try JSONDecoder().decode([ListItem].self, from: response.data)
        
        // Update cache
        listItems[listId] = items
        
        // Save locally
        for item in items {
            try? saveListItemLocally(item)
        }
        
        return items
    }
    
    func getListItems(_ list: MovieList) -> [ListItem] {
        guard let items = listItems[list.id] else { return [] }
        return items.sorted { $0.sortOrder < $1.sortOrder }
    }
    
    // MARK: - Sync Operations
    
    func syncListsFromSupabase() async {
        isLoading = true
        error = nil
        
        defer { isLoading = false }
        
        do {
            guard let currentUserId = getCurrentUserId() else {
                return
            }
            
            // Get lists for current user
            let response = try await supabaseClient
                .from("lists")
                .select("*")
                .eq("user_id", value: currentUserId.uuidString)
                .order("created_at", ascending: false)
                .execute()
            
            let lists = try JSONDecoder().decode([MovieList].self, from: response.data)
            
            // Calculate item counts manually since we can't rely on the join query
            var listsWithCounts: [MovieList] = []
            for list in lists {
                do {
                    let items = try await getItemsForList(list.id)
                    let listWithCount = MovieList(
                        id: list.id,
                        userId: list.userId,
                        name: list.name,
                        description: list.description,
                        createdAt: list.createdAt,
                        updatedAt: list.updatedAt,
                        itemCount: items.count,
                        pinned: list.pinned,
                        ranked: list.ranked,
                        tags: list.tags,
                        themedMonthDate: list.themedMonthDate
                    )
                    listsWithCounts.append(listWithCount)
                    listItems[list.id] = items
                } catch {
                    listsWithCounts.append(list) // Add with original count
                }
            }
            
            // Save all lists locally
            for list in listsWithCounts {
                try saveListLocally(list)
            }
            
            // Update in-memory data and sort
            self.movieLists = listsWithCounts
            sortLists()
            
        } catch {
            self.error = error
        }
    }
    
    // MARK: - Local Data Operations
    
    private func loadLocalLists() async {
        do {
            let descriptor = FetchDescriptor<PersistentMovieList>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            let persistentLists = try modelContext.fetch(descriptor)
            
            self.movieLists = persistentLists.map { $0.toMovieList() }
            sortLists()
            
            // Load list items
            let itemsDescriptor = FetchDescriptor<PersistentListItem>()
            let persistentItems = try modelContext.fetch(itemsDescriptor)
            
            // Group items by list ID
            for item in persistentItems {
                let listItem = item.toListItem()
                if listItems[listItem.listId] == nil {
                    listItems[listItem.listId] = []
                }
                listItems[listItem.listId]?.append(listItem)
            }
            
            // Sort items by sort order
            for (listId, items) in listItems {
                listItems[listId] = items.sorted { $0.sortOrder < $1.sortOrder }
            }
            
        } catch {
            self.error = error
        }
    }
    
    private func saveListLocally(_ movieList: MovieList) throws {
        let existingDescriptor = FetchDescriptor<PersistentMovieList>(
            predicate: #Predicate<PersistentMovieList> { $0.id == movieList.id.uuidString }
        )
        
        if let existingList = try modelContext.fetch(existingDescriptor).first {
            existingList.update(from: movieList)
        } else {
            let persistentList = PersistentMovieList(from: movieList)
            modelContext.insert(persistentList)
        }
        
        try modelContext.save()
    }
    
    private func saveListItemLocally(_ listItem: ListItem) throws {
        let existingDescriptor = FetchDescriptor<PersistentListItem>(
            predicate: #Predicate<PersistentListItem> { $0.id == listItem.id }
        )
        
        if let existingItem = try modelContext.fetch(existingDescriptor).first {
            existingItem.update(from: listItem)
        } else {
            let persistentItem = PersistentListItem(from: listItem)
            modelContext.insert(persistentItem)
        }
        
        try modelContext.save()
    }
    
    private func deleteListLocally(id: UUID) throws {
        let descriptor = FetchDescriptor<PersistentMovieList>(
            predicate: #Predicate<PersistentMovieList> { $0.id == id.uuidString }
        )
        
        if let listToDelete = try modelContext.fetch(descriptor).first {
            modelContext.delete(listToDelete)
            try modelContext.save()
        }
    }
    
    private func deleteListItemsLocally(listId: UUID) throws {
        let descriptor = FetchDescriptor<PersistentListItem>(
            predicate: #Predicate<PersistentListItem> { $0.listId == listId.uuidString }
        )
        
        let itemsToDelete = try modelContext.fetch(descriptor)
        for item in itemsToDelete {
            modelContext.delete(item)
        }
        
        try modelContext.save()
    }
    
    private func deleteListItemLocally(id: Int64) throws {
        let descriptor = FetchDescriptor<PersistentListItem>(
            predicate: #Predicate<PersistentListItem> { $0.id == id }
        )
        
        if let itemToDelete = try modelContext.fetch(descriptor).first {
            modelContext.delete(itemToDelete)
            try modelContext.save()
        }
    }
    
    // MARK: - Helper Methods
    
    private func getCurrentUserId() -> UUID? {
        // Check if SupabaseMovieService has authentication
        let movieService = SupabaseMovieService.shared
        
        guard movieService.isLoggedIn else {
            return nil
        }
        
        guard let currentUser = movieService.currentUser else {
            return nil
        }
        
        guard let userId = UUID(uuidString: currentUser.id.uuidString) else {
            return nil
        }
        
        return userId
    }
    
    private func refreshListItemCount(_ listId: UUID) async {
        if let listIndex = movieLists.firstIndex(where: { $0.id == listId }) {
            let itemCount = listItems[listId]?.count ?? 0
            let updatedList = MovieList(
                id: movieLists[listIndex].id,
                userId: movieLists[listIndex].userId,
                name: movieLists[listIndex].name,
                description: movieLists[listIndex].description,
                createdAt: movieLists[listIndex].createdAt,
                updatedAt: movieLists[listIndex].updatedAt,
                itemCount: itemCount,
                pinned: movieLists[listIndex].pinned,
                ranked: movieLists[listIndex].ranked,
                tags: movieLists[listIndex].tags,
                themedMonthDate: movieLists[listIndex].themedMonthDate
            )
            movieLists[listIndex] = updatedList
            try? saveListLocally(updatedList)
        }
    }
    
    private func sortLists() {
        movieLists.sort { list1, list2 in
            // Pinned lists always come first
            if list1.pinned && !list2.pinned {
                return true
            } else if !list1.pinned && list2.pinned {
                return false
            } else {
                // Both pinned or both unpinned, sort by updated date (most recent first)
                return list1.updatedAt > list2.updatedAt
            }
        }
    }

    // MARK: - Updated At Helper
    private func touchListUpdatedAt(_ listId: UUID) async {
        let now = Date()
        do {
            try await supabaseClient
                .from("lists")
                .update(["updated_at": ISO8601DateFormatter().string(from: now)])
                .eq("id", value: listId.uuidString)
                .execute()
        } catch {
            // Non-fatal; we'll still update locally
        }
        
        if let index = movieLists.firstIndex(where: { $0.id == listId }) {
            let list = movieLists[index]
            let bumped = MovieList(
                id: list.id,
                userId: list.userId,
                name: list.name,
                description: list.description,
                createdAt: list.createdAt,
                updatedAt: now,
                itemCount: list.itemCount,
                pinned: list.pinned,
                ranked: list.ranked,
                tags: list.tags,
                themedMonthDate: list.themedMonthDate
            )
            try? saveListLocally(bumped)
            movieLists[index] = bumped
            sortLists()
        }
    }
    
    // MARK: - Random Selection
    
    /// Fetch a random item from one or more lists with optional year filtering
    /// Uses SQL-side filtering and client-side random selection for optimal performance
    /// - Parameters:
    ///   - listIds: Array of list UUIDs to select from
    ///   - minYear: Optional minimum release year (inclusive). If nil, no minimum filter applied.
    ///   - maxYear: Optional maximum release year (inclusive). If nil, no maximum filter applied.
    /// - Returns: A randomly selected ListItem, or nil if no items match criteria
    /// - Throws: ListServiceError.invalidData if listIds array is empty
    /// - Note: Movies with null year values are included when no year filters are specified,
    ///         but excluded when year filtering is active
    func fetchRandomItemFromLists(listIds: [UUID], minYear: Int? = nil, maxYear: Int? = nil) async throws -> ListItem? {
        guard !listIds.isEmpty else {
            throw ListServiceError.invalidData("No lists provided")
        }
        
        // Validate year range if both are provided
        if let minYear = minYear, let maxYear = maxYear, minYear > maxYear {
            throw ListServiceError.invalidData("Minimum year cannot be greater than maximum year")
        }
        
        // Build query with list filtering
        let listIdStrings = listIds.map { $0.uuidString }
        
        var query = supabaseClient
            .from("list_items")
            .select()
        
        // Filter by list IDs using 'in' operator
        if listIds.count == 1 {
            query = query.eq("list_id", value: listIdStrings[0])
        } else {
            query = query.in("list_id", values: listIdStrings)
        }
        
        // Add year filters if provided
        // Note: gte/lte will exclude null values, which is the desired behavior
        // when year filtering is active
        if let minYear = minYear {
            query = query.gte("movie_year", value: minYear)
        }
        if let maxYear = maxYear {
            query = query.lte("movie_year", value: maxYear)
        }
        
        // Fetch matching items (up to 1000 for random selection)
        let response = try await query
            .limit(1000)
            .execute()
        
        guard !response.data.isEmpty else {
            return nil // No items found matching criteria
        }
        
        let items = try JSONDecoder().decode([ListItem].self, from: response.data)
        
        if items.isEmpty {
            return nil
        }
        
        // Pick random item from the fetched set
        return items.randomElement()
    }
    
    // MARK: - Optimized Database Functions
    
    /// Fetch all lists with pre-computed summary data in a single query
    /// Uses the get_lists_with_summary database function
    func fetchListsWithSummaryOptimized() async throws -> [ListWithSummaryDb] {
        guard let currentUserId = getCurrentUserId() else {
            throw ListServiceError.authenticationRequired
        }
        
        let response = try await supabaseClient
            .rpc("get_lists_with_summary", params: ["user_id_param": currentUserId.uuidString])
            .execute()
        
        let lists = try JSONDecoder().decode([ListWithSummaryDb].self, from: response.data)
        return lists
    }
    
    /// Sync lists using the optimized database function
    /// Falls back to legacy method if the function doesn't exist
    func syncListsFromSupabaseOptimized() async {
        isLoading = true
        error = nil
        
        defer { isLoading = false }
        
        do {
            // Try optimized function first
            let listsWithSummary = try await fetchListsWithSummaryOptimized()
            
            // Convert to MovieList objects
            let lists = listsWithSummary.map { $0.toMovieList() }
            
            // Save all lists locally
            for list in lists {
                try saveListLocally(list)
            }
            
            // Update in-memory data and sort
            self.movieLists = lists
            sortLists()
            
            // Note: We don't need to fetch items separately for the list view
            // Items will be fetched on-demand when opening a specific list
            
        } catch {
            // Fallback to legacy method if optimized function fails
            // print("Optimized list sync failed, falling back to legacy: \(error)")
            await syncListsFromSupabase()
        }
    }
    
    /// Fetch list items with watched status in a single query
    /// Uses the get_list_items_with_watched database function
    func fetchListItemsWithWatchedOptimized(listId: UUID) async throws -> [ListItemWithWatched] {
        let response = try await supabaseClient
            .rpc("get_list_items_with_watched", params: ["list_id_param": listId.uuidString])
            .execute()
        
        let items = try JSONDecoder().decode([ListItemWithWatched].self, from: response.data)
        return items
    }
    
    /// Get items for a list with watched status using optimized query
    /// Falls back to legacy method if the function doesn't exist
    func getItemsForListOptimized(_ listId: UUID) async throws -> ([ListItem], Set<Int>) {
        do {
            let itemsWithWatched = try await fetchListItemsWithWatchedOptimized(listId: listId)
            
            let listItems = itemsWithWatched.map { $0.toListItem() }
            let watchedTmdbIds = Set(itemsWithWatched.filter { $0.isWatched }.map { $0.tmdbId })
            
            // Cache the results
            self.listItems[listId] = listItems
            
            // Save locally
            for item in listItems {
                try? saveListItemLocally(item)
            }
            
            return (listItems, watchedTmdbIds)
        } catch {
            // Re-throw so the caller can fallback to legacy method with proper watched status loading
            // print("Optimized list items fetch failed: \(error)")
            throw error
        }
    }
}

// MARK: - Error Types

enum ListServiceError: LocalizedError {
    case listNotFound
    case itemNotFound
    case itemAlreadyExists
    case invalidData(String)
    case networkError(String)
    case authenticationRequired
    case unsupportedOperation(String)
    
    var errorDescription: String? {
        switch self {
        case .listNotFound:
            return "List not found"
        case .itemNotFound:
            return "Item not found"
        case .itemAlreadyExists:
            return "Movie is already in this list"
        case .invalidData(let message):
            return "Invalid data: \(message)"
        case .networkError(let message):
            return "Network error: \(message)"
        case .authenticationRequired:
            return "Authentication required"
        case .unsupportedOperation(let message):
            return "Unsupported operation: \(message)"
        }
    }
}

// MARK: - Insert Data Structures

struct AddListItemInsert: Codable {
    let listId: String
    let tmdbId: Int
    let movieTitle: String
    let moviePosterUrl: String?
    let movieBackdropPath: String?
    let movieYear: Int?
    let movieReleaseDate: String?
    let sortOrder: Int
    
    enum CodingKeys: String, CodingKey {
        case listId = "list_id"
        case tmdbId = "tmdb_id"
        case movieTitle = "movie_title"
        case moviePosterUrl = "movie_poster_url"
        case movieBackdropPath = "movie_backdrop_path"
        case movieYear = "movie_year"
        case movieReleaseDate = "movie_release_date"
        case sortOrder = "sort_order"
    }
}
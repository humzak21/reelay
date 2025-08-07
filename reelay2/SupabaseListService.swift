//
//  SupabaseListService.swift
//  reelay2
//
//  Created by Claude on 8/4/25.
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
    
    func createList(name: String, description: String? = nil) async throws -> MovieList {
        isLoading = true
        error = nil
        
        defer { isLoading = false }
        
        do {
            guard let currentUserId = getCurrentUserId() else {
                throw ListServiceError.authenticationRequired
            }
            
            let requestBody = CreateListRequest(
                name: name,
                description: description,
                userId: currentUserId.uuidString
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
    
    func updateList(_ list: MovieList, name: String? = nil, description: String? = nil) async throws -> MovieList {
        isLoading = true
        error = nil
        
        defer { isLoading = false }
        
        do {
            let requestBody = UpdateListRequest(name: name, description: description)
            
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
            pinned: true
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
            pinned: false
        )
        
        _ = try await updateListPinnedStatus(updatedList, pinned: false)
    }
    
    private func updateListPinnedStatus(_ list: MovieList, pinned: Bool) async throws -> MovieList {
        isLoading = true
        error = nil
        
        defer { isLoading = false }
        
        do {
            try await supabaseClient
                .from("lists")
                .update(["pinned": pinned])
                .eq("id", value: list.id.uuidString)
                .execute()
            
            let updatedList = MovieList(
                id: list.id,
                userId: list.userId,
                name: list.name,
                description: list.description,
                createdAt: list.createdAt,
                updatedAt: list.updatedAt,
                itemCount: list.itemCount,
                pinned: pinned
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
            
            let insertData = AddListItemInsert(
                listId: listId.uuidString,
                tmdbId: tmdbId,
                movieTitle: title,
                moviePosterUrl: posterUrl,
                movieBackdropPath: backdropPath,
                movieYear: year,
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
            
            // Update the list's item count
            await refreshListItemCount(listId)
            
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
            
            // Update the list's item count
            await refreshListItemCount(listId)
            
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
                let updatedItem = ListItem(
                    id: item.id,
                    listId: item.listId,
                    tmdbId: item.tmdbId,
                    movieTitle: item.movieTitle,
                    moviePosterUrl: item.moviePosterUrl,
                    movieBackdropPath: item.movieBackdropPath,
                    movieYear: item.movieYear,
                    addedAt: item.addedAt,
                    sortOrder: index
                )
                
                // Update in Supabase
                try await supabaseClient
                    .from("list_items")
                    .update(["sort_order": index])
                    .eq("id", value: String(item.id))
                    .execute()
                
                // Update locally
                try saveListItemLocally(updatedItem)
            }
            
            // Update in-memory data
            listItems[listId] = items.enumerated().map { index, item in
                ListItem(
                    id: item.id,
                    listId: item.listId,
                    tmdbId: item.tmdbId,
                    movieTitle: item.movieTitle,
                    moviePosterUrl: item.moviePosterUrl,
                    movieBackdropPath: item.movieBackdropPath,
                    movieYear: item.movieYear,
                    addedAt: item.addedAt,
                    sortOrder: index
                )
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
                print("🔒 Not authenticated - skipping sync")
                return
            }
            
            print("🔄 Syncing lists for user: \(currentUserId)")
            
            // Get lists for current user
            let response = try await supabaseClient
                .from("lists")
                .select("*")
                .eq("user_id", value: currentUserId.uuidString)
                .order("created_at", ascending: false)
                .execute()
            
            print("📡 Raw response data: \(String(data: response.data, encoding: .utf8) ?? "nil")")
            
            let lists = try JSONDecoder().decode([MovieList].self, from: response.data)
            print("✅ Decoded \(lists.count) lists")
            
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
                        pinned: list.pinned
                    )
                    listsWithCounts.append(listWithCount)
                    listItems[list.id] = items
                    print("📝 List '\(list.name)' has \(items.count) items")
                } catch {
                    print("⚠️ Failed to load items for list \(list.name): \(error)")
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
            
            print("🎉 Successfully synced \(listsWithCounts.count) lists")
            
        } catch {
            print("❌ Error syncing lists: \(error)")
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
        print("🔐 Auth check - isLoggedIn: \(movieService.isLoggedIn)")
        
        guard movieService.isLoggedIn else {
            print("🔐 User not logged in")
            return nil
        }
        
        guard let currentUser = movieService.currentUser else {
            print("🔐 No current user found")
            return nil
        }
        
        print("🔐 Current user ID: \(currentUser.id)")
        
        guard let userId = UUID(uuidString: currentUser.id.uuidString) else {
            print("🔐 Failed to convert user ID to UUID: \(currentUser.id.uuidString)")
            return nil
        }
        
        print("🔐 Successfully got user UUID: \(userId)")
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
                pinned: movieLists[listIndex].pinned
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
    let sortOrder: Int
    
    enum CodingKeys: String, CodingKey {
        case listId = "list_id"
        case tmdbId = "tmdb_id"
        case movieTitle = "movie_title"
        case moviePosterUrl = "movie_poster_url"
        case movieBackdropPath = "movie_backdrop_path"
        case movieYear = "movie_year"
        case sortOrder = "sort_order"
    }
}
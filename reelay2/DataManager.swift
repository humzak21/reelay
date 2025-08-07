//
//  DataManager.swift
//  reelay2
//
//  Created by Claude on 8/4/25.
//

import Foundation
import SwiftUI
import Combine

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
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        self.listService = SupabaseListService.shared
        self.movieService = SupabaseMovieService.shared
        
        // Subscribe to list service updates
        listService.$movieLists
            .assign(to: \.movieLists, on: self)
            .store(in: &cancellables)
        
        listService.$listItems
            .assign(to: \.listItems, on: self)
            .store(in: &cancellables)
    }
    
    // MARK: - List Operations
    
    func createList(name: String, description: String? = nil) async throws -> MovieList {
        return try await listService.createList(name: name, description: description)
    }
    
    func updateList(_ list: MovieList, name: String? = nil, description: String? = nil) async throws -> MovieList {
        return try await listService.updateList(list, name: name, description: description)
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
        try await listService.removeMovieFromList(tmdbId: tmdbId, listId: listId)
    }
    
    func reorderListItems(_ listId: UUID, items: [ListItem]) async throws {
        try await listService.reorderListItems(listId, items: items)
    }
    
    func getItemsForList(_ listId: UUID) async throws -> [ListItem] {
        return try await listService.getItemsForList(listId)
    }
    
    func getListItems(_ list: MovieList) -> [ListItem] {
        return listService.getListItems(list)
    }
    
    func getMoviesByTmdbId(tmdbId: Int) async throws -> [Movie] {
        return try await movieService.getMoviesByTmdbId(tmdbId: tmdbId)
    }
    
    func refreshLists() async {
        await listService.syncListsFromSupabase()
    }
}
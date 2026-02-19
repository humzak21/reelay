//
//  NavigationCoordinator.swift
//  reelay2
//
//  Created for macOS NavigationSplitView support
//

import SwiftUI
import Combine

// MARK: - Sidebar Items
enum SidebarItem: String, CaseIterable, Identifiable, Hashable {
    case home = "Home"
    case movies = "Movies"
    case lists = "Lists"
    case statistics = "Statistics"
    case search = "Search"
    case profile = "Profile"

    var id: String { rawValue }

    var title: String { rawValue }

    var systemImage: String {
        switch self {
        case .home: return "house"
        case .movies: return "film"
        case .lists: return "list.bullet"
        case .statistics: return "chart.bar"
        case .search: return "magnifyingglass"
        case .profile: return "person.circle"
        }
    }
}

// MARK: - Navigation Destination
enum NavigationDestination: Hashable, Equatable {
    case movieDetails(Movie)
    case listDetails(MovieList)
    case televisionDetails(Television)
    case albumDetails(Album)
    
    static func == (lhs: NavigationDestination, rhs: NavigationDestination) -> Bool {
        switch (lhs, rhs) {
        case (.movieDetails(let lMovie), .movieDetails(let rMovie)):
            return lMovie.id == rMovie.id
        case (.listDetails(let lList), .listDetails(let rList)):
            return lList.id == rList.id
        case (.televisionDetails(let lTV), .televisionDetails(let rTV)):
            return lTV.id == rTV.id
        case (.albumDetails(let lAlbum), .albumDetails(let rAlbum)):
            return lAlbum.id == rAlbum.id
        default:
            return false
        }
    }
    
    func hash(into hasher: inout Hasher) {
        switch self {
        case .movieDetails(let movie):
            hasher.combine("movie")
            hasher.combine(movie.id)
        case .listDetails(let list):
            hasher.combine("list")
            hasher.combine(list.id)
        case .televisionDetails(let television):
            hasher.combine("tv")
            hasher.combine(television.id)
        case .albumDetails(let album):
            hasher.combine("album")
            hasher.combine(album.id)
        }
    }
}

// MARK: - Navigation Coordinator
#if os(macOS)
@MainActor
class NavigationCoordinator: ObservableObject {
    @Published var selectedSidebarItem: SidebarItem? = .home
    @Published var detailDestination: NavigationDestination?
    
    // MARK: - Navigation Methods
    
    func showMovieDetails(_ movie: Movie) {
        detailDestination = .movieDetails(movie)
    }
    
    func showListDetails(_ list: MovieList) {
        detailDestination = .listDetails(list)
    }
    
    func showTelevisionDetails(_ show: Television) {
        detailDestination = .televisionDetails(show)
    }
    
    func showAlbumDetails(_ album: Album) {
        detailDestination = .albumDetails(album)
    }
    
    func clearDetail() {
        detailDestination = nil
    }
    
    func selectSidebarItem(_ item: SidebarItem) {
        selectedSidebarItem = item
        // Optionally clear detail when switching sidebar items
        // clearDetail()
    }
}
#endif

// MARK: - Hashable Extensions for Model Types

extension Movie: Hashable {
    static func == (lhs: Movie, rhs: Movie) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension MovieList: Hashable {
    static func == (lhs: MovieList, rhs: MovieList) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension Television: Hashable {
    static func == (lhs: Television, rhs: Television) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension Album: Hashable {
    static func == (lhs: Album, rhs: Album) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

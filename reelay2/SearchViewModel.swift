//
//  SearchViewModel.swift
//  reelay2
//
//  Created by Assistant on 8/10/25.
//

import Foundation
import Combine
import SwiftUI

@MainActor
class SearchViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var searchResults: [Movie] = []
    @Published var isSearching = false
    @Published var errorMessage: String?
    @Published var hasSearched = false
    
    private let movieService = SupabaseMovieService.shared
    private var searchCancellable: AnyCancellable?
    private var searchTask: Task<Void, Never>?
    
    // Sorting and filtering
    @Published var sortBy: SearchSortOption = .relevance
    @Published var filterByYear: Int?
    @Published var filterByRating: Double?
    @Published var showOnlyRewatches = false
    
    enum SearchSortOption: String, CaseIterable {
        case relevance = "Relevance"
        case watchDateNewest = "Recently Watched"
        case watchDateOldest = "Oldest Watched"
        case ratingHighest = "Highest Rated"
        case ratingLowest = "Lowest Rated"
        case titleAZ = "Title (A-Z)"
        case titleZA = "Title (Z-A)"
        case yearNewest = "Newest Films"
        case yearOldest = "Oldest Films"
        
        var displayName: String {
            return self.rawValue
        }
    }
    
    // Statistics for search results
    var resultStats: SearchResultStats {
        SearchResultStats(movies: filteredAndSortedResults)
    }
    
    var filteredAndSortedResults: [Movie] {
        var results = searchResults
        
        // Apply filters
        if let year = filterByYear {
            results = results.filter { $0.release_year == year }
        }
        
        if let minRating = filterByRating {
            results = results.filter { ($0.rating ?? 0) >= minRating }
        }
        
        if showOnlyRewatches {
            results = results.filter { $0.isRewatchMovie }
        }
        
        // Apply sorting
        switch sortBy {
        case .relevance:
            // Keep original order from search (most relevant)
            break
        case .watchDateNewest:
            results.sort { ($0.watch_date ?? "") > ($1.watch_date ?? "") }
        case .watchDateOldest:
            results.sort { ($0.watch_date ?? "") < ($1.watch_date ?? "") }
        case .ratingHighest:
            results.sort { ($0.detailed_rating ?? 0) > ($1.detailed_rating ?? 0) }
        case .ratingLowest:
            results.sort { ($0.detailed_rating ?? 0) < ($1.detailed_rating ?? 0) }
        case .titleAZ:
            results.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .titleZA:
            results.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedDescending }
        case .yearNewest:
            results.sort { ($0.release_year ?? 0) > ($1.release_year ?? 0) }
        case .yearOldest:
            results.sort { ($0.release_year ?? 0) < ($1.release_year ?? 0) }
        }
        
        return results
    }
    
    var availableYears: [Int] {
        let years = searchResults.compactMap { $0.release_year }
        return Array(Set(years)).sorted(by: >)
    }
    
    var hasActiveFilters: Bool {
        return filterByYear != nil || filterByRating != nil || showOnlyRewatches
    }
    
    init() {
        setupSearchDebouncing()
    }
    
    private func setupSearchDebouncing() {
        // Debounce search input to avoid too many API calls
        searchCancellable = $searchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] searchTerm in
                guard let self = self else { return }
                
                // Cancel any existing search task
                self.searchTask?.cancel()
                
                if searchTerm.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    self.clearSearch()
                } else {
                    self.searchTask = Task {
                        await self.performSearch(query: searchTerm)
                    }
                }
            }
    }
    
    func performSearch(query: String) async {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            clearSearch()
            return
        }
        
        isSearching = true
        errorMessage = nil
        hasSearched = true
        
        do {
            // Search with a higher limit to get more comprehensive results
            let results = try await movieService.getMovies(
                searchQuery: query,
                sortBy: .watchDate,
                ascending: false,
                limit: 3000
            )
            
            // Calculate relevance scores and sort by relevance
            let scoredResults = results.map { movie -> (movie: Movie, score: Double) in
                let score = calculateRelevanceScore(for: movie, query: query)
                return (movie, score)
            }
            
            // Sort by relevance score (highest first)
            let sortedResults = scoredResults
                .sorted { $0.score > $1.score }
                .map { $0.movie }
            
            await MainActor.run {
                self.searchResults = sortedResults
                self.isSearching = false
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Search failed: \(error.localizedDescription)"
                self.searchResults = []
                self.isSearching = false
            }
        }
    }
    
    private func calculateRelevanceScore(for movie: Movie, query: String) -> Double {
        let lowercaseQuery = query.lowercased()
        var score = 0.0
        
        // Title match (highest weight)
        let titleLower = movie.title.lowercased()
        if titleLower == lowercaseQuery {
            score += 100 // Exact match
        } else if titleLower.hasPrefix(lowercaseQuery) {
            score += 80 // Starts with query
        } else if titleLower.contains(lowercaseQuery) {
            score += 60 // Contains query
        }
        
        // Director match
        if let director = movie.director?.lowercased(),
           director.contains(lowercaseQuery) {
            score += 30
        }
        
        // Overview match
        if let overview = movie.overview?.lowercased(),
           overview.contains(lowercaseQuery) {
            score += 10
        }
        
        // Tags match
        if let tags = movie.tags?.lowercased(),
           tags.contains(lowercaseQuery) {
            score += 20
        }
        
        // Review match
        if let review = movie.review?.lowercased(),
           review.contains(lowercaseQuery) {
            score += 15
        }
        
        // Boost for higher ratings (slight preference for better movies)
        if let rating = movie.detailed_rating {
            score += rating / 100 * 5 // Max 5 points for 100-rated movies
        }
        
        // Boost for more recent watches (slight recency bias)
        if let watchDate = movie.watch_date {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            if let date = formatter.date(from: watchDate) {
                let daysSinceWatched = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 365
                if daysSinceWatched < 30 {
                    score += 10
                } else if daysSinceWatched < 90 {
                    score += 5
                } else if daysSinceWatched < 365 {
                    score += 2
                }
            }
        }
        
        return score
    }
    
    func clearSearch() {
        searchText = ""
        searchResults = []
        hasSearched = false
        errorMessage = nil
        clearFilters()
    }
    
    func clearFilters() {
        filterByYear = nil
        filterByRating = nil
        showOnlyRewatches = false
        sortBy = .relevance
    }
}

// MARK: - Search Result Statistics
struct SearchResultStats {
    let totalCount: Int
    let averageRating: Double
    let yearRange: String
    let rewatchCount: Int
    let topGenres: [String]
    
    init(movies: [Movie]) {
        self.totalCount = movies.count
        
        // Calculate average rating
        let ratings = movies.compactMap { $0.detailed_rating }
        self.averageRating = ratings.isEmpty ? 0 : ratings.reduce(0, +) / Double(ratings.count)
        
        // Calculate year range
        let years = movies.compactMap { $0.release_year }
        if let minYear = years.min(), let maxYear = years.max() {
            if minYear == maxYear {
                self.yearRange = "\(minYear)"
            } else {
                self.yearRange = "\(minYear) - \(maxYear)"
            }
        } else {
            self.yearRange = "N/A"
        }
        
        // Count rewatches
        self.rewatchCount = movies.filter { $0.isRewatchMovie }.count
        
        // Get top genres
        var genreCounts: [String: Int] = [:]
        for movie in movies {
            if let genres = movie.genres {
                for genre in genres {
                    genreCounts[genre, default: 0] += 1
                }
            }
        }
        self.topGenres = genreCounts
            .sorted { $0.value > $1.value }
            .prefix(3)
            .map { $0.key }
    }
}
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
    @Published var parsedSearchType: SearchType?
    
    private let movieService = SupabaseMovieService.shared
    private var searchCancellable: AnyCancellable?
    private var searchTask: Task<Void, Never>?
    
    // Available tags from CLAUDE.md
    private let availableTags = ["IMAX", "Theater", "Family", "Theboys", "Airplane", "Train", "Short"]
    
    enum SearchType {
        case general(String)
        case year(Int)
        case tag(String)
        case starRating(Int)
        case combined([SearchType])
    }
    
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
        
        // Parse the search query to determine search type
        let searchType = parseSearchQuery(query)
        parsedSearchType = searchType
        
        do {
            // Get all movies first with a higher limit
            let allResults = try await movieService.getMovies(
                searchQuery: nil, // Get all movies
                sortBy: .watchDate,
                ascending: false,
                limit: 5000
            )
            
            // Filter results based on parsed search type
            let filteredResults = filterMovies(allResults, by: searchType)
            
            // Calculate relevance scores and sort by relevance
            let scoredResults = filteredResults.map { movie -> (movie: Movie, score: Double) in
                let score = calculateRelevanceScore(for: movie, query: query, searchType: searchType)
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
    
    private func parseSearchQuery(_ query: String) -> SearchType {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercaseQuery = trimmedQuery.lowercased()
        
        // Check for star ratings (e.g., "5 stars", "4 star", "3.5 stars")
        let starPatterns = [
            #"(\d+(?:\.\d+)?)\s*stars?"#,
            #"(\d+(?:\.\d+)?)\s*⭐"#
        ]
        
        for pattern in starPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: trimmedQuery, options: [], range: NSRange(trimmedQuery.startIndex..., in: trimmedQuery)),
               let range = Range(match.range(at: 1), in: trimmedQuery) {
                let ratingString = String(trimmedQuery[range])
                if let rating = Double(ratingString) {
                    return .starRating(Int(rating))
                }
            }
        }
        
        // Check for years (4-digit numbers between 1900-2030)
        if let year = Int(trimmedQuery), year >= 1900, year <= 2030 {
            return .year(year)
        }
        
        // Check for exact tag matches (case insensitive)
        for tag in availableTags {
            if lowercaseQuery == tag.lowercased() {
                return .tag(tag)
            }
        }
        
        // Check for combined searches (space-separated terms)
        let terms = trimmedQuery.components(separatedBy: " ").filter { !$0.isEmpty }
        if terms.count > 1 {
            var searchTypes: [SearchType] = []
            
            for term in terms {
                let termType = parseSearchQuery(term)
                switch termType {
                case .general(_):
                    // Only add general terms if they're not already covered
                    if !searchTypes.contains(where: { if case .general(_) = $0 { return true } else { return false } }) {
                        searchTypes.append(.general(terms.joined(separator: " ")))
                    }
                default:
                    searchTypes.append(termType)
                }
            }
            
            if searchTypes.count > 1 {
                return .combined(searchTypes)
            }
        }
        
        // Default to general search
        return .general(trimmedQuery)
    }
    
    private func filterMovies(_ movies: [Movie], by searchType: SearchType) -> [Movie] {
        switch searchType {
        case .general(let query):
            return movies.filter { movie in
                let lowercaseQuery = query.lowercased()
                return movie.title.lowercased().contains(lowercaseQuery) ||
                       movie.director?.lowercased().contains(lowercaseQuery) == true ||
                       movie.overview?.lowercased().contains(lowercaseQuery) == true ||
                       movie.tags?.lowercased().contains(lowercaseQuery) == true ||
                       movie.review?.lowercased().contains(lowercaseQuery) == true
            }
            
        case .year(let year):
            return movies.filter { $0.release_year == year }
            
        case .tag(let tag):
            return movies.filter { movie in
                guard let tags = movie.tags?.lowercased() else { return false }
                return tags.contains(tag.lowercased())
            }
            
        case .starRating(let stars):
            return movies.filter { movie in
                guard let rating = movie.rating else { return false }
                return Int(rating) == stars
            }
            
        case .combined(let searchTypes):
            return movies.filter { movie in
                // Movie must match ALL search criteria
                return searchTypes.allSatisfy { type in
                    let filtered = filterMovies([movie], by: type)
                    return !filtered.isEmpty
                }
            }
        }
    }
    
    private func calculateRelevanceScore(for movie: Movie, query: String, searchType: SearchType) -> Double {
        var score = 0.0
        
        // Base scoring depends on search type
        switch searchType {
        case .general(let searchQuery):
            score += calculateGeneralRelevanceScore(for: movie, query: searchQuery)
            
        case .year(let year):
            // Exact year matches get highest priority
            if movie.release_year == year {
                score += 100
            }
            
        case .tag(let tag):
            // Exact tag matches get highest priority
            if let tags = movie.tags?.lowercased(),
               tags.contains(tag.lowercased()) {
                score += 100
            }
            
        case .starRating(let stars):
            // Exact star rating matches get highest priority
            if let rating = movie.rating,
               Int(rating) == stars {
                score += 100
            }
            
        case .combined(let searchTypes):
            // For combined searches, sum scores from each type
            for type in searchTypes {
                score += calculateRelevanceScore(for: movie, query: query, searchType: type)
            }
        }
        
        // Boost for higher ratings (slight preference for better movies)
        if let rating = movie.detailed_rating {
            score += rating / 100 * 2 // Max 2 points for 100-rated movies
        }
        
        // Boost for more recent watches (slight recency bias)
        if let watchDate = movie.watch_date {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            if let date = formatter.date(from: watchDate) {
                let daysSinceWatched = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 365
                if daysSinceWatched < 30 {
                    score += 5
                } else if daysSinceWatched < 90 {
                    score += 3
                } else if daysSinceWatched < 365 {
                    score += 1
                }
            }
        }
        
        return score
    }
    
    private func calculateGeneralRelevanceScore(for movie: Movie, query: String) -> Double {
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
        
        return score
    }
    
    func clearSearch() {
        searchText = ""
        searchResults = []
        hasSearched = false
        errorMessage = nil
        parsedSearchType = nil
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
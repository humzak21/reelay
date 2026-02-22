//
//  SearchViewModel.swift
//  reelay2
//
//  Created by Humza Khalil on 8/10/25.
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
    
    private let repository = MoviesRepository()
    private var searchCancellable: AnyCancellable?
    private var filtersCancellable: AnyCancellable?
    private var searchTask: Task<Void, Never>?
    private var lastSubmittedQuery: String?
    
    // Available tags from centralized configuration
    private var availableTags: [String] {
        return TagConfiguration.allTagNames
    }
    
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
        searchResults
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
        setupFilterAndSortObservers()
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

    private func setupFilterAndSortObservers() {
        filtersCancellable = Publishers.CombineLatest4(
            $sortBy.removeDuplicates(),
            $filterByYear.removeDuplicates(),
            $filterByRating.removeDuplicates(),
            $showOnlyRewatches.removeDuplicates()
        )
        .dropFirst()
        .sink { [weak self] _, _, _, _ in
            guard let self = self,
                  let existingQuery = self.lastSubmittedQuery,
                  !existingQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

            self.searchTask?.cancel()
            self.searchTask = Task {
                await self.performSearch(query: existingQuery)
            }
        }
    }
    
    func performSearch(query: String) async {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            clearSearch()
            return
        }
        
        lastSubmittedQuery = trimmedQuery
        isSearching = true
        errorMessage = nil
        hasSearched = true
        
        // Parse the search query to determine search type
        let searchType = parseSearchQuery(trimmedQuery)
        parsedSearchType = searchType
        
        do {
            let request = buildSearchRequest(for: trimmedQuery, searchType: searchType)
            var results = try await fetchAllSearchResults(request: request)

            if sortBy == .relevance {
                let scoredResults = results.map { movie -> (movie: Movie, score: Double) in
                    let score = calculateRelevanceScore(for: movie, query: trimmedQuery, searchType: searchType)
                    return (movie, score)
                }
                results = scoredResults
                    .sorted { $0.score > $1.score }
                    .map(\.movie)
            }

            await MainActor.run {
                self.searchResults = results
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

    private func buildSearchRequest(for query: String, searchType: SearchType) -> MovieSearchPageQuery {
        let (searchSortField, ascending) = mapSortOption(sortBy)
        var parsedFilters = MovieFilterSet()
        var serverSearchText = query

        switch searchType {
        case .general(let text):
            serverSearchText = text
        case .year(let year):
            parsedFilters.releaseYears = [year]
            serverSearchText = ""
        case .tag(let tag):
            parsedFilters.tags = [tag]
            serverSearchText = ""
        case .starRating(let stars):
            parsedFilters.minRating = Double(stars)
            parsedFilters.maxRating = Double(stars) + 0.99
            serverSearchText = ""
        case .combined(let parts):
            var generalTerms: [String] = []
            for part in parts {
                switch part {
                case .general(let text):
                    generalTerms.append(text)
                case .year(let year):
                    parsedFilters.releaseYears.append(year)
                case .tag(let tag):
                    parsedFilters.tags.append(tag)
                case .starRating(let stars):
                    parsedFilters.minRating = Double(stars)
                    parsedFilters.maxRating = Double(stars) + 0.99
                case .combined:
                    break
                }
            }
            serverSearchText = generalTerms.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let uiFilters = MovieFilterSet(
            releaseYears: filterByYear.map { [$0] } ?? [],
            showRewatchesOnly: showOnlyRewatches,
            minRating: filterByRating
        )

        let merged = mergeFilters(parsed: parsedFilters, ui: uiFilters)

        return MovieSearchPageQuery(
            searchText: serverSearchText,
            sortBy: searchSortField,
            ascending: ascending,
            filters: merged,
            page: 1,
            pageSize: 250
        )
    }

    private func fetchAllSearchResults(request: MovieSearchPageQuery) async throws -> [Movie] {
        var query = request
        var page = 1
        var all: [Movie] = []

        while true {
            query.page = page
            let response = try await repository.searchPage(query: query, forceRefresh: page == 1)
            all.append(contentsOf: response.items.map { $0.toMovie() })

            if !response.hasNextPage {
                break
            }
            page += 1
        }

        return all
    }

    private func mergeFilters(parsed: MovieFilterSet, ui: MovieFilterSet) -> MovieFilterSet {
        var merged = parsed

        merged.tags = Array(Set(parsed.tags + ui.tags))
        merged.genres = Array(Set(parsed.genres + ui.genres))
        merged.releaseYears = Array(Set(parsed.releaseYears + ui.releaseYears))
        merged.decades = Array(Set(parsed.decades + ui.decades))

        merged.showRewatchesOnly = parsed.showRewatchesOnly || ui.showRewatchesOnly
        merged.hideRewatches = parsed.hideRewatches || ui.hideRewatches
        merged.favoritesOnly = parsed.favoritesOnly || ui.favoritesOnly

        merged.startWatchDate = parsed.startWatchDate ?? ui.startWatchDate
        merged.endWatchDate = parsed.endWatchDate ?? ui.endWatchDate
        merged.minRuntime = parsed.minRuntime ?? ui.minRuntime
        merged.maxRuntime = parsed.maxRuntime ?? ui.maxRuntime
        merged.hasReview = parsed.hasReview ?? ui.hasReview

        merged.minRating = maxOptional(parsed.minRating, ui.minRating)
        merged.maxRating = minOptional(parsed.maxRating, ui.maxRating)
        merged.minDetailedRating = maxOptional(parsed.minDetailedRating, ui.minDetailedRating)
        merged.maxDetailedRating = minOptional(parsed.maxDetailedRating, ui.maxDetailedRating)

        return merged
    }

    private func mapSortOption(_ option: SearchSortOption) -> (MovieSortField, Bool) {
        switch option {
        case .relevance:
            return (.watchDate, false)
        case .watchDateNewest:
            return (.watchDate, false)
        case .watchDateOldest:
            return (.watchDate, true)
        case .ratingHighest:
            return (.detailedRating, false)
        case .ratingLowest:
            return (.detailedRating, true)
        case .titleAZ:
            return (.title, true)
        case .titleZA:
            return (.title, false)
        case .yearNewest:
            return (.releaseDate, false)
        case .yearOldest:
            return (.releaseDate, true)
        }
    }

    private func maxOptional(_ lhs: Double?, _ rhs: Double?) -> Double? {
        switch (lhs, rhs) {
        case let (l?, r?): return max(l, r)
        case let (l?, nil): return l
        case let (nil, r?): return r
        default: return nil
        }
    }

    private func minOptional(_ lhs: Double?, _ rhs: Double?) -> Double? {
        switch (lhs, rhs) {
        case let (l?, r?): return min(l, r)
        case let (l?, nil): return l
        case let (nil, r?): return r
        default: return nil
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
        lastSubmittedQuery = nil
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

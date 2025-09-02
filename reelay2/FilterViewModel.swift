//
//  FilterViewModel.swift
//  reelay2
//
//  Created by Humza Khalil
//

import Foundation
import SwiftUI
import Combine

@MainActor
class FilterViewModel: ObservableObject {
    // MARK: - Applied Filter Properties (trigger UI updates)
    @Published var selectedTags: Set<String> = []
    @Published var minStarRating: Double? = nil
    @Published var maxStarRating: Double? = nil
    @Published var minDetailedRating: Double? = nil
    @Published var maxDetailedRating: Double? = nil
    @Published var selectedGenres: Set<String> = []
    @Published var startDate: Date? = nil
    @Published var endDate: Date? = nil
    @Published var showRewatchesOnly: Bool = false
    @Published var hideRewatches: Bool = false
    @Published var minRuntime: Int? = nil
    @Published var maxRuntime: Int? = nil
    @Published var selectedDecades: Set<String> = []
    @Published var hasReview: Bool? = nil
    
    // MARK: - Staging Properties (for UI editing, update UI but don't trigger filtering)
    @Published var stagingSelectedTags: Set<String> = []
    @Published var stagingMinStarRating: Double? = nil
    @Published var stagingMaxStarRating: Double? = nil
    @Published var stagingMinDetailedRating: Double? = nil
    @Published var stagingMaxDetailedRating: Double? = nil
    @Published var stagingSelectedGenres: Set<String> = []
    @Published var stagingStartDate: Date? = nil
    @Published var stagingEndDate: Date? = nil
    @Published var stagingShowRewatchesOnly: Bool = false
    @Published var stagingHideRewatches: Bool = false
    @Published var stagingMinRuntime: Int? = nil
    @Published var stagingMaxRuntime: Int? = nil
    @Published var stagingSelectedDecades: Set<String> = []
    @Published var stagingHasReview: Bool? = nil
    
    // MARK: - Computed Properties
    var hasActiveFilters: Bool {
        return !selectedTags.isEmpty ||
               minStarRating != nil ||
               maxStarRating != nil ||
               minDetailedRating != nil ||
               maxDetailedRating != nil ||
               !selectedGenres.isEmpty ||
               startDate != nil ||
               endDate != nil ||
               showRewatchesOnly ||
               hideRewatches ||
               minRuntime != nil ||
               maxRuntime != nil ||
               !selectedDecades.isEmpty ||
               hasReview != nil
    }
    
    var activeFilterCount: Int {
        var count = 0
        if !selectedTags.isEmpty { count += 1 }
        if minStarRating != nil || maxStarRating != nil { count += 1 }
        if minDetailedRating != nil || maxDetailedRating != nil { count += 1 }
        if !selectedGenres.isEmpty { count += 1 }
        if startDate != nil || endDate != nil { count += 1 }
        if showRewatchesOnly || hideRewatches { count += 1 }
        if minRuntime != nil || maxRuntime != nil { count += 1 }
        if !selectedDecades.isEmpty { count += 1 }
        if hasReview != nil { count += 1 }
        return count
    }
    
    // MARK: - Methods
    func clearAllFilters() {
        selectedTags.removeAll()
        minStarRating = nil
        maxStarRating = nil
        minDetailedRating = nil
        maxDetailedRating = nil
        selectedGenres.removeAll()
        startDate = nil
        endDate = nil
        showRewatchesOnly = false
        hideRewatches = false
        minRuntime = nil
        maxRuntime = nil
        selectedDecades.removeAll()
        hasReview = nil
        
        // Also clear staging
        clearStagingFilters()
    }
    
    func clearStagingFilters() {
        stagingSelectedTags.removeAll()
        stagingMinStarRating = nil
        stagingMaxStarRating = nil
        stagingMinDetailedRating = nil
        stagingMaxDetailedRating = nil
        stagingSelectedGenres.removeAll()
        stagingStartDate = nil
        stagingEndDate = nil
        stagingShowRewatchesOnly = false
        stagingHideRewatches = false
        stagingMinRuntime = nil
        stagingMaxRuntime = nil
        stagingSelectedDecades.removeAll()
        stagingHasReview = nil
    }
    
    func loadCurrentFiltersToStaging() {
        stagingSelectedTags = selectedTags
        stagingMinStarRating = minStarRating
        stagingMaxStarRating = maxStarRating
        stagingMinDetailedRating = minDetailedRating
        stagingMaxDetailedRating = maxDetailedRating
        stagingSelectedGenres = selectedGenres
        stagingStartDate = startDate
        stagingEndDate = endDate
        stagingShowRewatchesOnly = showRewatchesOnly
        stagingHideRewatches = hideRewatches
        stagingMinRuntime = minRuntime
        stagingMaxRuntime = maxRuntime
        stagingSelectedDecades = selectedDecades
        stagingHasReview = hasReview
    }
    
    func applyStagingFilters() {
        selectedTags = stagingSelectedTags
        minStarRating = stagingMinStarRating
        maxStarRating = stagingMaxStarRating
        minDetailedRating = stagingMinDetailedRating
        maxDetailedRating = stagingMaxDetailedRating
        selectedGenres = stagingSelectedGenres
        startDate = stagingStartDate
        endDate = stagingEndDate
        showRewatchesOnly = stagingShowRewatchesOnly
        hideRewatches = stagingHideRewatches
        minRuntime = stagingMinRuntime
        maxRuntime = stagingMaxRuntime
        selectedDecades = stagingSelectedDecades
        hasReview = stagingHasReview
    }
    
    func toggleTag(_ tag: String) {
        if selectedTags.contains(tag) {
            selectedTags.remove(tag)
        } else {
            selectedTags.insert(tag)
        }
    }
    
    func toggleGenre(_ genre: String) {
        if selectedGenres.contains(genre) {
            selectedGenres.remove(genre)
        } else {
            selectedGenres.insert(genre)
        }
    }
    
    func toggleDecade(_ decade: String) {
        if selectedDecades.contains(decade) {
            selectedDecades.remove(decade)
        } else {
            selectedDecades.insert(decade)
        }
    }
    
    // MARK: - Staging Toggle Methods
    func toggleStagingTag(_ tag: String) {
        if stagingSelectedTags.contains(tag) {
            stagingSelectedTags.remove(tag)
        } else {
            stagingSelectedTags.insert(tag)
        }
    }
    
    func toggleStagingGenre(_ genre: String) {
        if stagingSelectedGenres.contains(genre) {
            stagingSelectedGenres.remove(genre)
        } else {
            stagingSelectedGenres.insert(genre)
        }
    }
    
    func toggleStagingDecade(_ decade: String) {
        if stagingSelectedDecades.contains(decade) {
            stagingSelectedDecades.remove(decade)
        } else {
            stagingSelectedDecades.insert(decade)
        }
    }
    
    func filterMovies(_ movies: [Movie]) -> [Movie] {
        return movies.filter { movie in
            // Tag filter
            if !selectedTags.isEmpty {
                guard let movieTags = movie.tags else { return false }
                let movieTagsArray = movieTags.components(separatedBy: CharacterSet(charactersIn: ", "))
                    .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
                let hasSelectedTag = selectedTags.contains { selectedTag in
                    movieTagsArray.contains(selectedTag.lowercased())
                }
                if !hasSelectedTag { return false }
            }
            
            // Star rating filter (inclusive)
            if let minRating = minStarRating {
                guard let movieRating = movie.rating, movieRating >= minRating else { return false }
            }
            if let maxRating = maxStarRating {
                guard let movieRating = movie.rating, movieRating <= maxRating else { return false }
            }
            
            // Detailed rating filter (inclusive)
            if let minDetailed = minDetailedRating {
                guard let movieDetailed = movie.detailed_rating, movieDetailed >= minDetailed else { return false }
            }
            if let maxDetailed = maxDetailedRating {
                guard let movieDetailed = movie.detailed_rating, movieDetailed <= maxDetailed else { return false }
            }
            
            // Genre filter
            if !selectedGenres.isEmpty {
                guard let movieGenres = movie.genres else { return false }
                let hasSelectedGenre = selectedGenres.contains { selectedGenre in
                    movieGenres.contains(selectedGenre)
                }
                if !hasSelectedGenre { return false }
            }
            
            // Date range filter
            if let start = startDate {
                guard let watchDateString = movie.watch_date,
                      let watchDate = DateFormatter.movieDateFormatter.date(from: watchDateString),
                      watchDate >= start else { return false }
            }
            if let end = endDate {
                guard let watchDateString = movie.watch_date,
                      let watchDate = DateFormatter.movieDateFormatter.date(from: watchDateString),
                      watchDate <= end else { return false }
            }
            
            // Rewatch filter
            if showRewatchesOnly && !movie.isRewatchMovie { return false }
            if hideRewatches && movie.isRewatchMovie { return false }
            
            // Runtime filter
            if let minTime = minRuntime {
                guard let movieRuntime = movie.runtime, movieRuntime >= minTime else { return false }
            }
            if let maxTime = maxRuntime {
                guard let movieRuntime = movie.runtime, movieRuntime <= maxTime else { return false }
            }
            
            // Decade filter
            if !selectedDecades.isEmpty {
                guard let releaseYear = movie.release_year else { return false }
                let decade = "\(releaseYear / 10 * 10)s"
                if !selectedDecades.contains(decade) { return false }
            }
            
            // Review filter
            if let reviewFilter = hasReview {
                let movieHasReview = movie.review != nil && !movie.review!.trimmingCharacters(in: .whitespaces).isEmpty
                if reviewFilter != movieHasReview { return false }
            }
            
            return true
        }
    }
    
    // MARK: - Helper Methods
    func getAvailableTags(from movies: [Movie]) -> [String] {
        var tags: Set<String> = []
        for movie in movies {
            if let movieTags = movie.tags {
                let movieTagsArray = movieTags.components(separatedBy: CharacterSet(charactersIn: ", "))
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                tags.formUnion(movieTagsArray)
            }
        }
        return Array(tags).sorted()
    }
    
    func getAvailableGenres(from movies: [Movie]) -> [String] {
        var genres: Set<String> = []
        for movie in movies {
            if let movieGenres = movie.genres {
                genres.formUnion(movieGenres)
            }
        }
        return Array(genres).sorted()
    }
    
    func getAvailableDecades(from movies: [Movie]) -> [String] {
        var decades: Set<String> = []
        for movie in movies {
            if let releaseYear = movie.release_year {
                let decade = "\(releaseYear / 10 * 10)s"
                decades.insert(decade)
            }
        }
        return Array(decades).sorted { decade1, decade2 in
            let year1 = Int(decade1.dropLast()) ?? 0
            let year2 = Int(decade2.dropLast()) ?? 0
            return year1 > year2 // Most recent first
        }
    }
    
    func getRatingRange(from movies: [Movie]) -> (min: Double, max: Double) {
        let ratings = movies.compactMap { $0.rating }
        return (ratings.min() ?? 0.0, ratings.max() ?? 5.0)
    }
    
    func getDetailedRatingRange(from movies: [Movie]) -> (min: Double, max: Double) {
        let ratings = movies.compactMap { $0.detailed_rating }
        return (ratings.min() ?? 0.0, ratings.max() ?? 100.0)
    }
    
    func getRuntimeRange(from movies: [Movie]) -> (min: Int, max: Int) {
        let runtimes = movies.compactMap { $0.runtime }
        return (runtimes.min() ?? 0, runtimes.max() ?? 300)
    }
    
    func getEarliestWatchDate(from movies: [Movie]) -> Date {
        let watchDates = movies.compactMap { movie -> Date? in
            guard let watchDateString = movie.watch_date else { return nil }
            return DateFormatter.movieDateFormatter.date(from: watchDateString)
        }
        return watchDates.min() ?? Date.distantPast
    }
}

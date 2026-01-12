//
//  ComparisonToolViewModel.swift
//  reelay2
//
//  Created by Humza Khalil on 1/11/26.
//

import Foundation
import Combine

/// ViewModel for the interactive film comparison tool.
/// Manages the comparison algorithm and state using a binary ladder approach.
@MainActor
final class ComparisonToolViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// The current movie being shown for comparison
    @Published private(set) var currentPromptedMovie: Movie?
    
    /// Current comparison number (1-5)
    @Published private(set) var currentComparisonNumber: Int = 1
    
    /// The target rating we're narrowing in on
    @Published private(set) var targetRating: Int
    
    /// Loading state
    @Published private(set) var isLoading: Bool = false
    
    /// Whether the comparison is complete
    @Published private(set) var isComplete: Bool = false
    
    /// Final determined rating (nil until complete)
    @Published private(set) var finalRating: Int?
    
    /// Error message if something goes wrong
    @Published private(set) var errorMessage: String?
    
    /// Whether there are enough movies to perform comparison
    @Published private(set) var hasEnoughMovies: Bool = true
    
    // MARK: - Private Properties
    
    /// Total number of comparisons
    private let totalComparisons = 5
    
    /// All movies available in the rating range
    private var moviesInRange: [Movie]
    
    /// Movies grouped by their detailed rating
    private var moviesByRating: [Int: [Movie]] = [:]
    
    /// Stack for undo functionality
    private var historyStack: [ComparisonState] = []
    
    /// Set of already used movie IDs to avoid repetition
    private var usedMovieIds: Set<Int> = []
    
    /// The rating range boundaries
    private let minRating: Int
    private let maxRating: Int
    
    // MARK: - Types
    
    /// Captures state for undo functionality
    private struct ComparisonState {
        let targetRating: Int
        let promptedMovie: Movie?
        let comparisonNumber: Int
        let usedMovieIds: Set<Int>
    }
    
    // MARK: - Initialization
    
    /// Initialize the comparison tool with a star rating and available movies
    /// - Parameters:
    ///   - starRating: The user's star rating (0.5 - 5.0)
    ///   - moviesInRange: All movies within the appropriate detailed rating range
    init(starRating: Double, moviesInRange: [Movie]) {
        self.moviesInRange = moviesInRange
        
        // Determine rating range based on star rating
        let range = Self.getRatingRange(for: starRating)
        self.minRating = range.min
        self.maxRating = range.max
        
        // Start at the bottom of the range
        self.targetRating = range.min
        
        // Group movies by rating for quick lookup
        self.groupMoviesByRating()
        
        // Check if we have enough movies
        self.hasEnoughMovies = !moviesInRange.isEmpty
        
        // Load first comparison movie
        if hasEnoughMovies {
            selectNextMovie()
        }
    }
    
    // MARK: - Public Methods
    
    /// User selected their film as better (new film > prompted film)
    func userSelectedTheirFilm() {
        guard !isComplete else { return }
        
        // Save current state for undo
        saveState()
        
        // Increment the target rating (move up the ladder)
        let step = calculateStep()
        targetRating = min(targetRating + step, maxRating)
        
        // Move to next comparison
        advanceComparison()
    }
    
    /// User selected the prompted film as better (prompted film > new film)
    func userSelectedPromptedFilm() {
        guard !isComplete else { return }
        
        // Save current state for undo
        saveState()
        
        // Special case: On the FIRST prompt, if prompted film is better,
        // the user's film is at the bottom of the range - complete immediately
        if currentComparisonNumber == 1 {
            finalRating = minRating
            isComplete = true
            return
        }
        
        // For subsequent prompts (2-5), decrement the rating and continue
        let step = calculateStep()
        targetRating = max(targetRating - step, minRating)
        
        // Continue to next comparison
        advanceComparison()
    }
    
    /// User selected that films are equal
    func userSelectedEqual() {
        guard !isComplete else { return }
        
        // Save current state for undo
        saveState()
        
        // On first prompt, equal means bottom of range
        if currentComparisonNumber == 1 {
            finalRating = minRating
            isComplete = true
            return
        }
        
        // For subsequent prompts, keep rating the same and continue
        // (no increment or decrement)
        advanceComparison()
    }
    
    /// Skip current movie and get a different one (doesn't count toward total)
    func skip() {
        guard !isComplete, currentPromptedMovie != nil else { return }
        
        // Mark current movie as used
        if let movie = currentPromptedMovie {
            usedMovieIds.insert(movie.id)
        }
        
        // Try to find another movie at the same rating
        selectNextMovie()
    }
    
    /// Undo the last comparison
    func undo() {
        guard let previousState = historyStack.popLast() else { return }
        
        // Restore previous state
        targetRating = previousState.targetRating
        currentPromptedMovie = previousState.promptedMovie
        currentComparisonNumber = previousState.comparisonNumber
        usedMovieIds = previousState.usedMovieIds
        
        // Reset completion if we were complete
        isComplete = false
        finalRating = nil
    }
    
    /// Check if undo is available
    var canUndo: Bool {
        !historyStack.isEmpty
    }
    
    /// Get the comparison progress text
    var progressText: String {
        "\(currentComparisonNumber) / \(totalComparisons)"
    }
    
    /// Get the comparison progress as a fraction
    var progress: Double {
        Double(currentComparisonNumber) / Double(totalComparisons)
    }
    
    // MARK: - Private Methods
    
    /// Group movies by their detailed rating for efficient lookup
    private func groupMoviesByRating() {
        moviesByRating = [:]
        
        for movie in moviesInRange {
            guard let detailedRating = movie.detailed_rating else { continue }
            let ratingInt = Int(detailedRating)
            
            if moviesByRating[ratingInt] == nil {
                moviesByRating[ratingInt] = []
            }
            moviesByRating[ratingInt]?.append(movie)
        }
    }
    
    /// Select the next movie to compare against
    private func selectNextMovie() {
        // Try to find a movie at the target rating
        if let movie = findMovieAtRating(targetRating) {
            currentPromptedMovie = movie
            return
        }
        
        // If no movie at exact rating, search nearby ratings
        for offset in 1...5 {
            // Try higher rating first
            if let movie = findMovieAtRating(targetRating + offset) {
                currentPromptedMovie = movie
                return
            }
            // Then try lower rating
            if let movie = findMovieAtRating(targetRating - offset) {
                currentPromptedMovie = movie
                return
            }
        }
        
        // If still no movie found, try any unused movie
        if let movie = moviesInRange.first(where: { !usedMovieIds.contains($0.id) }) {
            currentPromptedMovie = movie
            return
        }
        
        // No more movies available - complete with current rating
        finalRating = targetRating
        isComplete = true
    }
    
    /// Find a random unused movie at a specific rating
    private func findMovieAtRating(_ rating: Int) -> Movie? {
        guard rating >= minRating && rating <= maxRating else { return nil }
        
        guard let moviesAtRating = moviesByRating[rating] else { return nil }
        
        let unusedMovies = moviesAtRating.filter { !usedMovieIds.contains($0.id) }
        guard let movie = unusedMovies.randomElement() else { return nil }
        
        usedMovieIds.insert(movie.id)
        return movie
    }
    
    /// Save current state to history stack
    private func saveState() {
        let state = ComparisonState(
            targetRating: targetRating,
            promptedMovie: currentPromptedMovie,
            comparisonNumber: currentComparisonNumber,
            usedMovieIds: usedMovieIds
        )
        historyStack.append(state)
    }
    
    /// Advance to the next comparison
    private func advanceComparison() {
        currentComparisonNumber += 1
        
        // Check if we've completed all comparisons
        if currentComparisonNumber > totalComparisons {
            finalRating = targetRating
            isComplete = true
            return
        }
        
        // Check if we've hit the ceiling
        if targetRating >= maxRating {
            finalRating = maxRating
            isComplete = true
            return
        }
        
        // Select next movie
        selectNextMovie()
    }
    
    /// Calculate the step size for rating increment
    /// Uses smaller steps as we get more comparisons to narrow down
    private func calculateStep() -> Int {
        // Start with larger steps, reduce as we progress
        switch currentComparisonNumber {
        case 1: return 3
        case 2: return 2
        case 3: return 2
        case 4: return 1
        default: return 1
        }
    }
    
    /// Get the rating range for a given star rating
    static func getRatingRange(for starRating: Double) -> (min: Int, max: Int) {
        switch starRating {
        case 0.0..<0.75:
            return (0, 9)
        case 0.75..<1.25:
            return (10, 19)
        case 1.25..<1.75:
            return (20, 29)
        case 1.75..<2.25:
            return (30, 39)
        case 2.25..<2.75:
            return (40, 49)
        case 2.75..<3.25:
            return (50, 59)
        case 3.25..<3.75:
            return (60, 69)
        case 3.75..<4.25:
            return (70, 79)
        case 4.25..<4.75:
            return (80, 89)
        default: // 4.75 and above (5 stars)
            return (90, 100)
        }
    }
}

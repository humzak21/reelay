//
//  ComparisonToolViewModel.swift
//  reelay2
//
//  Created by Humza Khalil on 1/11/26.
//

import Foundation
import Combine
import SwiftUI

// MARK: - Sentiment Enum

/// Sentiment options for the sentiment-based comparison mode.
/// Used when user doesn't provide a star rating upfront.
enum Sentiment: CaseIterable {
    case hate
    case like
    case love
    
    var displayName: String {
        switch self {
        case .hate: return "Hate"
        case .like: return "Like"
        case .love: return "Love"
        }
    }
    
    var color: Color {
        switch self {
        case .hate: return Color(red: 0.90, green: 0.22, blue: 0.21)   // Material Red 600
        case .like: return Color(red: 0.98, green: 0.75, blue: 0.18)   // Material Yellow 700
        case .love: return Color(red: 0.26, green: 0.63, blue: 0.28)   // Material Green 600
        }
    }
    
    var initialRating: Int {
        switch self {
        case .hate: return 39   // Top of 2-star range
        case .like: return 54   // Middle of like range
        case .love: return 70   // Bottom of 4+ star range
        }
    }
    
    var rangeMin: Int {
        switch self {
        case .hate: return 0
        case .like: return 40
        case .love: return 70
        }
    }
    
    var rangeMax: Int {
        switch self {
        case .hate: return 39
        case .like: return 69
        case .love: return 100
        }
    }
    
    var earlyExitMessage: String {
        switch self {
        case .hate: return "You don't dislike this film"
        case .like: return "You might not just like this film"
        case .love: return "You might not love this film"
        }
    }
}

// MARK: - ViewModel

/// ViewModel for the interactive film comparison tool.
/// Manages the comparison algorithm and state using a binary ladder approach.
@MainActor
final class ComparisonToolViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// The current movie being shown for comparison
    @Published private(set) var currentPromptedMovie: Movie?
    
    /// Current comparison number (1-5 for standard, 1-10 for sentiment)
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
    
    // MARK: - Sentiment Mode Properties
    
    /// Whether we're in sentiment mode (no star rating provided)
    @Published private(set) var isSentimentMode: Bool = false
    
    /// The selected sentiment (Hate/Like/Love)
    @Published private(set) var selectedSentiment: Sentiment?
    
    /// Whether to show the sentiment selection screen
    @Published private(set) var showSentimentSelection: Bool = false
    
    /// Whether an early exit was triggered (user preferred prompted film on first comparison)
    @Published private(set) var earlyExitTriggered: Bool = false
    
    /// Message to show on early exit
    @Published private(set) var earlyExitMessage: String?
    
    // MARK: - Private Properties
    
    /// Total number of comparisons (5 for standard, 10 for sentiment)
    private var totalComparisons: Int = 5
    
    /// All movies available in the rating range
    private var moviesInRange: [Movie]
    
    /// All movies pool (for sentiment mode filtering)
    private var allMoviesPool: [Movie] = []
    
    /// Movies grouped by their detailed rating
    private var moviesByRating: [Int: [Movie]] = [:]
    
    /// Stack for undo functionality
    private var historyStack: [ComparisonState] = []
    
    /// Set of already used movie IDs to avoid repetition
    private var usedMovieIds: Set<Int> = []
    
    /// The rating range boundaries
    private var minRating: Int
    private var maxRating: Int
    
    // MARK: - Types
    
    /// Captures state for undo functionality
    private struct ComparisonState {
        let targetRating: Int
        let promptedMovie: Movie?
        let comparisonNumber: Int
        let usedMovieIds: Set<Int>
    }
    
    // MARK: - Initialization
    
    /// Initialize the comparison tool with a star rating and available movies (standard mode)
    /// - Parameters:
    ///   - starRating: The user's star rating (0.5 - 5.0)
    ///   - moviesInRange: All movies within the appropriate detailed rating range
    init(starRating: Double, moviesInRange: [Movie]) {
        self.moviesInRange = moviesInRange
        self.isSentimentMode = false
        
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
    
    /// Initialize for sentiment mode (no star rating provided)
    /// - Parameter moviesPool: All rated movies to filter from when sentiment is selected
    init(moviesPool: [Movie]) {
        self.moviesInRange = []
        self.allMoviesPool = moviesPool
        self.minRating = 0
        self.maxRating = 100
        self.targetRating = 0
        self.isSentimentMode = true
        self.showSentimentSelection = true
        self.totalComparisons = 10
    }
    
    // MARK: - Sentiment Mode Methods
    
    /// User selected a sentiment (Hate/Like/Love)
    func selectSentiment(_ sentiment: Sentiment) {
        selectedSentiment = sentiment
        showSentimentSelection = false
        
        // Set range based on sentiment
        minRating = sentiment.rangeMin
        maxRating = sentiment.rangeMax
        targetRating = sentiment.initialRating
        totalComparisons = 10
        
        // Filter movies to the selected range
        moviesInRange = allMoviesPool.filter { movie in
            guard let rating = movie.detailed_rating else { return false }
            let ratingInt = Int(rating)
            return ratingInt >= sentiment.rangeMin && ratingInt <= sentiment.rangeMax
        }
        
        // Regroup movies by rating
        groupMoviesByRating()
        
        // Check if we have enough movies
        hasEnoughMovies = !moviesInRange.isEmpty
        
        if hasEnoughMovies {
            selectNextMovie()
        }
    }
    
    /// Return to sentiment selection after early exit
    func returnToSentimentSelection() {
        showSentimentSelection = true
        selectedSentiment = nil
        earlyExitTriggered = false
        earlyExitMessage = nil
        currentComparisonNumber = 1
        isComplete = false
        finalRating = nil
        historyStack.removeAll()
        usedMovieIds.removeAll()
        currentPromptedMovie = nil
    }
    
    // MARK: - Public Methods
    
    /// User selected their film as better (new film > prompted film)
    func userSelectedTheirFilm() {
        guard !isComplete else { return }
        
        // Save current state for undo
        saveState()
        
        // First prompt special case for Hate sentiment
        // If user prefers their film over a hate-range film, they don't actually hate it
        if currentComparisonNumber == 1 {
            if isSentimentMode, let sentiment = selectedSentiment, sentiment == .hate {
                // Hate mode: picking their film means they don't hate it - trigger early exit
                earlyExitTriggered = true
                earlyExitMessage = sentiment.earlyExitMessage
                return
            }
        }
        
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
        
        // First prompt special case
        if currentComparisonNumber == 1 {
            if isSentimentMode, let sentiment = selectedSentiment {
                // For Hate: picking prompted film means theirs is worse - continue normally (go down)
                // For Like/Love: picking prompted film means they don't truly like/love it - early exit
                if sentiment != .hate {
                    earlyExitTriggered = true
                    earlyExitMessage = sentiment.earlyExitMessage
                    return
                }
                // Hate continues below to decrement rating
            } else {
                // Standard mode: complete immediately at minimum
                finalRating = minRating
                isComplete = true
                return
            }
        }
        
        // For subsequent prompts, decrement the rating and continue
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
        
        // Reset early exit if triggered
        earlyExitTriggered = false
        earlyExitMessage = nil
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
        if isSentimentMode {
            // Sentiment mode: pick from across the entire range for variety
            // Try to find a movie in a wider search area
            let searchOrder = generateRandomSearchOrder()
            
            for offset in searchOrder {
                if let movie = findMovieAtRating(targetRating + offset) {
                    currentPromptedMovie = movie
                    return
                }
            }
            
            // If still no movie found, try any unused movie in range
            let shuffledMovies = moviesInRange.shuffled()
            if let movie = shuffledMovies.first(where: { !usedMovieIds.contains($0.id) }) {
                currentPromptedMovie = movie
                return
            }
        } else {
            // Standard mode: search near target rating
            if let movie = findMovieAtRating(targetRating) {
                currentPromptedMovie = movie
                return
            }
            
            // If no movie at exact rating, search nearby ratings
            for offset in 1...5 {
                if let movie = findMovieAtRating(targetRating + offset) {
                    currentPromptedMovie = movie
                    return
                }
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
        }
        
        // No more movies available - complete with current rating
        finalRating = targetRating
        isComplete = true
    }
    
    /// Generate a randomized search order for finding movies in sentiment mode
    /// Prioritizes ratings closer to target but includes variety
    private func generateRandomSearchOrder() -> [Int] {
        var offsets: [Int] = [0]  // Always try exact match first
        
        // Add offsets in both directions, shuffled to add variety
        let maxOffset = min(10, max(targetRating - minRating, maxRating - targetRating))
        var positiveOffsets: [Int] = []
        var negativeOffsets: [Int] = []
        
        for i in 1...maxOffset {
            if targetRating + i <= maxRating {
                positiveOffsets.append(i)
            }
            if targetRating - i >= minRating {
                negativeOffsets.append(-i)
            }
        }
        
        // Shuffle and interleave for variety
        positiveOffsets.shuffle()
        negativeOffsets.shuffle()
        
        while !positiveOffsets.isEmpty || !negativeOffsets.isEmpty {
            if Bool.random() {
                if let offset = positiveOffsets.popLast() {
                    offsets.append(offset)
                } else if let offset = negativeOffsets.popLast() {
                    offsets.append(offset)
                }
            } else {
                if let offset = negativeOffsets.popLast() {
                    offsets.append(offset)
                } else if let offset = positiveOffsets.popLast() {
                    offsets.append(offset)
                }
            }
        }
        
        return offsets
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
    /// Uses randomized steps that get smaller as comparisons progress for fine-tuning
    private func calculateStep() -> Int {
        if isSentimentMode {
            // Sentiment mode: 10 comparisons with randomized steps
            // Early: large random steps to explore range
            // Middle: medium steps to narrow down  
            // Late: small steps to fine-tune
            
            switch currentComparisonNumber {
            case 1, 2, 3:
                // Early comparisons: large random steps (4-8)
                return Int.random(in: 4...8)
            case 4, 5, 6:
                // Middle comparisons: medium random steps (2-5)
                return Int.random(in: 2...5)
            case 7, 8:
                // Late comparisons: smaller random steps (1-3)
                return Int.random(in: 1...3)
            default:
                // Final comparisons: fine-tuning (1-2)
                return Int.random(in: 1...2)
            }
        } else {
            // Standard mode: 5 comparisons with slight randomness
            switch currentComparisonNumber {
            case 1: return Int.random(in: 2...4)
            case 2: return Int.random(in: 2...3)
            case 3: return Int.random(in: 1...2)
            default: return 1
            }
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

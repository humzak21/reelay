//
//  AddMovieViewModel.swift
//  reelay
//
//  Created by Humza Khalil on 6/11/25.
//

import Foundation

@MainActor
class AddMovieViewModel: ObservableObject {
    @Published var searchQuery = "" {
        didSet {
            debouncedSearch()
        }
    }
    @Published var tmdbMovies: [TMDBMovie] = []
    @Published var selectedMovie: TMDBMovieDetails?
    @Published var isSearching = false
    @Published var isLoadingDetails = false
    @Published var isSaving = false
    @Published var error: Error?
    
    // User input fields
    @Published var userRating: Double = 0
    @Published var detailedRating: Double = 0
    @Published var watchDate = Date()
    @Published var isRewatch = false
    @Published var notes = ""
    @Published var review = ""
    
    private let tmdbService = TMDBService.shared
    private let apiService = APIService.shared
    private var searchTask: Task<Void, Never>?
    private var debounceTask: Task<Void, Never>?
    
    private func debouncedSearch() {
        // Cancel previous debounce task
        debounceTask?.cancel()
        
        debounceTask = Task {
            // Wait for debounce period
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            // Check if task was cancelled
            guard !Task.isCancelled else { return }
            
            // Perform search if query is not empty
            if !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty {
                await searchMovies()
            } else {
                tmdbMovies = []
            }
        }
    }
    
    func searchMovies() async {
        // Cancel any existing search
        searchTask?.cancel()
        
        guard !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty else {
            tmdbMovies = []
            return
        }
        
        searchTask = Task {
            isSearching = true
            error = nil
            
            do {
                let results = try await tmdbService.searchMovies(query: searchQuery)
                
                // Check if task was cancelled
                guard !Task.isCancelled else { return }
                
                tmdbMovies = results
            } catch {
                // Check if task was cancelled
                guard !Task.isCancelled else { return }
                
                self.error = error
                print("Error searching movies: \(error)")
            }
            
            isSearching = false
        }
        
        await searchTask?.value
    }
    
    func selectMovie(_ tmdbMovie: TMDBMovie) async {
        isLoadingDetails = true
        error = nil
        
        do {
            let movieDetails = try await tmdbService.getMovieDetails(movieId: tmdbMovie.id)
            selectedMovie = movieDetails
        } catch {
            self.error = error
            print("Error loading movie details: \(error)")
        }
        
        isLoadingDetails = false
    }
    
    func saveMovie() async -> Bool {
        guard let selectedMovie = selectedMovie else { return false }
        
        isSaving = true
        error = nil
        
        do {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            
            let request = AddMovieRequest(
                title: selectedMovie.title,
                year: selectedMovie.releaseYear,
                userRating: userRating > 0 ? userRating : nil,
                detailedRating: detailedRating > 0 ? detailedRating : nil,
                watchDate: dateFormatter.string(from: watchDate),
                isRewatch: isRewatch,
                tmdbId: selectedMovie.id,
                overview: selectedMovie.overview,
                posterUrl: selectedMovie.fullPosterURL,
                backdropUrl: selectedMovie.fullBackdropURL,
                director: selectedMovie.director,
                runtime: selectedMovie.runtime,
                voteAverage: selectedMovie.voteAverage,
                genres: selectedMovie.genres.map(\.name).joined(separator: ", "),
                reviews: review.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : review
            )
            
            _ = try await apiService.addMovie(request)
            
            // Reset the form
            clearSelection()
            
            isSaving = false
            return true
        } catch {
            self.error = error
            print("Error saving movie: \(error)")
            isSaving = false
            return false
        }
    }
    
    func clearSelection() {
        // Cancel any ongoing tasks
        searchTask?.cancel()
        debounceTask?.cancel()
        
        selectedMovie = nil
        searchQuery = ""
        tmdbMovies = []
        userRating = 0
        detailedRating = 0
        watchDate = Date()
        isRewatch = false
        notes = ""
        review = ""
    }
} 
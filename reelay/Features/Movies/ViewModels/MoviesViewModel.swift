//
//  MoviesViewModel.swift
//  reelay
//
//  Created by Humza Khalil on 6/11/25.
//

import Foundation

@MainActor
class MoviesViewModel: ObservableObject {
    @Published var movies: [Movie] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var currentPage = 1
    @Published var hasMorePages = true
    
    private let apiService = APIService.shared
    private let limit = 50
    private var loadingTask: Task<Void, Never>?
    
    func loadMovies(refresh: Bool = false) async {
        // Cancel any existing loading task
        loadingTask?.cancel()
        
        if refresh {
            currentPage = 1
            hasMorePages = true
            movies = []
        }
        
        guard !isLoading && hasMorePages else { return }
        
        loadingTask = Task {
            isLoading = true
            error = nil
            
            do {
                let response = try await apiService.getAllMovies(page: currentPage, limit: limit)
                
                // Check if task was cancelled
                guard !Task.isCancelled else { return }
                
                if refresh {
                    movies = response.data
                } else {
                    movies.append(contentsOf: response.data)
                }
                
                hasMorePages = response.pagination?.hasNextPage ?? false
                currentPage += 1
            } catch {
                // Check if task was cancelled
                guard !Task.isCancelled else { return }
                
                self.error = error
                print("Error loading movies: \(error)")
            }
            
            isLoading = false
        }
        
        await loadingTask?.value
    }
    
    func addMovie(title: String, year: Int?, userRating: Double?, detailedRating: Double?, watchDate: Date?, isRewatch: Bool) async {
        isLoading = true
        error = nil
        
        do {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let dateString = dateFormatter.string(from: watchDate ?? Date())
            
            let request = AddMovieRequest(
                title: title,
                year: year,
                userRating: userRating,
                detailedRating: detailedRating,
                watchDate: dateString,
                isRewatch: isRewatch,
                tmdbId: nil,
                overview: nil,
                posterUrl: nil,
                backdropUrl: nil,
                director: nil,
                runtime: nil,
                voteAverage: nil,
                genres: nil,
                reviews: nil
            )
            
            let newMovie = try await apiService.addMovie(request)
            movies.insert(newMovie, at: 0)
        } catch {
            self.error = error
            print("Error adding movie: \(error)")
        }
        
        isLoading = false
    }
    
    func searchMovies(query: String) async {
        // Cancel any existing loading task
        loadingTask?.cancel()
        
        isLoading = true
        error = nil
        
        do {
            movies = try await apiService.searchMovies(query: query)
        } catch {
            self.error = error
            print("Error searching movies: \(error)")
        }
        
        isLoading = false
    }
}

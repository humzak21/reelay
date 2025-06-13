//
//  StatisticsViewModel.swift
//  reelay
//
//  Created by Humza Khalil on 6/11/25.
//

import Foundation

@MainActor
class StatisticsViewModel: ObservableObject {
    @Published var dashboardStats: DashboardStats?
    @Published var ratingDistribution: [RatingDistribution] = []
    @Published var genreStats: [GenreStats] = []
    @Published var filmsPerYear: [FilmsPerYear] = []
    @Published var isLoading = false
    @Published var isLoadingDashboard = false
    @Published var isLoadingRatings = false
    @Published var isLoadingGenres = false
    @Published var isLoadingYears = false
    @Published var error: Error?
    
    private let apiService = APIService.shared
    private var loadingTasks: [Task<Void, Never>] = []
    
    func loadAllStats() async {
        // Cancel any existing loading tasks
        cancelAllTasks()
        
        isLoading = true
        error = nil
        
        // Load stats progressively for better UX
        await withTaskGroup(of: Void.self) { group in
            // Load dashboard stats first (most important)
            group.addTask { 
                await self.loadDashboardStats() 
            }
            
            // Load other stats in parallel
            group.addTask { 
                await self.loadRatingDistribution() 
            }
            group.addTask { 
                await self.loadGenreStats() 
            }
            group.addTask { 
                await self.loadFilmsPerYear() 
            }
        }
        
        isLoading = false
    }
    
    func loadDashboardStatsOnly() async {
        cancelAllTasks()
        await loadDashboardStats()
    }
    
    private func loadDashboardStats() async {
        isLoadingDashboard = true
        
        let task = Task {
            do {
                dashboardStats = try await apiService.getDashboardStats()
            } catch {
                if !Task.isCancelled {
                    self.error = error
                    print("Error loading dashboard stats: \(error)")
                }
            }
            isLoadingDashboard = false
        }
        
        loadingTasks.append(task)
        await task.value
    }
    
    private func loadRatingDistribution() async {
        isLoadingRatings = true
        
        let task = Task {
            do {
                ratingDistribution = try await apiService.getRatingDistribution()
            } catch {
                if !Task.isCancelled {
                    self.error = error
                    print("Error loading rating distribution: \(error)")
                }
            }
            isLoadingRatings = false
        }
        
        loadingTasks.append(task)
        await task.value
    }
    
    private func loadGenreStats() async {
        isLoadingGenres = true
        
        let task = Task {
            do {
                genreStats = try await apiService.getGenreStats()
            } catch {
                if !Task.isCancelled {
                    self.error = error
                    print("Error loading genre stats: \(error)")
                }
            }
            isLoadingGenres = false
        }
        
        loadingTasks.append(task)
        await task.value
    }
    
    private func loadFilmsPerYear() async {
        isLoadingYears = true
        
        let task = Task {
            do {
                filmsPerYear = try await apiService.getFilmsPerYear()
            } catch {
                if !Task.isCancelled {
                    self.error = error
                    print("Error loading films per year: \(error)")
                }
            }
            isLoadingYears = false
        }
        
        loadingTasks.append(task)
        await task.value
    }
    
    private func cancelAllTasks() {
        loadingTasks.forEach { $0.cancel() }
        loadingTasks.removeAll()
    }
    
    deinit {
        // Cancel tasks synchronously without main actor isolation
        loadingTasks.forEach { $0.cancel() }
    }
}

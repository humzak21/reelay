//
//  StatisticsView.swift
//  reelay
//
//  Created by Humza Khalil on 6/11/25.
//

import SwiftUI
import Charts

struct StatisticsView: View {
    @Binding var showingAddMovie: Bool
    @StateObject private var viewModel = StatisticsViewModel()
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 20) {
                    // Dashboard Stats with individual loading state
                    if viewModel.isLoadingDashboard {
                        DashboardStatsSkeletonView()
                    } else if let dashboardStats = viewModel.dashboardStats {
                        DashboardStatsView(stats: dashboardStats)
                    }
                    
                    // Rating Distribution with individual loading state
                    if viewModel.isLoadingRatings {
                        ChartSkeletonView(title: "Rating Distribution")
                    } else if !viewModel.ratingDistribution.isEmpty {
                        RatingDistributionChartView(data: viewModel.ratingDistribution)
                    }
                    
                    // Genre Stats with individual loading state
                    if viewModel.isLoadingGenres {
                        ChartSkeletonView(title: "Genres")
                    } else if !viewModel.genreStats.isEmpty {
                        GenreStatsChartView(data: viewModel.genreStats)
                    }
                    
                    // Films Per Year with individual loading state
                    if viewModel.isLoadingYears {
                        ChartSkeletonView(title: "Films Per Year")
                    } else if !viewModel.filmsPerYear.isEmpty {
                        FilmsPerYearChartView(data: viewModel.filmsPerYear)
                    }
                }
                .padding()
            }
            .navigationTitle("Statistics")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showingAddMovie = true
                        } label: {
                            Label("Add Film", systemImage: "film")
                        }
                        
                        Button {
                            // TODO: Add TV show functionality
                        } label: {
                            Label("Add TV Show", systemImage: "tv")
                        }
                        
                        Button {
                            // TODO: Add music functionality
                        } label: {
                            Label("Add Music", systemImage: "music.note")
                        }
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
            .refreshable {
                await viewModel.loadAllStats()
            }
        }
        .task {
            // Load dashboard stats first for immediate feedback
            if viewModel.dashboardStats == nil {
                await viewModel.loadDashboardStatsOnly()
            }
            // Then load all stats
            await viewModel.loadAllStats()
        }
    }
}

struct DashboardStatsView: View {
    let stats: DashboardStats
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Dashboard")
                .font(.title2)
                .fontWeight(.bold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                StatCardView(title: "Total Films", value: "\(stats.totalFilms)", icon: "film")
                StatCardView(title: "Unique Films", value: "\(stats.uniqueFilms)", icon: "sparkles")
                StatCardView(title: "Average Rating", value: String(format: "%.1f", stats.avgRating), icon: "star")
                StatCardView(title: "This Year", value: "\(stats.filmsThisYear)", icon: "calendar")
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct StatCardView: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
            
            Text(value)
                .font(.title)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}

struct RatingDistributionChartView: View {
    let data: [RatingDistribution]
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Rating Distribution")
                .font(.title2)
                .fontWeight(.bold)
            
            Chart(data, id: \.ratingValue) { item in
                BarMark(
                    x: .value("Rating", item.ratingValue),
                    y: .value("Count", item.countFilms)
                )
                .foregroundStyle(.blue)
            }
            .frame(height: 200)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Skeleton Views for Loading States
struct DashboardStatsSkeletonView: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("Dashboard")
                .font(.title2)
                .fontWeight(.bold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                ForEach(0..<4, id: \.self) { _ in
                    StatCardSkeletonView()
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct StatCardSkeletonView: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 30, height: 30)
            
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 40, height: 20)
            
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 60, height: 12)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .opacity(isAnimating ? 0.5 : 1.0)
        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isAnimating)
        .onAppear {
            isAnimating = true
        }
    }
}

struct ChartSkeletonView: View {
    let title: String
    @State private var isAnimating = false
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
            
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.3))
                .frame(height: 200)
                .opacity(isAnimating ? 0.5 : 1.0)
                .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isAnimating)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .onAppear {
            isAnimating = true
        }
    }
}

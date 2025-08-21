//
//  SearchView.swift
//  reelay2
//
//  Created by Humza Khalil on 7/21/25.
//

import SwiftUI

struct SearchView: View {
    @StateObject private var viewModel = SearchViewModel()
    @State private var showingFilters = false
    @State private var viewMode: ViewMode = .list
    @State private var selectedMovie: Movie?
    
    // For rewatch color calculations
    private var allMovies: [Movie] {
        return viewModel.searchResults
    }
    
    enum ViewMode {
        case list, grid
        
        var icon: String {
            switch self {
            case .list: return "square.grid.2x2"
            case .grid: return "list.bullet"
            }
        }
    }
    
    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Filter summary bar
                if viewModel.hasActiveFilters {
                    filterSummaryBar
                }
                
                // Main content
                if viewModel.searchText.isEmpty && !viewModel.hasSearched {
                    emptySearchState
                } else if viewModel.isSearching {
                    loadingView
                } else if viewModel.filteredAndSortedResults.isEmpty && viewModel.hasSearched {
                    noResultsView
                } else if !viewModel.filteredAndSortedResults.isEmpty {
                    VStack(spacing: 0) {
                        // Quick stats
                        if !viewModel.searchResults.isEmpty {
                            searchStatsBar
                                .padding(.bottom, 8)
                        }
                        
                        // Search results
                        searchResultsView
                    }
                }
                
                Spacer(minLength: 0)
            }
        }
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $viewModel.searchText, placement: .navigationBarDrawer, prompt: "Search movies")
        
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    // View mode toggle
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewMode = viewMode == .list ? .grid : .list
                        }
                    }) {
                        Image(systemName: viewMode.icon)
                            .font(.system(size: 16, weight: .medium))
                    }
                    
                    // Filter button
                    Button(action: {
                        showingFilters = true
                    }) {
                        ZStack {
                            Image(systemName: "line.3.horizontal.decrease")
                                .font(.system(size: 16, weight: .medium))
                            
                            if viewModel.hasActiveFilters {
                                Circle()
                                    .fill(.red)
                                    .frame(width: 8, height: 8)
                                    .offset(x: 8, y: -8)
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingFilters) {
            SearchFiltersView(viewModel: viewModel)
        }
    }
    
    
    // MARK: - Search Stats Bar
    private var searchStatsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                StatChip(
                    icon: "film",
                    value: "\(viewModel.resultStats.totalCount)",
                    label: "Results"
                )
                
                if viewModel.resultStats.averageRating > 0 {
                    StatChip(
                        icon: "star.fill",
                        value: String(format: "%.1f", viewModel.resultStats.averageRating / 20),
                        label: "Avg Rating"
                    )
                }
                
                StatChip(
                    icon: "calendar",
                    value: viewModel.resultStats.yearRange,
                    label: "Years"
                )
                
                if viewModel.resultStats.rewatchCount > 0 {
                    StatChip(
                        icon: "arrow.clockwise",
                        value: "\(viewModel.resultStats.rewatchCount)",
                        label: "Rewatches"
                    )
                }
                
                ForEach(viewModel.resultStats.topGenres.prefix(2), id: \.self) { genre in
                    StatChip(
                        icon: "theatermasks",
                        value: genre,
                        label: "Genre"
                    )
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Filter Summary Bar
    private var filterSummaryBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "line.3.horizontal.decrease")
                .foregroundColor(.blue)
                .font(.system(size: 14, weight: .medium))
            
            Text("Filters active")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
            
            Text("•")
                .foregroundColor(.gray)
            
            Text("\(viewModel.filteredAndSortedResults.count) of \(viewModel.searchResults.count) results")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    viewModel.clearFilters()
                }
            }) {
                Text("Clear")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.red)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemFill))
    }
    
    // MARK: - Empty Search State
    private var emptySearchState: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "magnifyingglass.circle")
                .font(.system(size: 64))
                .foregroundColor(.gray)
            
            Text("Search Your Movie Diary")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text("Find any movie you've watched by searching for titles, directors, tags, or even text in your reviews.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            // Suggested searches
            VStack(alignment: .leading, spacing: 12) {
                Text("Try searching for:")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
                    ForEach(["IMAX", "theater", "2024", "5 stars", "family"], id: \.self) { suggestion in
                        Button(action: {
                            viewModel.searchText = suggestion
                        }) {
                            Text(suggestion)
                                .font(.caption)
                                .foregroundColor(.blue)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .stroke(Color.blue.opacity(0.5), lineWidth: 1)
                                )
                        }
                    }
                }
            }
            .padding(.horizontal, 40)
            
            Spacer()
        }
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.2)
            
            Text("Searching your diary...")
                .font(.body)
                .foregroundColor(.gray)
            
            Spacer()
        }
    }
    
    // MARK: - No Results View
    private var noResultsView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("No Results Found")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text("No movies match '\(viewModel.searchText)'")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            if viewModel.hasActiveFilters {
                Button(action: {
                    withAnimation {
                        viewModel.clearFilters()
                    }
                }) {
                    Text("Clear Filters")
                        .font(.body)
                        .foregroundColor(.blue)
                }
                .padding(.top, 8)
            }
            
            Spacer()
        }
        .padding(.horizontal, 40)
        .padding(.top, -40)
    }
    
    // MARK: - Search Results View
    private var searchResultsView: some View {
        ScrollView {
            if viewMode == .list {
                // List view
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.filteredAndSortedResults) { movie in
                        MovieSearchCard(movie: movie, searchQuery: viewModel.searchText, rewatchIconColor: getRewatchIconColor(for: movie))
                            .padding(.horizontal, 20)
                    }
                }
                .padding(.vertical, 12)
            } else {
                // Grid view
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ], spacing: 16) {
                    ForEach(viewModel.filteredAndSortedResults) { movie in
                        MovieSearchCardCompact(movie: movie)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
        }
    }
    
    // MARK: - Rewatch Icon Color Logic
    
    private func getRewatchIconColor(for movie: Movie) -> Color {
        guard movie.isRewatchMovie else { return .orange }
        
        // Grey: First entry in DB but marked as rewatch
        if isFirstEntryButMarkedAsRewatch(movie) {
            return .gray
        }
        
        // Yellow: First watched and rewatched in same calendar year
        if wasFirstWatchedInSameYearAsRewatch(movie) {
            return .yellow
        }
        
        // Orange: Movie was logged in a previous year
        if wasLoggedInPreviousYear(movie) {
            return .orange
        }
        
        // Default orange for any other rewatch scenario
        return .orange
    }
    
    private func isFirstEntryButMarkedAsRewatch(_ movie: Movie) -> Bool {
        guard let tmdbId = movie.tmdb_id else { return false }
        
        // Find all entries for this TMDB ID
        let entriesForMovie = allMovies.filter { $0.tmdb_id == tmdbId }
        
        // If this is the only entry and it's marked as rewatch, then it's grey
        return entriesForMovie.count == 1 && movie.isRewatchMovie
    }
    
    private func wasFirstWatchedInSameYearAsRewatch(_ movie: Movie) -> Bool {
        guard let watchDate = movie.watch_date,
              let movieWatchDate = DateFormatter.searchMovieDateFormatter.date(from: watchDate),
              let tmdbId = movie.tmdb_id else { return false }
        
        let calendar = Calendar.current
        let movieYear = calendar.component(.year, from: movieWatchDate)
        
        // Find all entries for this movie
        let entriesForMovie = allMovies.filter { $0.tmdb_id == tmdbId }
            .compactMap { movie -> (Movie, Date)? in
                guard let dateString = movie.watch_date,
                      let date = DateFormatter.searchMovieDateFormatter.date(from: dateString) else { return nil }
                return (movie, date)
            }
            .sorted { $0.1 < $1.1 }
        
        // Check if there are at least 2 entries in the same year
        let entriesInSameYear = entriesForMovie.filter {
            calendar.component(.year, from: $0.1) == movieYear
        }
        
        if entriesInSameYear.count >= 2 {
            // Check if the first was not a rewatch and current one is a rewatch
            let firstEntry = entriesInSameYear[0].0
            return !firstEntry.isRewatchMovie && movie.isRewatchMovie && movie.id != firstEntry.id
        }
        
        return false
    }
    
    private func wasLoggedInPreviousYear(_ movie: Movie) -> Bool {
        guard let watchDate = movie.watch_date,
              let movieWatchDate = DateFormatter.searchMovieDateFormatter.date(from: watchDate),
              let tmdbId = movie.tmdb_id else { return false }
        
        let calendar = Calendar.current
        let movieYear = calendar.component(.year, from: movieWatchDate)
        
        // Find all entries for this movie
        let entriesForMovie = allMovies.filter { $0.tmdb_id == tmdbId }
            .compactMap { movie -> Date? in
                guard let dateString = movie.watch_date,
                      let date = DateFormatter.searchMovieDateFormatter.date(from: dateString) else { return nil }
                return date
            }
        
        // Check if any entry was in a previous year
        return entriesForMovie.contains { date in
            calendar.component(.year, from: date) < movieYear
        }
    }
}

// MARK: - DateFormatter Extension for SearchView
extension DateFormatter {
    static let searchMovieDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

// MARK: - Stat Chip Component
struct StatChip: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
                Text(label)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemFill))
        )
    }
}

// MARK: - Search Filters View
struct SearchFiltersView: View {
    @ObservedObject var viewModel: SearchViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Sort options
                    VStack(alignment: .leading, spacing: 12) {
                        Text("SORT BY")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.gray)
                            .tracking(0.5)
                        
                        ForEach(SearchViewModel.SearchSortOption.allCases, id: \.self) { option in
                            Button(action: {
                                viewModel.sortBy = option
                            }) {
                                HStack {
                                    Text(option.displayName)
                                        .foregroundColor(.white)
                                    Spacer()
                                    if viewModel.sortBy == option {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                }
                                .padding(.vertical, 8)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    Divider()
                        .background(Color.gray.opacity(0.3))
                    
                    // Filter by year
                    VStack(alignment: .leading, spacing: 12) {
                        Text("RELEASE YEAR")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.gray)
                            .tracking(0.5)
                        
                        if !viewModel.availableYears.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    Button(action: {
                                        viewModel.filterByYear = nil
                                    }) {
                                        Text("All")
                                            .font(.caption)
                                            .foregroundColor(viewModel.filterByYear == nil ? .black : .white)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(
                                                Capsule()
                                                    .fill(viewModel.filterByYear == nil ? Color.white : Color.gray.opacity(0.3))
                                            )
                                    }
                                    
                                    ForEach(viewModel.availableYears, id: \.self) { year in
                                        Button(action: {
                                            viewModel.filterByYear = year
                                        }) {
                                            Text(String(year))
                                                .font(.caption)
                                                .foregroundColor(viewModel.filterByYear == year ? .black : .white)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(
                                                    Capsule()
                                                        .fill(viewModel.filterByYear == year ? Color.white : Color.gray.opacity(0.3))
                                                )
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Filter by rating
                    VStack(alignment: .leading, spacing: 12) {
                        Text("MINIMUM RATING")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.gray)
                            .tracking(0.5)
                        
                        HStack(spacing: 8) {
                            ForEach([0.0, 2.0, 3.0, 4.0, 4.5], id: \.self) { rating in
                                Button(action: {
                                    viewModel.filterByRating = viewModel.filterByRating == rating ? nil : rating
                                }) {
                                    HStack(spacing: 2) {
                                        ForEach(0..<Int(rating), id: \.self) { _ in
                                            Image(systemName: "star.fill")
                                                .font(.system(size: 10))
                                        }
                                        if rating.truncatingRemainder(dividingBy: 1) != 0 {
                                            Image(systemName: "star.leadinghalf.filled")
                                                .font(.system(size: 10))
                                        }
                                    }
                                    .foregroundColor(viewModel.filterByRating == rating ? .yellow : .gray)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule()
                                            .fill(viewModel.filterByRating == rating ? Color.yellow.opacity(0.2) : Color.gray.opacity(0.2))
                                    )
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Rewatch filter
                    Toggle("Show only rewatches", isOn: $viewModel.showOnlyRewatches)
                        .padding(.horizontal, 20)
                }
                .padding(.vertical, 20)
            }
                        .background(Color(.systemBackground))
            .navigationTitle("Filters & Sort")
            .navigationBarTitleDisplayMode(.large)
            
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Clear All") {
                        viewModel.clearFilters()
                    }
                    .foregroundColor(.red)
                    .opacity(viewModel.hasActiveFilters ? 1 : 0)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
            }
        }
    }
}

#Preview {
    SearchView()
}
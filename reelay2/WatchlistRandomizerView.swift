//
//  WatchlistRandomizerView.swift
//  reelay2
//
//  Created by Humza Khalil on 8/28/25.
//

import SwiftUI
import Auth

struct WatchlistRandomizerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var dataManager = DataManager.shared
    @ObservedObject private var movieService = SupabaseMovieService.shared
    @State private var randomMovie: ListItem?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedMovie: Movie?
    
    // Multi-list selection
    @State private var selectedListIds: Set<UUID> = []
    @State private var availableLists: [MovieList] = []
    @State private var showingListSelector = false
    
    // Filter criteria
    @State private var minYear: Int = 1880
    @State private var maxYear: Int = Calendar.current.component(.year, from: Date())
    @State private var showingFilters = false
    
    // Cached year range for pickers (computed once)
    private let yearRange: [Int] = {
        let currentYear = Calendar.current.component(.year, from: Date())
        return Array(1880...currentYear).reversed()
    }()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "dice")
                        .font(.system(size: 50))
                        .foregroundColor(.blue)
                    
                    Text("List Randomizer")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(Color.adaptiveText(scheme: colorScheme))
                    
                    Text("Can't decide what to watch? Let us pick for you!")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                .padding(.top, 20)
                
                Spacer()
                
                // Random movie display
                if let randomMovie = randomMovie {
                    randomMovieCard(randomMovie)
                } else if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                        Text("Finding your next watch...")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 60))
                            .foregroundColor(.gray.opacity(0.5))
                        
                        Text(selectedListIds.isEmpty ? "Select one or more lists and tap the dice!" : "Tap the dice to get a random movie from your selected lists!")
                            .font(.body)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                }
                
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                
                // List selection summary (always visible)
                listSelectionSummary
                
                // Multi-list selection (collapsible)
                if showingListSelector {
                    multiListSelectionSection
                }
                
                // Filter controls
                if showingFilters {
                    filtersSection
                }
                
                Spacer()
                
                // Action buttons
                VStack(spacing: 12) {
                    // List selector toggle button
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showingListSelector.toggle()
                        }
                    }) {
                        HStack {
                            Image(systemName: "list.bullet")
                                .font(.title2)
                            Text(showingListSelector ? "Hide Lists" : "Select Lists")
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(10)
                    }
                    
                    // Filter toggle button
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showingFilters.toggle()
                        }
                    }) {
                        HStack {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                                .font(.title2)
                            Text(showingFilters ? "Hide Filters" : "Show Filters")
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(10)
                    }
                    
                    Button(action: {
                        Task {
                            await randomizeSelection()
                        }
                    }) {
                        HStack {
                            Image(systemName: "dice")
                                .font(.title2)
                            Text(randomMovie == nil ? "Pick Random Movie" : "Pick Another")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(selectedListIds.isEmpty || isLoading ? Color.gray : Color.blue)
                        .cornerRadius(12)
                    }
                    .disabled(isLoading || selectedListIds.isEmpty)
                    
                    if randomMovie != nil {
                        Button(action: {
                            Task {
                                await openMovieDetails()
                            }
                        }) {
                            Text("View Details")
                                .fontWeight(.medium)
                                .foregroundColor(.blue)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(10)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            #if canImport(UIKit)
            .background(Color(.systemGroupedBackground))
            #else
            .background(Color(.windowBackgroundColor))
            #endif
            .navigationTitle("Randomizer")
            #if canImport(UIKit)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", systemImage: "xmark") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(item: $selectedMovie) { movie in
            MovieDetailsView(movie: movie)
        }
        .task {
            await loadAvailableLists()
        }
    }
    
    @ViewBuilder
    private var listSelectionSummary: some View {
        VStack(spacing: 8) {
            if !selectedListIds.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "checklist")
                        .foregroundColor(.blue)
                    Text("\(selectedListIds.count) list\(selectedListIds.count == 1 ? "" : "s") selected")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                    Text("No lists selected - tap 'Select Lists' below")
                        .font(.subheadline)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(.horizontal, 20)
    }
    
    @ViewBuilder
    private var multiListSelectionSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Select Lists")
                    .font(.headline)
                    .foregroundColor(Color.adaptiveText(scheme: colorScheme))
                
                Spacer()
                
                if !availableLists.isEmpty {
                    HStack(spacing: 8) {
                        Button(action: {
                            if selectedListIds.count == availableLists.count {
                                selectedListIds.removeAll()
                            } else {
                                selectedListIds = Set(availableLists.map { $0.id })
                            }
                            randomMovie = nil
                            errorMessage = nil
                        }) {
                            Text(selectedListIds.count == availableLists.count ? "Deselect All" : "Select All")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            
            if availableLists.isEmpty {
                Text("Loading lists...")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .frame(height: 100)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(availableLists, id: \.id) { list in
                            Button(action: {
                                if selectedListIds.contains(list.id) {
                                    selectedListIds.remove(list.id)
                                } else {
                                    selectedListIds.insert(list.id)
                                }
                                randomMovie = nil
                                errorMessage = nil
                            }) {
                                HStack {
                                    Image(systemName: selectedListIds.contains(list.id) ? "checkmark.square.fill" : "square")
                                        .foregroundColor(selectedListIds.contains(list.id) ? .blue : .gray)
                                        .font(.title3)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(list.name)
                                            .foregroundColor(Color.adaptiveText(scheme: colorScheme))
                                            .font(.body)
                                        
                                        Text("\(list.itemCount) movies")
                                            .foregroundColor(.gray)
                                            .font(.caption)
                                    }
                                    
                                    Spacer()
                                }
                                .padding(12)
                                .background(selectedListIds.contains(list.id) ? Color.blue.opacity(0.15) : Color.gray.opacity(0.1))
                                .cornerRadius(10)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                .frame(maxHeight: 250)
            }
        }
        .padding(.horizontal, 20)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
    
    @ViewBuilder
    private var filtersSection: some View {
        VStack(spacing: 16) {
            Text("Filters")
                .font(.headline)
                .foregroundColor(Color.adaptiveText(scheme: colorScheme))
            
            VStack(spacing: 12) {
                // Year range filter
                VStack(alignment: .leading, spacing: 8) {
                    Text("Release Year Range")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(Color.adaptiveText(scheme: colorScheme))
                    
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("From")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Picker("Min Year", selection: $minYear) {
                                ForEach(yearRange, id: \.self) { year in
                                    Text(String(year)).tag(year)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .frame(width: 100)
                            .background(Color.gray.opacity(0.12))
                            .cornerRadius(8)
                            .onChange(of: minYear) { oldValue, newValue in
                                // Ensure min year doesn't exceed max year
                                if newValue > maxYear {
                                    maxYear = newValue
                                }
                                randomMovie = nil
                                errorMessage = nil
                            }
                        }
                        
                        Text("to")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .padding(.top, 16)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("To")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Picker("Max Year", selection: $maxYear) {
                                ForEach(yearRange, id: \.self) { year in
                                    Text(String(year)).tag(year)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .frame(width: 100)
                            .background(Color.gray.opacity(0.12))
                            .cornerRadius(8)
                            .onChange(of: maxYear) { oldValue, newValue in
                                // Ensure max year doesn't go below min year
                                if newValue < minYear {
                                    minYear = newValue
                                }
                                randomMovie = nil
                                errorMessage = nil
                            }
                        }
                    }
                }
            }
            .padding(16)
            .background(Color.gray.opacity(0.15))
            .cornerRadius(12)
        }
        .padding(.horizontal, 20)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
    
    @ViewBuilder
    private func randomMovieCard(_ item: ListItem) -> some View {
        VStack(spacing: 16) {
            AsyncImage(url: item.posterURL) { image in
                image
                    .resizable()
                    .aspectRatio(2/3, contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .aspectRatio(2/3, contentMode: .fill)
            }
            .frame(width: 200, height: 300)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
            
            VStack(spacing: 8) {
                Text(item.movieTitle)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(Color.adaptiveText(scheme: colorScheme))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                
                if let year = item.movieYear {
                    Text("(\(String(year)))")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                if let releaseDate = item.movieReleaseDate {
                    Text("Release: \(formatReleaseDate(releaseDate))")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    private func randomizeSelection() async {
        guard !selectedListIds.isEmpty else {
            await MainActor.run {
                errorMessage = "Please select at least one list"
            }
            return
        }
        
        // Validate year range
        guard minYear <= maxYear else {
            await MainActor.run {
                errorMessage = "Minimum year cannot be greater than maximum year"
            }
            return
        }
        
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            // Use the optimized DataManager method with SQL-side random selection
            let selectedListIdsArray = Array(selectedListIds)
            let result = try await dataManager.getRandomMovieFromLists(
                listIds: selectedListIdsArray,
                minYear: minYear,
                maxYear: maxYear
            )
            
            await MainActor.run {
                if let result = result {
                    randomMovie = result
                } else {
                    // No movies found matching criteria
                    if showingFilters && (minYear > 1880 || maxYear < Calendar.current.component(.year, from: Date())) {
                        errorMessage = "No movies found matching your filter criteria. Try adjusting your year range."
                    } else {
                        errorMessage = "No movies found in the selected list(s)."
                    }
                    randomMovie = nil
                }
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "Error loading movies: \(error.localizedDescription)"
                randomMovie = nil
                isLoading = false
            }
        }
    }
    
    private func openMovieDetails() async {
        guard let randomMovie = randomMovie else { return }
        
        do {
            let existingMovies = try await movieService.getMoviesByTmdbId(tmdbId: randomMovie.tmdbId)
            
            await MainActor.run {
                if let firstLoggedMovie = existingMovies.first {
                    selectedMovie = firstLoggedMovie
                } else {
                    // Create a Movie object from ListItem data
                    let movie = Movie(
                        id: -1,
                        title: randomMovie.movieTitle,
                        release_year: randomMovie.movieYear,
                        release_date: randomMovie.movieReleaseDate,
                        rating: nil,
                        detailed_rating: nil,
                        review: nil,
                        tags: nil,
                        watch_date: nil,
                        is_rewatch: false,
                        tmdb_id: randomMovie.tmdbId,
                        overview: nil,
                        poster_url: randomMovie.moviePosterUrl,
                        backdrop_path: randomMovie.movieBackdropPath,
                        director: nil,
                        runtime: nil,
                        vote_average: nil,
                        vote_count: nil,
                        popularity: nil,
                        original_language: nil,
                        original_title: nil,
                        tagline: nil,
                        status: nil,
                        budget: nil,
                        revenue: nil,
                        imdb_id: nil,
                        homepage: nil,
                        genres: nil,
                        created_at: nil,
                        updated_at: nil,
                        favorited: nil
                    )
                    selectedMovie = movie
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = "Error loading movie details: \(error.localizedDescription)"
            }
        }
    }
    
    private func formatReleaseDate(_ dateString: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        guard let date = dateFormatter.date(from: dateString) else {
            return dateString
        }
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "MMM d, yyyy"
        return displayFormatter.string(from: date)
    }
    
    private func loadAvailableLists() async {
        // Only load list metadata - no need to load items
        // Lists are already cached in DataManager
        await MainActor.run {
            // Get all lists including the watchlist
            var lists = dataManager.movieLists
            
            // Add watchlist if user is logged in and it's not already in the list
            if movieService.isLoggedIn {
                let watchlistId = SupabaseWatchlistService.watchlistListId
                if !lists.contains(where: { $0.id == watchlistId }) {
                    let watchlist = MovieList.watchlistPlaceholder(userId: movieService.currentUser?.id ?? UUID())
                    lists.insert(watchlist, at: 0)
                }
            }
            
            // Sort lists alphabetically (keeping watchlist first if it exists)
            let sortedLists = lists.sorted { list1, list2 in
                // Keep watchlist at the top
                if list1.id == SupabaseWatchlistService.watchlistListId {
                    return true
                }
                if list2.id == SupabaseWatchlistService.watchlistListId {
                    return false
                }
                // Sort others alphabetically
                return list1.name.localizedCaseInsensitiveCompare(list2.name) == .orderedAscending
            }
            
            availableLists = sortedLists
            
            // Auto-select watchlist by default if available
            if let watchlist = sortedLists.first(where: { $0.id == SupabaseWatchlistService.watchlistListId }) {
                selectedListIds.insert(watchlist.id)
            }
        }
    }
}

#Preview {
    WatchlistRandomizerView()
}

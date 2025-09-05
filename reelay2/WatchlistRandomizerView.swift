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
    @StateObject private var dataManager = DataManager.shared
    @StateObject private var movieService = SupabaseMovieService.shared
    @State private var randomMovie: ListItem?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedMovie: Movie?
    
    // List selection
    @State private var selectedListId: UUID?
    @State private var availableLists: [MovieList] = []
    
    // Filter criteria
    @State private var minYear: Int = 1880
    @State private var maxYear: Int = Calendar.current.component(.year, from: Date())
    @State private var selectedGenres: Set<String> = []
    @State private var showingFilters = false
    
    // Year range for pickers
    private var yearRange: [Int] {
        Array(1880...Calendar.current.component(.year, from: Date())).reversed()
    }
    
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
                        .foregroundColor(.white)
                    
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
                        
                        Text(selectedListId != nil ? "Tap the dice to get a random movie from your selected list!" : "Select a list and tap the dice to get a random movie!")
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
                
                // List selection
                listSelectionSection
                
                // Filter controls
                if showingFilters {
                    filtersSection
                }
                
                Spacer()
                
                // Action buttons
                VStack(spacing: 12) {
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
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    .disabled(isLoading || selectedListId == nil)
                    
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
            .background(Color.black)
            .navigationTitle("Randomizer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
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
    private var listSelectionSection: some View {
        VStack(spacing: 16) {
            Text("Select List")
                .font(.headline)
                .foregroundColor(.white)
            
            if availableLists.isEmpty {
                Text("Loading lists...")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            } else {
                Menu {
                    ForEach(availableLists, id: \.id) { list in
                        Button(action: {
                            selectedListId = list.id
                            randomMovie = nil // Clear current random movie when switching lists
                            errorMessage = nil
                        }) {
                            Text(list.name)
                        }
                    }
                } label: {
                    HStack {
                        if let selectedListId = selectedListId,
                           let selectedList = availableLists.first(where: { $0.id == selectedListId }) {
                            Text(selectedList.name)
                                .foregroundColor(.white)
                            Spacer()
                        } else {
                            Text("Choose a list")
                                .foregroundColor(.gray)
                            Spacer()
                        }
                        Image(systemName: "chevron.down")
                            .foregroundColor(.blue)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.15))
                    .cornerRadius(12)
                }
            }
        }
        .padding(.horizontal, 20)
    }
    
    @ViewBuilder
    private var filtersSection: some View {
        VStack(spacing: 16) {
            Text("Filters")
                .font(.headline)
                .foregroundColor(.white)
            
            VStack(spacing: 12) {
                // Year range filter
                VStack(alignment: .leading, spacing: 8) {
                    Text("Release Year Range")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                    
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
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
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
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                    }
                }
                
                // Genre filter (placeholder)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Genres (Coming Soon)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                    
                    Text("Genre filtering will be available in a future update")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .italic()
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
                    .foregroundColor(.white)
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
        isLoading = true
        errorMessage = nil
        
        do {
            let allMovies = try await getMoviesFromSelectedList()
            
            await MainActor.run {
                if allMovies.isEmpty {
                    if showingFilters && (minYear > 1880 || maxYear < Calendar.current.component(.year, from: Date())) {
                        errorMessage = "No movies found matching your filter criteria. Try adjusting your year range."
                    } else if let selectedListId = selectedListId,
                              let selectedList = availableLists.first(where: { $0.id == selectedListId }) {
                        errorMessage = "No movies found in '\(selectedList.name)'."
                    } else {
                        errorMessage = "No movies found in the selected list."
                    }
                    randomMovie = nil
                } else {
                    randomMovie = allMovies.randomElement()
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
    
    private func getMoviesFromSelectedList() async throws -> [ListItem] {
        guard let selectedListId = selectedListId else {
            throw NSError(domain: "RandomizerError", code: 1, userInfo: [NSLocalizedDescriptionKey: "No list selected"])
        }
        
        // Ensure list data is loaded
        if selectedListId == SupabaseWatchlistService.watchlistListId {
            await dataManager.refreshWatchlist()
        } else {
            await dataManager.refreshLists()
        }
        
        // Get the items from the selected list
        let listItems = dataManager.listItems[selectedListId] ?? []
        
        // Capture year filters on MainActor to avoid concurrency issues
        let currentMinYear = await MainActor.run { minYear }
        let currentMaxYear = await MainActor.run { maxYear }
        
        // Filter movies by year criteria only
        let filteredItems = listItems.filter { item in
            if let year = item.movieYear {
                return year >= currentMinYear && year <= currentMaxYear
            } else {
                return true // Include movies with no year information
            }
        }
        
        return filteredItems
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
        await dataManager.refreshLists()
        await dataManager.refreshWatchlist()
        
        await MainActor.run {
            // Get all lists including the watchlist
            var lists = dataManager.movieLists
            
            // Add watchlist if user is logged in
            if movieService.isLoggedIn {
                let watchlist = MovieList.watchlistPlaceholder(userId: movieService.currentUser?.id ?? UUID())
                lists.insert(watchlist, at: 0)
                
                // Set watchlist as default selection
                if selectedListId == nil {
                    selectedListId = watchlist.id
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
        }
        
        // Ensure all list items are loaded
        for list in availableLists {
            if list.id == SupabaseWatchlistService.watchlistListId {
                // Watchlist items are already loaded by refreshWatchlist()
                continue
            } else {
                // Force-reload list items for regular lists
                do {
                    _ = try await dataManager.reloadItemsForList(list.id)
                } catch {
                    print("⚠️ Error loading items for list '\(list.name)': \(error)")
                }
            }
        }
    }
    
}

#Preview {
    WatchlistRandomizerView()
}
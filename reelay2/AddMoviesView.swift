//
//  AddMoviesView.swift
//  reelay2
//
//  Created by Humza Khalil on 8/1/25.
//

import SwiftUI
import SDWebImageSwiftUI

struct AddMoviesView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var tmdbService = TMDBService.shared
    @StateObject private var supabaseService = SupabaseMovieService.shared
    @StateObject private var watchlistService = SupabaseWatchlistService.shared
    @StateObject private var dataManager = DataManager.shared
    
    // Optional pre-selected movie for "Log Again" functionality
    let preSelectedMovie: TMDBMovie?
    
    // Search state
    @State private var searchText = ""
    @State private var searchResults: [TMDBMovie] = []
    @State private var isSearching = false
    @State private var selectedMovie: TMDBMovie?
    @State private var searchTask: Task<Void, Never>?
    
    init(preSelectedMovie: TMDBMovie? = nil) {
        self.preSelectedMovie = preSelectedMovie
    }
    
    // Movie details state
    @State private var movieDetails: TMDBMovieDetails?
    @State private var director: String?
    @State private var isLoadingDetails = false
    
    // User input state
    @State private var starRating: Double = 0.0
    @State private var detailedRating: String = ""
    @State private var review: String = ""
    @State private var tags: String = ""
    @State private var watchDate = Date()
    @State private var isRewatch = false
    @State private var isFavorited = false
    
    // UI state
    @State private var showingSimilarRatings = false
    @State private var similarRatingMovies: [Movie] = []
    @State private var displayedMoviesCount = 5
    @State private var isLoadingMoreMovies = false
    @State private var previousWatches: [Movie] = []
    @State private var showingPreviousWatches = false
    @State private var isAddingMovie = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var selectedPreviousMovie: Movie?
    @State private var showingMovieDetails = false
    @State private var ratingSearchText = ""
    
    // Watchlist state
    @State private var isAddingToWatchlist = false
    @State private var watchlistSuccessMessage = ""
    @State private var showingWatchlistSuccess = false
    
    // Movie lists state
    @State private var movieLists: [MovieList] = []
    @State private var showingMovieLists = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if selectedMovie == nil {
                    searchView
                } else {
                    addMovieView
                }
            }
            .navigationTitle(preSelectedMovie != nil ? "Log Again" : "Add Movie")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color(.systemBackground))
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", systemImage: "xmark") {
                        dismiss()
                    }
                }
                
                if selectedMovie != nil {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Add", systemImage: "checkmark") {
                            Task {
                                await addMovie()
                            }
                        }
                        .disabled(isAddingMovie)
                    }
                }
            }
            .alert("Error", isPresented: $showingAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
            .alert("Added to Watchlist", isPresented: $showingWatchlistSuccess) {
                Button("OK") { }
            } message: {
                Text(watchlistSuccessMessage)
            }
            .sheet(isPresented: $showingMovieDetails) {
                if let selectedMovie = selectedPreviousMovie {
                    MovieDetailsView(movie: selectedMovie)
                }
            }
            .onAppear {
                if let preSelected = preSelectedMovie {
                    selectedMovie = preSelected
                    // Load movie details and check for existing entries to prefill form
                    loadMovieDetails(movieId: preSelected.id)
                    Task {
                        await checkForExistingMovie(tmdbId: preSelected.id)
                        await checkForMovieLists(tmdbId: preSelected.id)
                    }
                }
            }
            .onDisappear {
                searchTask?.cancel()
            }
        }
    }
    
    // MARK: - Search View
    private var searchView: some View {
        VStack {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("Search movies...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .foregroundColor(.white)
                    .onSubmit {
                        performSearch()
                    }
                    .onChange(of: searchText) { _, newValue in
                        searchTask?.cancel()
                        if !newValue.isEmpty {
                            searchTask = Task {
                                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
                                if !Task.isCancelled {
                                    await performSearchDelayed()
                                }
                            }
                        } else {
                            searchResults = []
                        }
                    }
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                        searchResults = []
                        searchTask?.cancel()
                    }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                if isSearching {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.2))
            .cornerRadius(10)
            .padding(.horizontal)
            
            // Search results
            if searchResults.isEmpty && !searchText.isEmpty && !isSearching {
                VStack(spacing: 16) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    
                    Text("No Results")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text("Try searching with different keywords.")
                        .font(.body)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if searchResults.isEmpty && searchText.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "film")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    
                    Text("Search Movies")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text("Search for movies to add to your diary.")
                        .font(.body)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                searchResultsList
            }
            
            Spacer()
        }
        .background(Color(.systemBackground))
    }
    
    private var searchResultsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(searchResults) { movie in
                    SearchResultRow(
                        movie: movie,
                        onLog: {
                            selectMovie(movie)
                        },
                        onAddToWatchlist: {
                            Task {
                                await addToWatchlist(movie)
                            }
                        }
                    )
                }
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Add Movie View
    private var addMovieView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                movieHeader
                
                watchDateSection
                
                ratingSection
                
                favoriteSection
                
                // Previous entries section
                if !previousWatches.isEmpty {
                    previousEntriesSection
                }
                
                // Movie lists section
                if !movieLists.isEmpty {
                    movieListsSection
                }
                
                detailedRatingSection
                
                rewatchSection
                
                reviewSection
                
                tagsSection
                
                Spacer(minLength: 100)
            }
            .padding()
        }
        .background(Color.black)
        .onAppear {
            if let movie = selectedMovie {
                loadMovieDetails(movieId: movie.id)
            }
        }
    }
    
    // MARK: - Movie Header
    private var movieHeader: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Button("� Back to Search") {
                    selectedMovie = nil
                    movieDetails = nil
                    director = nil
                    resetForm()
                }
                .foregroundColor(.blue)
                
                Spacer()
            }
            
            if let movie = selectedMovie {
                HStack(alignment: .top, spacing: 15) {
                    WebImage(url: movie.posterURL)
                        .resizable()
                        .indicator(.activity)
                        .transition(.fade(duration: 0.5))
                        .aspectRatio(2/3, contentMode: .fill)
                        .frame(width: 120)
                        .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(movie.title)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if let year = movie.releaseYear {
                        Text(String(year))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    if let director = director {
                        Text("Directed by \(director)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else if isLoadingDetails {
                        Text("Loading director...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    if let overview = movie.overview {
                        Text(overview)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(4)
                    }
                }
                
                    Spacer()
                }
            }
        }
    }
    
    // MARK: - Rating Section
    private var ratingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Star Rating")
                .font(.headline)
            
            StarRatingView(rating: $starRating, size: 30)
            
            Text("Tap stars to rate (tap twice for half stars)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Favorite Section
    private var favoriteSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Favorite")
                .font(.headline)
            
            Button(action: {
                isFavorited.toggle()
            }) {
                HStack {
                    Image(systemName: isFavorited ? "heart.fill" : "heart")
                        .foregroundColor(isFavorited ? .orange : .secondary)
                        .font(.title2)
                    
                    Text(isFavorited ? "Remove from favorites" : "Mark as favorite")
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
                .padding(.vertical, 8)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    // MARK: - Detailed Rating Section
    private var detailedRatingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Detailed Rating (out of 100)")
                .font(.headline)
            
            TextField("Enter rating 0-100", text: $detailedRating)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .cornerRadius(24)
                .keyboardType(.numberPad)
                .onChange(of: detailedRating) { oldValue, newValue in
                    // Validate input
                    let filtered = newValue.filter { $0.isNumber }
                    if filtered != newValue {
                        detailedRating = filtered
                    }
                    
                    // Check for similar ratings
                    if let rating = Double(filtered), rating > 0 {
                        checkSimilarRatings(rating: rating)
                    }
                }
            
            if showingSimilarRatings && !similarRatingMovies.isEmpty {
                similarRatingsView
            }
        }
    }
    
    private var similarRatingsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Movies in same rating range (sorted by rating):")
                .font(.subheadline)
                .fontWeight(.medium)
            
            // Rating search bar
            HStack {
                TextField("Filter by specific rating", text: $ratingSearchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.numberPad)
                    .onChange(of: ratingSearchText) { oldValue, newValue in
                        // Validate input - only allow numbers
                        let filtered = newValue.filter { $0.isNumber }
                        if filtered != newValue {
                            ratingSearchText = filtered
                        }
                    }
                
                if !ratingSearchText.isEmpty {
                    Button("Clear") {
                        ratingSearchText = ""
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
            
            LazyVStack(spacing: 8) {
                ForEach(Array(filteredSimilarMovies.prefix(displayedMoviesCount).enumerated()), id: \.element.id) { index, movie in
                    ComparisonMovieRow(movie: movie)
                }
                
                // Show more button if there are more movies to display
                if displayedMoviesCount < filteredSimilarMovies.count {
                    Button(action: {
                        if !isLoadingMoreMovies {
                            displayedMoviesCount += 10
                        }
                    }) {
                        HStack {
                            if isLoadingMoreMovies {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                    .scaleEffect(0.8)
                            }
                            Text("Show More (\(filteredSimilarMovies.count - displayedMoviesCount) remaining)")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                        .padding(.vertical, 8)
                    }
                    .disabled(isLoadingMoreMovies)
                }
                
                // Show total count
                if !filteredSimilarMovies.isEmpty {
                    Text("Showing \(min(displayedMoviesCount, filteredSimilarMovies.count)) of \(filteredSimilarMovies.count) movies")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
    
    // MARK: - Computed Properties
    private var filteredSimilarMovies: [Movie] {
        guard !ratingSearchText.isEmpty, let searchRating = Int(ratingSearchText) else {
            return similarRatingMovies
        }
        
        return similarRatingMovies.filter { movie in
            if let detailedRating = movie.detailed_rating {
                return Int(detailedRating) == searchRating
            }
            return false
        }
    }
    
    // MARK: - Previous Entries Section
    private var previousEntriesSection: some View {
        VStack(spacing: 0) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showingPreviousWatches.toggle()
                }
            }) {
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "clock")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.orange)
                        
                        Text("Previous Entries")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        
                        Text("\(previousWatches.count) previous \(previousWatches.count == 1 ? "entry" : "entries") found")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Image(systemName: showingPreviousWatches ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                }
                .padding(16)
                .background(Color.orange.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
                .cornerRadius(24)
            }
            
            if showingPreviousWatches {
                VStack(spacing: 12) {
                    ForEach(previousWatches) { previousWatch in
                        PreviousEntryRow(movie: previousWatch) {
                            selectedPreviousMovie = previousWatch
                            showingMovieDetails = true
                        }
                    }
                }
                .padding(.top, 12)
            }
        }
    }
    
    // MARK: - Movie Lists Section
    private var movieListsSection: some View {
        VStack(spacing: 0) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showingMovieLists.toggle()
                }
            }) {
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.blue)
                        
                        Text("Already in Lists")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        
                        Text("\(movieLists.count) \(movieLists.count == 1 ? "list" : "lists")")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Image(systemName: showingMovieLists ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                }
                .padding(16)
                .background(Color.blue.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                )
                .cornerRadius(24)
            }
            
            if showingMovieLists {
                VStack(spacing: 12) {
                    ForEach(movieLists) { list in
                        MovieListRow(list: list)
                    }
                }
                .padding(.top, 12)
            }
        }
    }
    
    // MARK: - Review Section
    private var reviewSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Review")
                .font(.headline)
            
            TextField("Write your review...", text: $review, axis: .vertical)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .cornerRadius(24)
                .lineLimit(5...10)
        }
    }
    
    // MARK: - Tags Section
    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Tags")
                .font(.headline)
            
            TextField("e.g., theater, family, IMAX", text: $tags)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .cornerRadius(24)
                .autocapitalization(.none)
            
            Text("Separate tags with commas (e.g., theater, family, IMAX)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Watch Date Section
    private var watchDateSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Watch Date")
                .font(.headline)
            
            DatePicker("When did you watch this?", selection: $watchDate, displayedComponents: .date)
                .datePickerStyle(CompactDatePickerStyle())
        }
    }
    
    // MARK: - Rewatch Section
    private var rewatchSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Rewatch")
                .font(.headline)
            
            Toggle("This was a rewatch", isOn: $isRewatch)
        }
    }
    
    // MARK: - Helper Methods
    private func performSearch() {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else { 
            searchResults = []
            return 
        }
        
        Task {
            await performSearchAsync()
        }
    }
    
    private func performSearchDelayed() async {
        await performSearchAsync()
    }
    
    @MainActor
    private func performSearchAsync() async {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else { 
            searchResults = []
            return 
        }
        
        isSearching = true
        
        do {
            let response = try await tmdbService.searchMovies(query: searchText)
            searchResults = response.results
        } catch {
            alertMessage = "Search failed: \(error.localizedDescription)"
            showingAlert = true
            searchResults = []
        }
        
        isSearching = false
    }
    
    private func selectMovie(_ movie: TMDBMovie) {
        selectedMovie = movie
        resetForm()
        
        // Check if this movie has been watched before and is in any lists
        Task {
            await checkForExistingMovie(tmdbId: movie.id)
            await checkForMovieLists(tmdbId: movie.id)
        }
    }
    
    private func checkForExistingMovie(tmdbId: Int) async {
        do {
            let existingMovies = try await supabaseService.getMoviesByTmdbId(tmdbId: tmdbId)
            
            await MainActor.run {
                // Store all previous watches
                previousWatches = existingMovies.sorted { 
                    ($0.watch_date ?? "") > ($1.watch_date ?? "") 
                }
                
                // If we have previous watches, prefill with the latest entry
                if let latestMovie = existingMovies.first {
                    // Prefill ratings
                    if let rating = latestMovie.rating {
                        starRating = rating
                    }
                    
                    if let detailedRating = latestMovie.detailed_rating {
                        self.detailedRating = String(Int(detailedRating))
                    }
                    
                    // Set as rewatch since they've seen it before
                    isRewatch = true
                }
            }
        } catch {
            // Silently fail - if we can't check for existing movies, just continue normally
            await MainActor.run {
                previousWatches = []
            }
        }
    }
    
    private func checkForMovieLists(tmdbId: Int) async {
        await MainActor.run {
            let listsContainingMovie = dataManager.getListsContainingMovie(tmdbId: tmdbId)
            movieLists = listsContainingMovie
        }
    }
    
    private func loadMovieDetails(movieId: Int) {
        isLoadingDetails = true
        
        Task {
            do {
                let (details, directorName) = try await tmdbService.getCompleteMovieData(movieId: movieId)
                await MainActor.run {
                    movieDetails = details
                    director = directorName
                    isLoadingDetails = false
                }
            } catch {
                await MainActor.run {
                    isLoadingDetails = false
                    alertMessage = "Failed to load movie details: \(error.localizedDescription)"
                    showingAlert = true
                }
            }
        }
    }
    
    private func checkSimilarRatings(rating: Double) {
        Task {
            do {
                // Use decade-based ranges (100-90, 89-80, 79-70, etc.)
                let (minRating, maxRating) = getDecadeRange(for: rating)
                let movies = try await supabaseService.getMoviesInRatingRange(
                    minRating: minRating,
                    maxRating: maxRating,
                    limit: 3000  // Get more movies for pagination
                )

                // Deduplicate by movie identity (tmdb_id or title) AND detailed rating, keeping latest entry
                let deduplicatedMovies = deduplicateMoviesByIdentityAndDetailedRating(movies)

                // Sort movies by rating in descending order (highest first) and then by latest watch/created date
                let sortedMovies = deduplicatedMovies.sorted {
                    let lhsRating = Int($0.detailed_rating ?? -1)
                    let rhsRating = Int($1.detailed_rating ?? -1)
                    if lhsRating != rhsRating { return lhsRating > rhsRating }

                    let lhsDate = comparableDate(for: $0) ?? Date.distantPast
                    let rhsDate = comparableDate(for: $1) ?? Date.distantPast
                    return lhsDate > rhsDate
                }

                await MainActor.run {
                    similarRatingMovies = sortedMovies
                    displayedMoviesCount = 5  // Reset to show first 5
                    showingSimilarRatings = !sortedMovies.isEmpty
                }
            } catch {
                // Silently fail for similar ratings feature
                await MainActor.run {
                    showingSimilarRatings = false
                    similarRatingMovies = []
                    displayedMoviesCount = 5
                }
            }
        }
    }

    // MARK: - Deduplication Helpers
    private func deduplicateMoviesByIdentityAndDetailedRating(_ movies: [Movie]) -> [Movie] {
        // Group key combines movie identity (tmdb_id or normalized title) and integer detailed rating
        var keyToLatestMovie: [String: Movie] = [:]

        for movie in movies {
            guard let detailedRating = movie.detailed_rating else { continue }
            let ratingKey = String(Int(detailedRating))
            let identity = movieIdentityKey(movie)
            let groupKey = identity + "|" + ratingKey

            if let existing = keyToLatestMovie[groupKey] {
                // Keep the latest by comparable date
                let existingDate = comparableDate(for: existing) ?? Date.distantPast
                let candidateDate = comparableDate(for: movie) ?? Date.distantPast
                if candidateDate > existingDate {
                    keyToLatestMovie[groupKey] = movie
                }
            } else {
                keyToLatestMovie[groupKey] = movie
            }
        }

        return Array(keyToLatestMovie.values)
    }

    private func movieIdentityKey(_ movie: Movie) -> String {
        if let tmdbId = movie.tmdb_id {
            return "tmdb:" + String(tmdbId)
        }
        // Fallback to normalized title if tmdb_id is missing
        let normalizedTitle = movie.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return "title:" + normalizedTitle
    }

    private func comparableDate(for movie: Movie) -> Date? {
        // Prefer watch_date (logical chronology). Fallback to updated_at then created_at
        if let watchDateString = movie.watch_date, let watchDate = parseDate("yyyy-MM-dd", from: watchDateString) {
            return watchDate
        }
        if let updatedAtString = movie.updated_at, let updatedAt = parseISO8601Date(from: updatedAtString) {
            return updatedAt
        }
        if let createdAtString = movie.created_at, let createdAt = parseISO8601Date(from: createdAtString) {
            return createdAt
        }
        return nil
    }

    private func parseDate(_ format: String, from string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = format
        return formatter.date(from: string)
    }

    private func parseISO8601Date(from string: String) -> Date? {
        // Try strict ISO8601 first
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: string) { return d }

        // Try without fractional seconds
        iso.formatOptions = [.withInternetDateTime]
        if let d2 = iso.date(from: string) { return d2 }

        // Fallback: attempt a common Postgrest format without timezone
        if let d3 = parseDate("yyyy-MM-dd'T'HH:mm:ss", from: string) { return d3 }
        // Fallback: date only
        if let d4 = parseDate("yyyy-MM-dd", from: string) { return d4 }
        return nil
    }
    
    private func getDecadeRange(for rating: Double) -> (min: Double, max: Double) {
        let intRating = Int(rating)
        
        // Determine which decade range the rating falls into
        switch intRating {
        case 90...100:
            return (90, 100)
        case 80...89:
            return (80, 89)
        case 70...79:
            return (70, 79)
        case 60...69:
            return (60, 69)
        case 50...59:
            return (50, 59)
        case 40...49:
            return (40, 49)
        case 30...39:
            return (30, 39)
        case 20...29:
            return (20, 29)
        case 10...19:
            return (10, 19)
        default: // 0-9
            return (0, 9)
        }
    }
    
    private func addMovie() async {
        guard let selectedMovie = selectedMovie else { return }
        
        isAddingMovie = true
        
        do {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            
            let genres = movieDetails?.genreNames ?? []
            
            let movieRequest = AddMovieRequest(
                title: selectedMovie.title,
                release_year: selectedMovie.releaseYear,
                release_date: selectedMovie.releaseDate,
                rating: starRating > 0 ? starRating : nil,
                ratings100: Double(detailedRating),
                reviews: review.isEmpty ? nil : review,
                tags: tags.isEmpty ? nil : tags,
                watched_date: formatter.string(from: watchDate),
                rewatch: isRewatch ? "yes" : "no",
                tmdb_id: selectedMovie.id,
                overview: selectedMovie.overview,
                poster_url: selectedMovie.fullPosterURL,
                backdrop_path: selectedMovie.backdropPath,
                director: director,
                runtime: movieDetails?.runtime,
                vote_average: selectedMovie.voteAverage,
                vote_count: selectedMovie.voteCount,
                popularity: selectedMovie.popularity,
                original_language: selectedMovie.originalLanguage,
                original_title: selectedMovie.originalTitle,
                tagline: movieDetails?.tagline,
                status: movieDetails?.status,
                budget: movieDetails?.budget,
                revenue: movieDetails?.revenue,
                imdb_id: movieDetails?.imdbId,
                homepage: movieDetails?.homepage,
                genres: genres
            )
            
            let addedMovie = try await supabaseService.addMovie(movieRequest)
            
            // Set favorite status if selected
            if isFavorited {
                let _ = try await supabaseService.setMovieFavorite(movieId: addedMovie.id, isFavorite: true)
            }
            
            // Copy review to clipboard if it exists
            if !review.isEmpty {
                await MainActor.run {
                    UIPasteboard.general.string = review
                }
            }
            
            await MainActor.run {
                isAddingMovie = false
                dismiss()
            }
            
        } catch {
            await MainActor.run {
                isAddingMovie = false
                alertMessage = "Failed to add movie: \(error.localizedDescription)"
                showingAlert = true
            }
        }
    }
    
    private func resetForm() {
        starRating = 0.0
        detailedRating = ""
        review = ""
        tags = ""
        watchDate = Date()
        isRewatch = false
        isFavorited = false
        showingSimilarRatings = false
        similarRatingMovies = []
        displayedMoviesCount = 5
        previousWatches = []
        showingPreviousWatches = false
        ratingSearchText = ""
        movieLists = []
        showingMovieLists = false
    }
    
    // MARK: - Watchlist Operations
    private func addToWatchlist(_ movie: TMDBMovie) async {
        guard !isAddingToWatchlist else { return }
        
        isAddingToWatchlist = true
        
        do {
            try await watchlistService.upsertItem(
                tmdbId: movie.id,
                title: movie.title,
                posterUrl: movie.posterURL?.absoluteString,
                backdropPath: movie.backdropPath,
                year: movie.releaseYear,
                releaseDate: movie.releaseDate
            )
            
            await dataManager.refreshWatchlist()
            
            await MainActor.run {
                watchlistSuccessMessage = "\(movie.title) added to your watchlist!"
                showingWatchlistSuccess = true
                isAddingToWatchlist = false
            }
        } catch {
            await MainActor.run {
                alertMessage = "Failed to add \(movie.title) to watchlist: \(error.localizedDescription)"
                showingAlert = true
                isAddingToWatchlist = false
            }
        }
    }
}


// MARK: - Search Result Row
struct SearchResultRow: View {
    let movie: TMDBMovie
    let onLog: () -> Void
    let onAddToWatchlist: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Movie poster
            AsyncImage(url: movie.posterURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.gray)
                    )
            }
            .frame(width: 60, height: 90)
            .cornerRadius(8)
            .clipped()
            
            // Movie details
            VStack(alignment: .leading, spacing: 4) {
                Text(movie.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .lineLimit(2)
                
                if let year = movie.releaseYear {
                    Text(String(year))
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                if let overview = movie.overview, !overview.isEmpty {
                    Text(overview)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            // Action buttons
            VStack(spacing: 8) {
                Button(action: onLog) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16))
                        Text("Log")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.blue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(16)
                }
                
                Button(action: onAddToWatchlist) {
                    HStack(spacing: 4) {
                        Image(systemName: "bookmark.circle.fill")
                            .font(.system(size: 16))
                        Text("Watchlist")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.orange)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.2))
                    .cornerRadius(16)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.15))
        .cornerRadius(12)
    }
}

// MARK: - Comparison Movie Row
struct ComparisonMovieRow: View {
    let movie: Movie
    
    var body: some View {
        HStack(spacing: 12) {
            // Movie poster
            WebImage(url: movie.posterURL)
                .resizable()
                .aspectRatio(2/3, contentMode: .fill)
                .frame(width: 40, height: 60)
                .cornerRadius(6)
            
            // Movie details
            VStack(alignment: .leading, spacing: 2) {
                Text(movie.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                Text(movie.formattedReleaseYear)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // Star rating
                HStack(spacing: 2) {
                    ForEach(0..<5) { index in
                        Image(systemName: starType(for: index, rating: movie.rating))
                            .foregroundColor(starColor(for: movie.rating))
                            .font(.system(size: 10, weight: .regular))
                    }
                }
            }
            
            Spacer()
            
            // Numerical rating
            if let detailedRating = movie.detailed_rating {
                Text(String(format: "%.0f", detailedRating))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.purple)
                    .frame(minWidth: 25)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
    
    private func starType(for index: Int, rating: Double?) -> String {
        guard let rating = rating else { return "star" }
        
        if rating >= Double(index + 1) {
            return "star.fill"
        } else if rating >= Double(index) + 0.5 {
            return "star.leadinghalf.filled"
        } else {
            return "star"
        }
    }
    
    private func starColor(for rating: Double?) -> Color {
        guard let rating = rating else { return .blue }
        return rating == 5.0 ? .yellow : .blue
    }
}

// MARK: - Previous Entry Row
struct PreviousEntryRow: View {
    let movie: Movie
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Entry indicator
                Text("RE")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(width: 30, height: 20)
                    .background(Color.orange)
                    .cornerRadius(6)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(formattedWatchDate)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                    
                    HStack(spacing: 8) {
                        // Star rating
                        HStack(spacing: 2) {
                            ForEach(0..<5) { index in
                                Image(systemName: starType(for: index, rating: movie.rating))
                                    .foregroundColor(starColor(for: movie.rating))
                                    .font(.system(size: 12))
                            }
                        }
                        
                        if let rating = movie.rating {
                            Text("(\(String(format: "%.1f", rating)))")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        // Detailed rating
                        if let detailedRating = movie.detailed_rating {
                            HStack(spacing: 2) {
                                Image(systemName: "chart.bar.fill")
                                    .foregroundColor(.purple)
                                    .font(.system(size: 10))
                                
                                Text("\(String(format: "%.0f", detailedRating))/100")
                                    .font(.caption)
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    
                    // Show review if it exists
                    if let review = movie.review, !review.isEmpty {
                        Text("Review: \(review)")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .lineLimit(2)
                            .padding(.top, 2)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12))
            }
            .padding(12)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var formattedWatchDate: String {
        guard let watchDate = movie.watch_date else { return "Unknown Date" }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: watchDate) else { return "Unknown Date" }
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "MMM d, yyyy"
        return displayFormatter.string(from: date)
    }
    
    private func starType(for index: Int, rating: Double?) -> String {
        guard let rating = rating else { return "star" }
        
        if rating >= Double(index + 1) {
            return "star.fill"
        } else if rating >= Double(index) + 0.5 {
            return "star.leadinghalf.filled"
        } else {
            return "star"
        }
    }
    
    private func starColor(for rating: Double?) -> Color {
        guard let rating = rating else { return .blue }
        return rating == 5.0 ? .yellow : .blue
    }
}

// MARK: - Movie List Row
struct MovieListRow: View {
    let list: MovieList
    
    var body: some View {
        HStack(spacing: 12) {
            // List indicator
            Image(systemName: listIcon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(listColor)
                .frame(width: 24, height: 24)
                .background(listColor.opacity(0.2))
                .cornerRadius(6)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(list.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                if let description = list.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            if list.itemCount > 0 {
                Text("\(list.itemCount) \(list.itemCount == 1 ? "item" : "items")")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(12)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var listIcon: String {
        if list.name == "Watchlist" {
            return "bookmark.fill"
        } else if list.ranked {
            return "list.number"
        } else {
            return "list.bullet"
        }
    }
    
    private var listColor: Color {
        if list.name == "Watchlist" {
            return .orange
        } else if list.ranked {
            return .purple
        } else {
            return .blue
        }
    }
}

// MARK: - Preview
#Preview {
    AddMoviesView()
}
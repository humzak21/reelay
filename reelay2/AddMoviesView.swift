//
//  AddMoviesView.swift
//  reelay2
//
//  Created by Claude on 8/1/25.
//

import SwiftUI
import SDWebImageSwiftUI

struct AddMoviesView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var tmdbService = TMDBService.shared
    @StateObject private var supabaseService = SupabaseMovieService.shared
    
    // Search state
    @State private var searchText = ""
    @State private var searchResults: [TMDBMovie] = []
    @State private var isSearching = false
    @State private var selectedMovie: TMDBMovie?
    @State private var searchTask: Task<Void, Never>?
    
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
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if selectedMovie == nil {
                    searchView
                } else {
                    addMovieView
                }
            }
            .navigationTitle("Add Movie")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color.black)
            .preferredColorScheme(.dark)
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
            .sheet(isPresented: $showingMovieDetails) {
                if let selectedMovie = selectedPreviousMovie {
                    MovieDetailsView(movie: selectedMovie)
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
        .background(Color.black)
        .preferredColorScheme(.dark)
    }
    
    private var searchResultsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(searchResults) { movie in
                    SearchResultRow(movie: movie) {
                        selectMovie(movie)
                    }
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
                
                // Previous entries section
                if !previousWatches.isEmpty {
                    previousEntriesSection
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
        
        // Check if this movie has been watched before
        Task {
            await checkForExistingMovie(tmdbId: movie.id)
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
            print("Failed to check for existing movie: \(error)")
            await MainActor.run {
                previousWatches = []
            }
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
                    limit: 1000  // Get more movies for pagination
                )
                
                // Sort movies by rating in descending order (highest first)
                let sortedMovies = movies.sorted { ($0.detailed_rating ?? 0) > ($1.detailed_rating ?? 0) }
                
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
                poster_url: selectedMovie.posterPath,
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
            
            let _ = try await supabaseService.addMovie(movieRequest)
            
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
        showingSimilarRatings = false
        similarRatingMovies = []
        displayedMoviesCount = 5
        previousWatches = []
        showingPreviousWatches = false
        ratingSearchText = ""
    }
}


// MARK: - Search Result Row
struct SearchResultRow: View {
    let movie: TMDBMovie
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Movie poster
                AsyncImage(url: movie.posterURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
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
                            .lineLimit(3)
                    }
                }
                
                Spacer()
                
                // Chevron
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
            .padding()
            .background(Color.gray.opacity(0.15))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
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

// MARK: - Preview
#Preview {
    AddMoviesView()
}
//
//  MovieDetailsView.swift
//  reelay2
//
//  Created by Humza Khalil on 7/31/25.
//

import SwiftUI
import SDWebImageSwiftUI

struct MovieDetailsView: View {
    let movie: Movie
    @Environment(\.dismiss) private var dismiss
    @StateObject private var movieService = SupabaseMovieService.shared
    @State private var previousWatches: [Movie] = []
    @State private var showingPreviousWatches = false
    @State private var isEditingReview = false
    @State private var editedReview = ""
    @State private var isSavingReview = false
    @State private var currentMovie: Movie
    @State private var showingEditMovie = false
    @State private var showingDeleteAlert = false
    @State private var isDeletingMovie = false
    @State private var isReviewCopied = false
    @State private var selectedPreviousMovie: Movie?
    @State private var showingPreviousMovieDetails = false
    @State private var showingAddMovie = false
    
    init(movie: Movie) {
        self.movie = movie
        self._currentMovie = State(initialValue: movie)
    }
    
    private var isUnloggedMovie: Bool {
        currentMovie.id == -1
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 0) {
                    // Backdrop Section
                    backdropSection
                    
                    // Watch Date Section (only show for logged movies)
                    if !isUnloggedMovie {
                        watchDateSection
                    }
                    
                    // Main Content
                    VStack(spacing: 16) {
                        if isUnloggedMovie {
                            // Unlogged movie state
                            unloggedMovieView
                        } else {
                            // Logged movie state
                            // Movie Header Section
                            movieHeaderSection
                            
                            // Rating Cards
                            ratingCardsSection
                            
                            // Previously Watched Section
                            if !previousWatches.isEmpty {
                                previouslyWatchedSection
                            }
                            
                            // Review Section
                            reviewSection
                            
                            // Tags Section
                            if hasVisibleTags {
                                tagsSection
                            }
                            
                            // Movie Metadata
                            metadataSection
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(Color.black)
                    
                    Spacer(minLength: 100)
                }
            }
            .background(Color.black.ignoresSafeArea())
            .ignoresSafeArea(edges: .top)
            .navigationTitle("Movie Details")
            .navigationBarTitleDisplayMode(.inline)
            .preferredColorScheme(.dark)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Edit Movie", systemImage: "pencil") {
                            showingEditMovie = true
                        }
                        Button("Delete Movie", systemImage: "trash", role: .destructive) {
                            showingDeleteAlert = true
                        }
                        Button("Share", systemImage: "square.and.arrow.up") {
                            // Share action - to be implemented later
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                }
            }
        }
        .task {
            await loadPreviousWatches()
        }
        .sheet(isPresented: $isEditingReview) {
            EditReviewSheet(
                review: editedReview,
                movieTitle: currentMovie.title,
                onSave: { newReview in
                    await saveReview(newReview)
                },
                onCancel: {
                    isEditingReview = false
                }
            )
        }
        .sheet(isPresented: $showingEditMovie) {
            EditMovieView(movie: currentMovie) { updatedMovie in
                currentMovie = updatedMovie
                // Reload previous watches in case the edit affected them
                Task {
                    await loadPreviousWatches()
                }
            }
        }
        .alert("Delete Movie", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    await deleteMovie()
                }
            }
        } message: {
            Text("Are you sure you want to delete '\(currentMovie.title)'? This action cannot be undone.")
        }
        .sheet(isPresented: $showingPreviousMovieDetails) {
            if let selectedMovie = selectedPreviousMovie {
                MovieDetailsView(movie: selectedMovie)
            }
        }
        .sheet(isPresented: $showingAddMovie) {
            if isUnloggedMovie, let tmdbId = currentMovie.tmdb_id {
                AddMovieFromListView(
                    tmdbId: tmdbId,
                    title: currentMovie.title,
                    releaseYear: currentMovie.release_year,
                    posterUrl: currentMovie.poster_url,
                    backdropUrl: currentMovie.backdrop_path
                )
            } else {
                AddMoviesView()
            }
        }
    }
    
    private var unloggedMovieView: some View {
        VStack(spacing: 24) {
            // Movie Header Section (simplified for unlogged)
            HStack(alignment: .top, spacing: 20) {
                // Movie Poster
                AsyncImage(url: currentMovie.posterURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                }
                .frame(width: 100, height: 150)
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                
                // Movie Details
                VStack(alignment: .leading, spacing: 6) {
                    Text(currentMovie.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                    
                    Text(currentMovie.formattedReleaseYear)
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.8))
                        .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
                }
                
                Spacer()
            }
            
            // Unlogged state message
            VStack(spacing: 16) {
                Image(systemName: "film.stack")
                    .font(.system(size: 64))
                    .foregroundColor(.gray)
                
                Text("You haven't logged this film yet")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text("Add this movie to your diary to track your ratings, reviews, and watch history.")
                    .font(.body)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                
                Button("Add Movie") {
                    showingAddMovie = true
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.top, 8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
        }
    }
    
    private var backdropSection: some View {
        AsyncImage(url: currentMovie.backdropURL) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            case .failure(_):
                // Fallback to poster if backdrop fails
                AsyncImage(url: currentMovie.posterURL) { posterPhase in
                    switch posterPhase {
                    case .success(let posterImage):
                        posterImage
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure(_), .empty:
                        // Final fallback to solid color
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.gray.opacity(0.4), Color.gray.opacity(0.8)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    @unknown default:
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                    }
                }
            case .empty:
                // Loading state
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
            @unknown default:
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
            }
        }
        .frame(height: 300)
        .clipped()
        .overlay(
            // Enhanced gradient overlay for recessed appearance
            LinearGradient(
                colors: [
                    Color.black.opacity(0.1), 
                    Color.black.opacity(0.3),
                    Color.black.opacity(0.6),
                    Color.black.opacity(0.9)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    private var watchDateSection: some View {
        VStack(spacing: 8) {
            Text("WATCHED")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white.opacity(0.7))
                .textCase(.uppercase)
                .tracking(1.2)
            
            Text(formattedWatchDate)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
        }
        .padding(.top, 20)
        .padding(.bottom, 4)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.8), Color.black],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    private var movieHeaderSection: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 20) {
                // Movie Poster
                AsyncImage(url: currentMovie.posterURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                }
                .frame(width: 100, height: 150)
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                
                // Movie Details
                VStack(alignment: .leading, spacing: 6) {
                    Text(currentMovie.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                    
                    Text(currentMovie.formattedReleaseYear)
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.8))
                        .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
                    
                    if let director = currentMovie.director {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("DIRECTOR")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.white.opacity(0.7))
                                .textCase(.uppercase)
                                .tracking(1)
                                .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
                            
                            Text(director)
                                .font(.body)
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text("RUNTIME")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white.opacity(0.7))
                            .textCase(.uppercase)
                            .tracking(1)
                            .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
                        
                        Text(currentMovie.formattedRuntime)
                            .font(.body)
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
                    }
                    
                    // Rewatch Button
                    if currentMovie.isRewatchMovie {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 14, weight: .medium))
                            Text("REWATCH")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .tracking(1)
                        }
                        .foregroundColor(.orange)
                        .padding(.top, 2)
                    }
                }
                
                Spacer()
            }
        }
    }
    
    private var ratingCardsSection: some View {
        HStack(spacing: 15) {
            // Star Rating Card
            VStack(spacing: 10) {
                Text("STAR RATING")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.gray)
                    .textCase(.uppercase)
                    .tracking(0.5)
                
                HStack(spacing: 3) {
                    ForEach(0..<5) { index in
                        Image(systemName: starType(for: index, rating: currentMovie.rating))
                            .foregroundColor(starColor(for: currentMovie.rating))
                            .font(.system(size: 18, weight: .regular))
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 80)
            .padding(.vertical, 25)
            .glassEffect(in: .rect(cornerRadius: 24.0))
            
            // Numerical Rating Card
            VStack(spacing: 10) {
                Text("RATING / 100")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.gray)
                    .textCase(.uppercase)
                    .tracking(0.5)
                
                Text(currentMovie.formattedDetailedRating)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(detailedRatingColor(for: currentMovie.detailed_rating))
            }
            .frame(maxWidth: .infinity, minHeight: 80)
            .padding(.vertical, 25)
            .glassEffect(in: .rect(cornerRadius: 24.0))
        }
    }
    
    private var previouslyWatchedSection: some View {
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
                        
                        Text("Previously Watched")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        
                        Text("\(previousWatches.count) previous entry found")
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
                        PreviousWatchRow(movie: previousWatch) {
                            selectedPreviousMovie = previousWatch
                            showingPreviousMovieDetails = true
                        }
                    }
                }
                .padding(.top, 12)
            }
        }
    }
    
    private var reviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("REVIEW")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.gray)
                    .textCase(.uppercase)
                    .tracking(0.5)
                
                Spacer()
                
                Button(action: {
                    editedReview = currentMovie.review ?? ""
                    isEditingReview = true
                }) {
                    Image(systemName: "pencil")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.blue)
                }
            }
            
            Text(currentMovie.review ?? "No review yet")
                .font(.body)
                .foregroundColor(currentMovie.review != nil ? .white : .gray)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .glassEffect(in: .rect(cornerRadius: 24.0))
        .overlay(
            RoundedRectangle(cornerRadius: 24.0)
                .stroke(Color.blue.opacity(isReviewCopied ? 0.8 : 0), lineWidth: 2)
                .animation(.easeInOut(duration: 0.3), value: isReviewCopied)
        )
        .scaleEffect(isReviewCopied ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isReviewCopied)
        .onTapGesture {
            copyReviewToClipboard()
        }
        .opacity(isReviewCopied ? 0.9 : 1.0)
    }
    
    private var hasVisibleTags: Bool {
        guard let tags = currentMovie.tags, !tags.isEmpty else { return false }
        return !parsedTags.isEmpty
    }
    
    private var parsedTags: [String] {
        guard let tags = currentMovie.tags, !tags.isEmpty else { return [] }
        return tags.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
    
    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("TAGS")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.gray)
                    .textCase(.uppercase)
                    .tracking(0.5)
                
                Spacer()
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 12) {
                ForEach(parsedTags, id: \.self) { tag in
                    TagView(tag: tag)
                }
            }
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .glassEffect(in: .rect(cornerRadius: 24.0))
    }
    
    private var metadataSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Release Date")
                    .font(.body)
                    .foregroundColor(.gray)
                
                Spacer()
                
                Text(formattedReleaseDate)
                    .font(.body)
                    .foregroundColor(.white)
            }
            
            HStack {
                Text("TMDB")
                    .font(.body)
                    .foregroundColor(.gray)
                
                Spacer()
                
                Button("View on TMDB") {
                    if let tmdbId = currentMovie.tmdb_id {
                        if let url = URL(string: "https://www.themoviedb.org/movie/\(tmdbId)") {
                            UIApplication.shared.open(url)
                        }
                    }
                }
                .font(.body)
                .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .glassEffect(in: .rect(cornerRadius: 24.0))
    }
    
    private var formattedWatchDate: String {
        guard let watchDate = currentMovie.watch_date else { return "Unknown Date" }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: watchDate) else { return "Unknown Date" }
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "EEEE, MMMM d, yyyy"
        return displayFormatter.string(from: date)
    }
    
    private var formattedReleaseDate: String {
        guard let releaseDate = currentMovie.release_date else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: releaseDate) else { return releaseDate }
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "MMMM d, yyyy"
        return displayFormatter.string(from: date)
    }
    
    private func starType(for index: Int, rating: Double?) -> String {
        guard let rating = rating else { return "star" }
        
        let adjustedRating = rating
        
        if adjustedRating >= Double(index + 1) {
            return "star.fill"
        } else if adjustedRating >= Double(index) + 0.5 {
            return "star.leadinghalf.filled"
        } else {
            return "star"
        }
    }
    
    private func starColor(for rating: Double?) -> Color {
        guard let rating = rating else { return .blue }
        return rating == 5.0 ? .yellow : .blue
    }
    
    private func detailedRatingColor(for rating: Double?) -> Color {
        guard let rating = rating else { return .purple }
        return rating == 100.0 ? .yellow : .purple
    }
    
    private func loadPreviousWatches() async {
        guard let tmdbId = currentMovie.tmdb_id else { return }
        
        do {
            // Fetch all movies with the same TMDB ID
            let allWatches = try await movieService.getMoviesByTmdbId(tmdbId: tmdbId)
            
            // Filter out the current movie to show only previous watches
            let filteredWatches = allWatches.filter { otherMovie in
                otherMovie.id != currentMovie.id
            }
            
            await MainActor.run {
                previousWatches = filteredWatches
            }
            
        } catch {
            print("Failed to load previous watches: \(error)")
            await MainActor.run {
                previousWatches = []
            }
        }
    }
    
    private func saveReview(_ newReview: String) async {
        isSavingReview = true
        
        do {
            let updateRequest = UpdateMovieRequest(
                title: nil,
                release_year: nil,
                release_date: nil,
                rating: nil,
                ratings100: nil,
                reviews: newReview.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : newReview,
                tags: nil,
                watched_date: nil,
                rewatch: nil,
                tmdb_id: nil,
                overview: nil,
                poster_url: nil,
                backdrop_path: nil,
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
                genres: nil
            )
            
            let updatedMovie = try await movieService.updateMovie(id: currentMovie.id, with: updateRequest)
            
            // Update the current movie state and close the editing sheet
            await MainActor.run {
                currentMovie = updatedMovie
                isEditingReview = false
            }
            
        } catch {
            print("Failed to update review: \(error)")
            // You might want to show an alert here
        }
        
        isSavingReview = false
    }
    
    private func deleteMovie() async {
        isDeletingMovie = true
        
        do {
            try await movieService.deleteMovie(id: currentMovie.id)
            
            // Close the view after successful deletion
            await MainActor.run {
                dismiss()
            }
            
        } catch {
            print("Failed to delete movie: \(error)")
            // You might want to show an error alert here
        }
        
        isDeletingMovie = false
    }
    
    private func copyReviewToClipboard() {
        guard let review = currentMovie.review, !review.isEmpty else { return }
        
        UIPasteboard.general.string = review
        
        // Trigger the animation
        withAnimation(.easeInOut(duration: 0.2)) {
            isReviewCopied = true
        }
        
        // Reset the animation after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.easeInOut(duration: 0.2)) {
                isReviewCopied = false
            }
        }
    }
}

struct EditReviewSheet: View {
    @State private var reviewText: String
    let movieTitle: String
    let onSave: (String) async -> Void
    let onCancel: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var isSaving = false
    
    init(review: String, movieTitle: String, onSave: @escaping (String) async -> Void, onCancel: @escaping () -> Void) {
        self._reviewText = State(initialValue: review)
        self.movieTitle = movieTitle
        self.onSave = onSave
        self.onCancel = onCancel
    }
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Edit Review")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("for \(movieTitle)")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding(.horizontal)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Review")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    TextEditor(text: $reviewText)
                        .font(.body)
                        .foregroundColor(.white)
                        .scrollContentBackground(.hidden)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(12)
                        .frame(minHeight: 200)
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .padding(.top)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", systemImage: "xmark") {
                        onCancel()
                    }
                    .foregroundColor(.blue)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save", systemImage: "checkmark") {
                        Task {
                            isSaving = true
                            await onSave(reviewText)
                            isSaving = false
                            dismiss()
                        }
                    }
                    .foregroundColor(.blue)
                    .disabled(isSaving)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct PreviousWatchRow: View {
    let movie: Movie
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Rewatch indicator
                Text("RE")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(width: 24, height: 24)
                    .background(Color.orange)
                    .clipShape(Circle())
                
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
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12))
            }
            .padding(12)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(24)
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
        
        let adjustedRating = rating
        
        if adjustedRating >= Double(index + 1) {
            return "star.fill"
        } else if adjustedRating >= Double(index) + 0.5 {
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

struct TagView: View {
    let tag: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconForTag(tag))
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(colorForTag(tag))
            
            Text(tag.uppercased())
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .tracking(0.5)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorForTag(tag).opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(colorForTag(tag).opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private func iconForTag(_ tag: String) -> String {
        switch tag.lowercased() {
        case "imax":
            return "film"
        case "theater":
            return "popcorn"
        case "family":
            return "person.3.fill"
        case "theboys":
            return "person.2.fill"
        case "airplane":
            return "airplane"
        case "train":
            return "train.side.front.car"
        case "short":
            return "movieclapper.fill"
        default:
            return "tag.fill"
        }
    }
    
    private func colorForTag(_ tag: String) -> Color {
        switch tag.lowercased() {
        case "imax":
            return .red
        case "theater":
            return .purple
        case "family":
            return .yellow
        case "theboys":
            return .green
        case "airplane":
            return .orange
        case "train":
            return .cyan
        case "short":
            return .pink
        default:
            return .blue
        }
    }
}

// MARK: - Add Movie From List View
struct AddMovieFromListView: View {
    let tmdbId: Int
    let title: String
    let releaseYear: Int?
    let posterUrl: String?
    let backdropUrl: String?
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var tmdbService = TMDBService.shared
    @StateObject private var supabaseService = SupabaseMovieService.shared
    
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
    @State private var isAddingMovie = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    movieHeader
                    watchDateSection
                    ratingSection
                    detailedRatingSection
                    rewatchSection
                    reviewSection
                    tagsSection
                    
                    Spacer(minLength: 100)
                }
                .padding()
            }
            .background(Color.black)
            .preferredColorScheme(.dark)
            .navigationTitle("Add Movie")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", systemImage: "xmark") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add", systemImage: "checkmark") {
                        Task {
                            await addMovie()
                        }
                    }
                    .disabled(isAddingMovie)
                    .foregroundColor(.white)
                }
            }
            .onAppear {
                loadMovieDetails()
            }
            .alert("Error", isPresented: $showingAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    // MARK: - Movie Header
    private var movieHeader: some View {
        HStack(alignment: .top, spacing: 15) {
            AsyncImage(url: URL(string: posterUrl ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(2/3, contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
            }
            .frame(width: 120, height: 180)
            .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                if let year = releaseYear {
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
                
                if let overview = movieDetails?.overview {
                    Text(overview)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(4)
                }
            }
            
            Spacer()
        }
    }
    
    // MARK: - Rating Section
    private var ratingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Star Rating")
                .font(.headline)
                .foregroundColor(.white)
            
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
                .foregroundColor(.white)
            
            TextField("Enter rating 0-100", text: $detailedRating)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(.numberPad)
                .onChange(of: detailedRating) { oldValue, newValue in
                    let filtered = newValue.filter { $0.isNumber }
                    if filtered != newValue {
                        detailedRating = filtered
                    }
                }
        }
    }
    
    // MARK: - Review Section
    private var reviewSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Review")
                .font(.headline)
                .foregroundColor(.white)
            
            TextField("Write your review...", text: $review, axis: .vertical)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .lineLimit(5...10)
        }
    }
    
    // MARK: - Tags Section
    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Tags")
                .font(.headline)
                .foregroundColor(.white)
            
            TextField("e.g., theater, family, IMAX", text: $tags)
                .textFieldStyle(RoundedBorderTextFieldStyle())
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
                .foregroundColor(.white)
            
            DatePicker("When did you watch this?", selection: $watchDate, displayedComponents: .date)
                .datePickerStyle(CompactDatePickerStyle())
        }
    }
    
    // MARK: - Rewatch Section
    private var rewatchSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Rewatch")
                .font(.headline)
                .foregroundColor(.white)
            
            Toggle("This was a rewatch", isOn: $isRewatch)
        }
    }
    
    // MARK: - Helper Methods
    private func loadMovieDetails() {
        isLoadingDetails = true
        
        Task {
            do {
                let (details, directorName) = try await tmdbService.getCompleteMovieData(movieId: tmdbId)
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
    
    private func addMovie() async {
        isAddingMovie = true
        
        do {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            
            let genres = movieDetails?.genreNames ?? []
            
            let movieRequest = AddMovieRequest(
                title: title,
                release_year: releaseYear,
                release_date: movieDetails?.releaseDate,
                rating: starRating > 0 ? starRating : nil,
                ratings100: Double(detailedRating),
                reviews: review.isEmpty ? nil : review,
                tags: tags.isEmpty ? nil : tags,
                watched_date: formatter.string(from: watchDate),
                rewatch: isRewatch ? "yes" : "no",
                tmdb_id: tmdbId,
                overview: movieDetails?.overview,
                poster_url: posterUrl,
                backdrop_path: backdropUrl,
                director: director,
                runtime: movieDetails?.runtime,
                vote_average: movieDetails?.voteAverage,
                vote_count: movieDetails?.voteCount,
                popularity: movieDetails?.popularity,
                original_language: movieDetails?.originalLanguage,
                original_title: movieDetails?.originalTitle,
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
}

#Preview {
    MovieDetailsView(movie: Movie(
        id: 1,
        title: "Harry Potter and the Deathly Hallows: Part 1",
        release_year: 2010,
        release_date: "2010-11-17",
        rating: 4.5,
        detailed_rating: 82,
        review: "Moves at a blazing pace. Wish they added another 30 minutes in each film. If these were made 10 years later they definitely would've.",
        tags: "IMAX, Theater, Family",
        watch_date: "2025-07-18",
        is_rewatch: false,
        tmdb_id: 12444,
        overview: nil,
        poster_url: nil,
        backdrop_path: nil,
        director: "David Yates",
        runtime: 146,
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
        updated_at: nil
    ))
}

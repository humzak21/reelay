//
//  EditMovieView.swift
//  reelay2
//
//  Created by Humza Khalil on 8/1/25.
//

import SwiftUI
import SDWebImageSwiftUI

struct EditMovieView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var supabaseService = SupabaseMovieService.shared
    
    let movie: Movie
    let onSave: (Movie) -> Void
    
    // User input state
    @State private var starRating: Double = 0.0
    @State private var detailedRating: String = ""
    @State private var review: String = ""
    @State private var tags: String = ""
    @State private var watchDate = Date()
    @State private var isRewatch = false
    
    // UI state
    @State private var isUpdatingMovie = false
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
            .navigationTitle("Edit Movie")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", systemImage: "xmark") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save", systemImage: "checkmark") {
                        Task {
                            await updateMovie()
                        }
                    }
                    .disabled(isUpdatingMovie)
                }
            }
            .alert("Error", isPresented: $showingAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
        }
        .onAppear {
            setupInitialValues()
        }
    }
    
    // MARK: - Movie Header
    private var movieHeader: some View {
        VStack(alignment: .leading, spacing: 15) {
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
                    
                    if let year = movie.release_year {
                        Text(String(year))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    if let director = movie.director {
                        Text("Directed by \(director)")
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
    private func setupInitialValues() {
        // Set initial values from the movie
        starRating = movie.rating ?? 0.0
        detailedRating = movie.detailed_rating != nil ? String(Int(movie.detailed_rating!)) : ""
        review = movie.review ?? ""
        tags = movie.tags ?? ""
        isRewatch = movie.is_rewatch ?? false
        
        // Set watch date
        if let watchDateString = movie.watch_date {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            watchDate = formatter.date(from: watchDateString) ?? Date()
        }
    }
    
    private func updateMovie() async {
        isUpdatingMovie = true
        
        do {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            
            let updateRequest = UpdateMovieRequest(
                title: nil, // Don't update title
                release_year: nil, // Don't update release year
                release_date: nil, // Don't update release date
                rating: starRating > 0 ? starRating : nil,
                ratings100: Double(detailedRating),
                reviews: review.isEmpty ? nil : review,
                tags: tags.isEmpty ? nil : tags,
                watched_date: formatter.string(from: watchDate),
                rewatch: isRewatch ? "yes" : "no",
                tmdb_id: nil, // Don't update TMDB ID
                overview: nil, // Don't update overview
                poster_url: nil, // Don't update poster
                backdrop_path: nil, // Don't update backdrop
                director: nil, // Don't update director
                runtime: nil, // Don't update runtime
                vote_average: nil, // Don't update vote average
                vote_count: nil, // Don't update vote count
                popularity: nil, // Don't update popularity
                original_language: nil, // Don't update original language
                original_title: nil, // Don't update original title
                tagline: nil, // Don't update tagline
                status: nil, // Don't update status
                budget: nil, // Don't update budget
                revenue: nil, // Don't update revenue
                imdb_id: nil, // Don't update IMDB ID
                homepage: nil, // Don't update homepage
                genres: nil // Don't update genres
            )
            
            let updatedMovie = try await supabaseService.updateMovie(id: movie.id, with: updateRequest)
            
            await MainActor.run {
                isUpdatingMovie = false
                onSave(updatedMovie)
                dismiss()
            }
            
        } catch {
            await MainActor.run {
                isUpdatingMovie = false
                alertMessage = "Failed to update movie: \(error.localizedDescription)"
                showingAlert = true
            }
        }
    }
}

#Preview {
    EditMovieView(movie: Movie(
        id: 1,
        title: "Harry Potter and the Deathly Hallows: Part 1",
        release_year: 2010,
        release_date: "2010-11-17",
        rating: 4.5,
        detailed_rating: 82,
        review: "Great movie!",
        tags: "family, theater",
        watch_date: "2025-07-18",
        is_rewatch: false,
        tmdb_id: 12444,
        overview: "The final adventure begins...",
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
        updated_at: nil,
        favorited: false
    )) { _ in }
}
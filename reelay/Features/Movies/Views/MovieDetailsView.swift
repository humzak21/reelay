//
//  MovieDetailsView.swift
//  reelay
//
//  Created by Humza Khalil on 6/11/25.
//

import SwiftUI
import SDWebImageSwiftUI

struct MovieDetailsView: View {
    let movie: Movie
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Movie Header with Poster and Basic Info
                    movieHeaderView
                    
                    // Ratings Section
                    ratingsSection
                    
                    // Movie Information
                    movieInfoSection
                    
                    // Overview/Plot
                    if let overview = movie.overview, !overview.isEmpty {
                        overviewSection(overview)
                    }
                    
                    // Reviews/Notes
                    if let reviews = movie.reviews, !reviews.isEmpty {
                        reviewsSection(reviews)
                    }
                    
                    // Technical Details
                    technicalDetailsSection
                    
                    Spacer(minLength: 20)
                }
                .padding()
            }
            .navigationTitle("Movie Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            // TODO: Edit movie functionality
                        } label: {
                            Label("Edit Movie", systemImage: "pencil")
                        }
                        
                        Button(role: .destructive) {
                            // TODO: Delete movie functionality
                        } label: {
                            Label("Delete Movie", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    private var movieHeaderView: some View {
        HStack(alignment: .top, spacing: 16) {
            // Movie Poster
            WebImage(url: URL(string: movie.posterURL ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "film")
                            .foregroundColor(.gray)
                            .font(.system(size: 40))
                    )
            }
            .onFailure { error in
                print("Image loading failed: \(error)")
            }
            .indicator(.activity)
            .transition(.fade(duration: 0.3))
            .scaledToFill()
            .frame(width: 120, height: 180)
            .clipped()
            .cornerRadius(12)
            .shadow(radius: 4)
            
            // Movie Basic Info
            VStack(alignment: .leading, spacing: 8) {
                Text(movie.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.leading)
                
                if let releaseYear = movie.releaseYear {
                    Text(String(releaseYear))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.systemGray5))
                        .cornerRadius(6)
                }
                
                if let director = movie.director {
                    Text("Directed by \(director)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                if let runtime = movie.runtime {
                    Text("\(runtime) minutes")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Genres
                if let genres = movie.genres, !genres.isEmpty {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 4) {
                        ForEach(genres, id: \.id) { genre in
                            Text(genre.name)
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(4)
                        }
                    }
                }
                
                Spacer()
            }
            
            Spacer()
        }
    }
    
    private var ratingsSection: some View {
        VStack(spacing: 12) {
            Text("Your Ratings")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 20) {
                // User Rating
                if let rating = movie.rating {
                    VStack(spacing: 4) {
                        Text("Rating")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 4) {
                            StarRatingView(rating: rating, maxRating: 5)
                            Text(String(format: "%.1f", rating))
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                
                // Detailed Rating
                if let detailedRating = movie.detailedRating {
                    VStack(spacing: 4) {
                        Text("Detailed")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(String(format: "%.1f/10", detailedRating))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                
                // TMDB Rating
                if let voteAverage = movie.voteAverage {
                    VStack(spacing: 4) {
                        Text("TMDB")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(String(format: "%.1f/10", voteAverage))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.orange)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 1)
    }
    
    private var movieInfoSection: some View {
        VStack(spacing: 12) {
            Text("Watch Information")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 8) {
                if let watchDate = movie.watchDate {
                    HStack {
                        Text("Watched on:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(watchDate, style: .date)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }
                
                if movie.isRewatch {
                    HStack {
                        Text("Rewatch:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        HStack {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(.blue)
                            Text("Yes")
                                .fontWeight(.medium)
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                if let tags = movie.tags, !tags.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Tags:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 4) {
                            ForEach(tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.caption)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.green.opacity(0.1))
                                    .foregroundColor(.green)
                                    .cornerRadius(4)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 1)
    }
    
    private func overviewSection(_ overview: String) -> some View {
        VStack(spacing: 8) {
            Text("Overview")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text(overview)
                .font(.body)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 1)
    }
    
    private func reviewsSection(_ reviews: String) -> some View {
        VStack(spacing: 8) {
            Text("Your Review")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text(reviews)
                .font(.body)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 1)
    }
    
    private var technicalDetailsSection: some View {
        VStack(spacing: 8) {
            Text("Technical Details")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 6) {
                if let releaseDate = movie.releaseDate {
                    HStack {
                        Text("Release Date:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(releaseDate, style: .date)
                            .font(.subheadline)
                    }
                }
                
                if let tmdbID = movie.tmdbID {
                    HStack {
                        Text("TMDB ID:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(String(tmdbID))
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 1)
    }
}

#Preview {
    MovieDetailsView(movie: Movie(
        id: 1,
        title: "The Shawshank Redemption",
        rating: 4.5,
        detailedRating: 9.2,
        watchDate: Date(),
        isRewatch: false,
        notes: "Amazing movie about hope and friendship",
        tags: ["Drama", "Classic"],
        releaseDate: nil,
        releaseYear: 1994,
        runtime: 142,
        overview: "Two imprisoned men bond over a number of years, finding solace and eventual redemption through acts of common decency.",
        posterURL: nil,
        backdropURL: nil,
        voteAverage: 9.3,
        tmdbID: 278,
        director: "Frank Darabont",
        genres: [Genre(id: 18, name: "Drama")],
        reviews: "One of the greatest films ever made. The story of hope, friendship, and redemption is beautifully told."
    ))
} 
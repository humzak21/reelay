//
//  AddMovieView.swift
//  reelay
//
//  Created by Humza Khalil on 6/11/25.
//

import SwiftUI
import SDWebImageSwiftUI

struct AddMovieView: View {
    @ObservedObject var viewModel: MoviesViewModel
    @Environment(\.dismiss) private var dismiss
    @StateObject private var addMovieViewModel = AddMovieViewModel()
    @State private var showingError = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if addMovieViewModel.selectedMovie == nil {
                    // Search phase
                    searchView
                } else {
                    // Movie selected - show details and rating inputs
                    selectedMovieView
                }
            }
            .navigationTitle("Add Movie")
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
                
                if addMovieViewModel.selectedMovie != nil {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            Task {
                                let success = await addMovieViewModel.saveMovie()
                                if success {
                                    // Refresh the movies list
                                    await viewModel.loadMovies(refresh: true)
                                    dismiss()
                                }
                            }
                        } label: {
                            Image(systemName: "checkmark")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(addMovieViewModel.isSaving)
                    }
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(addMovieViewModel.error?.localizedDescription ?? "An unknown error occurred")
            }
        }
        .onChange(of: addMovieViewModel.error != nil) { _, hasError in
            showingError = hasError
        }
    }
    
    private var searchView: some View {
        VStack(spacing: 16) {
            // Search field
            VStack(alignment: .leading, spacing: 8) {
                Text("Search for a movie")
                    .font(.headline)
                    .padding(.horizontal)
                
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    
                    TextField("Enter movie title...", text: $addMovieViewModel.searchQuery)
                        .textFieldStyle(PlainTextFieldStyle())
                    
                    if addMovieViewModel.isSearching {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
            }
            
            // Search results
            if !addMovieViewModel.tmdbMovies.isEmpty {
                List {
                    ForEach(addMovieViewModel.tmdbMovies) { movie in
                        TMDBMovieRowView(movie: movie) {
                            Task {
                                await addMovieViewModel.selectMovie(movie)
                            }
                        }
                        .disabled(addMovieViewModel.isLoadingDetails)
                    }
                }
                .listStyle(PlainListStyle())
            } else if !addMovieViewModel.searchQuery.isEmpty && !addMovieViewModel.isSearching {
                VStack(spacing: 16) {
                    Image(systemName: "film.circle")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    
                    Text("No movies found")
                        .font(.title3)
                        .foregroundColor(.secondary)
                    
                    Text("Try adjusting your search terms")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 50)
            } else if addMovieViewModel.searchQuery.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "magnifyingglass.circle")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    
                    Text("Search for Movies")
                        .font(.title3)
                        .foregroundColor(.secondary)
                    
                    Text("Enter a movie title to get started")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 50)
            }
            
            Spacer()
        }
    }
    
    private var selectedMovieView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Selected movie header
                HStack {
                    Button("← Change Movie") {
                        addMovieViewModel.clearSelection()
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                    
                    Spacer()
                }
                .padding(.horizontal)
                
                // Movie details card
                if let movie = addMovieViewModel.selectedMovie {
                    SelectedMovieCardView(movie: movie)
                }
                
                // Rating inputs
                VStack(spacing: 16) {
                    Text("Your Rating")
                        .font(.title2)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Rating: \(addMovieViewModel.userRating, specifier: "%.1f")/5")
                            .font(.subheadline)
                        Slider(value: $addMovieViewModel.userRating, in: 0...5, step: 0.5)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Detailed Rating: \(addMovieViewModel.detailedRating, specifier: "%.1f")/10")
                            .font(.subheadline)
                        Slider(value: $addMovieViewModel.detailedRating, in: 0...10, step: 0.1)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                
                // Watch details
                VStack(spacing: 16) {
                    Text("Watch Details")
                        .font(.title2)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    VStack(spacing: 12) {
                        DatePicker("Watch Date", selection: $addMovieViewModel.watchDate, displayedComponents: .date)
                        
                        Toggle("Rewatch", isOn: $addMovieViewModel.isRewatch)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                
                // Review section
                VStack(spacing: 16) {
                    Text("Your Review")
                        .font(.title2)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Write your thoughts about this movie (optional)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        TextEditor(text: $addMovieViewModel.review)
                            .frame(minHeight: 100)
                            .padding(12)
                            .background(Color(.systemBackground))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(.systemGray4), lineWidth: 1)
                            )
                        
                        if addMovieViewModel.review.isEmpty {
                            Text("Share your thoughts, favorite scenes, or what you liked/disliked about the movie...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.leading, 4)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                

            }
            .padding(.bottom, 20)
        }
    }
}

struct TMDBMovieRowView: View {
    let movie: TMDBMovie
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                WebImage(url: URL(string: movie.fullPosterURL ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: "film")
                                .foregroundColor(.gray)
                                .font(.title3)
                        )
                }
                .frame(width: 60, height: 90)
                .clipped()
                .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(movie.title)
                        .font(.headline)
                        .lineLimit(2)
                        .foregroundColor(.primary)
                    
                    if let year = movie.releaseYear {
                        Text(String(year))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    if let overview = movie.overview, !overview.isEmpty {
                        Text(overview)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.caption)
                        Text(String(format: "%.1f", movie.voteAverage))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SelectedMovieCardView: View {
    let movie: TMDBMovieDetails
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                WebImage(url: URL(string: movie.fullPosterURL ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: "film")
                                .foregroundColor(.gray)
                                .font(.title2)
                        )
                }
                .frame(width: 100, height: 150)
                .clipped()
                .cornerRadius(12)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(movie.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .lineLimit(3)
                    
                    if let year = movie.releaseYear {
                        Text(String(year))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
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
                    
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                        Text(String(format: "%.1f", movie.voteAverage))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            
            if let overview = movie.overview, !overview.isEmpty {
                Text(overview)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .lineLimit(4)
            }
            
            if !movie.genres.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(movie.genres, id: \.id) { genre in
                            Text(genre.name)
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(16)
                        }
                    }
                    .padding(.horizontal, 1)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .padding(.horizontal)
    }
} 
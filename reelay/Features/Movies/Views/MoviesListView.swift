//
//  MoviesListView.swift
//  reelay
//
//  Created by Humza Khalil on 6/11/25.
//
import SwiftUI
import SDWebImageSwiftUI

enum ViewMode: CaseIterable {
    case list
    case grid
    
    var icon: String {
        switch self {
        case .list: return "list.bullet"
        case .grid: return "square.grid.3x3"
        }
    }
    
    var title: String {
        switch self {
        case .list: return "List"
        case .grid: return "Grid"
        }
    }
}

struct MoviesListView: View {
    @Binding var showingAddMovie: Bool
    @StateObject private var viewModel = MoviesViewModel()
    @State private var showingError = false
    @State private var viewMode: ViewMode = .list
    @State private var selectedYear: Int? = nil
    @State private var sortOption: SortOption = .dateWatched
    @State private var selectedMovie: Movie? = nil
    @State private var showingMovieDetails = false
    
    // Computed properties for filtering and sorting
    private var availableYears: [Int] {
        let years = viewModel.movies.compactMap { movie in
            movie.releaseYear ?? movie.watchDate?.year
        }
        return Array(Set(years)).sorted(by: >)
    }
    
    private var filteredAndSortedMovies: [Movie] {
        var movies = viewModel.movies
        
        // Apply year filter
        if let selectedYear = selectedYear {
            movies = movies.filter { movie in
                (movie.releaseYear ?? movie.watchDate?.year) == selectedYear
            }
        }
        
        // Apply sorting
        switch sortOption {
        case .dateWatched:
            movies.sort { ($0.watchDate ?? Date.distantPast) > ($1.watchDate ?? Date.distantPast) }
        case .title:
            movies.sort { $0.title < $1.title }
        case .rating:
            movies.sort { ($0.rating ?? 0) > ($1.rating ?? 0) }
        case .releaseYear:
            movies.sort { ($0.releaseYear ?? 0) > ($1.releaseYear ?? 0) }
        }
        
        return movies
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Main Content
                if viewModel.movies.isEmpty && !viewModel.isLoading {
                    emptyStateView
                } else {
                    switch viewMode {
                    case .list:
                        facetedListView
                    case .grid:
                        tiledGridView
                    }
                }
            }
            .navigationTitle("Movies")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    // Year Filter
                    if !viewModel.movies.isEmpty && !availableYears.isEmpty {
                        Menu {
                            Button("All Years") {
                                selectedYear = nil
                            }
                            ForEach(availableYears, id: \.self) { year in
                                Button(String(year)) {
                                    selectedYear = year
                                }
                            }
                        } label: {
                            Image(systemName: "calendar")
                        }
                    }
                    
                    // Sort Options
                    if !viewModel.movies.isEmpty {
                        Menu {
                            ForEach(SortOption.allCases, id: \.self) { option in
                                Button {
                                    sortOption = option
                                } label: {
                                    HStack {
                                        Text(option.title)
                                        if sortOption == option {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: "arrow.up.arrow.down")
                        }
                    }
                    
                    // View Mode Toggle
                    if !viewModel.movies.isEmpty {
                        Button {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                viewMode = viewMode == .list ? .grid : .list
                            }
                        } label: {
                            Image(systemName: viewMode == .list ? "square.grid.3x3" : "list.bullet")
                        }
                    }
                    
                    // Add Menu
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
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
                Button("Retry") {
                    Task {
                        await viewModel.loadMovies(refresh: true)
                    }
                }
            } message: {
                Text(viewModel.error?.localizedDescription ?? "An unknown error occurred")
            }
        }
        .sheet(isPresented: $showingMovieDetails) {
            if let selectedMovie = selectedMovie {
                MovieDetailsView(movie: selectedMovie)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
        .task {
            if viewModel.movies.isEmpty {
                await viewModel.loadMovies()
            }
        }
        .onChange(of: viewModel.error != nil) {
            showingError = viewModel.error != nil
        }
    }
    
    // MARK: - Subviews
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "film")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No movies yet")
                .font(.title2)
                .foregroundColor(.secondary)
            
            Text("Add your first movie using the Add Film button")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    private var facetedListView: some View {
        List {
            ForEach(filteredAndSortedMovies) { movie in
                FacetedMovieRowView(movie: movie)
                    .onTapGesture {
                        selectedMovie = movie
                        showingMovieDetails = true
                    }
                    .onAppear {
                        if movie.id == viewModel.movies.last?.id {
                            Task {
                                await viewModel.loadMovies()
                            }
                        }
                    }
            }
            
            if viewModel.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .padding()
                    Spacer()
                }
            }
        }
        .listStyle(PlainListStyle())
        .refreshable {
            await viewModel.loadMovies(refresh: true)
        }
    }
    
    private var tiledGridView: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 12) {
                ForEach(filteredAndSortedMovies) { movie in
                    MovieTileView(movie: movie)
                        .onTapGesture {
                            selectedMovie = movie
                            showingMovieDetails = true
                        }
                        .onAppear {
                            if movie.id == viewModel.movies.last?.id {
                                Task {
                                    await viewModel.loadMovies()
                                }
                            }
                        }
                }
                
                if viewModel.isLoading {
                    ForEach(0..<3, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                            .aspectRatio(2/3, contentMode: .fit)
                            .overlay(
                                ProgressView()
                                    .scaleEffect(0.8)
                            )
                    }
                }
            }
            .padding()
        }
        .refreshable {
            await viewModel.loadMovies(refresh: true)
        }
    }
}

// MARK: - Supporting Types

enum SortOption: CaseIterable {
    case dateWatched
    case title
    case rating
    case releaseYear
    
    var title: String {
        switch self {
        case .dateWatched: return "Date Watched"
        case .title: return "Title"
        case .rating: return "Rating"
        case .releaseYear: return "Release Year"
        }
    }
}

// MARK: - Row Views

struct FacetedMovieRowView: View {
    let movie: Movie
    
    var body: some View {
        HStack(spacing: 12) {
            // Movie Poster
            WebImage(url: URL(string: movie.posterURL ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "film")
                            .foregroundColor(.gray)
                            .font(.title2)
                    )
            }
            .onFailure { error in
                print("Image loading failed: \(error)")
            }
            .indicator(.activity)
            .transition(.fade(duration: 0.3))
            .scaledToFill()
            .frame(width: 70, height: 105)
            .clipped()
            .cornerRadius(8)
            
            // Movie Details
            VStack(alignment: .leading, spacing: 6) {
                // Title and Year
                HStack {
                    Text(movie.title)
                        .font(.headline)
                        .lineLimit(2)
                    
                    Spacer()
                    
                    if let year = movie.releaseYear {
                        Text(String(year))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(.systemGray5))
                            .cornerRadius(4)
                    }
                }
                
                // Director
                if let director = movie.director {
                    Text("Directed by \(director)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Rating and Watch Date
                HStack {
                    if let rating = movie.rating {
                        StarRatingView(rating: rating, maxRating: 5)
                    }
                    
                    Spacer()
                    
                    if let watchDate = movie.watchDate {
                        Text(watchDate, style: .date)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Review Preview
                if let reviews = movie.reviews, !reviews.isEmpty {
                    Text(reviews)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .padding(.top, 2)
                }
            }
            
            // Rewatch Indicator
            VStack {
                if movie.isRewatch {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.blue)
                        .font(.caption)
                }
                Spacer()
            }
        }
        .padding(.vertical, 8)
    }
}

struct MovieTileView: View {
    let movie: Movie
    
    var body: some View {
        VStack(spacing: 8) {
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
                            .font(.title2)
                    )
            }
            .onFailure { error in
                print("Image loading failed: \(error)")
            }
            .indicator(.activity)
            .transition(.fade(duration: 0.3))
            .scaledToFill()
            .aspectRatio(2/3, contentMode: .fit)
            .clipped()
            .cornerRadius(12)
            .overlay(
                // Rating overlay
                VStack {
                    HStack {
                        Spacer()
                        if let rating = movie.rating {
                            Text(String(format: "%.1f", rating))
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.black.opacity(0.7))
                                .cornerRadius(8)
                        }
                    }
                    Spacer()
                    HStack {
                        if movie.isRewatch {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(.white)
                                .font(.caption)
                                .padding(4)
                                .background(Color.blue)
                                .cornerRadius(6)
                        }
                        Spacer()
                    }
                }
                .padding(8)
            )
            
            // Movie Title with Fixed Height
            Text(movie.title)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .frame(height: 32) // Fixed height for consistent alignment
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// Keep the original MovieRowView for backward compatibility
struct MovieRowView: View {
    let movie: Movie
    
    var body: some View {
        FacetedMovieRowView(movie: movie)
    }
}

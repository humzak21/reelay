//
//  ContentView.swift
//  reelay
//
//  Created by Humza Khalil on 6/2/25.
//

import SwiftUI

struct ContentView: View {
    @State private var showingAddMovie = false
    @StateObject private var moviesViewModel = MoviesViewModel()
    @State private var searchText = ""
    
    var body: some View {
        TabView {
            Tab("Movies", systemImage: "film") {
                MoviesListView(showingAddMovie: $showingAddMovie)
            }
            
            Tab("Statistics", systemImage: "chart.bar") {
                StatisticsView(showingAddMovie: $showingAddMovie)
            }
            
            Tab("Settings", systemImage: "gearshape") {
                SettingsView(showingAddMovie: $showingAddMovie)
            }
            
            Tab(role: .search) {
                SearchableMoviesView(searchText: $searchText)
            }
        }
        .sheet(isPresented: $showingAddMovie) {
            AddMovieView(viewModel: moviesViewModel)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .environmentObject(moviesViewModel)
    }
}

// New view specifically for searchable movies that follows Liquid Glass guidelines
struct SearchableMoviesView: View {
    @Binding var searchText: String
    @StateObject private var viewModel = MoviesViewModel()
    @State private var showingError = false
    @State private var selectedMovie: Movie? = nil
    @State private var showingMovieDetails = false
    
    var body: some View {
        NavigationView {
            VStack {
                if viewModel.movies.isEmpty && !viewModel.isLoading && searchText.isEmpty {
                    // Empty state for search
                    VStack(spacing: 20) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("Search Movies")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        
                        Text("Enter a movie title to search your collection")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else if viewModel.movies.isEmpty && !viewModel.isLoading && !searchText.isEmpty {
                    // No results state
                    VStack(spacing: 20) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("No Results")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        
                        Text("No movies found for '\(searchText)'")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    List {
                        ForEach(viewModel.movies) { movie in
                            MovieRowView(movie: movie)
                                .onTapGesture {
                                    selectedMovie = movie
                                    showingMovieDetails = true
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
                }
            }
            .navigationTitle("Search")
            .searchable(text: $searchText, prompt: "Search movies...")
            .onChange(of: searchText) { _, newValue in
                Task {
                    if newValue.isEmpty {
                        viewModel.movies = []
                    } else if newValue.count >= 2 { // Start searching after 2 characters
                        await viewModel.searchMovies(query: newValue)
                    }
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
                Button("Retry") {
                    if !searchText.isEmpty {
                        Task {
                            await viewModel.searchMovies(query: searchText)
                        }
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
        .onChange(of: viewModel.error != nil) { _, hasError in
            showingError = hasError
        }
    }
}

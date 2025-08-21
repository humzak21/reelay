//
//  WatchlistEditView.swift
//  reelay2
//
//  Created by Humza Khalil on 8/14/25.
//

import SwiftUI
import Auth

struct WatchlistEditView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var dataManager = DataManager.shared
    @StateObject private var watchlistService = SupabaseWatchlistService.shared
    @StateObject private var tmdbService = TMDBService.shared
    
    @State private var searchText = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var searchResults: [TMDBMovie] = []
    @State private var isSearching = false
    @State private var currentSortOption: ListSortOption = .addedDate
    
    private var watchlistItems: [ListItem] {
        let items = dataManager.getListItems(watchlistList)
        return items.sorted(by: currentSortOption)
    }
    
    private var watchlistList: MovieList {
        dataManager.movieLists.first { $0.id == SupabaseWatchlistService.watchlistListId } ??
        MovieList.watchlistPlaceholder(userId: SupabaseMovieService.shared.currentUser?.id ?? UUID())
    }
    
    private var filteredWatchlistItems: [ListItem] {
        if searchText.isEmpty {
            return watchlistItems
        }
        return watchlistItems.filter { item in
            item.movieTitle.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                searchBar
                
                // Sort options
                sortOptionsBar
                
                // Content
                if isSearching && !searchText.isEmpty {
                    searchResultsView
                } else {
                    watchlistView
                }
            }
            .background(Color.black)
            .navigationTitle("Edit Watchlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", systemImage: "xmark") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .task {
                await dataManager.refreshWatchlist()
            }
        }
    }
    
    @ViewBuilder
    private var searchBar: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("Search movies or watchlist...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .foregroundColor(.white)
                    .onChange(of: searchText) { _, newValue in
                        if !newValue.isEmpty && newValue.count > 2 {
                            Task {
                                await performSearch(query: newValue)
                            }
                        } else {
                            searchResults = []
                            isSearching = false
                        }
                    }
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                        searchResults = []
                        isSearching = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }
    
    @ViewBuilder
    private var sortOptionsBar: some View {
        if !isSearching || searchText.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(ListSortOption.allCases.prefix(6)) { option in
                        Button(action: {
                            currentSortOption = option
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: option.systemImage)
                                    .font(.caption)
                                Text(option.displayName)
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(currentSortOption == option ? Color.blue : Color(.systemGray5))
                            .foregroundColor(currentSortOption == option ? .white : .primary)
                            .cornerRadius(16)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.top, 8)
        }
    }
    
    @ViewBuilder
    private var searchResultsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Search Results")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 20)
            
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if searchResults.isEmpty && !searchText.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    Text("No movies found")
                        .font(.title2)
                        .foregroundColor(.white)
                    Text("Try a different search term")
                        .font(.body)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(searchResults) { movie in
                            WatchlistSearchResultRow(movie: movie) {
                                Task {
                                    await addToWatchlist(movie)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }
    
    @ViewBuilder
    private var watchlistView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Watchlist (\(watchlistItems.count))")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
            }
            .padding(.horizontal, 20)
            
            if filteredWatchlistItems.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    Text("No movies in watchlist")
                        .font(.title2)
                        .foregroundColor(.white)
                    Text("Add movies using the search above")
                        .font(.body)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredWatchlistItems) { item in
                            WatchlistItemRow(item: item) {
                                Task {
                                    await removeFromWatchlist(item)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }
    
    private func performSearch(query: String) async {
        isLoading = true
        isSearching = true
        errorMessage = nil
        
        do {
            let results = try await tmdbService.searchMovies(query: query)
            await MainActor.run {
                searchResults = results.results
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "Search failed: \(error.localizedDescription)"
                searchResults = []
                isLoading = false
            }
        }
    }
    
    private func addToWatchlist(_ movie: TMDBMovie) async {
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
        } catch {
            await MainActor.run {
                errorMessage = "Failed to add movie: \(error.localizedDescription)"
            }
        }
    }
    
    private func removeFromWatchlist(_ item: ListItem) async {
        do {
            try await watchlistService.deleteItem(tmdbId: item.tmdbId)
            await dataManager.refreshWatchlist()
        } catch {
            await MainActor.run {
                errorMessage = "Failed to remove movie: \(error.localizedDescription)"
            }
        }
    }
}

struct WatchlistSearchResultRow: View {
    let movie: TMDBMovie
    let onAdd: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
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
            .frame(width: 50, height: 75)
            .cornerRadius(8)
            .clipped()
            
            VStack(alignment: .leading, spacing: 4) {
                Text(movie.title)
                    .font(.headline)
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
            
            Button(action: onAdd) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct WatchlistItemRow: View {
    let item: ListItem
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: item.posterURL) { image in
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
            .frame(width: 50, height: 75)
            .cornerRadius(8)
            .clipped()
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.movieTitle)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(2)
                
                if let year = item.movieYear {
                    Text(String(year))
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                Text("Added \(item.addedAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Button(action: onRemove) {
                Image(systemName: "trash.circle.fill")
                    .font(.title2)
                    .foregroundColor(.red)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

#Preview {
    WatchlistEditView()
}
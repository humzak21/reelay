//
//  ListDetailsView.swift
//  reelay2
//
//  Created by Claude on 8/4/25.
//

import SwiftUI

struct ListDetailsView: View {
    let list: MovieList
    @Environment(\.dismiss) private var dismiss
    @StateObject private var dataManager = DataManager.shared
    @State private var isLoading = false
    @State private var showingAddMovies = false
    @State private var showingEditList = false
    @State private var showingDeleteAlert = false
    @State private var errorMessage: String?
    
    private var listItems: [ListItem] {
        dataManager.getListItems(list)
    }
    
    private var firstMovieBackdrop: String? {
        // For now, we'll use the poster URL as backdrop since we don't store backdrop URLs in list items
        // This will show the poster image as a wider backdrop - still looks good
        guard let firstItem = listItems.first,
              let posterUrl = firstItem.moviePosterUrl else { return nil }
        
        // Use higher resolution if it's a TMDB URL
        if posterUrl.contains("image.tmdb.org/t/p/w500") {
            return posterUrl.replacingOccurrences(of: "w500", with: "w1280")
        }
        
        return posterUrl
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Backdrop extends behind navigation bar
                VStack(spacing: 0) {
                    headerView
                        .frame(height: 80)
                        .ignoresSafeArea(edges: .top)
                    
                    Spacer()
                }
                
                // Content positioned below backdrop
                VStack(spacing: 0) {
                    // Spacer to push content below backdrop
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: 260)
                    
                    // Scrollable movies grid in same position
                    if listItems.isEmpty {
                        emptyStateView
                    } else {
                        ScrollView {
                            moviesGridView
                                .padding(.top, 20)
                        }
                    }
                }
            }
            .background(Color.black)
            .preferredColorScheme(.dark)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                    .fontWeight(.medium)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Add Movies") {
                            showingAddMovies = true
                        }
                        
                        Button("Edit List") {
                            showingEditList = true
                        }
                        
                        if list.pinned {
                            Button("Unpin List") {
                                Task {
                                    await unpinList()
                                }
                            }
                        } else {
                            Button("Pin List") {
                                Task {
                                    await pinList()
                                }
                            }
                        }
                        
                        Divider()
                        
                        Button("Delete List", role: .destructive) {
                            showingDeleteAlert = true
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundColor(.white)
                            .fontWeight(.medium)
                    }
                }
            }
            .sheet(isPresented: $showingAddMovies) {
                AddMoviesToListView(list: list)
            }
            .sheet(isPresented: $showingEditList) {
                EditListView(list: list)
            }
            .alert("Delete List", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    Task {
                        await deleteList()
                    }
                }
            } message: {
                Text("Are you sure you want to delete '\(list.name)'? This action cannot be undone.")
            }
        }
    }
    
    @ViewBuilder
    private var headerView: some View {
        ZStack(alignment: .bottomLeading) {
            // Backdrop image - fills the header container completely
            if let backdropUrl = firstMovieBackdrop {
                AsyncImage(url: URL(string: backdropUrl)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.gray.opacity(0.3)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
            } else {
                // Default gradient background when no backdrop
                LinearGradient(
                    colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            
            // Dark gradient overlay for text readability - only at bottom half
            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.8)],
                startPoint: UnitPoint(x: 0.5, y: 0.5),
                endPoint: .bottom
            )
            
            // List title and description overlay - positioned at bottom
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .center, spacing: 6) {
                    Text(list.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.8), radius: 2, x: 0, y: 1)
                    
                    if list.pinned {
                        Image(systemName: "pin.fill")
                            .foregroundColor(.yellow)
                            .font(.body)
                            .shadow(color: .black.opacity(0.8), radius: 2, x: 0, y: 1)
                    }
                    
                    Spacer()
                }
                
                if let description = list.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.9))
                        .lineLimit(2)
                        .shadow(color: .black.opacity(0.8), radius: 2, x: 0, y: 1)
                }
                
                Text("\(list.itemCount) films")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.8))
                    .textCase(.uppercase)
                    .fontWeight(.medium)
                    .shadow(color: .black.opacity(0.8), radius: 2, x: 0, y: 1)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
    }
    
    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "film.stack")
                .font(.system(size: 64))
                .foregroundColor(.gray)
            
            Text("No Movies Yet")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            Text("Add movies to this list to get started.")
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button("Add Movies") {
                showingAddMovies = true
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private var moviesGridView: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
            ForEach(listItems) { item in
                MoviePosterView(item: item, list: list)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 20)
    }
    
    private func pinList() async {
        do {
            try await dataManager.pinList(list)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func unpinList() async {
        do {
            try await dataManager.unpinList(list)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func deleteList() async {
        do {
            try await dataManager.deleteList(list)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct MoviePosterView: View {
    let item: ListItem
    let list: MovieList
    @StateObject private var dataManager = DataManager.shared
    @State private var showingRemoveAlert = false
    
    var body: some View {
        Button(action: {
            // Could implement navigation to movie details here
        }) {
            AsyncImage(url: URL(string: item.moviePosterUrl ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(2/3, contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .aspectRatio(2/3, contentMode: .fill)
                    .overlay(
                        VStack {
                            Image(systemName: "photo")
                                .foregroundColor(.gray)
                            Text(item.movieTitle)
                                .font(.caption)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .lineLimit(3)
                        }
                    )
            }
            .clipped()
            .cornerRadius(12)
            .contextMenu {
                Button("Remove from List", role: .destructive) {
                    showingRemoveAlert = true
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .alert("Remove Movie", isPresented: $showingRemoveAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) {
                Task {
                    await removeMovie()
                }
            }
        } message: {
            Text("Remove '\(item.movieTitle)' from '\(list.name)'?")
        }
    }
    
    private func removeMovie() async {
        do {
            try await dataManager.removeMovieFromList(tmdbId: item.tmdbId, listId: list.id)
        } catch {
            print("Error removing movie: \(error)")
        }
    }
}

// Add Movies to List View with TMDB Search
struct AddMoviesToListView: View {
    let list: MovieList
    @Environment(\.dismiss) private var dismiss
    @StateObject private var dataManager = DataManager.shared
    @StateObject private var tmdbService = TMDBService.shared
    
    @State private var searchText = ""
    @State private var searchResults: [TMDBMovie] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?
    @State private var errorMessage: String?
    @State private var addingMovieIds: Set<Int> = []
    
    var body: some View {
        NavigationView {
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
                
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.horizontal)
                }
                
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
                        
                        Text("Search for movies to add to your list.")
                            .font(.body)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(searchResults) { movie in
                                MovieSearchResultView(
                                    movie: movie,
                                    list: list,
                                    isAdding: addingMovieIds.contains(movie.id)
                                ) {
                                    await addMovie(movie)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                Spacer()
            }
            .background(Color.black)
            .preferredColorScheme(.dark)
            .navigationTitle("Add Movies")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onDisappear {
                searchTask?.cancel()
            }
        }
    }
    
    private func performSearch() {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
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
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            return
        }
        
        isSearching = true
        errorMessage = nil
        
        do {
            let response = try await tmdbService.searchMovies(query: searchText)
            // Filter out movies already in the list
            let existingTmdbIds = Set(dataManager.getListItems(list).map { $0.tmdbId })
            searchResults = response.results.filter { !existingTmdbIds.contains($0.id) }
        } catch {
            errorMessage = error.localizedDescription
            searchResults = []
        }
        
        isSearching = false
    }
    
    private func addMovie(_ movie: TMDBMovie) async {
        addingMovieIds.insert(movie.id)
        
        do {
            try await dataManager.addMovieToList(
                tmdbId: movie.id,
                title: movie.title,
                posterUrl: movie.posterURL?.absoluteString,
                year: movie.releaseYear,
                listId: list.id
            )
            
            // Remove from search results since it's now added
            searchResults.removeAll { $0.id == movie.id }
        } catch {
            errorMessage = error.localizedDescription
        }
        
        addingMovieIds.remove(movie.id)
    }
}

struct MovieSearchResultView: View {
    let movie: TMDBMovie
    let list: MovieList
    let isAdding: Bool
    let onAddMovie: () async -> Void
    
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
            
            // Add button
            Button(action: {
                Task {
                    await onAddMovie()
                }
            }) {
                Group {
                    if isAdding {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                }
            }
            .disabled(isAdding)
            .buttonStyle(PlainButtonStyle())
        }
        .padding()
        .background(Color.gray.opacity(0.15))
        .cornerRadius(12)
    }
}

struct EditListView: View {
    let list: MovieList
    @Environment(\.dismiss) private var dismiss
    @StateObject private var dataManager = DataManager.shared
    @State private var listName: String
    @State private var listDescription: String
    @State private var isUpdating = false
    @State private var errorMessage: String?
    
    init(list: MovieList) {
        self.list = list
        self._listName = State(initialValue: list.name)
        self._listDescription = State(initialValue: list.description ?? "")
    }
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("List Name")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    TextField("Enter list name", text: $listName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Description (Optional)")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    TextField("Enter description", text: $listDescription, axis: .vertical)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .lineLimit(3, reservesSpace: true)
                }
                
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                }
                
                Spacer()
            }
            .padding()
            .background(Color.black)
            .preferredColorScheme(.dark)
            .navigationTitle("Edit List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            await updateList()
                        }
                    }
                    .disabled(listName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isUpdating)
                }
            }
        }
    }
    
    private func updateList() async {
        guard !listName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isUpdating = true
        errorMessage = nil
        
        do {
            let name = listName.trimmingCharacters(in: .whitespacesAndNewlines)
            let description = listDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            
            _ = try await dataManager.updateList(
                list,
                name: name != list.name ? name : nil,
                description: description != (list.description ?? "") ? (description.isEmpty ? nil : description) : nil
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isUpdating = false
    }
}

#Preview {
    ListDetailsView(list: MovieList(
        id: UUID(),
        userId: UUID(),
        name: "Sample List",
        description: "A sample movie list for preview",
        itemCount: 3
    ))
}
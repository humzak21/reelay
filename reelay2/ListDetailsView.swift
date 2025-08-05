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
        guard let firstItem = listItems.first else { return nil }
        
        // Prefer backdrop URL if available
        if let backdropUrl = firstItem.movieBackdropUrl {
            return backdropUrl
        }
        
        // Fallback to poster URL with higher resolution
        guard let posterUrl = firstItem.moviePosterUrl else { return nil }
        if posterUrl.contains("image.tmdb.org/t/p/w500") {
            return posterUrl.replacingOccurrences(of: "w500", with: "w1280")
        }
        
        return posterUrl
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 0) {
                    // Backdrop Section
                    backdropSection
                    
                    // List Info Section (similar to watch date section)
                    listInfoSection
                    
                    // Content Section
                    VStack(spacing: 16) {
                        if listItems.isEmpty {
                            emptyStateView
                        } else {
                            moviesGridView
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
            .preferredColorScheme(.dark)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close", systemImage: "xmark") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                    .fontWeight(.medium)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Add Movies", systemImage: "plus") {
                            showingAddMovies = true
                        }
                        
                        Button("Edit List", systemImage: "pencil") {
                            showingEditList = true
                        }
                        
                        if list.pinned {
                            Button("Unpin List", systemImage: "pin.slash") {
                                Task {
                                    await unpinList()
                                }
                            }
                        } else {
                            Button("Pin List", systemImage: "pin.fill") {
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
    
    private var listInfoSection: some View {
        VStack(spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                Text(list.name.uppercased())
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .tracking(1)
                
                if list.pinned {
                    Image(systemName: "pin.fill")
                        .foregroundColor(.yellow)
                        .font(.body)
                }
            }
            
            if let description = list.description, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
            
            Text("\(list.itemCount) FILMS")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white.opacity(0.7))
                .textCase(.uppercase)
                .tracking(1.2)
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
    
    private var backdropSection: some View {
        AsyncImage(url: URL(string: firstMovieBackdrop ?? "")) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            case .failure(_):
                // Fallback to default gradient when backdrop fails
                LinearGradient(
                    colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
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
    
    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 16) {
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
            
            Button("Add Movies") {
                showingAddMovies = true
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    @ViewBuilder
    private var moviesGridView: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
            ForEach(listItems) { item in
                MoviePosterView(item: item, list: list)
            }
        }
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
    @State private var selectedMovie: Movie?
    @State private var showingMovieDetails = false
    @State private var isLoadingMovie = false
    
    var body: some View {
        Button(action: {
            Task {
                await loadLatestMovieEntry()
            }
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
            .overlay(
                Group {
                    if isLoadingMovie {
                        Color.black.opacity(0.6)
                            .cornerRadius(12)
                            .overlay(
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            )
                    }
                }
            )
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
        .sheet(isPresented: $showingMovieDetails) {
            if let selectedMovie = selectedMovie {
                MovieDetailsView(movie: selectedMovie)
            }
        }
    }
    
    private func removeMovie() async {
        do {
            try await dataManager.removeMovieFromList(tmdbId: item.tmdbId, listId: list.id)
        } catch {
            print("Error removing movie: \(error)")
        }
    }
    
    private func loadLatestMovieEntry() async {
        isLoadingMovie = true
        
        do {
            let movies = try await dataManager.getMoviesByTmdbId(tmdbId: item.tmdbId)
            
            if movies.isEmpty {
                // No entries exist, create a placeholder movie for the unlogged state
                let placeholderMovie = Movie(
                    id: -1, // Use -1 to indicate this is a placeholder
                    title: item.movieTitle,
                    release_year: item.movieYear,
                    release_date: nil,
                    rating: nil,
                    detailed_rating: nil,
                    review: nil,
                    tags: nil,
                    watch_date: nil,
                    is_rewatch: nil,
                    tmdb_id: item.tmdbId,
                    overview: nil,
                    poster_url: item.moviePosterUrl,
                    backdrop_path: item.movieBackdropUrl,
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
                    genres: nil,
                    created_at: nil,
                    updated_at: nil
                )
                
                await MainActor.run {
                    selectedMovie = placeholderMovie
                    showingMovieDetails = true
                    isLoadingMovie = false
                }
            } else {
                // Find the latest entry (most recent watch_date or created_at)
                let latestMovie = movies.max { movie1, movie2 in
                    let date1 = movie1.watch_date ?? movie1.created_at ?? ""
                    let date2 = movie2.watch_date ?? movie2.created_at ?? ""
                    return date1 < date2
                }
                
                await MainActor.run {
                    selectedMovie = latestMovie
                    if latestMovie != nil {
                        showingMovieDetails = true
                    }
                    isLoadingMovie = false
                }
            }
        } catch {
            print("Error loading latest movie entry: \(error)")
            await MainActor.run {
                isLoadingMovie = false
            }
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
                backdropUrl: movie.backdropURL?.absoluteString,
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
    @State private var listItems: [ListItem] = []
    @State private var isReordering = false
    
    init(list: MovieList) {
        self.list = list
        self._listName = State(initialValue: list.name)
        self._listDescription = State(initialValue: list.description ?? "")
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // List Details Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("List Details")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        
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
                    }
                    
                    // List Items Section
                    if !listItems.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Movies")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                Button(isReordering ? "Done" : "Reorder") {
                                    withAnimation {
                                        isReordering.toggle()
                                    }
                                }
                                .foregroundColor(.blue)
                            }
                            
                            VStack(spacing: 12) {
                                ForEach(listItems) { item in
                                    EditableListItemView(
                                        item: item,
                                        isReordering: isReordering,
                                        onRemove: {
                                            await removeItem(item)
                                        }
                                    )
                                }
                                .onMove(perform: isReordering ? moveItems : nil)
                            }
                        }
                    }
                    
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                .padding()
            }
            .background(Color.black)
            .preferredColorScheme(.dark)
            .environment(\.editMode, isReordering ? .constant(.active) : .constant(.inactive))
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
            .onAppear {
                loadListItems()
            }
        }
    }
    
    private func loadListItems() {
        listItems = dataManager.getListItems(list)
    }
    
    private func moveItems(from source: IndexSet, to destination: Int) {
        listItems.move(fromOffsets: source, toOffset: destination)
        
        // Save the reordered items
        Task {
            do {
                try await dataManager.reorderListItems(list.id, items: listItems)
            } catch {
                errorMessage = error.localizedDescription
                // Reload items on error to revert changes
                loadListItems()
            }
        }
    }
    
    private func removeItem(_ item: ListItem) async {
        do {
            try await dataManager.removeMovieFromList(tmdbId: item.tmdbId, listId: list.id)
            loadListItems()
        } catch {
            errorMessage = error.localizedDescription
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

struct EditableListItemView: View {
    let item: ListItem
    let isReordering: Bool
    let onRemove: () async -> Void
    @State private var showingRemoveAlert = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Drag handle (only show when reordering)
            if isReordering {
                Image(systemName: "line.3.horizontal")
                    .font(.title2)
                    .foregroundColor(.gray)
                    .frame(width: 20)
            }
            
            // Movie poster
            AsyncImage(url: URL(string: item.moviePosterUrl ?? "")) { image in
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
            
            // Movie details
            VStack(alignment: .leading, spacing: 4) {
                Text(item.movieTitle)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .lineLimit(2)
                
                if let year = item.movieYear {
                    Text(String(year))
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            // Remove button (only show when not reordering)
            if !isReordering {
                Button(action: {
                    showingRemoveAlert = true
                }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.red)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding()
        .background(Color.gray.opacity(0.15))
        .cornerRadius(12)
        .alert("Remove Movie", isPresented: $showingRemoveAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) {
                Task {
                    await onRemove()
                }
            }
        } message: {
            Text("Remove '\(item.movieTitle)' from this list?")
        }
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
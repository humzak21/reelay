//
//  AddToListsView.swift
//  reelay2
//
//  Created by Humza Khalil on 8/9/25.
//

import SwiftUI

struct AddToListsView: View {
    let movie: Movie
    @ObservedObject private var listService = SupabaseListService.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedListIds: Set<UUID> = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingSuccess = false
    
    private var movieAlreadyInLists: Set<UUID> {
        var listsContainingMovie: Set<UUID> = []
        
        guard let tmdbId = movie.tmdb_id else { return listsContainingMovie }
        
        for list in listService.movieLists {
            let items = listService.getListItems(list)
            if items.contains(where: { $0.tmdbId == tmdbId }) {
                listsContainingMovie.insert(list.id)
            }
        }
        
        return listsContainingMovie
    }
    
    private var availableLists: [MovieList] {
        return listService.movieLists.filter { !movieAlreadyInLists.contains($0.id) }
    }
    
    private var listsAlreadyContainingMovie: [MovieList] {
        return listService.movieLists.filter { movieAlreadyInLists.contains($0.id) }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Movie info header
                movieInfoHeader
                
                // Lists content
                if listService.movieLists.isEmpty {
                    emptyStateView
                } else {
                    listsScrollView
                }
                
                Spacer()
                
                // Add button
                if !selectedListIds.isEmpty {
                    addToListsButton
                }
            }
            .background(Color(.systemBackground))
            .navigationTitle("Add to Lists")
            .navigationBarTitleDisplayMode(.inline)
            
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", systemImage: "xmark") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .alert("Success", isPresented: $showingSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Movie added to \(selectedListIds.count) list\(selectedListIds.count == 1 ? "" : "s")")
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                }
            }
        }
    }
    
    @ViewBuilder
    private var movieInfoHeader: some View {
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
            .frame(width: 50, height: 75)
            .cornerRadius(8)
            
            // Movie details
            VStack(alignment: .leading, spacing: 4) {
                Text(movie.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .lineLimit(2)
                
                Text(movie.formattedReleaseYear)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.gray.opacity(0.15))
    }
    
    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("No Lists Yet")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            Text("Create your first list to start organizing your movies.")
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
        }
    }
    
    @ViewBuilder
    private var listsScrollView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // Available lists section
                if !availableLists.isEmpty {
                    sectionHeader(title: "Available Lists", count: availableLists.count)
                    
                    ForEach(availableLists) { list in
                        listRow(list: list, isAvailable: true)
                    }
                }
                
                // Already in lists section
                if !listsAlreadyContainingMovie.isEmpty {
                    sectionHeader(title: "Already in Lists", count: listsAlreadyContainingMovie.count)
                    
                    ForEach(listsAlreadyContainingMovie) { list in
                        listRow(list: list, isAvailable: false)
                    }
                }
            }
            .padding(.top, 8)
        }
    }
    
    @ViewBuilder
    private func sectionHeader(title: String, count: Int) -> some View {
        HStack {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            Text("(\(count))")
                .font(.headline)
                .foregroundColor(.gray)
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 8)
    }
    
    @ViewBuilder
    private func listRow(list: MovieList, isAvailable: Bool) -> some View {
        Button(action: {
            if isAvailable {
                if selectedListIds.contains(list.id) {
                    selectedListIds.remove(list.id)
                } else {
                    selectedListIds.insert(list.id)
                }
            }
        }) {
            HStack(spacing: 12) {
                // Selection indicator
                Image(systemName: isAvailable ? 
                      (selectedListIds.contains(list.id) ? "checkmark.circle.fill" : "circle") : 
                      "checkmark.circle.fill")
                    .foregroundColor(isAvailable ? 
                                   (selectedListIds.contains(list.id) ? .blue : .gray) : 
                                   .green)
                    .font(.system(size: 20))
                
                // List info
                VStack(alignment: .leading, spacing: 2) {
                    Text(list.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(isAvailable ? .white : .gray)
                        .lineLimit(1)
                    
                    HStack(spacing: 8) {
                        Text("\(list.itemCount) movie\(list.itemCount == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        if list.ranked {
                            Image(systemName: "list.number")
                                .font(.caption)
                                .foregroundColor(.purple)
                        }
                        
                        if list.pinned {
                            Image(systemName: "pin.fill")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }
                
                Spacer()
                
                if !isAvailable {
                    Text("Already Added")
                        .font(.caption)
                        .foregroundColor(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.2))
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(isAvailable ? Color.clear : Color.gray.opacity(0.1))
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!isAvailable)
    }
    
    @ViewBuilder
    private var addToListsButton: some View {
        Button(action: {
            Task {
                await addMovieToSelectedLists()
            }
        }) {
            HStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16, weight: .medium))
                }
                
                Text("Add to \(selectedListIds.count) List\(selectedListIds.count == 1 ? "" : "s")")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.blue)
            .cornerRadius(12)
        }
        .disabled(isLoading)
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }
    
    private func addMovieToSelectedLists() async {
        guard let tmdbId = movie.tmdb_id else {
            errorMessage = "Movie missing TMDB ID"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        var successCount = 0
        var errors: [String] = []
        
        for listId in selectedListIds {
            do {
                try await listService.addMovieToList(
                    tmdbId: tmdbId,
                    title: movie.title,
                    posterUrl: movie.poster_url,
                    backdropPath: movie.backdrop_path,
                    year: movie.release_year,
                    listId: listId
                )
                successCount += 1
            } catch {
                if let listServiceError = error as? ListServiceError,
                   case .itemAlreadyExists = listServiceError {
                    // Skip already existing items silently
                    continue
                } else {
                    errors.append(error.localizedDescription)
                }
            }
        }
        
        isLoading = false
        
        if !errors.isEmpty {
            errorMessage = "Failed to add to some lists: \(errors.joined(separator: ", "))"
        } else if successCount > 0 {
            showingSuccess = true
        }
    }
}

#Preview {
    AddToListsView(movie: Movie(
        id: 1,
        title: "Sample Movie",
        release_year: 2023,
        release_date: "2023-01-01",
        rating: 4.0,
        detailed_rating: 85,
        review: nil,
        tags: nil,
        watch_date: "2023-01-01",
        is_rewatch: false,
        tmdb_id: 12345,
        overview: nil,
        poster_url: nil,
        backdrop_path: nil,
        director: nil,
        runtime: 120,
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
        genres: ["Action", "Drama"],
        created_at: nil,
        updated_at: nil,
        favorited: false
    ))
}
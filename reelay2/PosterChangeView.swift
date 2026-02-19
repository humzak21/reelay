//
//  PosterChangeView.swift
//  reelay2
//
//  Created by Humza Khalil
//

import SwiftUI

struct PosterChangeView: View {
    let tmdbId: Int
    let currentPosterUrl: String?
    let movieTitle: String
    let onPosterSelected: (String) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    private let tmdbService = TMDBService.shared
    private let dataManager = DataManager.shared
    private let movieService = SupabaseMovieService.shared
    
    @State private var availablePosters: [TMDBImage] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedPosterUrl: String?
    @State private var isUpdating = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Current poster section
                if let currentPosterUrl = currentPosterUrl {
                    currentPosterSection(currentPosterUrl)
                }
                
                // Available posters section
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                        ForEach(availablePosters) { poster in
                            posterTile(poster: poster)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
                
                if isLoading {
                    VStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        Text("Loading alternate posters...")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if availablePosters.isEmpty && !isLoading {
                    VStack(spacing: 16) {
                        Image(systemName: "photo.stack")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        
                        Text("No Alternate Posters")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(Color.adaptiveText(scheme: colorScheme))
                        
                        Text("This movie doesn't have alternate poster options available.")
                            .font(.body)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding()
                }
            }
            .background(Color.adaptiveBackground(scheme: colorScheme))
            .navigationTitle("Change Poster")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") {
                        dismiss()
                    }
                    .foregroundColor(Color.adaptiveText(scheme: colorScheme))
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Update", systemImage: "checkmark") {
                        if let selectedPosterUrl = selectedPosterUrl {
                            Task {
                                await updatePoster(selectedPosterUrl)
                            }
                        }
                    }
                    .disabled(selectedPosterUrl == nil || isUpdating)
                    .foregroundColor(selectedPosterUrl != nil ? .blue : .gray)
                }
            }
        }
        .task {
            await loadAlternatePosters()
        }
    }
    
    @ViewBuilder
    private func currentPosterSection(_ currentUrl: String) -> some View {
        VStack(spacing: 12) {
            Text("CURRENT POSTER")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.gray)
                .textCase(.uppercase)
                .tracking(1.2)
            
            AsyncImage(url: URL(string: currentUrl)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
            }
            .frame(width: 120, height: 180)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.blue, lineWidth: 2)
            )
            
            Text(movieTitle)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(Color.adaptiveText(scheme: colorScheme))
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            LinearGradient(
                colors: [
                    Color.adaptiveBackground(scheme: colorScheme).opacity(0.8), 
                    Color.adaptiveBackground(scheme: colorScheme)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    @ViewBuilder
    private func posterTile(poster: TMDBImage) -> some View {
        Button(action: {
            selectedPosterUrl = poster.fullURL
        }) {
            AsyncImage(url: poster.fullImageURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    )
            }
            .frame(height: 160)
            .clipped()
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        selectedPosterUrl == poster.fullURL ? Color.blue : Color.clear,
                        lineWidth: 3
                    )
            )
            .overlay(
                // Selection indicator
                Group {
                    if selectedPosterUrl == poster.fullURL {
                        VStack {
                            HStack {
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.blue)
                                    .background(
                                        Circle()
                                            .fill(Color.white)
                                            .frame(width: 20, height: 20)
                                    )
                            }
                            Spacer()
                        }
                        .padding(8)
                    }
                }
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func loadAlternatePosters() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let imagesResponse = try await tmdbService.getMovieImages(movieId: tmdbId)
            
            await MainActor.run {
                // Filter out the current poster and sort by vote average
                let currentPosterPath = currentPosterUrl?.components(separatedBy: "/").last?.replacingOccurrences(of: "w500", with: "")
                availablePosters = (imagesResponse.posters ?? [])
                    .filter { poster in
                        // Filter out current poster if it matches
                        if let currentPath = currentPosterPath {
                            return !poster.filePath.contains(currentPath)
                        }
                        return true
                    }
                    .sorted { $0.voteAverage > $1.voteAverage }
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to load alternate posters: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
    
    private func updatePoster(_ newPosterUrl: String) async {
        await MainActor.run {
            isUpdating = true
            errorMessage = nil
        }
        
        do {
            // Update movie entries with this TMDB ID
            try await movieService.updatePosterForTmdbId(tmdbId: tmdbId, newPosterUrl: newPosterUrl)
            
            // Update list items with this TMDB ID
            try await dataManager.updatePosterForTmdbId(tmdbId: tmdbId, newPosterUrl: newPosterUrl)
            
            await MainActor.run {
                // Call the callback to update the parent view
                onPosterSelected(newPosterUrl)
                isUpdating = false
                // Dismiss the view
                dismiss()
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to update poster: \(error.localizedDescription)"
                isUpdating = false
            }
        }
    }
}

#Preview {
    PosterChangeView(
        tmdbId: 550,
        currentPosterUrl: "https://image.tmdb.org/t/p/w500/pB8BM7pdSp6B6Ih7QZ4DrQ3PmJK.jpg",
        movieTitle: "Fight Club",
        onPosterSelected: { _ in }
    )
}
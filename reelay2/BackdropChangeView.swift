//
//  BackdropChangeView.swift
//  reelay2
//
//  Created by Humza Khalil on 8/9/25.
//

import SwiftUI

struct BackdropChangeView: View {
    let tmdbId: Int
    let currentBackdropUrl: String?
    let movieTitle: String
    let onBackdropSelected: (String) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var tmdbService = TMDBService.shared
    @StateObject private var dataManager = DataManager.shared
    @StateObject private var movieService = SupabaseMovieService.shared
    
    @State private var availableBackdrops: [TMDBImage] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedBackdropUrl: String?
    @State private var isUpdating = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Current backdrop section
                if let currentBackdropUrl = currentBackdropUrl {
                    currentBackdropSection(currentBackdropUrl)
                }
                
                // Available backdrops section
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                        ForEach(availableBackdrops) { backdrop in
                            backdropTile(backdrop: backdrop)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
                
                if isLoading {
                    VStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        Text("Loading alternate backdrops...")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if availableBackdrops.isEmpty && !isLoading {
                    VStack(spacing: 16) {
                        Image(systemName: "photo.stack")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        
                        Text("No Alternate Backdrops")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        
                        Text("This movie doesn't have alternate backdrop options available.")
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
            .background(Color.black)
            .navigationTitle("Change Backdrop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", systemImage: "xmark") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Update", systemImage: "checkmark") {
                        if let selectedBackdropUrl = selectedBackdropUrl {
                            Task {
                                await updateBackdrop(selectedBackdropUrl)
                            }
                        }
                    }
                    .disabled(selectedBackdropUrl == nil || isUpdating)
                    .foregroundColor(selectedBackdropUrl != nil ? .blue : .gray)
                }
            }
        }
        .task {
            await loadAlternateBackdrops()
        }
    }
    
    @ViewBuilder
    private func currentBackdropSection(_ currentUrl: String) -> some View {
        VStack(spacing: 12) {
            Text("CURRENT BACKDROP")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.gray)
                .textCase(.uppercase)
                .tracking(1.2)
            
            AsyncImage(url: URL(string: currentUrl.hasPrefix("http") ? currentUrl : "https://image.tmdb.org/t/p/w1280\(currentUrl)")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
            }
            .frame(width: 320, height: 180)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.blue, lineWidth: 2)
            )
            
            Text(movieTitle)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.8), Color.black],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    @ViewBuilder
    private func backdropTile(backdrop: TMDBImage) -> some View {
        Button(action: {
            selectedBackdropUrl = backdrop.fullBackdropURL
        }) {
            AsyncImage(url: backdrop.fullBackdropImageURL) { image in
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
            .frame(height: 100)
            .clipped()
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        selectedBackdropUrl == backdrop.fullBackdropURL ? Color.blue : Color.clear,
                        lineWidth: 3
                    )
            )
            .overlay(
                // Selection indicator
                Group {
                    if selectedBackdropUrl == backdrop.fullBackdropURL {
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
    
    private func loadAlternateBackdrops() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let imagesResponse = try await tmdbService.getMovieImages(movieId: tmdbId)
            
            await MainActor.run {
                // Filter out the current backdrop and sort by vote average
                let currentBackdropPath = currentBackdropUrl?.components(separatedBy: "/").last?.replacingOccurrences(of: "w1280", with: "")
                availableBackdrops = (imagesResponse.backdrops ?? [])
                    .filter { backdrop in
                        // Filter out current backdrop if it matches
                        if let currentPath = currentBackdropPath {
                            return !backdrop.filePath.contains(currentPath)
                        }
                        return true
                    }
                    .sorted { $0.voteAverage > $1.voteAverage }
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to load alternate backdrops: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
    
    private func updateBackdrop(_ newBackdropUrl: String) async {
        isUpdating = true
        
        do {
            // Update movie entries with this TMDB ID
            try await movieService.updateBackdropForTmdbId(tmdbId: tmdbId, newBackdropUrl: newBackdropUrl)
            
            // Update list items with this TMDB ID
            try await dataManager.updateBackdropForTmdbId(tmdbId: tmdbId, newBackdropUrl: newBackdropUrl)
            
            await MainActor.run {
                onBackdropSelected(newBackdropUrl)
                dismiss()
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to update backdrop: \(error.localizedDescription)"
                isUpdating = false
            }
        }
    }
}

#Preview {
    BackdropChangeView(
        tmdbId: 550,
        currentBackdropUrl: "https://image.tmdb.org/t/p/w1280/87hTDiay2N2qWyX4Ctx71Rm3dcJ.jpg",
        movieTitle: "Fight Club",
        onBackdropSelected: { _ in }
    )
}

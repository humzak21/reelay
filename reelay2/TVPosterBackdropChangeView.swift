//
//  TVPosterBackdropChangeView.swift
//  reelay2
//
//  Created for TV show poster and backdrop management
//

import SwiftUI

struct TVPosterBackdropChangeView: View {
    let tmdbId: Int
    let currentPosterUrl: String?
    let currentBackdropUrl: String?
    let tvShowName: String
    let onPosterSelected: (String) -> Void
    let onBackdropSelected: (String) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    private let tmdbService = TMDBService.shared
    private let dataManager = DataManager.shared
    private let televisionService = SupabaseTelevisionService.shared
    
    @State private var selectedTab: ImageType = .poster
    @State private var availablePosters: [TMDBImage] = []
    @State private var availableBackdrops: [TMDBImage] = []
    @State private var isLoadingPosters = false
    @State private var isLoadingBackdrops = false
    @State private var errorMessage: String?
    @State private var selectedPosterUrl: String?
    @State private var selectedBackdropUrl: String?
    @State private var isUpdating = false
    
    enum ImageType: String, CaseIterable {
        case poster = "Poster"
        case backdrop = "Backdrop"
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab picker
                Picker("Image Type", selection: $selectedTab) {
                    ForEach(ImageType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                
                // Current image section
                if selectedTab == .poster {
                    if let currentPosterUrl = currentPosterUrl {
                        currentPosterSection(currentPosterUrl)
                    }
                } else {
                    if let currentBackdropUrl = currentBackdropUrl {
                        currentBackdropSection(currentBackdropUrl)
                    }
                }
                
                // Available images section
                ScrollView {
                    if selectedTab == .poster {
                        posterGridView
                    } else {
                        backdropGridView
                    }
                }
                
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding()
                }
            }
            .background(Color.adaptiveBackground(scheme: colorScheme))
            .navigationTitle("Change \(selectedTab.rawValue)")
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
                        Task {
                            await updateSelectedImage()
                        }
                    }
                    .disabled(!hasSelection || isUpdating)
                    .foregroundColor(hasSelection ? .blue : .gray)
                }
            }
        }
        .task {
            await loadImages()
        }
        .onChange(of: selectedTab) { _, _ in
            Task {
                await loadImages()
            }
        }
    }
    
    private var hasSelection: Bool {
        selectedTab == .poster ? selectedPosterUrl != nil : selectedBackdropUrl != nil
    }
    
    // MARK: - Current Poster Section
    
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
            
            Text(tvShowName)
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
    
    // MARK: - Current Backdrop Section
    
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
            
            Text(tvShowName)
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
    
    // MARK: - Poster Grid View
    
    @ViewBuilder
    private var posterGridView: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
            ForEach(availablePosters) { poster in
                posterTile(poster: poster)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        
        if isLoadingPosters {
            VStack {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                Text("Loading alternate posters...")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.top, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if availablePosters.isEmpty && !isLoadingPosters {
            VStack(spacing: 16) {
                Image(systemName: "photo.stack")
                    .font(.system(size: 48))
                    .foregroundColor(.gray)
                
                Text("No Alternate Posters")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(Color.adaptiveText(scheme: colorScheme))
                
                Text("This TV show doesn't have alternate poster options available.")
                    .font(.body)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    // MARK: - Backdrop Grid View
    
    @ViewBuilder
    private var backdropGridView: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
            ForEach(availableBackdrops) { backdrop in
                backdropTile(backdrop: backdrop)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        
        if isLoadingBackdrops {
            VStack {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                Text("Loading alternate backdrops...")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.top, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if availableBackdrops.isEmpty && !isLoadingBackdrops {
            VStack(spacing: 16) {
                Image(systemName: "photo.stack")
                    .font(.system(size: 48))
                    .foregroundColor(.gray)
                
                Text("No Alternate Backdrops")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(Color.adaptiveText(scheme: colorScheme))
                
                Text("This TV show doesn't have alternate backdrop options available.")
                    .font(.body)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    // MARK: - Poster Tile
    
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
    
    // MARK: - Backdrop Tile
    
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
    
    // MARK: - Data Loading Functions
    
    private func loadImages() async {
        if selectedTab == .poster {
            await loadAlternatePosters()
        } else {
            await loadAlternateBackdrops()
        }
    }
    
    private func loadAlternatePosters() async {
        isLoadingPosters = true
        errorMessage = nil
        
        do {
            let imagesResponse = try await tmdbService.getTVSeriesImages(seriesId: tmdbId)
            
            await MainActor.run {
                let currentPosterPath = currentPosterUrl?.components(separatedBy: "/").last?.replacingOccurrences(of: "w500", with: "")
                availablePosters = (imagesResponse.posters ?? [])
                    .filter { poster in
                        if let currentPath = currentPosterPath {
                            return !poster.filePath.contains(currentPath)
                        }
                        return true
                    }
                    .sorted { $0.voteAverage > $1.voteAverage }
                isLoadingPosters = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to load alternate posters: \(error.localizedDescription)"
                isLoadingPosters = false
            }
        }
    }
    
    private func loadAlternateBackdrops() async {
        isLoadingBackdrops = true
        errorMessage = nil
        
        do {
            let imagesResponse = try await tmdbService.getTVSeriesImages(seriesId: tmdbId)
            
            await MainActor.run {
                let currentBackdropPath = currentBackdropUrl?.components(separatedBy: "/").last?.replacingOccurrences(of: "w1280", with: "")
                availableBackdrops = (imagesResponse.backdrops ?? [])
                    .filter { backdrop in
                        if let currentPath = currentBackdropPath {
                            return !backdrop.filePath.contains(currentPath)
                        }
                        return true
                    }
                    .sorted { $0.voteAverage > $1.voteAverage }
                isLoadingBackdrops = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to load alternate backdrops: \(error.localizedDescription)"
                isLoadingBackdrops = false
            }
        }
    }
    
    private func updateSelectedImage() async {
        isUpdating = true
        
        do {
            if selectedTab == .poster, let posterUrl = selectedPosterUrl {
                try await updatePoster(posterUrl)
            } else if selectedTab == .backdrop, let backdropUrl = selectedBackdropUrl {
                try await updateBackdrop(backdropUrl)
            }
            
            await MainActor.run {
                dismiss()
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to update \(selectedTab.rawValue.lowercased()): \(error.localizedDescription)"
                isUpdating = false
            }
        }
    }
    
    private func updatePoster(_ newPosterUrl: String) async throws {
        try await televisionService.updateTVPosterForTmdbId(tmdbId: tmdbId, newPosterUrl: newPosterUrl)
        try await dataManager.updateTVPosterForTmdbId(tmdbId: tmdbId, newPosterUrl: newPosterUrl)
        
        await MainActor.run {
            onPosterSelected(newPosterUrl)
        }
    }
    
    private func updateBackdrop(_ newBackdropUrl: String) async throws {
        try await televisionService.updateTVBackdropForTmdbId(tmdbId: tmdbId, newBackdropUrl: newBackdropUrl)
        try await dataManager.updateTVBackdropForTmdbId(tmdbId: tmdbId, newBackdropUrl: newBackdropUrl)
        
        await MainActor.run {
            onBackdropSelected(newBackdropUrl)
        }
    }
}

#Preview {
    TVPosterBackdropChangeView(
        tmdbId: 1396,
        currentPosterUrl: "https://image.tmdb.org/t/p/w500/ggFHVNu6YYI5L9pCfOacjizRGt.jpg",
        currentBackdropUrl: "https://image.tmdb.org/t/p/w1280/tsRy63Mu5cu8etL1X7ZLyf7UP1M.jpg",
        tvShowName: "Breaking Bad",
        onPosterSelected: { _ in },
        onBackdropSelected: { _ in }
    )
}

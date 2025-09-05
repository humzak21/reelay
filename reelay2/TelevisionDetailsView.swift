//
//  TelevisionDetailsView.swift
//  reelay2
//
//  Created by Humza Khalil on 9/1/25.
//

import SwiftUI
import SDWebImageSwiftUI

struct TelevisionDetailsView: View {
    let televisionShow: Television
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var dataManager = DataManager.shared
    @StateObject private var tmdbService = TMDBService.shared
    @StateObject private var televisionService = SupabaseTelevisionService.shared
    @StateObject private var streamingService = StreamingService.shared
    @State private var currentShow: Television
    @State private var isUpdatingProgress = false
    @State private var showingSeasonEpisodeSelector = false
    @State private var selectedSeason: Int
    @State private var selectedEpisode: Int
    @State private var showingStatusSelector = false
    @State private var selectedStatus: WatchingStatus
    @State private var streamingData: StreamingAvailabilityResponse?
    @State private var isLoadingStreaming = false
    
    init(televisionShow: Television) {
        self.televisionShow = televisionShow
        self._currentShow = State(initialValue: televisionShow)
        self._selectedSeason = State(initialValue: televisionShow.current_season ?? 1)
        self._selectedEpisode = State(initialValue: televisionShow.current_episode ?? 1)
        self._selectedStatus = State(initialValue: televisionShow.watchingStatus)
    }
    
    private var appBackground: Color {
        colorScheme == .dark ? .black : Color(.systemBackground)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 0) {
                    // Backdrop Section
                    backdropSection
                    
                    // Main Content
                    VStack(spacing: 16) {
                        // TV Show Header Section
                        showHeaderSection
                        
                        // Current Progress Section
                        currentProgressSection
                        
                        // Quick Actions Section
                        quickActionsSection
                        
                        // Status Section
                        statusSection
                        
                        // Current Episode Information Section
                        currentEpisodeSection
                        
                        // Streaming Availability Section
                        streamingSection
                        
                        // Show Metadata
                        metadataSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            }
            .background(appBackground)
            .ignoresSafeArea(edges: .top)
            .navigationTitle("TV Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close", systemImage: "xmark") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        Button(action: {
                            Task {
                                await toggleFavorite()
                            }
                        }) {
                            Image(systemName: currentShow.isFavorited ? "heart.fill" : "heart")
                                .foregroundColor(currentShow.isFavorited ? .orange : .primary)
                        }
                        
                        Menu {
                            Button("Delete Show", systemImage: "trash", role: .destructive) {
                                // TODO: Implement delete functionality
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingSeasonEpisodeSelector) {
            SeasonEpisodeSelectorView(
                currentSeason: $selectedSeason,
                currentEpisode: $selectedEpisode,
                maxSeasons: currentShow.number_of_seasons ?? 1,
                onSave: { season, episode in
                    Task {
                        await updateProgress(season: season, episode: episode)
                    }
                }
            )
        }
    }
    
    // MARK: - Backdrop Section
    
    @ViewBuilder
    private var backdropSection: some View {
        WebImage(url: currentShow.backdropURL) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
        } placeholder: {
            // Fallback gradient when no backdrop
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.gray.opacity(0.4), Color.gray.opacity(0.8)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
        .frame(height: 300)
        .clipped()
        .overlay(
            // Enhanced gradient overlay matching MovieDetailsView
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
    
    // MARK: - Show Header Section
    
    @ViewBuilder
    private var showHeaderSection: some View {
        HStack(alignment: .top, spacing: 16) {
            // Poster
            if let posterURL = currentShow.posterURL {
                WebImage(url: posterURL)
                    .resizable()
                    .aspectRatio(2/3, contentMode: .fill)
                    .frame(width: 120, height: 180)
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .aspectRatio(2/3, contentMode: .fill)
                    .frame(width: 120, height: 180)
                    .cornerRadius(12)
            }
            
            // Title and Info
            VStack(alignment: .leading, spacing: 8) {
                Text(currentShow.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                
                if let firstAirYear = currentShow.first_air_year {
                    Text("First Aired: \(String(firstAirYear))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                if let totalSeasons = currentShow.number_of_seasons,
                   let totalEpisodes = currentShow.number_of_episodes {
                    Text("\(totalSeasons) Season\(totalSeasons == 1 ? "" : "s"), \(totalEpisodes) Episodes")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                if let seriesStatus = currentShow.series_status {
                    Text(seriesStatus)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(8)
                }
                
                Spacer()
            }
            
            Spacer()
        }
    }
    
    // MARK: - Current Progress and Quick Actions Section
    
    @ViewBuilder
    private var currentProgressSection: some View {
        HStack(spacing: 15) {
            // Current Progress Card
            VStack(spacing: 10) {
                Text("CURRENT EPISODE")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.gray)
                    .textCase(.uppercase)
                    .tracking(0.5)
                
                Button(action: {
                    selectedSeason = currentShow.current_season ?? 1
                    selectedEpisode = currentShow.current_episode ?? 1
                    showingSeasonEpisodeSelector = true
                }) {
                    Text(currentShow.progressText)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
            .frame(maxWidth: .infinity, minHeight: 120)
            .padding(.vertical, 20)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(24)
            
            // Quick Actions Card
            VStack(spacing: 10) {
                Text("QUICK ACTIONS")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.gray)
                    .textCase(.uppercase)
                    .tracking(0.5)
                
                VStack(spacing: 8) {
                    Button(action: {
                        Task {
                            await nextEpisode()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "forward.fill")
                                .font(.caption)
                            Text("Next")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.white)
                        .frame(minWidth: 80)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue)
                        .cornerRadius(8)
                    }
                    .disabled(isUpdatingProgress)
                    
                    Button(action: {
                        Task {
                            await previousEpisode()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "backward.fill")
                                .font(.caption)
                            Text("Previous")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.white)
                        .frame(minWidth: 80)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.gray.opacity(0.5))
                        .cornerRadius(8)
                    }
                    .disabled(isUpdatingProgress)
                    
                    if currentShow.watchingStatus == .watching {
                        Button(action: {
                            Task {
                                await markAsCompleted()
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption)
                                Text("Complete")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.white)
                            .frame(minWidth: 80)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.green)
                            .cornerRadius(8)
                        }
                        .disabled(isUpdatingProgress)
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 120)
            .padding(.vertical, 20)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(24)
        }
    }
    
    @ViewBuilder
    private var quickActionsSection: some View {
        EmptyView()
    }
    
    // MARK: - Status Section
    
    @ViewBuilder
    private var statusSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Status")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
            }
            
            Menu {
                ForEach(WatchingStatus.allCases, id: \.self) { status in
                    Button(action: {
                        Task {
                            await updateStatus(status)
                        }
                    }) {
                        HStack {
                            Text(status.displayName)
                            if currentShow.watchingStatus == status {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    Text(currentShow.watchingStatus.displayName)
                        .font(.body)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .foregroundColor(.secondary)
                }
                .padding(16)
                .background(Color.gray.opacity(0.15))
                .cornerRadius(12)
            }
        }
        .padding(16)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(16)
    }
    
    // MARK: - Current Episode Section
    
    @ViewBuilder
    private var currentEpisodeSection: some View {
        // Only show if we have episode information
        if currentShow.current_episode_name != nil ||
           currentShow.current_episode_overview != nil ||
           currentShow.current_episode_air_date != nil {
            
            VStack(spacing: 12) {
                HStack {
                    Text("Current Episode")
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                }
                
                VStack(spacing: 16) {
                    // Episode still image and basic info
                    HStack(alignment: .top, spacing: 12) {
                        // Episode still image
                        if let stillURL = currentShow.currentEpisodeStillURL {
                            WebImage(url: stillURL)
                                .resizable()
                                .aspectRatio(16/9, contentMode: .fill)
                                .frame(width: 120, height: 68)
                                .cornerRadius(8)
                                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                        } else {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .aspectRatio(16/9, contentMode: .fill)
                                .frame(width: 120, height: 68)
                                .cornerRadius(8)
                        }
                        
                        // Episode info
                        VStack(alignment: .leading, spacing: 4) {
                            if let episodeName = currentShow.current_episode_name {
                                Text(episodeName)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.leading)
                            }
                            
                            HStack(spacing: 12) {
                                if let airDate = currentShow.formattedCurrentEpisodeAirDate {
                                    Text(airDate)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                if let runtime = currentShow.formattedCurrentEpisodeRuntime {
                                    Text("• \(runtime)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                if let rating = currentShow.formattedCurrentEpisodeRating {
                                    Text("• ⭐ \(rating)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                        }
                        
                        Spacer()
                    }
                    
                    // Episode overview
                    if let overview = currentShow.current_episode_overview, !overview.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Episode Summary")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            
                            Text(overview)
                                .font(.body)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.leading)
                        }
                    }
                }
            }
            .padding(16)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(16)
        }
    }
    
    // MARK: - Metadata Section
    
    @ViewBuilder
    private var metadataSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Show Information")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
            }
            
            if let overview = currentShow.overview, !overview.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Overview")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                    
                    Text(overview)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
            }
            
            if !currentShow.genreArray.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Genres")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                        Spacer()
                    }
                    
                    HStack {
                        Text(currentShow.genreArray.joined(separator: ", "))
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                        Spacer()
                    }
                }
            }
            
            if !currentShow.networkArray.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Networks")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                        Spacer()
                    }
                    
                    HStack {
                        Text(currentShow.networkArray.joined(separator: ", "))
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                        Spacer()
                    }
                }
            }
            
            if !currentShow.creatorArray.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Created By")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                        Spacer()
                    }
                    
                    HStack {
                        Text(currentShow.creatorArray.joined(separator: ", "))
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                        Spacer()
                    }
                }
            }
        }
        .padding(16)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(16)
    }
    
    // MARK: - Progress Update Functions
    
    private func nextEpisode() async {
        guard !isUpdatingProgress else { return }
        let newEpisode = (currentShow.current_episode ?? 1) + 1
        let currentSeasonNum = currentShow.current_season ?? 1
        
        await updateProgressWithEpisodeInfo(season: currentSeasonNum, episode: newEpisode)
    }
    
    private func previousEpisode() async {
        guard !isUpdatingProgress else { return }
        guard let currentEpisode = currentShow.current_episode, currentEpisode > 1 else { return }
        
        let newEpisode = currentEpisode - 1
        let currentSeasonNum = currentShow.current_season ?? 1
        
        await updateProgressWithEpisodeInfo(season: currentSeasonNum, episode: newEpisode)
    }
    
    private func updateProgress(season: Int, episode: Int) async {
        await updateProgressWithEpisodeInfo(season: season, episode: episode)
    }
    
    private func updateProgressWithEpisodeInfo(season: Int, episode: Int) async {
        guard !isUpdatingProgress else { return }
        isUpdatingProgress = true
        
        do {
            // Fetch episode information from TMDB if we have a TMDB ID
            var episodeName: String?
            var episodeOverview: String?
            var episodeAirDate: String?
            var episodeStillPath: String?
            var episodeRuntime: Int?
            var episodeVoteAverage: Double?
            
            if let tmdbId = currentShow.tmdb_id {
                do {
                    let episodeDetails = try await tmdbService.getTVEpisodeDetails(
                        seriesId: tmdbId,
                        seasonNumber: season,
                        episodeNumber: episode
                    )
                    
                    episodeName = episodeDetails.name
                    episodeOverview = episodeDetails.overview
                    episodeAirDate = episodeDetails.airDate
                    episodeStillPath = episodeDetails.stillPath
                    episodeRuntime = episodeDetails.runtime
                    episodeVoteAverage = episodeDetails.voteAverage
                } catch {
                    print("Failed to fetch episode details: \(error)")
                    // Continue without episode details - not a critical failure
                }
            }
            
            // Update progress and episode information
            _ = try await televisionService.updateProgressWithEpisodeInfo(
                id: currentShow.id,
                season: season,
                episode: episode,
                episodeName: episodeName,
                episodeOverview: episodeOverview,
                episodeAirDate: episodeAirDate,
                episodeStillPath: episodeStillPath,
                episodeRuntime: episodeRuntime,
                episodeVoteAverage: episodeVoteAverage
            )
            
            // Refresh data from DataManager
            await dataManager.refreshTelevision()
            
            // Update local state
            await MainActor.run {
                if let updatedShow = dataManager.allTelevision.first(where: { $0.id == currentShow.id }) {
                    currentShow = updatedShow
                }
            }
        } catch {
            print("Error updating progress with episode info: \(error)")
        }
        
        isUpdatingProgress = false
    }
    
    private func updateStatus(_ status: WatchingStatus) async {
        guard !isUpdatingProgress else { return }
        isUpdatingProgress = true
        
        do {
            try await dataManager.updateTelevisionStatus(id: currentShow.id, status: status)
            
            // Update local state
            await MainActor.run {
                if let updatedShow = dataManager.allTelevision.first(where: { $0.id == currentShow.id }) {
                    currentShow = updatedShow
                }
            }
        } catch {
            print("Error updating status: \(error)")
        }
        
        isUpdatingProgress = false
    }
    
    private func markAsCompleted() async {
        await updateStatus(.completed)
    }
    
    // MARK: - Streaming Availability Functions
    
    private func loadStreamingData() async {
        guard let tmdbId = currentShow.tmdb_id else { return }
        
        await MainActor.run {
            isLoadingStreaming = true
        }
        
        do {
            let streaming = try await streamingService.getTVShowStreamingAvailability(tmdbId: tmdbId, country: "us")
            await MainActor.run {
                streamingData = streaming
                isLoadingStreaming = false
            }
        } catch {
            await MainActor.run {
                streamingData = nil
                isLoadingStreaming = false
                print("Failed to load TV streaming data: \(error.localizedDescription)")
            }
        }
    }
    
    private func toggleFavorite() async {
        do {
            let updatedShow = try await televisionService.toggleTVShowFavorite(showId: currentShow.id)
            await MainActor.run {
                currentShow = updatedShow
            }
        } catch {
            print("Failed to toggle favorite: \(error.localizedDescription)")
        }
    }
    
    private var streamingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "tv.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.blue)
                
                Text("STREAMING AVAILABILITY")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.gray)
                    .textCase(.uppercase)
                    .tracking(0.5)
                
                Spacer()
                
                if isLoadingStreaming {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            if let streaming = streamingData {
                if streaming.error != nil {
                    Text("Streaming information not available")
                        .font(.body)
                        .foregroundColor(.gray)
                        .padding(.vertical, 8)
                } else {
                    let usStreamingOptions = streaming.streamingOptions["us"] ?? []
                    
                    if usStreamingOptions.isEmpty {
                        Text("Not currently available on major streaming platforms")
                            .font(.body)
                            .foregroundColor(.gray)
                            .padding(.vertical, 8)
                    } else {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                            ForEach(Array(usStreamingOptions.prefix(6)), id: \.link) { option in
                                TVStreamingServiceCard(streamingOption: option)
                            }
                        }
                        
                        if usStreamingOptions.count > 6 {
                            Text("+ \(usStreamingOptions.count - 6) more services")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .padding(.top, 8)
                        }
                    }
                }
            } else if !isLoadingStreaming {
                Button("Load Streaming Availability") {
                    Task {
                        await loadStreamingData()
                    }
                }
                .font(.body)
                .foregroundColor(.blue)
                .padding(.vertical, 8)
            }
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(16)
    }
}

// MARK: - Season/Episode Selector Sheet

struct SeasonEpisodeSelectorView: View {
    @Binding var currentSeason: Int
    @Binding var currentEpisode: Int
    let maxSeasons: Int
    let onSave: (Int, Int) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedSeason: Int
    @State private var selectedEpisode: Int
    
    init(currentSeason: Binding<Int>, currentEpisode: Binding<Int>, maxSeasons: Int, onSave: @escaping (Int, Int) -> Void) {
        self._currentSeason = currentSeason
        self._currentEpisode = currentEpisode
        self.maxSeasons = maxSeasons
        self.onSave = onSave
        self._selectedSeason = State(initialValue: currentSeason.wrappedValue)
        self._selectedEpisode = State(initialValue: currentEpisode.wrappedValue)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Select Season & Episode")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.top)
                
                HStack(spacing: 40) {
                    // Season Picker
                    VStack {
                        Text("Season")
                            .font(.headline)
                        
                        Picker("Season", selection: $selectedSeason) {
                            ForEach(1...maxSeasons, id: \.self) { season in
                                Text("Season \(season)")
                                    .tag(season)
                            }
                        }
                        .pickerStyle(WheelPickerStyle())
                        .frame(width: 150)
                    }
                    
                    // Episode Picker
                    VStack {
                        Text("Episode")
                            .font(.headline)
                        
                        Picker("Episode", selection: $selectedEpisode) {
                            ForEach(1...50, id: \.self) { episode in
                                Text("Episode \(episode)")
                                    .tag(episode)
                            }
                        }
                        .pickerStyle(WheelPickerStyle())
                        .frame(width: 150)
                    }
                }
                
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", systemImage: "xmark") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(selectedSeason, selectedEpisode)
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Status Selector Sheet

struct StatusSelectorView: View {
    @Binding var currentStatus: WatchingStatus
    let onSave: (WatchingStatus) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedStatus: WatchingStatus
    
    init(currentStatus: Binding<WatchingStatus>, onSave: @escaping (WatchingStatus) -> Void) {
        self._currentStatus = currentStatus
        self.onSave = onSave
        self._selectedStatus = State(initialValue: currentStatus.wrappedValue)
    }
    
    var body: some View {
        NavigationView {
            List {
                ForEach(WatchingStatus.allCases, id: \.self) { status in
                    Button(action: {
                        selectedStatus = status
                    }) {
                        HStack {
                            Text(status.displayName)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            if selectedStatus == status {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Status")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", systemImage: "xmark") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(selectedStatus)
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    TelevisionDetailsView(televisionShow: Television(
        id: 1,
        name: "Breaking Bad",
        first_air_year: 2008,
        first_air_date: "2008-01-20",
        last_air_date: "2013-09-29",
        rating: nil,
        detailed_rating: nil,
        review: nil,
        tags: nil,
        current_season: 3,
        current_episode: 7,
        total_seasons: 5,
        total_episodes: 62,
        status: "watching",
        tmdb_id: 1396,
        overview: "A high school chemistry teacher diagnosed with inoperable lung cancer turns to manufacturing and selling methamphetamine in order to secure his family's future.",
        poster_url: "/ggFHVNu6YYI5L9pCfOacjizRGt.jpg",
        backdrop_path: "/tsRy63Mu5cu8etL1X7ZLyf7UP1M.jpg",
        vote_average: 9.5,
        vote_count: 12345,
        popularity: 123.45,
        original_language: "en",
        original_name: "Breaking Bad",
        tagline: "Change the recipe",
        series_status: "Ended",
        homepage: "http://www.amc.com/shows/breaking-bad",
        genres: ["Drama", "Crime"],
        networks: ["AMC"],
        created_by: ["Vince Gilligan"],
        episode_run_time: [47],
        in_production: false,
        number_of_episodes: 62,
        number_of_seasons: 5,
        origin_country: ["US"],
        type: "Scripted",
        current_episode_name: "One Minute",
        current_episode_overview: "Hank's increasing volatility forces a confrontation with Jesse and trouble at work. Skyler pressures Walt to make a deal.",
        current_episode_air_date: "2010-05-02",
        current_episode_still_path: "/rUeBjHkqGWNxHiHVHRcUG5Pk6jl.jpg",
        current_episode_runtime: 47,
        current_episode_vote_average: 8.9,
        created_at: "2023-01-01T00:00:00Z",
        updated_at: "2023-01-01T00:00:00Z"
    ))
}

// MARK: - TV Streaming Service Card Component

struct TVStreamingServiceCard: View {
    let streamingOption: StreamingOption
    
    var body: some View {
        Button(action: {
            if let url = URL(string: streamingOption.link) {
                UIApplication.shared.open(url)
            }
        }) {
            VStack(spacing: 8) {
                VStack(spacing: 4) {
                    Text(streamingOption.service.name)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text(streamingOption.type.capitalized)
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
                
                if let price = streamingOption.price {
                    Text(price.formatted)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 60)
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(serviceBackgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(serviceBorderColor, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var serviceBackgroundColor: Color {
        switch streamingOption.service.id.lowercased() {
        case "netflix":
            return Color.red.opacity(0.1)
        case "prime", "amazon":
            return Color.blue.opacity(0.1)
        case "disney":
            return Color.purple.opacity(0.1)
        case "hbo", "max":
            return Color.purple.opacity(0.1)
        case "hulu":
            return Color.green.opacity(0.1)
        case "apple":
            return Color.gray.opacity(0.1)
        default:
            return Color.gray.opacity(0.05)
        }
    }
    
    private var serviceBorderColor: Color {
        switch streamingOption.service.id.lowercased() {
        case "netflix":
            return Color.red.opacity(0.3)
        case "prime", "amazon":
            return Color.blue.opacity(0.3)
        case "disney":
            return Color.purple.opacity(0.3)
        case "hbo", "max":
            return Color.purple.opacity(0.3)
        case "hulu":
            return Color.green.opacity(0.3)
        case "apple":
            return Color.gray.opacity(0.3)
        default:
            return Color.gray.opacity(0.2)
        }
    }
}

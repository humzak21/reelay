//
//  AddTelevisionView.swift
//  reelay2
//
//  Created by Humza Khalil on 9/1/25.
//

import SwiftUI
import SDWebImageSwiftUI

struct AddTelevisionView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var tmdbService = TMDBService.shared
    @StateObject private var televisionService = SupabaseTelevisionService.shared
    @StateObject private var dataManager = DataManager.shared
    
    // Search state
    @State private var searchText = ""
    @State private var searchResults: [TMDBTVShow] = []
    @State private var isSearching = false
    @State private var selectedShow: TMDBTVShow?
    @State private var searchTask: Task<Void, Never>?
    
    // Show details state
    @State private var showDetails: TMDBTVSeriesDetails?
    @State private var isLoadingDetails = false
    
    // User input state
    @State private var selectedSeason: Int = 1
    @State private var selectedEpisode: Int = 1
    @State private var watchingStatus: WatchingStatus = .watching
    @State private var isFavorited: Bool = false
    
    // UI state
    @State private var isAddingShow = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var showingSeasonEpisodeSelector = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if selectedShow == nil {
                    searchView
                } else {
                    addShowView
                }
            }
            .navigationTitle("Add TV Show")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color(.systemBackground))
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", systemImage: "xmark") {
                        dismiss()
                    }
                }
                
                if selectedShow != nil {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        HStack(spacing: 16) {
                            Button(action: {
                                isFavorited.toggle()
                            }) {
                                Image(systemName: isFavorited ? "heart.fill" : "heart")
                                    .foregroundColor(isFavorited ? .orange : .gray)
                            }
                            
                            Button("Add", systemImage: "checkmark") {
                                Task {
                                    await addShow()
                                }
                            }
                            .disabled(isAddingShow)
                        }
                    }
                }
            }
            .alert("Error", isPresented: $showingAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
            .sheet(isPresented: $showingSeasonEpisodeSelector) {
                seasonEpisodeSelectorSheet
            }
        }
        .task {
            // Auto-focus search if no show is pre-selected
            if selectedShow == nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    // Focus would go here if needed
                }
            }
        }
    }
    
    // MARK: - Search View
    
    @ViewBuilder
    private var searchView: some View {
        VStack {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("Search TV shows...", text: $searchText)
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
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                        searchResults = []
                        searchTask?.cancel()
                    }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(PlainButtonStyle())
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
            
            // Search results
            if searchResults.isEmpty && !searchText.isEmpty && !isSearching {
                Spacer()
                Text("No TV shows found")
                    .foregroundColor(.gray)
                    .font(.body)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(searchResults) { show in
                            TVShowRow(show: show) {
                                Task {
                                    await selectShow(show)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)
                }
            }
        }
    }
    
    // MARK: - Add Show View
    
    @ViewBuilder
    private var addShowView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Show Header
                if let show = selectedShow {
                    showHeaderSection(show: show)
                }
                
                // Current Progress Section
                currentProgressSection
                
                // Status Selection Section
                statusSelectionSection
                
                // Season/Episode Details (if available)
                if let details = showDetails {
                    seasonEpisodeDetailsSection(details: details)
                }
                
                Spacer(minLength: 100)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
    }
    
    @ViewBuilder
    private func showHeaderSection(show: TMDBTVShow) -> some View {
        HStack(alignment: .top, spacing: 16) {
            // Poster
            if let posterURL = show.posterURL {
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
            
            // Show Info
            VStack(alignment: .leading, spacing: 8) {
                Text(show.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                
                if let firstAirYear = show.firstAirYear {
                    Text("First Aired: \(String(firstAirYear))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                if let overview = show.overview, !overview.isEmpty {
                    Text(overview)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(4)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
            }
            
            Spacer()
        }
    }
    
    @ViewBuilder
    private var currentProgressSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Current Progress")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
            }
            
            Button(action: {
                showingSeasonEpisodeSelector = true
            }) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Season \(selectedSeason), Episode \(selectedEpisode)")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        
                        Text("Tap to change")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
                .padding(16)
                .background(Color.gray.opacity(0.15))
                .cornerRadius(12)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(16)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(16)
    }
    
    @ViewBuilder
    private var statusSelectionSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Watching Status")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
            }
            
            Picker("Status", selection: $watchingStatus) {
                ForEach(WatchingStatus.allCases, id: \.self) { status in
                    Text(status.displayName)
                        .tag(status)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
        }
        .padding(16)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(16)
    }
    
    @ViewBuilder
    private func seasonEpisodeDetailsSection(details: TMDBTVSeriesDetails) -> some View {
        VStack(spacing: 12) {
            HStack {
                Text("Show Information")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
            }
            
            if let totalSeasons = details.numberOfSeasons,
               let totalEpisodes = details.numberOfEpisodes {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Total Seasons")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(totalSeasons)")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text("Total Episodes")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(totalEpisodes)")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                }
            }
            
            if !details.genreNames.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Genres")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    Text(details.genreNames.joined(separator: ", "))
                        .font(.body)
                        .foregroundColor(.white)
                }
            }
        }
        .padding(16)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(16)
    }
    
    // MARK: - Actions
    
    private func selectShow(_ show: TMDBTVShow) async {
        selectedShow = show
        
        // Load show details
        isLoadingDetails = true
        do {
            let details = try await tmdbService.getTVSeriesDetails(seriesId: show.id)
            await MainActor.run {
                showDetails = details
                // Set max season limit based on show details
                if let totalSeasons = details.numberOfSeasons, selectedSeason > totalSeasons {
                    selectedSeason = 1
                }
            }
        } catch {
            print("Error loading show details: \(error)")
        }
        isLoadingDetails = false
    }
    
    private func performSearch() {
        searchTask?.cancel()
        
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else {
            searchResults = []
            return
        }
        
        Task {
            await performSearchDelayed()
        }
    }
    
    private func performSearchDelayed() async {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        await MainActor.run {
            isSearching = true
        }
        
        do {
            let results = try await tmdbService.searchTVShows(query: searchText, page: 1)
            await MainActor.run {
                searchResults = results.results
                isSearching = false
            }
        } catch {
            print("Search error: \(error)")
            await MainActor.run {
                searchResults = []
                isSearching = false
            }
        }
    }
    
    private func addShow() async {
        guard let show = selectedShow else { return }
        
        isAddingShow = true
        
        do {
            // Check if show already exists
            if let existingShow = try await televisionService.televisionExists(tmdbId: show.id) {
                await MainActor.run {
                    alertMessage = "This TV show is already in your library."
                    showingAlert = true
                    isAddingShow = false
                }
                return
            }
            
            // Fetch current episode information from TMDB
            var episodeName: String?
            var episodeOverview: String?
            var episodeAirDate: String?
            var episodeStillPath: String?
            var episodeRuntime: Int?
            var episodeVoteAverage: Double?
            
            do {
                let episodeDetails = try await tmdbService.getTVEpisodeDetails(
                    seriesId: show.id,
                    seasonNumber: selectedSeason,
                    episodeNumber: selectedEpisode
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
            
            // Create add request
            let addRequest = AddTelevisionRequest(
                name: show.name,
                tmdb_id: show.id,
                first_air_year: show.firstAirYear,
                first_air_date: show.firstAirDate,
                last_air_date: show.lastAirDate,
                overview: show.overview,
                poster_url: show.posterPath,
                backdrop_path: show.backdropPath,
                vote_average: show.voteAverage,
                vote_count: show.voteCount,
                popularity: show.popularity,
                original_language: show.originalLanguage,
                original_name: show.originalName,
                tagline: showDetails?.tagline,
                series_status: showDetails?.status,
                homepage: showDetails?.homepage,
                genres: showDetails?.genreNames,
                networks: showDetails?.networks?.map { $0.name },
                created_by: showDetails?.createdBy?.map { $0.name },
                episode_run_time: showDetails?.episodeRunTime,
                in_production: showDetails?.inProduction,
                number_of_episodes: showDetails?.numberOfEpisodes,
                number_of_seasons: showDetails?.numberOfSeasons,
                origin_country: show.originCountry,
                type: showDetails?.type,
                status: watchingStatus.rawValue,
                current_season: selectedSeason,
                current_episode: selectedEpisode,
                total_seasons: showDetails?.numberOfSeasons,
                total_episodes: showDetails?.numberOfEpisodes,
                rating: nil,
                detailed_rating: nil,
                review: nil,
                tags: nil,
                current_episode_name: episodeName,
                current_episode_overview: episodeOverview,
                current_episode_air_date: episodeAirDate,
                current_episode_still_path: episodeStillPath,
                current_episode_runtime: episodeRuntime,
                current_episode_vote_average: episodeVoteAverage,
                favorited: isFavorited,
                created_at: ISO8601DateFormatter().string(from: Date())
            )
            
            // Add to database
            _ = try await televisionService.addTelevision(addRequest)
            
            // Refresh data
            await dataManager.refreshTelevision()
            
            await MainActor.run {
                dismiss()
            }
        } catch {
            await MainActor.run {
                alertMessage = "Failed to add TV show: \(error.localizedDescription)"
                showingAlert = true
            }
        }
        
        isAddingShow = false
    }
}

// MARK: - TV Show Row Component

struct TVShowRow: View {
    let show: TMDBTVShow
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Poster
                if let posterURL = show.posterURL {
                    WebImage(url: posterURL)
                        .resizable()
                        .aspectRatio(2/3, contentMode: .fill)
                        .frame(width: 60, height: 90)
                        .cornerRadius(8)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .aspectRatio(2/3, contentMode: .fill)
                        .frame(width: 60, height: 90)
                        .cornerRadius(8)
                }
                
                // Show Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(show.name)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                    
                    if let firstAirYear = show.firstAirYear {
                        Text("First aired \(String(firstAirYear))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if let overview = show.overview, !overview.isEmpty {
                        Text(overview)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                }
                
                Spacer()
            }
            .padding(12)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Season/Episode Selector Sheet Extension

extension AddTelevisionView {
    private var seasonEpisodeSelectorSheet: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Where are you currently?")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.top)
                
                HStack(spacing: 40) {
                    // Season Picker
                    VStack {
                        Text("Season")
                            .font(.headline)
                        
                        Picker("Season", selection: $selectedSeason) {
                            ForEach(1...(showDetails?.numberOfSeasons ?? 10), id: \.self) { season in
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
                        showingSeasonEpisodeSelector = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done", systemImage: "checkmark") {
                        showingSeasonEpisodeSelector = false
                    }
                }
            }
        }
    }
}

#Preview {
    AddTelevisionView()
}
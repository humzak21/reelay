//
//  TelevisionView.swift
//  reelay2
//
//  Created for television show management and display
//

import SwiftUI
import SDWebImageSwiftUI

struct TelevisionView: View {
    @StateObject private var televisionService = SupabaseTelevisionService.shared
    @State private var televisionShows: [Television] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingAddTelevision = false
    @State private var sortBy: TVSortField = .name
    @State private var sortAscending = true
    @State private var showingSortOptions = false
    @State private var searchText = ""
    @State private var selectedShow: Television?
    @State private var showToDelete: Television?
    @State private var showingDeleteShowAlert: Bool = false
    @State private var viewMode: ViewMode = .list
    @State private var selectedStatus: WatchingStatus = .watching
    @State private var selectedTab: TabType = .status(.watching)
    
    enum TabType: Equatable {
        case status(WatchingStatus)
        case favorites
    }
    @State private var showingStatusPicker = false
    
    // MARK: - Efficient Loading States
    @State private var hasLoadedInitially = false
    @State private var lastRefreshTime: Date = Date.distantPast
    @State private var isRefreshing = false
    
    private let refreshInterval: TimeInterval = 300  // 5 minutes
    
    enum ViewMode {
        case list, tile
        
        var icon: String {
            switch self {
            case .list: return "square.grid.2x2"
            case .tile: return "list.bullet"
            }
        }
    }
    
    private var filteredShows: [Television] {
        let tabFiltered: [Television]
        switch selectedTab {
        case .status(let status):
            tabFiltered = televisionShows.filter { $0.watchingStatus == status }
        case .favorites:
            tabFiltered = televisionShows.filter { $0.isFavorited }
        }
        
        let searchFiltered = searchText.isEmpty ? tabFiltered : tabFiltered.filter { show in
            show.name.localizedCaseInsensitiveContains(searchText) ||
            (show.original_name?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
        return sortShows(searchFiltered)
    }
    
    private var watchingCount: Int {
        televisionShows.filter { $0.watchingStatus == .watching }.count
    }
    
    private var completedCount: Int {
        televisionShows.filter { $0.watchingStatus == .completed }.count
    }
    
    private var planToWatchCount: Int {
        televisionShows.filter { $0.watchingStatus == .planToWatch }.count
    }
    
    private var droppedCount: Int {
        televisionShows.filter { $0.watchingStatus == .dropped }.count
    }
    
    private var favoritesCount: Int {
        televisionShows.filter { $0.isFavorited }.count
    }
    
    // MARK: - Local Sorting Logic
    private func sortShows(_ shows: [Television]) -> [Television] {
        return shows.sorted { show1, show2 in
            switch sortBy {
            case .name:
                let name1 = show1.name.lowercased()
                let name2 = show2.name.lowercased()
                if name1 == name2 {
                    let created1 = show1.created_at ?? ""
                    let created2 = show2.created_at ?? ""
                    return sortAscending ? created1 < created2 : created1 > created2
                }
                return sortAscending ? name1 < name2 : name1 > name2
                
            case .firstAirDate:
                let date1 = show1.first_air_date ?? ""
                let date2 = show2.first_air_date ?? ""
                if date1 == date2 {
                    let created1 = show1.created_at ?? ""
                    let created2 = show2.created_at ?? ""
                    return sortAscending ? created1 < created2 : created1 > created2
                }
                return sortAscending ? date1 < date2 : date1 > date2
                
            case .rating:
                let rating1 = show1.rating ?? 0.0
                let rating2 = show2.rating ?? 0.0
                if rating1 == rating2 {
                    let created1 = show1.created_at ?? ""
                    let created2 = show2.created_at ?? ""
                    return sortAscending ? created1 < created2 : created1 > created2
                }
                return sortAscending ? rating1 < rating2 : rating1 > rating2
                
            case .status:
                let status1 = show1.status ?? ""
                let status2 = show2.status ?? ""
                if status1 == status2 {
                    let created1 = show1.created_at ?? ""
                    let created2 = show2.created_at ?? ""
                    return sortAscending ? created1 < created2 : created1 > created2
                }
                return sortAscending ? status1 < status2 : status1 > status2
                
            case .createdAt:
                let created1 = show1.created_at ?? ""
                let created2 = show2.created_at ?? ""
                return sortAscending ? created1 < created2 : created1 > created2
                
            case .updatedAt:
                let updated1 = show1.updated_at ?? ""
                let updated2 = show2.updated_at ?? ""
                return sortAscending ? updated1 < updated2 : updated1 > updated2
            }
        }
    }
    
    // MARK: - Main Content View
    @ViewBuilder
    private var mainContentView: some View {
        if isLoading && televisionShows.isEmpty {
            VStack(spacing: 0) {
                statusTabs
                loadingView
            }
        } else if televisionShows.isEmpty {
            VStack(spacing: 0) {
                statusTabs
                emptyStateView
            }
        } else if filteredShows.isEmpty {
            VStack(spacing: 0) {
                statusTabs
                emptyFilteredStateView
            }
        } else {
            contentView
        }
    }
    
    var body: some View {
        contentWithNavigation
    }
    
    private var contentWithNavigation: some View {
        VStack(spacing: 0) {
            mainContentView
        }
        .navigationTitle("TV Shows")
        .navigationBarTitleDisplayMode(.large)
        .background(Color(.systemBackground))
        .searchable(text: $searchText, placement: .navigationBarDrawer, prompt: "Search TV shows")
        .toolbar {
            toolbarContent
        }
        .task {
            if !hasLoadedInitially {
                await loadShowsIfNeeded(force: true)
                hasLoadedInitially = true
            }
        }
        .onAppear {
            if shouldRefreshData() {
                Task {
                    await loadShowsIfNeeded(force: false)
                }
            }
        }
        .onChange(of: showingAddTelevision) { _, isShowing in
            if !isShowing {
                Task {
                    await loadShowsIfNeeded(force: true)
                }
            }
        }
        .sheet(isPresented: $showingAddTelevision) {
            AddTelevisionView()
        }
        .confirmationDialog("Sort By", isPresented: $showingSortOptions) {
            ForEach(TVSortField.allCases, id: \.rawValue) { field in
                Button(field.displayName) {
                    if sortBy == field {
                        sortAscending.toggle()
                    } else {
                        sortBy = field
                        sortAscending = true
                    }
                }
            }
        }
        .alert("Delete TV Show", isPresented: $showingDeleteShowAlert) {
            Button("Delete", role: .destructive) {
                if let show = showToDelete {
                    deleteShow(show)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            if let show = showToDelete {
                Text("Are you sure you want to delete \"\(show.name)\"?")
            }
        }
        .sheet(item: $selectedShow) { show in
            TelevisionDetailsView(televisionShow: show)
        }
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            HStack(spacing: 16) {
                Button(action: { showingSortOptions = true }) {
                    Image(systemName: sortAscending ? "arrow.up" : "arrow.down")
                        .font(.system(size: 16, weight: .medium))
                }
                
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        viewMode = viewMode == .list ? .tile : .list
                    }
                }) {
                    Image(systemName: viewMode.icon)
                        .font(.system(size: 16, weight: .medium))
                }
            }
        }
        
        ToolbarItem(placement: .navigationBarTrailing) {
            Button(action: { showingAddTelevision = true }) {
                Image(systemName: "plus")
            }
        }
    }
    
    // MARK: - Status Tabs
    private var statusTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                statusTab(
                    status: .watching,
                    count: watchingCount,
                    icon: "play.circle.fill",
                    title: "Watching"
                )
                
                statusTab(
                    status: .completed,
                    count: completedCount,
                    icon: "checkmark.circle.fill",
                    title: "Completed"
                )
                
                statusTab(
                    status: .planToWatch,
                    count: planToWatchCount,
                    icon: "bookmark.circle",
                    title: "Plan to Watch"
                )
                
                statusTab(
                    status: .dropped,
                    count: droppedCount,
                    icon: "xmark.circle.fill",
                    title: "Dropped"
                )
                
                favoritesTab(
                    count: favoritesCount,
                    icon: "heart.fill",
                    title: "Best Shows"
                )
            }
            .padding(.horizontal)
        }
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 1),
            alignment: .bottom
        )
    }
    
    private func statusTab(status: WatchingStatus, count: Int, icon: String, title: String) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = .status(status)
                selectedStatus = status
            }
        }) {
            VStack(spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                    
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("(\(count))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .foregroundColor(selectedTab == .status(status) ? .blue : .primary)
                
                Rectangle()
                    .fill(selectedTab == .status(status) ? .blue : .clear)
                    .frame(height: 2)
                    .animation(.easeInOut(duration: 0.2), value: selectedTab)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    private func favoritesTab(count: Int, icon: String, title: String) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = .favorites
            }
        }) {
            VStack(spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(selectedTab == .favorites ? .orange : .primary)
                    
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("(\(count))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .foregroundColor(selectedTab == .favorites ? .orange : .primary)
                
                Rectangle()
                    .fill(selectedTab == .favorites ? .orange : .clear)
                    .frame(height: 2)
                    .animation(.easeInOut(duration: 0.2), value: selectedTab)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    // MARK: - Content Views
    private var contentView: some View {
        Group {
            switch viewMode {
            case .list:
                listView
            case .tile:
                tileView
            }
        }
    }
    
    private var listView: some View {
        VStack(spacing: 0) {
            statusTabs
            
            List {
                ForEach(filteredShows) { show in
                    TelevisionListRow(
                        television: show,
                        onTap: { selectedShow = show },
                        onDelete: { 
                            showToDelete = show
                            showingDeleteShowAlert = true
                        }
                    )
                    .contextMenu {
                        Button(action: {
                            Task {
                                await toggleTVShowFavorite(show)
                            }
                        }) {
                            Label(
                                show.isFavorited ? "Remove from Favorites" : "Add to Favorites",
                                systemImage: show.isFavorited ? "heart.fill" : "heart"
                            )
                        }
                        
                        Button(role: .destructive, action: {
                            showToDelete = show
                            showingDeleteShowAlert = true
                        }) {
                            Label("Delete Show", systemImage: "trash")
                        }
                    }
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }
            }
            .listStyle(PlainListStyle())
            .refreshable {
                await loadShowsIfNeeded(force: true)
            }
        }
    }
    
    private var tileView: some View {
        VStack(spacing: 0) {
            statusTabs
            
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ], spacing: 12) {
                    ForEach(filteredShows) { show in
                        TelevisionTileView(
                            television: show,
                            onTap: { selectedShow = show }
                        )
                        .contextMenu {
                            Button(action: {
                                Task {
                                    await toggleTVShowFavorite(show)
                                }
                            }) {
                                Label(
                                    show.isFavorited ? "Remove from Favorites" : "Add to Favorites",
                                    systemImage: show.isFavorited ? "heart.fill" : "heart"
                                )
                            }
                            
                            Button(role: .destructive, action: {
                                showToDelete = show
                                showingDeleteShowAlert = true
                            }) {
                                Label("Delete Show", systemImage: "trash")
                            }
                        }
                    }
                }
                .padding()
            }
            .refreshable {
                await loadShowsIfNeeded(force: true)
            }
        }
    }
    
    // MARK: - Empty States
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Loading TV shows...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "tv.circle")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("No TV Shows Yet")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Start building your watchlist by adding TV shows you want to track.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: {
                showingAddTelevision = true
            }) {
                Label("Add Your First TV Show", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyFilteredStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("No Results Found")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Try adjusting your search or check a different status.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Data Loading
    private func shouldRefreshData() -> Bool {
        return Date().timeIntervalSince(lastRefreshTime) > refreshInterval
    }
    
    private func loadShowsIfNeeded(force: Bool) async {
        guard !isRefreshing else { return }
        
        if !force && !shouldRefreshData() {
            return
        }
        
        await MainActor.run {
            if force || televisionShows.isEmpty {
                isLoading = true
            }
            isRefreshing = true
            errorMessage = nil
        }
        
        do {
            let loadedShows = try await televisionService.getTelevisionShows(limit: 1000)
            
            await MainActor.run {
                televisionShows = loadedShows
                isLoading = false
                isRefreshing = false
                lastRefreshTime = Date()
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
                isRefreshing = false
            }
        }
    }
    
    private func deleteShow(_ show: Television) {
        Task {
            do {
                try await televisionService.deleteTelevision(id: show.id)
                await loadShowsIfNeeded(force: true)
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func toggleTVShowFavorite(_ show: Television) async {
        do {
            let updatedShow = try await televisionService.toggleTVShowFavorite(showId: show.id)
            
            await MainActor.run {
                // Update the show in the local array
                if let index = televisionShows.firstIndex(where: { $0.id == show.id }) {
                    
                    // Create a new show with updated favorite status
                    televisionShows[index] = Television(
                        id: updatedShow.id,
                        name: updatedShow.name,
                        first_air_year: updatedShow.first_air_year,
                        first_air_date: updatedShow.first_air_date,
                        last_air_date: updatedShow.last_air_date,
                        rating: updatedShow.rating,
                        detailed_rating: updatedShow.detailed_rating,
                        review: updatedShow.review,
                        tags: updatedShow.tags,
                        current_season: updatedShow.current_season,
                        current_episode: updatedShow.current_episode,
                        total_seasons: updatedShow.total_seasons,
                        total_episodes: updatedShow.total_episodes,
                        status: updatedShow.status,
                        tmdb_id: updatedShow.tmdb_id,
                        overview: updatedShow.overview,
                        poster_url: updatedShow.poster_url,
                        backdrop_path: updatedShow.backdrop_path,
                        vote_average: updatedShow.vote_average,
                        vote_count: updatedShow.vote_count,
                        popularity: updatedShow.popularity,
                        original_language: updatedShow.original_language,
                        original_name: updatedShow.original_name,
                        tagline: updatedShow.tagline,
                        series_status: updatedShow.series_status,
                        homepage: updatedShow.homepage,
                        genres: updatedShow.genres,
                        networks: updatedShow.networks,
                        created_by: updatedShow.created_by,
                        episode_run_time: updatedShow.episode_run_time,
                        in_production: updatedShow.in_production,
                        number_of_episodes: updatedShow.number_of_episodes,
                        number_of_seasons: updatedShow.number_of_seasons,
                        origin_country: updatedShow.origin_country,
                        type: updatedShow.type,
                        current_episode_name: updatedShow.current_episode_name,
                        current_episode_overview: updatedShow.current_episode_overview,
                        current_episode_air_date: updatedShow.current_episode_air_date,
                        current_episode_still_path: updatedShow.current_episode_still_path,
                        current_episode_runtime: updatedShow.current_episode_runtime,
                        current_episode_vote_average: updatedShow.current_episode_vote_average,
                        created_at: updatedShow.created_at,
                        updated_at: updatedShow.updated_at,
                        favorited: updatedShow.favorited
                    )
                    
                    print("🔥 DEBUG TELEVISIONVIEW: Local array updated. New status: \(televisionShows[index].isFavorited)")
                } else {
                    print("🔥 DEBUG TELEVISIONVIEW: ERROR - Could not find show in local array!")
                }
            }
        } catch {
            print("🔥 DEBUG TELEVISIONVIEW ERROR: \(error.localizedDescription)")
            await MainActor.run {
                errorMessage = "Failed to update favorite status: \(error.localizedDescription)"
            }
        }
    }
}


// MARK: - Television List Row
struct TelevisionListRow: View {
    let television: Television
    let onTap: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // TV show poster
                WebImage(url: television.posterURL)
                    .resizable()
                    .indicator(.activity)
                    .transition(.fade(duration: 0.5))
                    .aspectRatio(2/3, contentMode: .fill)
                    .frame(width: 60, height: 90)
                    .cornerRadius(8)
                
                // TV show info
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(television.name)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        
                        if television.isFavorited {
                            Image(systemName: "heart.fill")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        
                        Spacer()
                    }
                    
                    if let originalName = television.original_name, originalName != television.name {
                        Text(originalName)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    HStack(spacing: 8) {
                        if let year = television.first_air_year {
                            Text(String(year))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if !television.genreArray.isEmpty {
                            Text(television.genreArray.prefix(2).joined(separator: ", "))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    
                    // Progress information
                    if television.isCurrentlyWatching {
                        Text(television.progressText)
                            .font(.caption2)
                            .foregroundColor(.blue)
                    } else if television.isCompleted {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption2)
                                .foregroundColor(.green)
                            Text("Completed")
                                .font(.caption2)
                                .foregroundColor(.green)
                        }
                    }
                }
                
                Spacer()
                
                // Status badge
                VStack(alignment: .trailing, spacing: 4) {
                    statusBadge
                    
                    if let rating = television.rating, rating > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundColor(.yellow)
                            Text(television.formattedRating)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.vertical, 4)
    }
    
    private var statusBadge: some View {
        Text(television.watchingStatus.displayName)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.2))
            .foregroundColor(statusColor)
            .cornerRadius(8)
    }
    
    private var statusColor: Color {
        switch television.watchingStatus {
        case .watching:
            return .green
        case .completed:
            return .blue
        case .dropped:
            return .red
        case .planToWatch:
            return .orange
        }
    }
}

// MARK: - Television Tile View
struct TelevisionTileView: View {
    let television: Television
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                // TV show poster
                WebImage(url: television.posterURL)
                    .resizable()
                    .indicator(.activity)
                    .transition(.fade(duration: 0.5))
                    .aspectRatio(2/3, contentMode: .fill)
                    .cornerRadius(12)
                    .overlay(
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                statusBadge
                            }
                            .padding(8)
                        }
                    )
                
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Text(television.name)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                        
                        if television.isFavorited {
                            Image(systemName: "heart.fill")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                    }
                    
                    if let year = television.first_air_year {
                        Text(String(year))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    if television.isCurrentlyWatching {
                        Text(television.progressText)
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    private var statusBadge: some View {
        Text(television.watchingStatus.displayName)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(statusColor.opacity(0.9))
            .foregroundColor(.white)
            .cornerRadius(6)
    }
    
    private var statusColor: Color {
        switch television.watchingStatus {
        case .watching:
            return .green
        case .completed:
            return .blue
        case .dropped:
            return .red
        case .planToWatch:
            return .orange
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationView {
        TelevisionView()
    }
}
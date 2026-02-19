//
//  AlbumsView.swift
//  reelay2
//
//  Created for album management and display
//

import SwiftUI
import SDWebImageSwiftUI

struct AlbumsView: View {
    @ObservedObject private var albumService = SupabaseAlbumService.shared
    @ObservedObject private var spotifyService = SpotifyService.shared
    @State private var albums: [Album] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingAddAlbum = false
    @State private var sortBy: AlbumSortField = .createdAt
    @State private var sortAscending = false
    @State private var showingSortOptions = false
    @State private var searchText = ""
    @State private var selectedAlbum: Album?
    @State private var albumToEdit: Album?
    @State private var albumToDelete: Album?
    @State private var showingDeleteAlbumAlert: Bool = false
    @State private var viewMode: ViewMode = .list
    @State private var selectedStatus: AlbumStatus = .wantToListen
    @State private var showingFavorites = false
    @State private var showingStatusPicker = false
    @State private var isRefreshingMetadata = false
    @State private var refreshingAlbumId: Int?
    
    // MARK: - Efficient Loading States
    @State private var hasLoadedInitially = false
    @State private var lastRefreshTime: Date = Date.distantPast
    @State private var isRefreshing = false
    
    private let refreshInterval: TimeInterval = 300  // 5 minutes
    
    #if os(macOS)
    @EnvironmentObject private var navigationCoordinator: NavigationCoordinator
    #endif
    
    enum ViewMode {
        case list, tile
        
        var icon: String {
            switch self {
            case .list: return "square.grid.2x2"
            case .tile: return "list.bullet"
            }
        }
    }
    
    private var filteredAlbums: [Album] {
        let statusFiltered = showingFavorites ? albums.filter { $0.isFavorited } : albums.filter { $0.albumStatus == selectedStatus }
        let searchFiltered = searchText.isEmpty ? statusFiltered : statusFiltered.filter { album in
            album.title.localizedCaseInsensitiveContains(searchText) ||
            album.artist.localizedCaseInsensitiveContains(searchText)
        }
        return sortAlbums(searchFiltered)
    }
    
    private var wantToListenCount: Int {
        albums.filter { $0.albumStatus == .wantToListen }.count
    }
    
    private var listenedCount: Int {
        albums.filter { $0.albumStatus == .listened }.count
    }
    
    private var favoritesCount: Int {
        albums.filter { $0.isFavorited }.count
    }
    
    // MARK: - Local Sorting Logic
    private func sortAlbums(_ albums: [Album]) -> [Album] {
        return albums.sorted { album1, album2 in
            switch sortBy {
            case .title:
                let title1 = album1.title.lowercased()
                let title2 = album2.title.lowercased()
                if title1 == title2 {
                    let created1 = album1.created_at
                    let created2 = album2.created_at
                    return sortAscending ? created1 < created2 : created1 > created2
                }
                return sortAscending ? title1 < title2 : title1 > title2
                
            case .artist:
                let artist1 = album1.artist.lowercased()
                let artist2 = album2.artist.lowercased()
                if artist1 == artist2 {
                    let created1 = album1.created_at
                    let created2 = album2.created_at
                    return sortAscending ? created1 < created2 : created1 > created2
                }
                return sortAscending ? artist1 < artist2 : artist1 > artist2
                
            case .releaseYear:
                let year1 = album1.release_year ?? 0
                let year2 = album2.release_year ?? 0
                if year1 == year2 {
                    let created1 = album1.created_at
                    let created2 = album2.created_at
                    return sortAscending ? created1 < created2 : created1 > created2
                }
                return sortAscending ? year1 < year2 : year1 > year2
                
            case .createdAt:
                let created1 = album1.created_at
                let created2 = album2.created_at
                return sortAscending ? created1 < created2 : created1 > created2
                
            case .listenedDate:
                let date1 = album1.listened_date ?? ""
                let date2 = album2.listened_date ?? ""
                if date1 == date2 {
                    let created1 = album1.created_at
                    let created2 = album2.created_at
                    return sortAscending ? created1 < created2 : created1 > created2
                }
                return sortAscending ? date1 < date2 : date1 > date2
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Main content with tabs inside scrollable areas
            if isLoading && albums.isEmpty {
                VStack(spacing: 0) {
                    statusTabs
                    loadingView
                }
            } else if albums.isEmpty {
                VStack(spacing: 0) {
                    statusTabs
                    emptyStateView
                }
            } else if filteredAlbums.isEmpty {
                VStack(spacing: 0) {
                    statusTabs
                    emptyFilteredStateView
                }
            } else {
                contentView
            }
        }
        .navigationTitle("Albums")
        #if canImport(UIKit)
        .navigationBarTitleDisplayMode(.large)
        .background(Color(.systemGroupedBackground))
        .searchable(text: $searchText, placement: .navigationBarDrawer, prompt: "Search albums")
        #else
        .background(Color(.windowBackgroundColor))
        .searchable(text: $searchText, prompt: "Search albums")
        #endif
        .toolbar {
            ToolbarItem(placement: .automatic) {
                HStack(spacing: 16) {
                    Button(action: {
                        showingSortOptions = true
                    }) {
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
            
            ToolbarItem(placement: .confirmationAction) {
                Button(action: {
                    showingAddAlbum = true
                }) {
                    Image(systemName: "plus")
                }
            }
        }
        .task {
            if albumService.isLoggedIn && !hasLoadedInitially {
                await loadAlbumsIfNeeded(force: true)
                hasLoadedInitially = true
            }
        }
        .onChange(of: albumService.isLoggedIn) { _, isLoggedIn in
            if isLoggedIn {
                Task {
                    await loadAlbumsIfNeeded(force: true)
                    hasLoadedInitially = true
                }
            } else {
                albums = []
                errorMessage = nil
                hasLoadedInitially = false
                lastRefreshTime = Date.distantPast
            }
        }
        .onAppear {
            if albumService.isLoggedIn && shouldRefreshData() {
                Task {
                    await loadAlbumsIfNeeded(force: false)
                }
            }
        }
        .sheet(isPresented: $showingAddAlbum) {
            AddAlbumsView()
        }
        .onChange(of: showingAddAlbum) { _, isShowing in
            if !isShowing && albumService.isLoggedIn {
                Task {
                    await loadAlbumsIfNeeded(force: true)
                }
            }
        }
        .confirmationDialog("Sort By", isPresented: $showingSortOptions) {
            ForEach(AlbumSortField.allCases, id: \.rawValue) { field in
                Button(field.displayName) {
                    if sortBy == field {
                        sortAscending.toggle()
                    } else {
                        sortBy = field
                        sortAscending = false
                    }
                }
            }
        }
        .alert("Delete Album", isPresented: $showingDeleteAlbumAlert) {
            Button("Delete", role: .destructive) {
                if let album = albumToDelete {
                    deleteAlbum(album)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            if let album = albumToDelete {
                Text("Are you sure you want to delete \"\(album.title)\" by \(album.artist)?")
            }
        }
        #if os(iOS)
        .sheet(item: $selectedAlbum) { album in
            AlbumDetailsView(album: album)
        }
        #else
        .onChange(of: selectedAlbum) { _, album in
            if let album = album {
                navigationCoordinator.showAlbumDetails(album)
                selectedAlbum = nil
            }
        }
        #endif
    }
    
    // MARK: - Status Tabs
    private var statusTabs: some View {
        HStack(spacing: 0) {
            statusTab(
                status: .wantToListen,
                count: wantToListenCount,
                icon: "headphones.circle",
                title: "To Listen"
            )
            
            statusTab(
                status: .listened,
                count: listenedCount,
                icon: "checkmark.circle.fill",
                title: "Listened"
            )
            
            favoritesTab(
                count: favoritesCount,
                icon: "heart.fill",
                title: "Best Albums"
            )
        }
        #if canImport(UIKit)
        .background(Color(.systemGroupedBackground))
        #else
        .background(Color(.windowBackgroundColor))
        #endif
        .overlay(
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 1),
            alignment: .bottom
        )
    }
    
    private func statusTab(status: AlbumStatus, count: Int, icon: String, title: String) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedStatus = status
                showingFavorites = false
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
                .foregroundColor(selectedStatus == status && !showingFavorites ? .blue : .primary)
                
                Rectangle()
                    .fill(selectedStatus == status && !showingFavorites ? .blue : .clear)
                    .frame(height: 2)
                    .animation(.easeInOut(duration: 0.2), value: selectedStatus)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
    
    private func favoritesTab(count: Int, icon: String, title: String) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                showingFavorites = true
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
                .foregroundColor(showingFavorites ? .orange : .primary)
                
                Rectangle()
                    .fill(showingFavorites ? .orange : .clear)
                    .frame(height: 2)
                    .animation(.easeInOut(duration: 0.2), value: showingFavorites)
            }
        }
        .frame(maxWidth: .infinity)
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
                ForEach(filteredAlbums) { album in
                    AlbumListRow(
                        album: album,
                        onTap: { selectedAlbum = album },
                        onToggleStatus: { toggleAlbumStatus(album) },
                        onDelete: { 
                            albumToDelete = album
                            showingDeleteAlbumAlert = true
                        },
                        onRefreshMetadata: album.spotify_id == nil ? { refreshMetadata(album) } : nil,
                        isRefreshingMetadata: refreshingAlbumId == album.id
                    )
                    .contextMenu {
                        Button(action: { toggleAlbumStatus(album) }) {
                            Label(
                                album.albumStatus == .listened ? "Mark as Want to Listen" : "Mark as Listened",
                                systemImage: album.albumStatus == .listened ? "headphones.circle" : "checkmark.circle"
                            )
                        }
                        
                        Button(action: { toggleAlbumFavorite(album) }) {
                            Label(
                                album.isFavorited ? "Remove from Favorites" : "Add to Favorites",
                                systemImage: album.isFavorited ? "heart.fill" : "heart"
                            )
                        }
                        
                        if album.spotify_id == nil {
                            Button(action: { refreshMetadata(album) }) {
                                Label("Refresh Metadata", systemImage: "arrow.clockwise")
                            }
                            .disabled(refreshingAlbumId == album.id)
                        }
                        
                        Divider()
                        
                        Button(role: .destructive, action: {
                            albumToDelete = album
                            showingDeleteAlbumAlert = true
                        }) {
                            Label("Delete Album", systemImage: "trash")
                        }
                    }
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }
            }
            .listStyle(PlainListStyle())
            .refreshable {
                await loadAlbumsIfNeeded(force: true)
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
                    ForEach(filteredAlbums) { album in
                        AlbumTileView(
                            album: album,
                            onTap: { selectedAlbum = album }
                        )
                        .contextMenu {
                            Button(action: { toggleAlbumStatus(album) }) {
                                Label(
                                    album.albumStatus == .listened ? "Mark as Want to Listen" : "Mark as Listened",
                                    systemImage: album.albumStatus == .listened ? "headphones.circle" : "checkmark.circle"
                                )
                            }
                            
                            Button(action: { toggleAlbumFavorite(album) }) {
                                Label(
                                    album.isFavorited ? "Remove from Favorites" : "Add to Favorites",
                                    systemImage: album.isFavorited ? "heart.fill" : "heart"
                                )
                            }
                            
                            if album.spotify_id == nil {
                                Button(action: { refreshMetadata(album) }) {
                                    Label("Refresh Metadata", systemImage: "arrow.clockwise")
                                }
                                .disabled(refreshingAlbumId == album.id)
                            }
                            
                            Divider()
                            
                            Button(role: .destructive, action: {
                                albumToDelete = album
                                showingDeleteAlbumAlert = true
                            }) {
                                Label("Delete Album", systemImage: "trash")
                            }
                        }
                    }
                }
                .padding()
            }
            .refreshable {
                await loadAlbumsIfNeeded(force: true)
            }
        }
    }
    
    // MARK: - Empty States
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Loading albums...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "music.note.house")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("No Albums Yet")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Start building your music collection by adding albums you want to listen to.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: {
                showingAddAlbum = true
            }) {
                Label("Add Your First Album", systemImage: "plus.circle.fill")
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
            Image(systemName: showingFavorites ? "heart" : "magnifyingglass")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text(showingFavorites ? "No Favorite Albums" : "No Results Found")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text(showingFavorites ? "Start adding albums to your favorites by tapping the heart icon." : "Try adjusting your search or check a different status.")
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
    
    private func loadAlbumsIfNeeded(force: Bool) async {
        guard !isRefreshing else { return }
        
        if !force && !shouldRefreshData() {
            return
        }
        
        await MainActor.run {
            if force || albums.isEmpty {
                isLoading = true
            }
            isRefreshing = true
            errorMessage = nil
        }
        
        do {
            let loadedAlbums = try await albumService.getAlbums(limit: 1000)
            
            await MainActor.run {
                albums = loadedAlbums
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
    
    private func toggleAlbumStatus(_ album: Album) {
        Task {
            do {
                let newStatus: AlbumStatus = album.albumStatus == .listened ? .wantToListen : .listened
                let updateRequest = UpdateAlbumRequest(
                    status: newStatus.rawValue,
                    listened_date: newStatus == .listened ? Date() : nil
                )
                
                let _ = try await albumService.updateAlbum(id: album.id, with: updateRequest)
                await loadAlbumsIfNeeded(force: true)
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func deleteAlbum(_ album: Album) {
        Task {
            do {
                try await albumService.deleteAlbum(id: album.id)
                await loadAlbumsIfNeeded(force: true)
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func refreshMetadata(_ album: Album) {
        guard album.spotify_id == nil else { return }
        
        Task {
            await MainActor.run {
                isRefreshingMetadata = true
                refreshingAlbumId = album.id
            }
            
            do {
                let _ = try await albumService.refreshAlbumMetadata(id: album.id, spotifyService: spotifyService)
                await loadAlbumsIfNeeded(force: true)
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to refresh metadata: \(error.localizedDescription)"
                }
            }
            
            await MainActor.run {
                isRefreshingMetadata = false
                refreshingAlbumId = nil
            }
        }
    }
    
    private func toggleAlbumFavorite(_ album: Album) {
        Task {
            do {
                try await albumService.toggleAlbumFavorite(albumId: album.id)
                await loadAlbumsIfNeeded(force: true)
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Album List Row
struct AlbumListRow: View {
    let album: Album
    let onTap: () -> Void
    let onToggleStatus: () -> Void
    let onDelete: () -> Void
    let onRefreshMetadata: (() -> Void)?
    let isRefreshingMetadata: Bool
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Album cover
                WebImage(url: album.coverURL)
                    .resizable()
                    .indicator(.activity)
                    .transition(.fade(duration: 0.5))
                    .aspectRatio(1, contentMode: .fill)
                    .frame(width: 60, height: 60)
                    .cornerRadius(8)
                
                // Album info
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text(album.title)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        
                        if album.isFavorited {
                            Image(systemName: "heart.fill")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        
                        Spacer()
                    }
                    
                    Text(album.artist)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    HStack(spacing: 8) {
                        if let year = album.release_year {
                            Text(String(year))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if !album.genreArray.isEmpty {
                            Text(album.genreArray.prefix(2).joined(separator: ", "))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    
                    if album.albumStatus == .listened, let listenedDate = album.listened_date {
                        Text("Listened: \(formatDate(listenedDate))")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
                }
                
                Spacer()
                
                // Centered checkmark button
                Button(action: onToggleStatus) {
                    Image(systemName: album.albumStatus == .listened ? "arrow.counterclockwise" : "checkmark.circle")
                        .font(.system(size: 20))
                        .foregroundColor(album.albumStatus == .listened ? .orange : .green)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.vertical, 4)
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "MMM d, yyyy"
            return displayFormatter.string(from: date)
        }
        
        return dateString
    }
}

// MARK: - Album Tile View
struct AlbumTileView: View {
    let album: Album
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                // Album cover with fixed size
                WebImage(url: album.coverURL)
                    .resizable()
                    .indicator(.activity)
                    .transition(.fade(duration: 0.5))
                    .aspectRatio(1, contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .cornerRadius(12)
                    .clipped()
                    .overlay(
                        // Favorite heart overlay
                        Group {
                            if album.isFavorited {
                                VStack {
                                    HStack {
                                        Image(systemName: "heart.fill")
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                            .padding(4)
                                            .background(
                                                Circle()
                                                    .fill(.ultraThinMaterial.opacity(0.6))
                                            )
                                            .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 1)
                                        Spacer()
                                    }
                                    Spacer()
                                }
                                .padding(6)
                            }
                        }, alignment: .topLeading
                    )
                
                // Fixed height text container
                VStack(spacing: 4) {
                    Text(album.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Text(album.artist)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .frame(height: 44)
                .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Preview
#Preview {
    NavigationView {
        AlbumsView()
    }
}

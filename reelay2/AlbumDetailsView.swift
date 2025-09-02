//
//  AlbumDetailsView.swift
//  reelay2
//
//  Created for album details display
//

import SwiftUI
import SDWebImageSwiftUI

struct AlbumDetailsView: View {
    let album: Album
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var albumService = SupabaseAlbumService.shared
    @StateObject private var spotifyService = SpotifyService.shared
    @State private var currentAlbum: Album
    @State private var showingDeleteAlert = false
    @State private var isDeletingAlbum = false
    @State private var showingChangeStatus = false
    @State private var newListenedDate = Date()
    @State private var isUpdatingStatus = false
    @State private var isRefreshingTracks = false
    
    init(album: Album) {
        self.album = album
        self._currentAlbum = State(initialValue: album)
    }
    
    private var appBackground: Color {
        colorScheme == .dark ? .black : Color(.systemBackground)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 0) {
                    // Album Cover Section (replaces backdrop)
                    albumCoverSection
                    
                    // Listen Date Section
                    if currentAlbum.albumStatus == .listened {
                        listenDateSection
                    }
                    
                    // Main Content
                    VStack(spacing: 16) {
                        // Album Header Section
                        albumHeaderSection
                        
                        // Status Card
                        statusCardSection
                        
                        // Tracklist Section
                        if let tracks = currentAlbum.tracks, !tracks.isEmpty {
                            tracklistSection
                        }
                        
                        // Album Metadata
                        metadataSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(appBackground)
                    
                    Spacer(minLength: 100)
                }
            }
            .refreshable {
                // Refresh album data
                await refreshAlbumData()
            }
            .background(appBackground.ignoresSafeArea())
            .ignoresSafeArea(edges: .top)
            .navigationTitle("Album Details")
            .navigationBarTitleDisplayMode(.inline)
            
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Change Status", systemImage: currentAlbum.albumStatus.systemImageName) {
                            showingChangeStatus = true
                        }
                        
                        if currentAlbum.tracks?.isEmpty != false {
                            Button("Refresh Tracks", systemImage: "arrow.clockwise") {
                                Task {
                                    await refreshTracksFromSpotify()
                                }
                            }
                            .disabled(isRefreshingTracks)
                        }
                        
                        Button("Delete Album", systemImage: "trash", role: .destructive) {
                            showingDeleteAlert = true
                        }
                        Button("Share", systemImage: "square.and.arrow.up") {
                            // Share action - to be implemented later
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                }
            }
        }
        .alert("Delete Album", isPresented: $showingDeleteAlert) {
            Button("Cancel", systemImage: "xmark", role: .cancel) { }
            Button("Delete", systemImage: "trash", role: .destructive) {
                Task {
                    await deleteAlbum()
                }
            }
        } message: {
            Text("Are you sure you want to delete '\(currentAlbum.title)' by \(currentAlbum.artist)? This action cannot be undone.")
        }
        .sheet(isPresented: $showingChangeStatus) {
            ChangeAlbumStatusSheet(
                currentStatus: currentAlbum.albumStatus,
                listenedDate: newListenedDate,
                onSave: { newStatus, listenDate in
                    Task {
                        await updateStatus(newStatus, listenedDate: listenDate)
                    }
                }
            )
        }
        .onAppear {
            Task {
                await refreshAlbumData()
            }
        }
    }
    
    // MARK: - Album Cover Section
    private var albumCoverSection: some View {
        // Album cover as backdrop
        WebImage(url: currentAlbum.coverURL)
            .resizable()
            .indicator(.activity)
            .transition(.fade(duration: 0.5))
            .aspectRatio(contentMode: .fill)
            .frame(height: 300)
            .clipped()
            .overlay(
                LinearGradient(
                    colors: [Color.clear, appBackground.opacity(0.8)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
    }
    
    // MARK: - Listen Date Section
    private var listenDateSection: some View {
        VStack(spacing: 8) {
            if let listenedDate = currentAlbum.listened_date {
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.green)
                        .font(.system(size: 16, weight: .medium))
                    
                    Text("Listened on \(formatDate(listenedDate))")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }
        }
    }
    
    // MARK: - Album Header Section
    private var albumHeaderSection: some View {
        HStack(alignment: .top, spacing: 16) {
            // Album cover (smaller)
            WebImage(url: currentAlbum.coverURL)
                .resizable()
                .indicator(.activity)
                .transition(.fade(duration: 0.5))
                .aspectRatio(1, contentMode: .fill)
                .frame(width: 120, height: 120)
                .cornerRadius(12)
                .shadow(radius: 8)
            
            VStack(alignment: .leading, spacing: 8) {
                Text(currentAlbum.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .lineLimit(3)
                
                Text(currentAlbum.artist)
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                if let year = currentAlbum.release_year {
                    Text(String(year))
                        .font(.subheadline)
                        .foregroundColor(Color(.tertiaryLabel))
                }
                
                if !currentAlbum.genreArray.isEmpty {
                    Text(currentAlbum.formattedGenres)
                        .font(.caption)
                        .foregroundColor(Color(.tertiaryLabel))
                        .lineLimit(2)
                }
            }
            
            Spacer()
        }
    }
    
    // MARK: - Status Card Section
    private var statusCardSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: currentAlbum.albumStatus.systemImageName)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(statusColor)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(currentAlbum.albumStatus.displayName)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(statusDescription)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if currentAlbum.albumStatus == .wantToListen {
                    Button(action: {
                        Task {
                            await markAsListened()
                        }
                    }) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(.green)
                    }
                    .disabled(isUpdatingStatus)
                }
            }
            .padding()
            .background(statusColor.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(statusColor.opacity(0.3), lineWidth: 1)
            )
        }
    }
    
    
    // MARK: - Metadata Section
    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Album Information")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                if let label = currentAlbum.label {
                    metadataRow(title: "Label", value: label)
                }
                
                if let country = currentAlbum.country {
                    metadataRow(title: "Country", value: country)
                }
                
                if let albumType = currentAlbum.album_type {
                    metadataRow(title: "Type", value: albumType.capitalized)
                }
                
                if let totalTracks = currentAlbum.total_tracks {
                    metadataRow(title: "Tracks", value: "\(totalTracks)")
                }
                
                if let catno = currentAlbum.catno {
                    metadataRow(title: "Catalog #", value: catno)
                }
                
                if let barcode = currentAlbum.barcode {
                    metadataRow(title: "Barcode", value: barcode)
                }
                
                metadataRow(title: "Added", value: formatDate(currentAlbum.created_at))
                
                if let spotifyId = currentAlbum.spotify_id {
                    metadataRow(title: "Spotify ID", value: spotifyId)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Tracklist Section
    private var tracklistSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Tracklist")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 0) {
                ForEach(currentAlbum.tracks?.sorted(by: { $0.track_number < $1.track_number }) ?? [], id: \.id) { track in
                    trackRow(track: track)
                    
                    if track.id != currentAlbum.tracks?.last?.id {
                        Divider()
                            .padding(.leading, 40)
                    }
                }
            }
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    private func trackRow(track: Track) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Track number
            Text("\(track.track_number)")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .frame(width: 24, alignment: .trailing)
            
            VStack(alignment: .leading, spacing: 4) {
                // Track title
                Text(track.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                
                // Artist and features
                if !track.fullArtistString.isEmpty {
                    Text(track.fullArtistString)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Duration
            if !track.formattedDuration.isEmpty && track.formattedDuration != "Unknown" {
                Text(track.formattedDuration)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    private func metadataRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .multilineTextAlignment(.trailing)
        }
    }
    
    // MARK: - Computed Properties
    private var statusColor: Color {
        switch currentAlbum.albumStatus {
        case .wantToListen: return .orange
        case .listened: return .green
        case .removed: return .red
        }
    }
    
    private var statusDescription: String {
        switch currentAlbum.albumStatus {
        case .wantToListen: return "This album is on your listen list"
        case .listened: return "You have listened to this album"
        case .removed: return "This album was removed from your list"
        }
    }
    
    // MARK: - Helper Methods
    private func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "MMMM d, yyyy"
            return displayFormatter.string(from: date)
        }
        
        return dateString
    }
    
    
    private func updateStatus(_ newStatus: AlbumStatus, listenedDate: Date?) async {
        isUpdatingStatus = true
        
        do {
            let updateRequest = UpdateAlbumRequest(
                status: newStatus.rawValue,
                listened_date: newStatus == .listened ? listenedDate : nil
            )
            let updatedAlbum = try await albumService.updateAlbum(id: currentAlbum.id, with: updateRequest)
            
            await MainActor.run {
                currentAlbum = updatedAlbum
                isUpdatingStatus = false
                showingChangeStatus = false
            }
        } catch {
            await MainActor.run {
                isUpdatingStatus = false
                // Handle error - could show alert
            }
        }
    }
    
    private func deleteAlbum() async {
        isDeletingAlbum = true
        
        do {
            try await albumService.deleteAlbum(id: currentAlbum.id)
            
            await MainActor.run {
                isDeletingAlbum = false
                dismiss()
            }
        } catch {
            await MainActor.run {
                isDeletingAlbum = false
                // Handle error - could show alert
            }
        }
    }
    
    private func markAsListened() async {
        isUpdatingStatus = true
        
        do {
            let updateRequest = UpdateAlbumRequest(
                status: AlbumStatus.listened.rawValue,
                listened_date: Date()
            )
            let updatedAlbum = try await albumService.updateAlbum(id: currentAlbum.id, with: updateRequest)
            
            await MainActor.run {
                currentAlbum = updatedAlbum
                isUpdatingStatus = false
            }
        } catch {
            await MainActor.run {
                isUpdatingStatus = false
                // Handle error - could show alert
            }
        }
    }
    
    private func refreshAlbumData() async {
        do {
            // Get the album with tracks from the database
            if let refreshedAlbum = try await albumService.getAlbumWithTracks(albumId: currentAlbum.id) {
                await MainActor.run {
                    currentAlbum = refreshedAlbum
                }
            }
        } catch {
            // Handle error silently for refresh
            print("Failed to refresh album data: \(error)")
        }
    }
    
    private func refreshTracksFromSpotify() async {
        await MainActor.run {
            isRefreshingTracks = true
        }
        
        do {
            // First, try to get the album from Spotify if we have a Spotify ID
            var spotifyAlbum: SpotifyAlbum?
            
            if let spotifyId = currentAlbum.spotify_id {
                // We have a Spotify ID, get the album directly
                spotifyAlbum = try await spotifyService.getAlbumDetails(albumId: spotifyId)
            } else {
                // Search for the album on Spotify
                let searchQuery = "\(currentAlbum.title) \(currentAlbum.artist)"
                let searchResponse = try await spotifyService.searchAlbums(query: searchQuery, limit: 5)
                
                // Find the best match
                if let searchResults = searchResponse.albums?.items, !searchResults.isEmpty {
                    spotifyAlbum = findBestSpotifyMatch(searchResults: searchResults)
                    
                    // If we found a match and don't have a Spotify ID, update the album with it
                    if let match = spotifyAlbum, currentAlbum.spotify_id == nil {
                        let updateRequest = UpdateAlbumRequest(spotify_id: match.id)
                        _ = try await albumService.updateAlbum(id: currentAlbum.id, with: updateRequest)
                    }
                }
            }
            
            // If we have a Spotify album with tracks, add them to our database
            if let album = spotifyAlbum,
               let spotifyTracks = album.tracks?.items,
               !spotifyTracks.isEmpty {
                
                // Delete existing tracks first (in case we're refreshing)
                try await albumService.deleteTracksForAlbum(albumId: currentAlbum.id)
                
                // Convert Spotify tracks to our Track model
                let tracks = spotifyTracks.compactMap { spotifyTrack -> Track? in
                    guard let trackName = spotifyTrack.name,
                          let trackNumber = spotifyTrack.trackNumber else { return nil }
                    
                    let artistName = spotifyTrack.artists?.first?.name
                    let featuredArtists = spotifyTrack.artists?.dropFirst().compactMap { $0.name }
                    
                    return Track(
                        id: 0, // Will be set by database
                        album_id: currentAlbum.id,
                        track_number: trackNumber,
                        title: trackName,
                        artist: artistName,
                        featured_artists: featuredArtists?.isEmpty == false ? Array(featuredArtists!) : nil,
                        duration_ms: spotifyTrack.durationMs,
                        spotify_id: spotifyTrack.id,
                        created_at: "", // Will be set by database
                        updated_at: "" // Will be set by database
                    )
                }
                
                // Save tracks to database
                let savedTracks = try await albumService.addTracksToAlbum(albumId: currentAlbum.id, tracks: tracks)
                
                // Update the current album with the saved tracks
                await MainActor.run {
                    var updatedAlbum = currentAlbum
                    updatedAlbum = Album(
                        id: updatedAlbum.id,
                        title: updatedAlbum.title,
                        artist: updatedAlbum.artist,
                        release_year: updatedAlbum.release_year,
                        release_date: updatedAlbum.release_date,
                        genres: updatedAlbum.genres,
                        label: updatedAlbum.label,
                        country: updatedAlbum.country,
                        spotify_id: updatedAlbum.spotify_id ?? album.id,
                        album_type: updatedAlbum.album_type,
                        total_tracks: updatedAlbum.total_tracks,
                        cover_image_url: updatedAlbum.cover_image_url,
                        spotify_uri: updatedAlbum.spotify_uri,
                        spotify_href: updatedAlbum.spotify_href,
                        catno: updatedAlbum.catno,
                        barcode: updatedAlbum.barcode,
                        status: updatedAlbum.status,
                        notes: updatedAlbum.notes,
                        user_id: updatedAlbum.user_id,
                        created_at: updatedAlbum.created_at,
                        updated_at: updatedAlbum.updated_at,
                        listened_date: updatedAlbum.listened_date,
                        tracks: savedTracks
                    )
                    currentAlbum = updatedAlbum
                }
            }
            
        } catch {
            print("Failed to refresh tracks from Spotify: \(error)")
        }
        
        await MainActor.run {
            isRefreshingTracks = false
        }
    }
    
    private func findBestSpotifyMatch(searchResults: [SpotifyAlbum]) -> SpotifyAlbum? {
        let originalTitle = currentAlbum.title.lowercased()
        let originalArtist = currentAlbum.artist.lowercased()
        
        // Look for exact matches first
        for result in searchResults {
            let spotifyTitle = (result.name ?? "").lowercased()
            let spotifyArtist = result.artistNames.lowercased()
            
            if spotifyTitle == originalTitle && spotifyArtist == originalArtist {
                return result
            }
        }
        
        // Look for partial matches
        for result in searchResults {
            let spotifyTitle = (result.name ?? "").lowercased()
            let spotifyArtist = result.artistNames.lowercased()
            
            let titleMatch = spotifyTitle.contains(originalTitle) || originalTitle.contains(spotifyTitle)
            let artistMatch = spotifyArtist.contains(originalArtist) || originalArtist.contains(spotifyArtist)
            
            if titleMatch && artistMatch {
                return result
            }
        }
        
        // Return first result if no good match found
        return searchResults.first
    }
}


// MARK: - Change Album Status Sheet
struct ChangeAlbumStatusSheet: View {
    let currentStatus: AlbumStatus
    @State var selectedStatus: AlbumStatus
    @State var listenedDate: Date
    let onSave: (AlbumStatus, Date?) -> Void
    @Environment(\.dismiss) private var dismiss
    
    init(currentStatus: AlbumStatus, listenedDate: Date, onSave: @escaping (AlbumStatus, Date?) -> Void) {
        self.currentStatus = currentStatus
        self._selectedStatus = State(initialValue: currentStatus)
        self._listenedDate = State(initialValue: listenedDate)
        self.onSave = onSave
    }
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Change album status")
                    .font(.headline)
                    .padding(.horizontal)
                
                VStack(spacing: 12) {
                    ForEach([AlbumStatus.wantToListen, AlbumStatus.listened], id: \.rawValue) { status in
                        Button(action: {
                            selectedStatus = status
                        }) {
                            HStack {
                                Image(systemName: status.systemImageName)
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(selectedStatus == status ? .blue : .secondary)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(status.displayName)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(selectedStatus == status ? .blue : .primary)
                                }
                                
                                Spacer()
                                
                                if selectedStatus == status {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding()
                            .background(selectedStatus == status ? Color.blue.opacity(0.1) : Color.clear)
                            .cornerRadius(12)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal)
                
                if selectedStatus == .listened {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Listen Date")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .padding(.horizontal)
                        
                        DatePicker("When did you listen to this?", selection: $listenedDate, displayedComponents: .date)
                            .datePickerStyle(CompactDatePickerStyle())
                            .padding(.horizontal)
                    }
                }
                
                Spacer()
            }
            .navigationTitle("Change Status")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", systemImage: "xmark") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save", systemImage: "checkmark") {
                        onSave(selectedStatus, selectedStatus == .listened ? listenedDate : nil)
                    }
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    AlbumDetailsView(album: Album(
        id: 1,
        title: "Sample Album",
        artist: "Sample Artist",
        release_year: 2023,
        created_at: "2023-01-01",
        updated_at: "2023-01-01"
    ))
}
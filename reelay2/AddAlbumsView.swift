//
//  AddAlbumsView.swift
//  reelay2
//
//  Created for album search and adding functionality
//

import SwiftUI
import SDWebImageSwiftUI

struct AddAlbumsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var spotifyService = SpotifyService.shared
    @StateObject private var supabaseService = SupabaseAlbumService.shared
    @StateObject private var dataManager = DataManager.shared
    
    // Search state
    @State private var searchText = ""
    @State private var searchResults: [SpotifyAlbum] = []
    @State private var isSearching = false
    @State private var selectedResult: SpotifyAlbum?
    @State private var searchTask: Task<Void, Never>?
    
    // Manual entry state
    @State private var isManualEntry = false
    @State private var manualTitle = ""
    @State private var manualArtist = ""
    @State private var manualReleaseYear: Int?
    @State private var manualGenres = ""
    @State private var manualLabel = ""
    @State private var manualAlbumType = ""
    @State private var manualCoverURL = ""
    @State private var entryMode: EntryMode = .search
    
    // Album details state
    @State private var albumDetails: SpotifyAlbum?
        @State private var isLoadingDetails = false
    
    // User input state
    @State private var notes: String = ""
    @State private var listenedDate = Date()
    @State private var hasListened = false
    @State private var isFavorited = false
    
    // UI state
    @State private var isAddingAlbum = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var previousEntries: [Album] = []
    @State private var showingPreviousEntries = false
    
    enum EntryMode {
        case search, manual
        
        var title: String {
            switch self {
            case .search: return "Search Spotify"
            case .manual: return "Manual Entry"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if selectedResult == nil && !isManualEntry {
                    mainView
                } else {
                    addAlbumView
                }
            }
            .navigationTitle("Add Album")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color(.systemBackground))
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", systemImage: "xmark") {
                        dismiss()
                    }
                }
                
                if selectedResult != nil || isManualEntry {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Add", systemImage: "checkmark") {
                            Task {
                                await addAlbum()
                            }
                        }
                        .disabled(isAddingAlbum || (isManualEntry && (manualTitle.isEmpty || manualArtist.isEmpty)))
                    }
                }
            }
            .alert("Error", isPresented: $showingAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
            .onDisappear {
                searchTask?.cancel()
            }
        }
    }
    
    // MARK: - Main View
    private var mainView: some View {
        VStack(spacing: 0) {
            // Mode selector
            modeSelectorView
            
            // Content based on selected mode
            if entryMode == .search {
                searchView
            } else {
                manualEntryView
            }
        }
    }
    
    private var modeSelectorView: some View {
        HStack(spacing: 0) {
            ForEach([EntryMode.search, EntryMode.manual], id: \.self) { mode in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        entryMode = mode
                        resetAllForms()
                    }
                }) {
                    VStack(spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: mode == .search ? "magnifyingglass" : "pencil")
                                .font(.system(size: 16, weight: .medium))
                            
                            Text(mode.title)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(entryMode == mode ? .blue : .primary)
                        
                        Rectangle()
                            .fill(entryMode == mode ? .blue : .clear)
                            .frame(height: 2)
                            .animation(.easeInOut(duration: 0.2), value: entryMode)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
        }
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 1),
            alignment: .bottom
        )
    }
    
    // MARK: - Search View
    private var searchView: some View {
        VStack {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("Search albums...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
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
                        .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                        .scaleEffect(0.8)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.2))
            .cornerRadius(10)
            .padding(.horizontal)
            
            // Search results
            if searchResults.isEmpty && !searchText.isEmpty && !isSearching {
                VStack(spacing: 16) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    
                    Text("No Results")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Try searching with different keywords.")
                        .font(.body)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if searchResults.isEmpty && searchText.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "music.note.house")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    
                    Text("Search Albums")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Search for albums to add to your listen list.")
                        .font(.body)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                searchResultsList
            }
            
            Spacer()
        }
        .background(Color(.systemBackground))
    }
    
    private var searchResultsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(searchResults) { result in
                    AlbumSearchResultRow(
                        result: result,
                        onSelect: {
                            selectAlbum(result)
                        }
                    )
                }
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Manual Entry View
    private var manualEntryView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Album Details")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .padding(.horizontal)
                    
                    VStack(spacing: 16) {
                        HStack {
                            Text("Title *")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .frame(width: 80, alignment: .leading)
                            
                            TextField("Album title", text: $manualTitle)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        
                        HStack {
                            Text("Artist *")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .frame(width: 80, alignment: .leading)
                            
                            TextField("Artist name", text: $manualArtist)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        
                        HStack {
                            Text("Year")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .frame(width: 80, alignment: .leading)
                            
                            TextField("Release year", value: $manualReleaseYear, format: .number)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.numberPad)
                        }
                        
                        HStack {
                            Text("Genres")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .frame(width: 80, alignment: .leading)
                            
                            TextField("Rock, Pop, Jazz (comma separated)", text: $manualGenres)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        
                        HStack {
                            Text("Label")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .frame(width: 80, alignment: .leading)
                            
                            TextField("Record label", text: $manualLabel)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        
                        HStack {
                            Text("Type")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .frame(width: 80, alignment: .leading)
                            
                            TextField("Album, EP, Single", text: $manualAlbumType)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Cover URL")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .frame(width: 80, alignment: .leading)
                                
                                TextField("https://...", text: $manualCoverURL)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .keyboardType(.URL)
                                    .autocapitalization(.none)
                            }
                            
                            if !manualCoverURL.isEmpty, let url = URL(string: manualCoverURL) {
                                HStack {
                                    Spacer().frame(width: 80)
                                    
                                    AsyncImage(url: url) { image in
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        Rectangle()
                                            .fill(Color.gray.opacity(0.3))
                                            .overlay(
                                                ProgressView()
                                                    .progressViewStyle(CircularProgressViewStyle())
                                            )
                                    }
                                    .frame(width: 80, height: 80)
                                    .cornerRadius(8)
                                    .clipped()
                                    
                                    Spacer()
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                Button(action: {
                    isManualEntry = true
                }) {
                    Text("Continue to Details")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            manualTitle.isEmpty || manualArtist.isEmpty ? 
                            Color.gray.opacity(0.3) : Color.blue
                        )
                        .cornerRadius(12)
                }
                .disabled(manualTitle.isEmpty || manualArtist.isEmpty)
                .padding(.horizontal)
                
                Spacer(minLength: 100)
            }
            .padding(.vertical)
        }
        .background(Color(.systemBackground))
    }
    
    // MARK: - Add Album View
    private var addAlbumView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                albumHeader
                
                if !previousEntries.isEmpty {
                    previousEntriesSection
                }
                
                listenStatusSection
                
                if hasListened {
                    listenedDateSection
                }
                
                notesSection
                
                Spacer(minLength: 100)
            }
            .padding()
        }
        .background(Color.black)
        .onAppear {
            if selectedResult != nil {
                Task {
                    await loadAlbumDetails()
                    await checkForExistingAlbum()
                }
            }
        }
    }
    
    // MARK: - Album Header
    private var albumHeader: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Button("← Back") {
                    if isManualEntry {
                        isManualEntry = false
                    } else {
                        selectedResult = nil
                        albumDetails = nil
                    }
                    resetForm()
                }
                .foregroundColor(.blue)
                
                Spacer()
            }
            
            if let result = selectedResult {
                HStack(alignment: .top, spacing: 15) {
                    WebImage(url: URL(string: result.primaryImage?.url ?? ""))
                        .resizable()
                        .indicator(.activity)
                        .transition(.fade(duration: 0.5))
                        .aspectRatio(1, contentMode: .fill)
                        .frame(width: 120, height: 120)
                        .cornerRadius(8)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(result.name ?? "Unknown Album")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(result.artistNames)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        if let year = result.releaseYear {
                            Text(year)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        if let albumType = result.albumType {
                            Text(albumType.capitalized)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if let label = result.label {
                            Text("Label: \(label)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                    }
                    
                    Spacer()
                }
            } else if isManualEntry {
                HStack(alignment: .top, spacing: 15) {
                    if !manualCoverURL.isEmpty, let url = URL(string: manualCoverURL) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .overlay(
                                    ProgressView()
                                )
                        }
                        .frame(width: 120, height: 120)
                        .cornerRadius(8)
                        .clipped()
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .overlay(
                                Image(systemName: "music.note")
                                    .font(.system(size: 30))
                                    .foregroundColor(.gray)
                            )
                            .frame(width: 120, height: 120)
                            .cornerRadius(8)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(manualTitle)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(manualArtist)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        if let year = manualReleaseYear {
                            Text(String(year))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        if !manualAlbumType.isEmpty {
                            Text(manualAlbumType.capitalized)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if !manualLabel.isEmpty {
                            Text("Label: \(manualLabel)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                    }
                    
                    Spacer()
                }
            }
        }
    }
    
    // MARK: - Previous Entries Section
    private var previousEntriesSection: some View {
        VStack(spacing: 0) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showingPreviousEntries.toggle()
                }
            }) {
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "clock")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.orange)
                        
                        Text("Previous Entries")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        
                        Text("\(previousEntries.count) previous \(previousEntries.count == 1 ? "entry" : "entries") found")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Image(systemName: showingPreviousEntries ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                }
                .padding(16)
                .background(Color.orange.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
                .cornerRadius(24)
            }
            
            if showingPreviousEntries {
                VStack(spacing: 12) {
                    ForEach(previousEntries) { entry in
                        AlbumPreviousEntryRow(album: entry)
                    }
                }
                .padding(.top, 12)
            }
        }
    }
    
    // MARK: - Listen Status Section
    private var listenStatusSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Listen Status")
                .font(.headline)
            
            Toggle("I have already listened to this album", isOn: $hasListened)
            
            // Favorite toggle
            HStack {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isFavorited.toggle()
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: isFavorited ? "heart.fill" : "heart")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(isFavorited ? .orange : .gray)
                        
                        Text(isFavorited ? "Remove from Favorites" : "Add to Favorites")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(isFavorited ? .orange : .primary)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
            }
        }
    }
    
    // MARK: - Listened Date Section
    private var listenedDateSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Date Listened")
                .font(.headline)
            
            DatePicker("When did you listen to this?", selection: $listenedDate, displayedComponents: .date)
                .datePickerStyle(CompactDatePickerStyle())
        }
    }
    
    // MARK: - Notes Section
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Notes")
                .font(.headline)
            
            TextField("Add notes about this album...", text: $notes, axis: .vertical)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .cornerRadius(24)
                .lineLimit(3...6)
        }
    }
    
    // MARK: - Helper Methods
    private func performSearch() {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else {
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
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else {
            searchResults = []
            return
        }
        
        isSearching = true
        
        do {
            let response = try await spotifyService.searchAlbums(query: searchText)
            searchResults = response.albums?.items ?? []
        } catch {
            print("Search error: \(error)")
            searchResults = []
        }
        
        isSearching = false
    }
    
    private func selectAlbum(_ result: SpotifyAlbum) {
        selectedResult = result
        resetForm()
    }
    
    private func loadAlbumDetails() async {
        guard let result = selectedResult else { return }
        
        isLoadingDetails = true
        
        do {
            let album = try await spotifyService.getAlbumDetails(albumId: result.id)
            await MainActor.run {
                albumDetails = album
                isLoadingDetails = false
            }
        } catch {
            await MainActor.run {
                isLoadingDetails = false
            }
        }
    }
    
    private func checkForExistingAlbum() async {
        guard let result = selectedResult else { return }
        
        do {
            let existingAlbums = try await supabaseService.getAlbums(
                searchQuery: result.name ?? ""
            )
            
            await MainActor.run {
                previousEntries = existingAlbums.filter { album in
                    album.spotify_id == result.id || 
                    album.title.lowercased() == (result.name ?? "").lowercased()
                }
            }
        } catch {
            await MainActor.run {
                previousEntries = []
            }
        }
    }
    
    private func addAlbum() async {
        guard selectedResult != nil || isManualEntry else { return }
        
        isAddingAlbum = true
        
        do {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            
            let status = hasListened ? AlbumStatus.listened.rawValue : AlbumStatus.wantToListen.rawValue
            let listenedDateString = hasListened ? formatter.string(from: listenedDate) : nil
            
            let albumRequest: AddAlbumRequest
            
            if let selectedResult = selectedResult {
                // Spotify result
                albumRequest = AddAlbumRequest(
                    title: selectedResult.name ?? "Unknown Album",
                    artist: selectedResult.artistNames,
                    release_year: selectedResult.releaseYear != nil ? Int(selectedResult.releaseYear!) : nil,
                    release_date: selectedResult.releaseDate,
                    genres: selectedResult.genres,
                    label: selectedResult.label,
                    country: nil,
                    spotify_id: selectedResult.id,
                    album_type: selectedResult.albumType,
                    total_tracks: selectedResult.totalTracks,
                    cover_image_url: selectedResult.primaryImage?.url,
                    spotify_uri: selectedResult.uri,
                    spotify_href: selectedResult.href,
                    status: status,
                    notes: notes.isEmpty ? nil : notes,
                    favorited: isFavorited
                )
            } else {
                // Manual entry
                let genresArray = manualGenres.isEmpty ? nil : 
                    manualGenres.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                
                albumRequest = AddAlbumRequest(
                    title: manualTitle,
                    artist: manualArtist,
                    release_year: manualReleaseYear,
                    release_date: nil,
                    genres: genresArray,
                    label: manualLabel.isEmpty ? nil : manualLabel,
                    country: nil,
                    spotify_id: nil,
                    album_type: manualAlbumType.isEmpty ? nil : manualAlbumType,
                    total_tracks: nil,
                    cover_image_url: manualCoverURL.isEmpty ? nil : manualCoverURL,
                    spotify_uri: nil,
                    spotify_href: nil,
                    status: status,
                    notes: notes.isEmpty ? nil : notes,
                    favorited: isFavorited
                )
            }
            
            let addedAlbum = try await supabaseService.addAlbum(albumRequest)
            
            // If this is a Spotify album, fetch and save the tracks
            if let selectedResult = selectedResult {
                await fetchAndSaveTracklist(for: addedAlbum, spotifyId: selectedResult.id)
            }
            
            // Update the listened date if applicable
            if hasListened {
                let updateRequest = UpdateAlbumRequest(listened_date: listenedDate)
                let _ = try await supabaseService.updateAlbum(id: addedAlbum.id, with: updateRequest)
            }
            
            await MainActor.run {
                isAddingAlbum = false
                dismiss()
            }
            
        } catch {
            await MainActor.run {
                isAddingAlbum = false
                alertMessage = "Failed to add album: \(error.localizedDescription)"
                showingAlert = true
            }
        }
    }
    
    private func resetForm() {
        notes = ""
        listenedDate = Date()
        hasListened = false
        isFavorited = false
        previousEntries = []
        showingPreviousEntries = false
    }
    
    private func resetAllForms() {
        // Reset search state
        searchText = ""
        searchResults = []
        searchTask?.cancel()
        selectedResult = nil
        albumDetails = nil
        
        // Reset manual entry state
        isManualEntry = false
        manualTitle = ""
        manualArtist = ""
        manualReleaseYear = nil
        manualGenres = ""
        manualLabel = ""
        manualAlbumType = ""
        manualCoverURL = ""
        
        // Reset common form state
        resetForm()
    }
    
    private func fetchAndSaveTracklist(for album: Album, spotifyId: String) async {
        print("🎵 Starting track fetch for album ID: \(album.id), Spotify ID: \(spotifyId)")
        
        do {
            // Use the dedicated album tracks endpoint for better efficiency
            print("🎵 Fetching tracks from Spotify...")
            let tracksResponse = try await spotifyService.getAlbumTracks(albumId: spotifyId, limit: 50)
            print("🎵 Received \(tracksResponse.items.count) tracks from Spotify")
            
            // If we have tracks, save them to the database
            if !tracksResponse.items.isEmpty {
                // Convert Spotify simplified tracks to our Track model
                let tracks = tracksResponse.items.compactMap { spotifyTrack -> Track? in
                    guard let trackName = spotifyTrack.name,
                          let trackNumber = spotifyTrack.trackNumber else { 
                        print("⚠️ Skipping track - missing name or track number")
                        return nil 
                    }
                    
                    let artistName = spotifyTrack.artists?.first?.name
                    let featuredArtists = spotifyTrack.artists?.dropFirst().compactMap { $0.name }
                    
                    return Track(
                        id: 0, // Will be set by database
                        album_id: album.id,
                        track_number: trackNumber,
                        title: trackName,
                        artist: artistName,
                        featured_artists: featuredArtists?.isEmpty == false ? Array(featuredArtists!) : nil,
                        duration_ms: spotifyTrack.durationMs,
                        spotify_id: spotifyTrack.id,
                        spotify_uri: spotifyTrack.uri,
                        spotify_href: spotifyTrack.href,
                        created_at: "", // Will be set by database
                        updated_at: "" // Will be set by database
                    )
                }
                
                print("🎵 Converted \(tracks.count) tracks, saving to database...")
                
                // Save tracks to database
                let savedTracks = try await supabaseService.addTracksToAlbum(albumId: album.id, tracks: tracks)
                print("✅ Successfully saved \(savedTracks.count) tracks to database")
            } else {
                print("⚠️ No tracks received from Spotify")
            }
        } catch {
            // Log the full error for debugging
            print("❌ Failed to fetch and save tracklist: \(error)")
            print("❌ Error details: \(error.localizedDescription)")
        }
    }
    
}

// MARK: - Album Search Result Row
struct AlbumSearchResultRow: View {
    let result: SpotifyAlbum
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Album cover
                AsyncImage(url: URL(string: result.primaryImage?.url ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: "music.note")
                                .foregroundColor(.gray)
                        )
                }
                .frame(width: 60, height: 60)
                .cornerRadius(8)
                .clipped()
                
                // Album details
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.name ?? "Unknown Album")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                    
                    Text(result.artistNames)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    if let year = result.releaseYear {
                        Text(year)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    
                    if let albumType = result.albumType {
                        Text(albumType.capitalized)
                            .font(.caption)
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                // Select button
                VStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16))
                        Text("Select")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.blue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(16)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .padding()
        .background(Color.gray.opacity(0.15))
        .cornerRadius(12)
    }
}

// MARK: - Album Previous Entry Row
struct AlbumPreviousEntryRow: View {
    let album: Album
    
    var body: some View {
        HStack(spacing: 12) {
            // Entry indicator
            Text(album.albumStatus == .listened ? "LI" : "WL")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 30, height: 20)
                .background(album.albumStatus == .listened ? Color.green : Color.orange)
                .cornerRadius(6)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(album.albumStatus.displayName)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                
                if let listenedDate = album.listened_date {
                    Text("Listened: \(formatDate(listenedDate))")
                        .font(.caption)
                        .foregroundColor(.gray)
                } else {
                    Text("Added: \(formatDate(album.created_at))")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                if let notes = album.notes, !notes.isEmpty {
                    Text("Notes: \(notes)")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(2)
                        .padding(.top, 2)
                }
            }
            
            Spacer()
        }
        .padding(12)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
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

// MARK: - Preview
#Preview {
    AddAlbumsView()
}
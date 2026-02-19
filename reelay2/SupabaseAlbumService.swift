//
//  SupabaseAlbumService.swift
//  reelay2
//
//  Created for album tracking functionality
//

import Foundation
import Supabase
import Combine

class SupabaseAlbumService: ObservableObject {
    static let shared = SupabaseAlbumService()
    
    // Use the shared authenticated client from SupabaseMovieService
    private var supabase: SupabaseClient {
        return SupabaseMovieService.shared.client
    }
    
    @Published var isLoggedIn = false
    @Published var currentUser: User?
    
    var client: SupabaseClient { supabase }
    
    private init() {
        // Check current auth state using shared client
        Task {
            await checkAuthState()
        }
    }
    
    // MARK: - Authentication
    
    @MainActor
    private func checkAuthState() async {
        do {
            let session = try await supabase.auth.session
            currentUser = session.user
            isLoggedIn = true
        } catch {
            currentUser = nil
            isLoggedIn = false
        }
    }
    
    // MARK: - CRUD Operations
    
    /// Get all albums with optional filtering and sorting
    nonisolated func getAlbums(
        searchQuery: String? = nil,
        status: AlbumStatus = .wantToListen,
        sortBy: AlbumSortField = .createdAt,
        ascending: Bool = false,
        limit: Int = 1000,
        offset: Int = 0
    ) async throws -> [Album] {
        
        var query = supabase
            .from("albums")
            .select()
        
        // Filter by status
        query = query.eq("status", value: status.rawValue)
        
        // Apply search filter
        if let searchQuery = searchQuery, !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty {
            query = query.or("title.ilike.%\(searchQuery)%,artist.ilike.%\(searchQuery)%")
        }
        
        // Apply sorting and pagination
        let sortColumn = sortBy.supabaseColumn
        let finalQuery = query.order(sortColumn, ascending: ascending)
                             .range(from: offset, to: offset + limit - 1)
        
        let response = try await finalQuery.execute()
        
        if response.data.isEmpty {
            return []
        }
        
        let responseString = String(data: response.data, encoding: .utf8) ?? ""
        
        // If response is just [], the table is empty
        if responseString.trimmingCharacters(in: .whitespacesAndNewlines) == "[]" {
            return []
        }
        
        let albums: [Album] = try JSONDecoder().decode([Album].self, from: response.data)
        return albums
    }
    
    /// Add a new album to the list
    nonisolated func addAlbum(_ albumData: AddAlbumRequest) async throws -> Album {

        
        do {
            let response = try await supabase
                .from("albums")
                .insert(albumData)
                .select()
                .execute()
            

            let albums: [Album] = try JSONDecoder().decode([Album].self, from: response.data)
            guard let album = albums.first else {
                throw SupabaseAlbumError.noAlbumReturned
            }
            

            return album
        } catch {

            throw error
        }
    }
    
    /// Update an existing album
    nonisolated func updateAlbum(id: Int, with albumData: UpdateAlbumRequest) async throws -> Album {
        let response = try await supabase
            .from("albums")
            .update(albumData)
            .eq("id", value: id)
            .select()
            .execute()
        
        let albums: [Album] = try JSONDecoder().decode([Album].self, from: response.data)
        guard let album = albums.first else {
            throw SupabaseAlbumError.noAlbumReturned
        }
        
        return album
    }
    
    /// Delete an album
    nonisolated func deleteAlbum(id: Int) async throws {
        try await supabase
            .from("albums")
            .delete()
            .eq("id", value: id)
            .execute()
    }
    
    /// Check if an album with the given Spotify ID already exists
    nonisolated func albumExists(spotifyId: String) async throws -> Album? {
        let response = try await supabase
            .from("albums")
            .select()
            .eq("spotify_id", value: spotifyId)
            .limit(1)
            .execute()
        
        let albums: [Album] = try JSONDecoder().decode([Album].self, from: response.data)
        return albums.first
    }
    
    /// Mark album as listened
    nonisolated func markAsListened(id: Int, listenedDate: Date = Date()) async throws -> Album {
        let updateData = UpdateAlbumRequest(
            status: AlbumStatus.listened.rawValue,
            listened_date: listenedDate
        )
        
        return try await updateAlbum(id: id, with: updateData)
    }
    
    /// Mark album as want to listen again
    nonisolated func markAsWantToListen(id: Int) async throws -> Album {
        let updateData = UpdateAlbumRequest(
            status: AlbumStatus.wantToListen.rawValue,
            listened_date: nil
        )
        
        return try await updateAlbum(id: id, with: updateData)
    }
    
    /// Get albums by status
    nonisolated func getAlbumsByStatus(_ status: AlbumStatus) async throws -> [Album] {
        return try await getAlbums(status: status)
    }
    
    /// Get count of albums by status
    nonisolated func getAlbumCount(status: AlbumStatus? = nil) async throws -> Int {
        var query = supabase
            .from("albums")
            .select("id", head: true)
        
        if let status = status {
            query = query.eq("status", value: status.rawValue)
        }
        
        let response = try await query.execute()
        return response.count ?? 0
    }
    
    /// Refresh album metadata from Spotify for albums that have Spotify IDs
    nonisolated func refreshAlbumMetadata(id: Int, spotifyService: SpotifyService) async throws -> Album {
        // First get the current album
        let currentAlbums = try await getAlbums()
        guard let album = currentAlbums.first(where: { $0.id == id }) else {
            throw SupabaseAlbumError.albumNotFound
        }
        
        // Only refresh if album has no Spotify ID (manual entry)
        guard album.spotify_id == nil else {
            return album // Already has Spotify metadata
        }
        
        // Search for the album on Spotify
        let searchQuery = "\(album.title) \(album.artist)"
        let searchResponse = try await spotifyService.searchAlbums(query: searchQuery)
        
        guard let spotifyResults = searchResponse.albums?.items,
              !spotifyResults.isEmpty else {
            throw SupabaseAlbumError.noAlbumReturned
        }
        
        // Find the best match
        let bestMatch = findBestSpotifyMatch(originalAlbum: album, spotifyResults: spotifyResults)
        
        guard let match = bestMatch else {
            throw SupabaseAlbumError.noAlbumReturned
        }
        
        // Get detailed album info
        let detailedAlbum = try await spotifyService.getAlbumDetails(albumId: match.id)
        
        // Update the album with Spotify metadata
        let updateRequest = UpdateAlbumRequest(
            release_year: detailedAlbum.releaseYear != nil ? Int(detailedAlbum.releaseYear!) : nil,
            release_date: detailedAlbum.releaseDate,
            genres: detailedAlbum.genres,
            spotify_id: detailedAlbum.id,
            album_type: detailedAlbum.albumType,
            total_tracks: detailedAlbum.totalTracks,
            cover_image_url: detailedAlbum.primaryImage?.url,
            spotify_uri: detailedAlbum.uri,
            spotify_href: detailedAlbum.href
        )
        
        return try await updateAlbum(id: id, with: updateRequest)
    }
    
    /// Find the best Spotify match for a manual album entry
    private func findBestSpotifyMatch(originalAlbum: Album, spotifyResults: [SpotifyAlbum]) -> SpotifyAlbum? {
        let originalTitle = originalAlbum.title.lowercased()
        let originalArtist = originalAlbum.artist.lowercased()
        
        // Look for exact matches first
        for result in spotifyResults {
            let spotifyTitle = (result.name ?? "").lowercased()
            let spotifyArtist = result.artistNames.lowercased()
            
            if spotifyTitle == originalTitle && spotifyArtist == originalArtist {
                return result
            }
        }
        
        // Look for partial matches
        for result in spotifyResults {
            let spotifyTitle = (result.name ?? "").lowercased()
            let spotifyArtist = result.artistNames.lowercased()
            
            let titleMatch = spotifyTitle.contains(originalTitle) || originalTitle.contains(spotifyTitle)
            let artistMatch = spotifyArtist.contains(originalArtist) || originalArtist.contains(spotifyArtist)
            
            if titleMatch && artistMatch {
                return result
            }
        }
        
        // Return first result if no good match found
        return spotifyResults.first
    }
    
    // MARK: - Track Management
    
    /// Add tracks to an album
    nonisolated func addTracksToAlbum(albumId: Int, tracks: [Track]) async throws -> [Track] {

        
        // Convert tracks to insert format (without id, created_at, updated_at)
        let tracksToInsert = tracks.map { track in
            TrackInsert(
                album_id: albumId,
                track_number: track.track_number,
                title: track.title,
                artist: track.artist,
                featured_artists: track.featured_artists,
                duration_ms: track.duration_ms,
                spotify_id: track.spotify_id,
                spotify_uri: track.spotify_uri,
                spotify_href: track.spotify_href
            )
        }
        

        
        do {
            let response = try await supabase
                .from("album_tracks")
                .insert(tracksToInsert)
                .select()
                .execute()
            

            let insertedTracks: [Track] = try JSONDecoder().decode([Track].self, from: response.data)

            return insertedTracks
        } catch {
            // print("❌ Database error: \(error)")
            // print("❌ Error type: \(type(of: error))")
            let supabaseError = error as NSError
            // print("❌ Error domain: \(supabaseError.domain)")
            // print("❌ Error code: \(supabaseError.code)")
            // print("❌ Error userInfo: \(supabaseError.userInfo)")
            throw error
        }
    }
    
    /// Get tracks for an album
    nonisolated func getTracksForAlbum(albumId: Int) async throws -> [Track] {
        let response = try await supabase
            .from("album_tracks")
            .select()
            .eq("album_id", value: albumId)
            .order("track_number", ascending: true)
            .execute()
        
        let tracks: [Track] = try JSONDecoder().decode([Track].self, from: response.data)
        return tracks
    }
    
    /// Delete all tracks for an album
    nonisolated func deleteTracksForAlbum(albumId: Int) async throws {
        try await supabase
            .from("album_tracks")
            .delete()
            .eq("album_id", value: albumId)
            .execute()
    }
    
    /// Get album with tracks
    nonisolated func getAlbumWithTracks(albumId: Int) async throws -> Album? {
        // Get the album
        let albums = try await getAlbums()
        guard let album = albums.first(where: { $0.id == albumId }) else {
            return nil
        }
        
        // Get the tracks
        let tracks = try await getTracksForAlbum(albumId: albumId)
        
        // Create a new album with tracks
        let albumWithTracks = Album(
            id: album.id,
            title: album.title,
            artist: album.artist,
            release_year: album.release_year,
            release_date: album.release_date,
            genres: album.genres,
            label: album.label,
            country: album.country,
            spotify_id: album.spotify_id,
            album_type: album.album_type,
            total_tracks: album.total_tracks,
            cover_image_url: album.cover_image_url,
            spotify_uri: album.spotify_uri,
            spotify_href: album.spotify_href,
            catno: album.catno,
            barcode: album.barcode,
            status: album.status,
            notes: album.notes,
            user_id: album.user_id,
            created_at: album.created_at,
            updated_at: album.updated_at,
            listened_date: album.listened_date,
            tracks: tracks
        )
        
        return albumWithTracks
    }
    
    // MARK: - Favorite Functions
    
    nonisolated func toggleAlbumFavorite(albumId: Int) async throws -> Album {
        // First get the current album to toggle its favorited status
        let albums = try await getAlbums()
        guard let currentAlbum = albums.first(where: { $0.id == albumId }) else {
            throw SupabaseAlbumError.albumNotFound
        }
        
        let newFavoritedStatus = !(currentAlbum.favorited ?? false)
        let updateData = UpdateAlbumRequest(favorited: newFavoritedStatus)
        
        return try await updateAlbum(id: albumId, with: updateData)
    }
    
    nonisolated func setAlbumFavorite(albumId: Int, isFavorite: Bool) async throws -> Album {
        let updateData = UpdateAlbumRequest(favorited: isFavorite)
        return try await updateAlbum(id: albumId, with: updateData)
    }
    
    nonisolated func getFavoriteAlbums() async throws -> [Album] {
        let response = try await supabase
            .from("albums")
            .select()
            .eq("favorited", value: true)
            .order("created_at", ascending: false)
            .execute()
        
        let albums: [Album] = try JSONDecoder().decode([Album].self, from: response.data)
        return albums
    }
}

// Models are defined in Album.swift

// MARK: - Errors

enum SupabaseAlbumError: LocalizedError {
    case noAlbumReturned
    case albumNotFound
    case invalidData
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .noAlbumReturned:
            return "No album data returned from server"
        case .albumNotFound:
            return "Album not found"
        case .invalidData:
            return "Invalid album data"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}
//
//  Album.swift
//  reelay2
//
//  Created for album tracking functionality
//

import Foundation

struct Album: Codable, Identifiable, @unchecked Sendable {
    let id: Int
    let title: String
    let artist: String
    let release_year: Int?
    let release_date: String?
    let genres: [String]?
    let label: String?
    let country: String?
    let spotify_id: String?
    let album_type: String?
    let total_tracks: Int?
    let cover_image_url: String?
    let spotify_uri: String?
    let spotify_href: String?
    let catno: String?
    let barcode: String?
    let status: String
    let notes: String?
    let user_id: String?
    let created_at: String
    let updated_at: String
    let listened_date: String?
    let tracks: [Track]?
    
    init(
        id: Int,
        title: String,
        artist: String,
        release_year: Int? = nil,
        release_date: String? = nil,
        genres: [String]? = nil,
        label: String? = nil,
        country: String? = nil,
        spotify_id: String? = nil,
        album_type: String? = nil,
        total_tracks: Int? = nil,
        cover_image_url: String? = nil,
        spotify_uri: String? = nil,
        spotify_href: String? = nil,
        catno: String? = nil,
        barcode: String? = nil,
        status: String = AlbumStatus.wantToListen.rawValue,
        notes: String? = nil,
        user_id: String? = nil,
        created_at: String,
        updated_at: String,
        listened_date: String? = nil,
        tracks: [Track]? = nil
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.release_year = release_year
        self.release_date = release_date
        self.genres = genres
        self.label = label
        self.country = country
        self.spotify_id = spotify_id
        self.album_type = album_type
        self.total_tracks = total_tracks
        self.cover_image_url = cover_image_url
        self.spotify_uri = spotify_uri
        self.spotify_href = spotify_href
        self.catno = catno
        self.barcode = barcode
        self.status = status
        self.notes = notes
        self.user_id = user_id
        self.created_at = created_at
        self.updated_at = updated_at
        self.listened_date = listened_date
        self.tracks = tracks
    }
    
    enum CodingKeys: String, CodingKey {
        case id, title, artist, genres, label, country, notes, status, tracks
        case release_year
        case release_date
        case spotify_id
        case album_type
        case total_tracks
        case cover_image_url
        case spotify_uri
        case spotify_href
        case catno, barcode
        case user_id
        case created_at
        case updated_at
        case listened_date
    }
}

// MARK: - Computed Properties
extension Album {
    var genreArray: [String] {
        return genres ?? []
    }
    
    var formattedReleaseYear: String {
        guard let year = release_year else { return "Unknown" }
        return String(year)
    }
    
    var coverURL: URL? {
        guard let urlString = cover_image_url, !urlString.isEmpty else { return nil }
        return URL(string: urlString)
    }
    
    var albumStatus: AlbumStatus {
        return AlbumStatus(rawValue: status) ?? .wantToListen
    }
    
    var formattedGenres: String {
        return genreArray.joined(separator: ", ")
    }
    
    var artistAndLabel: String {
        if let label = label, !label.isEmpty {
            return "\(artist) • \(label)"
        }
        return artist
    }
    
    var displayFormat: String {
        return album_type?.capitalized ?? "Unknown Type"
    }
    
    var totalTracksString: String {
        guard let tracks = total_tracks else { return "Unknown" }
        return "\(tracks) track\(tracks == 1 ? "" : "s")"
    }
}

// MARK: - Album Request Models
struct AddAlbumRequest: Codable {
    let title: String
    let artist: String
    let release_year: Int?
    let release_date: String?
    let genres: [String]?
    let label: String?
    let country: String?
    let spotify_id: String?
    let album_type: String?
    let total_tracks: Int?
    let cover_image_url: String?
    let spotify_uri: String?
    let spotify_href: String?
    let catno: String?
    let barcode: String?
    let status: String
    let notes: String?
    let user_id: String?
    
    enum CodingKeys: String, CodingKey {
        case title, artist, genres, label, country, notes, status
        case release_year
        case release_date
        case spotify_id
        case album_type
        case total_tracks
        case cover_image_url
        case spotify_uri
        case spotify_href
        case catno, barcode
        case user_id
    }
    
    init(
        title: String,
        artist: String,
        release_year: Int? = nil,
        release_date: String? = nil,
        genres: [String]? = nil,
        label: String? = nil,
        country: String? = nil,
        spotify_id: String? = nil,
        album_type: String? = nil,
        total_tracks: Int? = nil,
        cover_image_url: String? = nil,
        spotify_uri: String? = nil,
        spotify_href: String? = nil,
        catno: String? = nil,
        barcode: String? = nil,
        status: String = AlbumStatus.wantToListen.rawValue,
        notes: String? = nil,
        user_id: String? = nil
    ) {
        self.title = title
        self.artist = artist
        self.release_year = release_year
        self.release_date = release_date
        self.genres = genres
        self.label = label
        self.country = country
        self.spotify_id = spotify_id
        self.album_type = album_type
        self.total_tracks = total_tracks
        self.cover_image_url = cover_image_url
        self.spotify_uri = spotify_uri
        self.spotify_href = spotify_href
        self.catno = catno
        self.barcode = barcode
        self.status = status
        self.notes = notes
        self.user_id = user_id
    }
}

struct UpdateAlbumRequest: Codable {
    let title: String?
    let artist: String?
    let release_year: Int?
    let release_date: String?
    let genres: [String]?
    let label: String?
    let country: String?
    let spotify_id: String?
    let album_type: String?
    let total_tracks: Int?
    let cover_image_url: String?
    let spotify_uri: String?
    let spotify_href: String?
    let catno: String?
    let barcode: String?
    let status: String?
    let notes: String?
    let listened_date: Date?
    
    enum CodingKeys: String, CodingKey {
        case title, artist, genres, label, country, notes, status
        case release_year
        case release_date
        case spotify_id
        case album_type
        case total_tracks
        case cover_image_url
        case spotify_uri
        case spotify_href
        case catno, barcode
        case listened_date
    }
    
    init(
        title: String? = nil,
        artist: String? = nil,
        release_year: Int? = nil,
        release_date: String? = nil,
        genres: [String]? = nil,
        label: String? = nil,
        country: String? = nil,
        spotify_id: String? = nil,
        album_type: String? = nil,
        total_tracks: Int? = nil,
        cover_image_url: String? = nil,
        spotify_uri: String? = nil,
        spotify_href: String? = nil,
        catno: String? = nil,
        barcode: String? = nil,
        status: String? = nil,
        notes: String? = nil,
        listened_date: Date? = nil
    ) {
        self.title = title
        self.artist = artist
        self.release_year = release_year
        self.release_date = release_date
        self.genres = genres
        self.label = label
        self.country = country
        self.spotify_id = spotify_id
        self.album_type = album_type
        self.total_tracks = total_tracks
        self.cover_image_url = cover_image_url
        self.spotify_uri = spotify_uri
        self.spotify_href = spotify_href
        self.catno = catno
        self.barcode = barcode
        self.status = status
        self.notes = notes
        self.listened_date = listened_date
    }
}

// MARK: - Enums
enum AlbumStatus: String, CaseIterable {
    case wantToListen = "want_to_listen"
    case listened = "listened"
    case removed = "removed"
    
    var displayName: String {
        switch self {
        case .wantToListen: return "Want to Listen"
        case .listened: return "Listened"
        case .removed: return "Removed"
        }
    }
    
    var systemImageName: String {
        switch self {
        case .wantToListen: return "headphones.circle"
        case .listened: return "checkmark.circle.fill"
        case .removed: return "trash.circle"
        }
    }
}

enum AlbumSortField: String, CaseIterable {
    case createdAt = "created_at"
    case title = "title"
    case artist = "artist"
    case releaseYear = "release_year"
    case listenedDate = "listened_date"
    
    var displayName: String {
        switch self {
        case .createdAt: return "Date Added"
        case .title: return "Title"
        case .artist: return "Artist"
        case .releaseYear: return "Release Year"
        case .listenedDate: return "Date Listened"
        }
    }
    
    var supabaseColumn: String {
        return self.rawValue
    }
}

// MARK: - Track Model
struct Track: Codable, Identifiable, @unchecked Sendable {
    let id: Int
    let album_id: Int
    let track_number: Int
    let title: String
    let artist: String?
    let featured_artists: [String]?
    let duration_ms: Int?
    let spotify_id: String?
    let created_at: String
    let updated_at: String
    
    init(
        id: Int,
        album_id: Int,
        track_number: Int,
        title: String,
        artist: String? = nil,
        featured_artists: [String]? = nil,
        duration_ms: Int? = nil,
        spotify_id: String? = nil,
        created_at: String,
        updated_at: String
    ) {
        self.id = id
        self.album_id = album_id
        self.track_number = track_number
        self.title = title
        self.artist = artist
        self.featured_artists = featured_artists
        self.duration_ms = duration_ms
        self.spotify_id = spotify_id
        self.created_at = created_at
        self.updated_at = updated_at
    }
    
    enum CodingKeys: String, CodingKey {
        case id, title, artist, created_at, updated_at
        case album_id
        case track_number
        case featured_artists
        case duration_ms
        case spotify_id
    }
}

// MARK: - Track Extensions
extension Track {
    var formattedDuration: String {
        guard let durationMs = duration_ms else { return "Unknown" }
        let totalSeconds = durationMs / 1000
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var displayArtist: String {
        return artist ?? "Unknown Artist"
    }
    
    var featuredArtistsString: String {
        guard let featured = featured_artists, !featured.isEmpty else { return "" }
        return "feat. " + featured.joined(separator: ", ")
    }
    
    var fullArtistString: String {
        let main = displayArtist
        let featured = featuredArtistsString
        return featured.isEmpty ? main : "\(main) \(featured)"
    }
}

// MARK: - Track Insert Model
struct TrackInsert: Codable {
    let album_id: Int
    let track_number: Int
    let title: String
    let artist: String?
    let featured_artists: [String]?
    let duration_ms: Int?
    let spotify_id: String?
    
    enum CodingKeys: String, CodingKey {
        case album_id, track_number, title, artist, featured_artists, duration_ms, spotify_id
    }
}
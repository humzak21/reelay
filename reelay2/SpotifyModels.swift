//
//  SpotifyModels.swift
//  reelay2
//
//  Created for Spotify Web API integration
//

import Foundation

// MARK: - Spotify Access Token
struct SpotifyAccessToken: Codable {
    let accessToken: String
    let tokenType: String
    let expiresIn: Int
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
    }
}

// MARK: - Spotify Search Response
struct SpotifySearchResponse: Codable {
    let albums: SpotifyAlbumsResponse?
    let artists: SpotifyArtistsResponse?
    let tracks: SpotifyTracksResponse?
}

// MARK: - Spotify Albums Response
struct SpotifyAlbumsResponse: Codable {
    let href: String?
    let items: [SpotifyAlbum]
    let limit: Int?
    let next: String?
    let offset: Int?
    let previous: String?
    let total: Int?
}

// MARK: - Spotify Artists Response  
struct SpotifyArtistsResponse: Codable {
    let href: String?
    let items: [SpotifyArtist]
    let limit: Int?
    let next: String?
    let offset: Int?
    let previous: String?
    let total: Int?
}

// MARK: - Spotify Tracks Response
struct SpotifyTracksResponse: Codable {
    let href: String?
    let items: [SpotifyTrack]
    let limit: Int?
    let next: String?
    let offset: Int?
    let previous: String?
    let total: Int?
}

// MARK: - Spotify Album
struct SpotifyAlbum: Codable, Identifiable {
    let id: String
    let name: String?
    let albumType: String?
    let totalTracks: Int?
    let availableMarkets: [String]?
    let releaseDate: String?
    let releaseDatePrecision: String?
    let uri: String?
    let href: String?
    let popularity: Int?
    let label: String?
    let artists: [SpotifySimplifiedArtist]?
    let tracks: SpotifyTracksCollection?
    let images: [SpotifyImage]?
    let externalUrls: SpotifyExternalUrls?
    let externalIds: SpotifyExternalIds?
    let copyrights: [SpotifyCopyright]?
    let genres: [String]?
    
    enum CodingKeys: String, CodingKey {
        case id, name, uri, href, popularity, label, artists, tracks, images, genres
        case albumType = "album_type"
        case totalTracks = "total_tracks"
        case availableMarkets = "available_markets"
        case releaseDate = "release_date"
        case releaseDatePrecision = "release_date_precision"
        case externalUrls = "external_urls"
        case externalIds = "external_ids"
        case copyrights
    }
}

// MARK: - Spotify Artist
struct SpotifyArtist: Codable, Identifiable {
    let id: String
    let name: String?
    let genres: [String]?
    let popularity: Int?
    let followers: SpotifyFollowers?
    let images: [SpotifyImage]?
    let externalUrls: SpotifyExternalUrls?
    let uri: String?
    let href: String?
    
    enum CodingKeys: String, CodingKey {
        case id, name, genres, popularity, followers, images, uri, href
        case externalUrls = "external_urls"
    }
}

// MARK: - Spotify Simplified Artist
struct SpotifySimplifiedArtist: Codable, Identifiable {
    let id: String
    let name: String?
    let uri: String?
    let href: String?
    let externalUrls: SpotifyExternalUrls?
    
    enum CodingKeys: String, CodingKey {
        case id, name, uri, href
        case externalUrls = "external_urls"
    }
}

// MARK: - Spotify Track
struct SpotifyTrack: Codable, Identifiable {
    let id: String
    let name: String?
    let artists: [SpotifySimplifiedArtist]?
    let album: SpotifySimplifiedAlbum?
    let durationMs: Int?
    let explicit: Bool?
    let popularity: Int?
    let trackNumber: Int?
    let discNumber: Int?
    let uri: String?
    let href: String?
    let isLocal: Bool?
    let previewUrl: String?
    let externalUrls: SpotifyExternalUrls?
    let externalIds: SpotifyExternalIds?
    
    enum CodingKeys: String, CodingKey {
        case id, name, artists, album, explicit, popularity, uri, href
        case durationMs = "duration_ms"
        case trackNumber = "track_number"
        case discNumber = "disc_number"
        case isLocal = "is_local"
        case previewUrl = "preview_url"
        case externalUrls = "external_urls"
        case externalIds = "external_ids"
    }
}

// MARK: - Spotify Simplified Album
struct SpotifySimplifiedAlbum: Codable, Identifiable {
    let id: String
    let name: String?
    let albumType: String?
    let totalTracks: Int?
    let availableMarkets: [String]?
    let releaseDate: String?
    let releaseDatePrecision: String?
    let uri: String?
    let href: String?
    let artists: [SpotifySimplifiedArtist]?
    let images: [SpotifyImage]?
    let externalUrls: SpotifyExternalUrls?
    
    enum CodingKeys: String, CodingKey {
        case id, name, uri, href, artists, images
        case albumType = "album_type"
        case totalTracks = "total_tracks"
        case availableMarkets = "available_markets"
        case releaseDate = "release_date"
        case releaseDatePrecision = "release_date_precision"
        case externalUrls = "external_urls"
    }
}

// MARK: - Spotify Simplified Track
struct SpotifySimplifiedTrack: Codable, Identifiable {
    let id: String
    let name: String?
    let artists: [SpotifySimplifiedArtist]?
    let durationMs: Int?
    let explicit: Bool?
    let trackNumber: Int?
    let discNumber: Int?
    let uri: String?
    let href: String?
    let isLocal: Bool?
    let previewUrl: String?
    let externalUrls: SpotifyExternalUrls?
    
    enum CodingKeys: String, CodingKey {
        case id, name, artists, explicit, uri, href
        case durationMs = "duration_ms"
        case trackNumber = "track_number"
        case discNumber = "disc_number"
        case isLocal = "is_local"
        case previewUrl = "preview_url"
        case externalUrls = "external_urls"
    }
}

// MARK: - Spotify Tracks Collection
struct SpotifyTracksCollection: Codable {
    let href: String?
    let items: [SpotifySimplifiedTrack]?
    let limit: Int?
    let next: String?
    let offset: Int?
    let previous: String?
    let total: Int?
}

// MARK: - Spotify Image
struct SpotifyImage: Codable {
    let url: String?
    let height: Int?
    let width: Int?
}

// MARK: - Spotify External URLs
struct SpotifyExternalUrls: Codable {
    let spotify: String?
}

// MARK: - Spotify External IDs
struct SpotifyExternalIds: Codable {
    let isrc: String?
    let ean: String?
    let upc: String?
}

// MARK: - Spotify Followers
struct SpotifyFollowers: Codable {
    let href: String?
    let total: Int?
}

// MARK: - Spotify Copyright
struct SpotifyCopyright: Codable {
    let text: String?
    let type: String?
}

// MARK: - Helper Extensions
extension SpotifyAlbum {
    var primaryImage: SpotifyImage? {
        return images?.first
    }
    
    var releaseYear: String? {
        guard let releaseDate = releaseDate else { return nil }
        return String(releaseDate.prefix(4))
    }
    
    var artistNames: String {
        guard let artists = artists, !artists.isEmpty else { return "Unknown Artist" }
        return artists.compactMap { $0.name }.joined(separator: ", ")
    }
}

extension SpotifyArtist {
    var primaryImage: SpotifyImage? {
        return images?.first
    }
    
    var genreString: String {
        guard let genres = genres, !genres.isEmpty else { return "" }
        return genres.joined(separator: ", ")
    }
}

extension SpotifyTrack {
    var durationString: String {
        guard let durationMs = durationMs else { return "0:00" }
        let totalSeconds = durationMs / 1000
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var artistNames: String {
        guard let artists = artists, !artists.isEmpty else { return "Unknown Artist" }
        return artists.compactMap { $0.name }.joined(separator: ", ")
    }
}
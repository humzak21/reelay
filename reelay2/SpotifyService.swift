//
//  SpotifyService.swift
//  reelay2
//
//  Created for Spotify Web API integration
//

import Foundation
import Combine

class SpotifyService: ObservableObject {
    static let shared = SpotifyService()
    
    private let baseURL = "https://api.spotify.com/v1"
    private let clientId = Config.SPOTIFY_CLIENT_ID
    private let clientSecret = Config.SPOTIFY_CLIENT_SECRET
    private let session = URLSession.shared
    
    @Published var accessToken: String?
    @Published var tokenExpiresAt: Date?
    
    private init() {}
    
    // MARK: - Authentication
    private func getClientCredentialsToken() async throws -> SpotifyAccessToken {
        let tokenURL = "https://accounts.spotify.com/api/token"
        
        guard let url = URL(string: tokenURL) else {
            throw SpotifyError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let credentials = "\(clientId):\(clientSecret)".data(using: .utf8)?.base64EncodedString() ?? ""
        request.setValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")
        
        let bodyData = "grant_type=client_credentials".data(using: .utf8)
        request.httpBody = bodyData
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SpotifyError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw SpotifyError.httpError(httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        let tokenResponse = try decoder.decode(SpotifyAccessToken.self, from: data)
        
        // Store token and expiration time
        await MainActor.run {
            self.accessToken = tokenResponse.accessToken
            self.tokenExpiresAt = Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn))
        }
        
        return tokenResponse
    }
    
    private func ensureValidToken() async throws {
        if let token = accessToken, let expiresAt = tokenExpiresAt, Date() < expiresAt {
            return // Token is still valid
        }
        
        _ = try await getClientCredentialsToken()
    }
    
    // MARK: - Search Albums
    func searchAlbums(query: String, limit: Int = 20, offset: Int = 0) async throws -> SpotifySearchResponse {
        try await ensureValidToken()
        
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw SpotifyError.invalidQuery
        }
        
        guard let token = accessToken else {
            throw SpotifyError.noAccessToken
        }
        
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "\(baseURL)/search?q=\(encodedQuery)&type=album&limit=\(limit)&offset=\(offset)"
        
        guard let url = URL(string: urlString) else {
            throw SpotifyError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SpotifyError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 429 {
                throw SpotifyError.rateLimitExceeded
            }
            throw SpotifyError.httpError(httpResponse.statusCode)
        }
        
        do {
            let decoder = JSONDecoder()
            let searchResponse = try decoder.decode(SpotifySearchResponse.self, from: data)
            return searchResponse
        } catch {
            print("Spotify API decoding error: \(error)")
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Raw JSON: \(jsonString)")
            }
            throw SpotifyError.decodingError(error)
        }
    }
    
    // MARK: - Get Album Details
    func getAlbumDetails(albumId: String) async throws -> SpotifyAlbum {
        try await ensureValidToken()
        
        guard let token = accessToken else {
            throw SpotifyError.noAccessToken
        }
        
        let urlString = "\(baseURL)/albums/\(albumId)"
        
        guard let url = URL(string: urlString) else {
            throw SpotifyError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SpotifyError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 429 {
                throw SpotifyError.rateLimitExceeded
            }
            throw SpotifyError.httpError(httpResponse.statusCode)
        }
        
        do {
            let decoder = JSONDecoder()
            let album = try decoder.decode(SpotifyAlbum.self, from: data)
            return album
        } catch {
            print("Spotify API decoding error: \(error)")
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Raw JSON: \(jsonString)")
            }
            throw SpotifyError.decodingError(error)
        }
    }
    
    // MARK: - Search Artists
    func searchArtists(query: String, limit: Int = 20, offset: Int = 0) async throws -> SpotifySearchResponse {
        try await ensureValidToken()
        
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw SpotifyError.invalidQuery
        }
        
        guard let token = accessToken else {
            throw SpotifyError.noAccessToken
        }
        
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "\(baseURL)/search?q=\(encodedQuery)&type=artist&limit=\(limit)&offset=\(offset)"
        
        guard let url = URL(string: urlString) else {
            throw SpotifyError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SpotifyError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 429 {
                throw SpotifyError.rateLimitExceeded
            }
            throw SpotifyError.httpError(httpResponse.statusCode)
        }
        
        do {
            let decoder = JSONDecoder()
            let searchResponse = try decoder.decode(SpotifySearchResponse.self, from: data)
            return searchResponse
        } catch {
            print("Spotify API decoding error: \(error)")
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Raw JSON: \(jsonString)")
            }
            throw SpotifyError.decodingError(error)
        }
    }
    
    // MARK: - Search Combined (Albums and Artists)
    func searchAlbumsAndArtists(query: String, limit: Int = 20, offset: Int = 0) async throws -> SpotifySearchResponse {
        try await ensureValidToken()
        
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw SpotifyError.invalidQuery
        }
        
        guard let token = accessToken else {
            throw SpotifyError.noAccessToken
        }
        
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "\(baseURL)/search?q=\(encodedQuery)&type=album,artist&limit=\(limit)&offset=\(offset)"
        
        guard let url = URL(string: urlString) else {
            throw SpotifyError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SpotifyError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 429 {
                throw SpotifyError.rateLimitExceeded
            }
            throw SpotifyError.httpError(httpResponse.statusCode)
        }
        
        do {
            let decoder = JSONDecoder()
            let searchResponse = try decoder.decode(SpotifySearchResponse.self, from: data)
            return searchResponse
        } catch {
            print("Spotify API decoding error: \(error)")
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Raw JSON: \(jsonString)")
            }
            throw SpotifyError.decodingError(error)
        }
    }
}

// MARK: - Spotify Errors
enum SpotifyError: LocalizedError {
    case invalidQuery
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case decodingError(Error)
    case rateLimitExceeded
    case noAccessToken
    case authenticationFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidQuery:
            return "Invalid search query"
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .decodingError(let error):
            return "Decoding error: \(error.localizedDescription)"
        case .rateLimitExceeded:
            return "Rate limit exceeded. Please try again later."
        case .noAccessToken:
            return "No valid access token"
        case .authenticationFailed:
            return "Authentication failed"
        }
    }
}
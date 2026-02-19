//
//  PlexService.swift
//  reelay2
//
//  Created by Humza Khalil on 2/14/26.
//

import Foundation
import SwiftUI
import Combine
import AuthenticationServices

// MARK: - Models

struct PlexMovie: Identifiable {
    let id: String // ratingKey
    let title: String
    let year: Int?
    let tmdbId: Int?
    let imdbId: String?
    let thumbPath: String?
    
    func thumbURL(baseURL: String) -> URL? {
        guard let thumbPath = thumbPath else { return nil }
        return URL(string: "\(baseURL)\(thumbPath)")
    }
}

struct PlexLibrarySection: Identifiable {
    let id: String
    let title: String
    let type: String
}

struct PlexServer: Identifiable {
    let id: String // clientIdentifier
    let name: String
    let connections: [PlexServerConnection]
    let owned: Bool
    
    /// Best connection URI — prefers non-local HTTPS connections
    var bestConnectionURI: String? {
        // Prefer non-local HTTPS plex.direct connections (skip Docker/internal IPs)
        if let remote = connections.first(where: {
            $0.uri.contains("plex.direct") && $0.protocol == "https" && !$0.local
        }) {
            return remote.uri
        }
        // Then any non-local HTTPS
        if let remoteHttps = connections.first(where: { $0.protocol == "https" && !$0.local }) {
            return remoteHttps.uri
        }
        // Then any non-local
        if let remote = connections.first(where: { !$0.local }) {
            return remote.uri
        }
        // Fallback to any connection
        return connections.first?.uri
    }
}

struct PlexServerConnection {
    let `protocol`: String
    let address: String
    let port: Int
    let uri: String
    let local: Bool
}

enum PlexServiceError: Error, LocalizedError {
    case notConfigured
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case decodingError(String)
    case networkError(Error)
    case noMovieLibraries
    case authTimeout
    case authCancelled
    case noServersFound
    
    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Plex not connected. Sign in via Settings."
        case .invalidURL: return "Invalid Plex server URL."
        case .invalidResponse: return "Invalid response from Plex."
        case .httpError(let code): return "Plex returned HTTP \(code)."
        case .decodingError(let msg): return "Failed to parse Plex response: \(msg)"
        case .networkError(let error): return "Network error: \(error.localizedDescription)"
        case .noMovieLibraries: return "No movie libraries found on your Plex server."
        case .authTimeout: return "Authentication timed out. Please try again."
        case .authCancelled: return "Authentication was cancelled."
        case .noServersFound: return "No Plex servers found on your account."
        }
    }
}

// MARK: - Plex API JSON Response Models

private struct PlexMediaContainer: Decodable {
    let MediaContainer: PlexMediaContainerInner
}

private struct PlexMediaContainerInner: Decodable {
    let Directory: [PlexDirectoryItem]?
    let Metadata: [PlexMetadataItem]?
    let size: Int?
}

private struct PlexDirectoryItem: Decodable {
    let key: String
    let title: String
    let type: String
}

private struct PlexMetadataItem: Decodable {
    let ratingKey: String
    let title: String
    let year: Int?
    let thumb: String?
    let Guid: [PlexGuidItem]?
}

private struct PlexGuidItem: Decodable {
    let id: String
}

// OAuth PIN response
private struct PlexPinResponse: Decodable {
    let id: Int
    let code: String
    let authToken: String?
}

// Resources response
private struct PlexResourceResponse: Decodable {
    let name: String?
    let clientIdentifier: String?
    let provides: String?
    let owned: Bool?
    let connections: [PlexResourceConnection]?
}

private struct PlexResourceConnection: Decodable {
    let `protocol`: String?
    let address: String?
    let port: Int?
    let uri: String?
    let local: Bool?
}

// MARK: - PlexService

class PlexService: ObservableObject {
    static let shared = PlexService()
    
    // MARK: - Published Properties
    @Published var isLoading = false
    @Published var error: String?
    @Published var libraryMovieCount: Int = 0
    @Published var isConfigured: Bool = false
    @Published var isAuthenticating = false
    @Published var connectedUsername: String?
    @Published var selectedServerName: String?
    @Published var availableServers: [PlexServer] = []
    @Published var availableLibrarySections: [PlexLibrarySection] = []
    @Published var selectedLibrarySectionId: String?
    @Published var selectedLibrarySectionName: String?
    
    // MARK: - Storage Keys
    private static let authTokenKey = "plexAuthToken"
    private static let clientIdKey = "plexClientIdentifier"
    private static let serverURIKey = "plexSelectedServerURI"
    private static let serverNameKey = "plexSelectedServerName"
    private static let usernameKey = "plexUsername"
    private static let librarySectionIdKey = "plexLibrarySectionId"
    private static let librarySectionNameKey = "plexLibrarySectionName"
    
    // MARK: - Constants
    private static let plexProduct = "Reelay"
    private static let plexVersion = "1.0"
    private static let plexTVBaseURL = "https://plex.tv"
    
    // MARK: - Cached Library
    private var moviesByTmdbId: [Int: PlexMovie] = [:]
    private var allMovies: [PlexMovie] = []
    private(set) var isLibraryLoaded = false
    
    /// Custom URLSession that trusts Plex *.plex.direct certificates
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 120
        return URLSession(configuration: config, delegate: PlexURLSessionDelegate(), delegateQueue: nil)
    }()
    
    // MARK: - Client Identifier (persisted per install)
    
    var clientIdentifier: String {
        if let existing = UserDefaults.standard.string(forKey: Self.clientIdKey) {
            return existing
        }
        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: Self.clientIdKey)
        return newId
    }
    
    // MARK: - Auth Token
    
    var authToken: String? {
        get { UserDefaults.standard.string(forKey: Self.authTokenKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.authTokenKey)
            updateConfiguredState()
        }
    }
    
    // MARK: - Selected Server URI
    
    var selectedServerURI: String? {
        get { UserDefaults.standard.string(forKey: Self.serverURIKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.serverURIKey) }
    }
    
    // MARK: - Configuration
    
    private init() {
        let savedName = UserDefaults.standard.string(forKey: Self.serverNameKey)
        let savedUsername = UserDefaults.standard.string(forKey: Self.usernameKey)
        selectedServerName = savedName
        connectedUsername = savedUsername
        selectedLibrarySectionId = UserDefaults.standard.string(forKey: Self.librarySectionIdKey)
        selectedLibrarySectionName = UserDefaults.standard.string(forKey: Self.librarySectionNameKey)
        updateConfiguredState()
    }
    
    private func updateConfiguredState() {
        let configured = authToken != nil
            && !(authToken?.isEmpty ?? true)
            && selectedServerURI != nil
            && !(selectedServerURI?.isEmpty ?? true)
        DispatchQueue.main.async {
            self.isConfigured = configured
        }
    }
    
    /// Standard Plex headers for plex.tv API calls
    private var plexHeaders: [String: String] {
        var headers: [String: String] = [
            "Accept": "application/json",
            "X-Plex-Client-Identifier": clientIdentifier,
            "X-Plex-Product": Self.plexProduct,
            "X-Plex-Version": Self.plexVersion
        ]
        if let token = authToken {
            headers["X-Plex-Token"] = token
        }
        return headers
    }
    
    // MARK: - OAuth PIN Flow
    
    /// Step 1: Request a PIN from plex.tv
    func requestPIN() async throws -> (pinId: Int, code: String) {

        
        guard let url = URL(string: "\(Self.plexTVBaseURL)/api/v2/pins?strong=true") else {
            throw PlexServiceError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        for (key, value) in plexHeaders {
            request.addValue(value, forHTTPHeaderField: key)
        }
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data() // Empty body, params in URL
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 201 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw PlexServiceError.httpError(statusCode: code)
        }
        
        let pin = try JSONDecoder().decode(PlexPinResponse.self, from: data)

        return (pin.id, pin.code)
    }
    
    /// Step 2: Build the auth URL for the browser
    func authURL(code: String) -> URL? {
        var components = URLComponents(string: "https://app.plex.tv/auth")
        components?.fragment = "?clientID=\(clientIdentifier)&code=\(code)&context%5Bdevice%5D%5Bproduct%5D=\(Self.plexProduct)"
        return components?.url
    }
    
    /// Step 3: Poll for the auth token (call after user is redirected to browser)
    func pollForToken(pinId: Int, maxAttempts: Int = 150) async throws -> String {

        
        await MainActor.run { isAuthenticating = true }
        defer { Task { @MainActor in isAuthenticating = false } }
        
        for attempt in 1...maxAttempts {
            guard let url = URL(string: "\(Self.plexTVBaseURL)/api/v2/pins/\(pinId)") else {
                throw PlexServiceError.invalidURL
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            for (key, value) in plexHeaders {
                request.addValue(value, forHTTPHeaderField: key)
            }
            
            let (data, _) = try await session.data(for: request)
            let pin = try JSONDecoder().decode(PlexPinResponse.self, from: data)
            
            if let token = pin.authToken, !token.isEmpty {

                authToken = token
                return token
            }
            
            // Wait 2 seconds before next poll
            try await Task.sleep(nanoseconds: 2_000_000_000)
        }
        
        throw PlexServiceError.authTimeout
    }
    
    /// Step 4: Fetch available servers from plex.tv
    func fetchServers() async throws -> [PlexServer] {

        
        guard let url = URL(string: "\(Self.plexTVBaseURL)/api/v2/resources?includeHttps=1&includeRelay=0") else {
            throw PlexServiceError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        for (key, value) in plexHeaders {
            request.addValue(value, forHTTPHeaderField: key)
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw PlexServiceError.httpError(statusCode: code)
        }
        
        // Debug: log raw response
        if let rawString = String(data: data, encoding: .utf8) {
            // print("📦 [PlexService] Resources response: \(rawString.prefix(500))")
        }
        
        let resources: [PlexResourceResponse]
        do {
            resources = try JSONDecoder().decode([PlexResourceResponse].self, from: data)
        } catch {

            throw PlexServiceError.decodingError(error.localizedDescription)
        }
        
        // Filter to servers only (provides contains "server")
        let servers = resources
            .filter { ($0.provides ?? "").contains("server") }
            .map { resource in
                PlexServer(
                    id: resource.clientIdentifier ?? UUID().uuidString,
                    name: resource.name ?? "Unknown Server",
                    connections: (resource.connections ?? []).compactMap { conn in
                        guard let uri = conn.uri else { return nil }
                        return PlexServerConnection(
                            protocol: conn.protocol ?? "https",
                            address: conn.address ?? "",
                            port: conn.port ?? 32400,
                            uri: uri,
                            local: conn.local ?? false
                        )
                    },
                    owned: resource.owned ?? false
                )
            }
        

        
        await MainActor.run {
            availableServers = servers
        }
        
        return servers
    }
    
    /// Step 5: Select a server and store its connection URI
    func selectServer(_ server: PlexServer) {
        // Debug: log all available connections
        // print("🔗 [PlexService] Available connections for \(server.name):")
        // for conn in server.connections {
        //    print("   \(conn.local ? "🏠 LOCAL" : "🌐 REMOTE") \(conn.protocol)://\(conn.address):\(conn.port) → \(conn.uri)")
        //}
        
        guard let uri = server.bestConnectionURI else { return }
        selectedServerURI = uri
        let name = server.name
        UserDefaults.standard.set(name, forKey: Self.serverNameKey)
        DispatchQueue.main.async {
            self.selectedServerName = name
        }
        updateConfiguredState()

        // Clear library section when changing servers
        selectedLibrarySectionId = nil
        selectedLibrarySectionName = nil
        UserDefaults.standard.removeObject(forKey: Self.librarySectionIdKey)
        UserDefaults.standard.removeObject(forKey: Self.librarySectionNameKey)
    }
    
    /// Fetch username from plex.tv (for display in settings)
    func fetchUsername() async throws {
        guard let url = URL(string: "\(Self.plexTVBaseURL)/api/v2/user") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        for (key, value) in plexHeaders {
            request.addValue(value, forHTTPHeaderField: key)
        }
        
        let (data, _) = try await session.data(for: request)
        
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let username = json["username"] as? String ?? json["title"] as? String {
            UserDefaults.standard.set(username, forKey: Self.usernameKey)
            await MainActor.run {
                connectedUsername = username
            }

        }
    }
    
    // MARK: - API Helpers (Server Calls)
    
    private func makeServerRequest(path: String, queryItems: [URLQueryItem]? = nil) throws -> URLRequest {
        guard let baseURL = selectedServerURI, let token = authToken else {
            throw PlexServiceError.notConfigured
        }
        
        var urlString = "\(baseURL)\(path)"
        
        if let queryItems = queryItems, !queryItems.isEmpty {
            var components = URLComponents(string: urlString)
            components?.queryItems = queryItems
            if let built = components?.url?.absoluteString {
                urlString = built
            }
        }
        
        guard let url = URL(string: urlString) else {
            throw PlexServiceError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue(token, forHTTPHeaderField: "X-Plex-Token")
        request.timeoutInterval = 15
        return request
    }
    
    private func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PlexServiceError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw PlexServiceError.httpError(statusCode: httpResponse.statusCode)
        }
        
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            let responseStr = String(data: data, encoding: .utf8) ?? "(binary)"

            throw PlexServiceError.decodingError(error.localizedDescription)
        }
    }
    
    // MARK: - Library Functions
    
    func testConnection() async throws -> String {

        let request = try makeServerRequest(path: "/")
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw PlexServiceError.httpError(statusCode: code)
        }
        
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let container = json["MediaContainer"] as? [String: Any],
           let friendlyName = container["friendlyName"] as? String {

            return friendlyName
        }
        
        return "Plex Server"
    }
    
    func fetchMovieLibrarySections() async throws -> [PlexLibrarySection] {

        let request = try makeServerRequest(path: "/library/sections")
        let container: PlexMediaContainer = try await perform(request)
        
        let sections = (container.MediaContainer.Directory ?? [])
            .filter { $0.type == "movie" }
            .map { PlexLibrarySection(id: $0.key, title: $0.title, type: $0.type) }
        

        return sections
    }
    
    func fetchMoviesFromSection(sectionKey: String) async throws -> [PlexMovie] {

        let request = try makeServerRequest(
            path: "/library/sections/\(sectionKey)/all",
            queryItems: [
                URLQueryItem(name: "type", value: "1"),
                URLQueryItem(name: "includeGuids", value: "1")
            ]
        )
        
        let container: PlexMediaContainer = try await perform(request)
        let metadata = container.MediaContainer.Metadata ?? []
        
        let movies = metadata.map { item -> PlexMovie in
            var tmdbId: Int?
            var imdbId: String?
            
            for guid in item.Guid ?? [] {
                if guid.id.hasPrefix("tmdb://") {
                    tmdbId = Int(String(guid.id.dropFirst("tmdb://".count)))
                } else if guid.id.hasPrefix("imdb://") {
                    imdbId = String(guid.id.dropFirst("imdb://".count))
                }
            }
            
            return PlexMovie(
                id: item.ratingKey, title: item.title, year: item.year,
                tmdbId: tmdbId, imdbId: imdbId, thumbPath: item.thumb
            )
        }
        

        return movies
    }
    
    /// Select a library section to load movies from
    func selectLibrarySection(_ section: PlexLibrarySection) {
        selectedLibrarySectionId = section.id
        selectedLibrarySectionName = section.title
        UserDefaults.standard.set(section.id, forKey: Self.librarySectionIdKey)
        UserDefaults.standard.set(section.title, forKey: Self.librarySectionNameKey)

    }
    
    func refreshLibrary() async throws -> Int {
        guard let sectionId = selectedLibrarySectionId else {
            throw PlexServiceError.noMovieLibraries
        }
        

        
        await MainActor.run { isLoading = true; error = nil }
        defer { Task { @MainActor in isLoading = false } }
        
        do {
            let allFetchedMovies = try await fetchMoviesFromSection(sectionKey: sectionId)
            
            var newIndex: [Int: PlexMovie] = [:]
            var matchedCount = 0
            for movie in allFetchedMovies {
                if let tmdbId = movie.tmdbId {
                    newIndex[tmdbId] = movie
                    matchedCount += 1
                }
            }
            
            moviesByTmdbId = newIndex
            allMovies = allFetchedMovies
            isLibraryLoaded = true
            
            let totalCount = allFetchedMovies.count
            await MainActor.run { libraryMovieCount = totalCount }
            

            return totalCount
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
            throw error
        }
    }
    
    // MARK: - Lookup
    
    func getMovie(byTmdbId tmdbId: Int) -> PlexMovie? {
        return moviesByTmdbId[tmdbId]
    }
    
    func isMovieAvailable(tmdbId: Int) -> Bool {
        return moviesByTmdbId[tmdbId] != nil
    }
    
    func findMovie(title: String, year: Int?) -> PlexMovie? {
        let normalizedTitle = title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return allMovies.first { movie in
            let plexTitle = movie.title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            let titleMatch = plexTitle == normalizedTitle
            if let year = year, let movieYear = movie.year {
                return titleMatch && movieYear == year
            }
            return titleMatch
        }
    }
    
    // MARK: - Cleanup
    
    func clearCache() {
        moviesByTmdbId = [:]
        allMovies = []
        isLibraryLoaded = false
        DispatchQueue.main.async { self.libraryMovieCount = 0 }
    }
    
    func signOut() {
        UserDefaults.standard.removeObject(forKey: Self.authTokenKey)
        UserDefaults.standard.removeObject(forKey: Self.serverURIKey)
        UserDefaults.standard.removeObject(forKey: Self.serverNameKey)
        UserDefaults.standard.removeObject(forKey: Self.usernameKey)
        UserDefaults.standard.removeObject(forKey: Self.librarySectionIdKey)
        UserDefaults.standard.removeObject(forKey: Self.librarySectionNameKey)
        clearCache()
        DispatchQueue.main.async {
            self.connectedUsername = nil
            self.selectedServerName = nil
            self.availableServers = []
            self.availableLibrarySections = []
            self.selectedLibrarySectionId = nil
            self.selectedLibrarySectionName = nil
        }
        updateConfiguredState()

    }
}

// MARK: - TLS Delegate

private class PlexURLSessionDelegate: NSObject, URLSessionDelegate {
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        
        let host = challenge.protectionSpace.host
        
        // Trust *.plex.direct hosts (Plex's remote access certificates)
        if host.hasSuffix(".plex.direct") {
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}

//
//  StreamingService.swift
//  reelay2
//
//  Created by Humza Khalil on 9/2/25.
//

import Foundation
import Combine

struct StreamingAvailabilityResponse: Codable {
    let title: String
    let overview: String?
    let tmdbId: String
    let imdbId: String?
    let type: String
    let streamingOptions: [String: [StreamingOption]]
    let genres: [String]?
    let releaseYear: Int?
    let cast: [String]?
    let directors: [String]?
    let posterUrl: String?
    let backdropUrl: String?
    let error: String?
}

struct StreamingOption: Codable {
    let link: String
    let service: StreamingServiceInfo
    let type: String
    let quality: String?
    let audios: [String]?
    let subtitles: [String]?
    let price: StreamingPrice?
}

struct StreamingServiceInfo: Codable {
    let id: String
    let name: String
    let homePage: String?
    let themeColorCode: String?
    let imageSet: StreamingServiceImageSet?
}

struct StreamingServiceImageSet: Codable {
    let lightThemeImage: String?
    let darkThemeImage: String?
    let whiteImage: String?
}

struct StreamingPrice: Codable {
    let amount: String
    let currency: String
    let formatted: String
}

struct StreamingServicesResponse: Codable {
    let country: String
    let services: [String]
}

@MainActor
class StreamingService: ObservableObject {
    static let shared = StreamingService()
    
    private let baseURL = "https://streaming-availability.p.rapidapi.com"
    private let session = URLSession.shared
    private let decoder = JSONDecoder()
    
    @Published var isLoading = false
    @Published var error: String?
    
    // Get RapidAPI key from config
    private let rapidAPIKey = Config.RAPID_API_KEY
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Get streaming availability for a movie by TMDB ID
    func getMovieStreamingAvailability(tmdbId: Int, country: String = "us") async throws -> StreamingAvailabilityResponse {
        await MainActor.run {
            isLoading = true
            error = nil
        }
        
        defer {
            Task {
                await MainActor.run {
                    isLoading = false
                }
            }
        }
        
        // Use the correct endpoint for TMDB ID lookup
        guard let url = URL(string: "\(baseURL)/shows/tmdb:\(tmdbId)?country=\(country)") else {
            await MainActor.run {
                error = "Invalid URL"
            }
            throw StreamingServiceError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(rapidAPIKey, forHTTPHeaderField: "X-RapidAPI-Key")
        request.addValue("streaming-availability.p.rapidapi.com", forHTTPHeaderField: "X-RapidAPI-Host")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                await MainActor.run {
                    error = "Invalid response"
                }
                throw StreamingServiceError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                await MainActor.run {
                    error = "HTTP error: \(httpResponse.statusCode)"
                }
                throw StreamingServiceError.httpError(httpResponse.statusCode)
            }
            
            let result = try decoder.decode(StreamingAvailabilityResponse.self, from: data)
            return result
            
        } catch let decodingError as DecodingError {
            await MainActor.run {
                error = "Failed to decode response: \(decodingError.localizedDescription)"
            }
            throw StreamingServiceError.decodingError(decodingError)
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
            }
            throw error
        }
    }
    
    /// Get streaming availability for a TV show by TMDB ID
    func getTVShowStreamingAvailability(tmdbId: Int, country: String = "us") async throws -> StreamingAvailabilityResponse {
        // TV shows use the same endpoint structure, just with a different TMDB ID
        return try await getMovieStreamingAvailability(tmdbId: tmdbId, country: country)
    }
    
    /// Get supported streaming services for a country
    func getSupportedServices(country: String = "us") async throws -> StreamingServicesResponse {
        guard let url = URL(string: "\(baseURL)/countries/\(country)") else {
            throw StreamingServiceError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Use RapidAPI authentication
        guard !rapidAPIKey.isEmpty else {
            throw StreamingServiceError.authenticationRequired
        }
        
        request.addValue(rapidAPIKey, forHTTPHeaderField: "X-RapidAPI-Key")
        request.addValue("streaming-availability.p.rapidapi.com", forHTTPHeaderField: "X-RapidAPI-Host")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw StreamingServiceError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw StreamingServiceError.httpError(httpResponse.statusCode)
        }
        
        return try decoder.decode(StreamingServicesResponse.self, from: data)
    }
    
    /// Clear streaming cache for specific content
    /// Note: This is a placeholder as Movie of the Night API doesn't have cache clearing
    func clearStreamingCache(type: String, tmdbId: Int) async throws {
        // Movie of the Night API doesn't support cache clearing
        // This method is kept for compatibility but does nothing
        throw StreamingServiceError.invalidURL
    }
    
    // MARK: - Private Methods
    
    // The Movie of the Night API requires a more complex implementation
    // involving IMDB ID lookup and proper show searching. This is a placeholder.
}

// MARK: - Error Types

enum StreamingServiceError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case decodingError(DecodingError)
    case authenticationRequired
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .authenticationRequired:
            return "Authentication required for this operation"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Helper Extensions

extension StreamingAvailabilityResponse {
    /// Get all available streaming services for the configured country
    func getAvailableServices(for country: String = "us") -> [String] {
        return streamingOptions[country]?.map { $0.service.name } ?? []
    }
    
    /// Get streaming options for a specific service
    func getStreamingOptions(for serviceName: String, country: String = "us") -> [StreamingOption] {
        return streamingOptions[country]?.filter { $0.service.name.lowercased() == serviceName.lowercased() } ?? []
    }
    
    /// Check if content is available on a specific service
    func isAvailableOn(_ serviceName: String, country: String = "us") -> Bool {
        return !getStreamingOptions(for: serviceName, country: country).isEmpty
    }
    
    /// Get all free streaming options
    func getFreeStreamingOptions(country: String = "us") -> [StreamingOption] {
        return streamingOptions[country]?.filter { $0.price == nil || $0.price?.amount == "0" } ?? []
    }
    
    /// Get all paid streaming options
    func getPaidStreamingOptions(country: String = "us") -> [StreamingOption] {
        return streamingOptions[country]?.filter { $0.price != nil && $0.price?.amount != "0" } ?? []
    }
}

// MARK: - Popular Streaming Services

extension StreamingService {
    /// Popular streaming service IDs for easy reference
    enum PopularServices {
        static let netflix = "netflix"
        static let primeVideo = "prime"
        static let disneyPlus = "disney"
        static let hboMax = "hbo"
        static let hulu = "hulu"
        static let appleTV = "apple"
        static let paramount = "paramount"
        static let peacock = "peacock"
        static let starz = "starz"
    }
}
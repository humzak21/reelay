//
//  StreamingService.swift
//  reelay2
//
//  Created by Humza Khalil on 9/2/25.
//

import Foundation
import Combine

struct StreamingAvailabilityResponse: Codable {
    let itemType: String?
    let showType: String?
    let id: String?
    let imdbId: String?
    let tmdbId: String?
    let title: String?
    let overview: String?
    let releaseYear: Int?
    let originalTitle: String?
    let genres: [StreamingGenre]?
    let directors: [String]?
    let cast: [String]?
    let rating: Int?
    let runtime: Int?
    let imageSet: StreamingImageSet?
    let streamingOptions: [String: [StreamingOption]]?
    
    // Error handling
    let error: String?
    let message: String?
    
    // Computed properties for backward compatibility
    var type: String { showType ?? "unknown" }
    var posterUrl: String? { imageSet?.verticalPoster?.w480 }
    var backdropUrl: String? { imageSet?.horizontalBackdrop?.w1080 }
}

struct StreamingGenre: Codable {
    let id: String
    let name: String
}

struct StreamingImageSet: Codable {
    let verticalPoster: StreamingImageVariants?
    let horizontalPoster: StreamingImageVariants?
    let verticalBackdrop: StreamingImageVariants?
    let horizontalBackdrop: StreamingImageVariants?
}

struct StreamingImageVariants: Codable {
    let w240: String?
    let w360: String?
    let w480: String?
    let w600: String?
    let w720: String?
    let w1080: String?
}

struct StreamingOption: Codable, Identifiable {
    let id = UUID()
    let link: String
    let service: StreamingServiceInfo
    let type: String
    let quality: String?
    let audios: [StreamingLanguage]?
    let subtitles: [StreamingLanguage]?
    let price: StreamingPrice?
    
    private enum CodingKeys: String, CodingKey {
        case link, service, type, quality, audios, subtitles, price
    }
}

struct StreamingLanguage: Codable {
    let language: String?
    let region: String?
    
    // Handle cases where it might be a simple string or different structure
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        // Try to decode as string first
        if let stringValue = try? container.decode(String.self) {
            self.language = stringValue
            self.region = nil
        } else {
            // Try to decode as object
            let objectContainer = try decoder.container(keyedBy: CodingKeys.self)
            self.language = try objectContainer.decodeIfPresent(String.self, forKey: .language)
            self.region = try objectContainer.decodeIfPresent(String.self, forKey: .region)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(language, forKey: .language)
        try container.encodeIfPresent(region, forKey: .region)
    }
    
    private enum CodingKeys: String, CodingKey {
        case language, region
    }
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
        // print("🎬 [StreamingService] Starting movie streaming lookup for TMDB ID: \(tmdbId), country: \(country)")
        
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
        
        // Format TMDB ID correctly for the API (movie/{id})
        let formattedTmdbId = "movie/\(tmdbId)"
        // print("🔍 [StreamingService] Formatted TMDB ID: \(formattedTmdbId)")
        
        // Build URL with country parameter
        var urlComponents = URLComponents(string: "\(baseURL)/shows/\(formattedTmdbId)")
        urlComponents?.queryItems = [URLQueryItem(name: "country", value: country)]
        
        guard let url = urlComponents?.url else {
            let errorMsg = "Invalid URL for TMDB ID: \(tmdbId)"
            // print("❌ [StreamingService] \(errorMsg)")
            await MainActor.run {
                error = errorMsg
            }
            throw StreamingServiceError.invalidURL
        }
        
        // print("🌐 [StreamingService] Request URL: \(url.absoluteString)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(rapidAPIKey, forHTTPHeaderField: "X-RapidAPI-Key")
        request.addValue("streaming-availability.p.rapidapi.com", forHTTPHeaderField: "X-RapidAPI-Host")
        
        // print("🔑 [StreamingService] API Key present: \(!rapidAPIKey.isEmpty)")
        // print("📤 [StreamingService] Making request to streaming API...")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                let errorMsg = "Invalid response type"
                // print("❌ [StreamingService] \(errorMsg)")
                await MainActor.run {
                    error = errorMsg
                }
                throw StreamingServiceError.invalidResponse
            }
            
            // print("📥 [StreamingService] HTTP Status: \(httpResponse.statusCode)")
            // print("📥 [StreamingService] Response headers: \(httpResponse.allHeaderFields)")
            
            // Log response data for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                // print("📥 [StreamingService] Response body: \(responseString.prefix(500))...")
            }
            
            guard httpResponse.statusCode == 200 else {
                let errorMsg = "HTTP error: \(httpResponse.statusCode)"
                // print("❌ [StreamingService] \(errorMsg)")
                
                // Try to parse error response
                if let errorResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    // print("❌ [StreamingService] Error response: \(errorResponse)")
                }
                
                await MainActor.run {
                    error = errorMsg
                }
                throw StreamingServiceError.httpError(httpResponse.statusCode)
            }
            
            let result = try decoder.decode(StreamingAvailabilityResponse.self, from: data)
            // print("✅ [StreamingService] Successfully decoded response for: \(result.title ?? "Unknown")")
            // print("📺 [StreamingService] Streaming options count: \(result.streamingOptions?[country]?.count ?? 0)")
            
            // Check for API-level errors in the response
            if let error = result.error ?? result.message {
                // print("⚠️ [StreamingService] API returned error: \(error)")
                await MainActor.run {
                    self.error = error
                }
                // Return the response with error info rather than throwing
            }
            
            return result
            
        } catch let decodingError as DecodingError {
            let errorMsg = "Failed to decode response: \(decodingError.localizedDescription)"
            // print("❌ [StreamingService] Decoding error: \(decodingError)")
            
            // Print detailed decoding error info

            
            await MainActor.run {
                error = errorMsg
            }
            throw StreamingServiceError.decodingError(decodingError)
        } catch {
            let errorMsg = "Network error: \(error.localizedDescription)"
            // print("❌ [StreamingService] \(errorMsg)")
            await MainActor.run {
                self.error = errorMsg
            }
            throw StreamingServiceError.networkError(error)
        }
    }
    
    /// Get streaming availability for a TV show by TMDB ID
    func getTVShowStreamingAvailability(tmdbId: Int, country: String = "us") async throws -> StreamingAvailabilityResponse {
        // print("📺 [StreamingService] Starting TV show streaming lookup for TMDB ID: \(tmdbId), country: \(country)")
        
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
        
        // Format TMDB ID correctly for TV shows (tv/{id})
        let formattedTmdbId = "tv/\(tmdbId)"
        // print("🔍 [StreamingService] Formatted TMDB ID for TV: \(formattedTmdbId)")
        
        // Build URL with country parameter
        var urlComponents = URLComponents(string: "\(baseURL)/shows/\(formattedTmdbId)")
        urlComponents?.queryItems = [URLQueryItem(name: "country", value: country)]
        
        guard let url = urlComponents?.url else {
            let errorMsg = "Invalid URL for TV TMDB ID: \(tmdbId)"
            // print("❌ [StreamingService] \(errorMsg)")
            await MainActor.run {
                error = errorMsg
            }
            throw StreamingServiceError.invalidURL
        }
        
        // print("🌐 [StreamingService] TV Request URL: \(url.absoluteString)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(rapidAPIKey, forHTTPHeaderField: "X-RapidAPI-Key")
        request.addValue("streaming-availability.p.rapidapi.com", forHTTPHeaderField: "X-RapidAPI-Host")
        
        // print("🔑 [StreamingService] TV API Key present: \(!rapidAPIKey.isEmpty)")
        // print("📤 [StreamingService] Making TV request to streaming API...")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                let errorMsg = "Invalid response type for TV show"
                // print("❌ [StreamingService] \(errorMsg)")
                await MainActor.run {
                    error = errorMsg
                }
                throw StreamingServiceError.invalidResponse
            }
            
            // print("📥 [StreamingService] TV HTTP Status: \(httpResponse.statusCode)")
            // print("📥 [StreamingService] TV Response headers: \(httpResponse.allHeaderFields)")
            
            // Log response data for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                // print("📥 [StreamingService] TV Response body: \(responseString.prefix(500))...")
            }
            
            guard httpResponse.statusCode == 200 else {
                let errorMsg = "TV HTTP error: \(httpResponse.statusCode)"
                // print("❌ [StreamingService] \(errorMsg)")
                
                // Try to parse error response
                if let errorResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    // print("❌ [StreamingService] TV Error response: \(errorResponse)")
                }
                
                await MainActor.run {
                    error = errorMsg
                }
                throw StreamingServiceError.httpError(httpResponse.statusCode)
            }
            
            let result = try decoder.decode(StreamingAvailabilityResponse.self, from: data)
            // print("✅ [StreamingService] Successfully decoded TV response for: \(result.title ?? "Unknown")")
            // print("📺 [StreamingService] TV Streaming options count: \(result.streamingOptions?[country]?.count ?? 0)")
            
            // Check for API-level errors in the response
            if let error = result.error ?? result.message {
                // print("⚠️ [StreamingService] TV API returned error: \(error)")
                await MainActor.run {
                    self.error = error
                }
                // Return the response with error info rather than throwing
            }
            
            return result
            
        } catch let decodingError as DecodingError {
            let errorMsg = "Failed to decode TV response: \(decodingError.localizedDescription)"
            // print("❌ [StreamingService] TV Decoding error: \(decodingError)")
            
            // Print detailed decoding error info

            
            await MainActor.run {
                error = errorMsg
            }
            throw StreamingServiceError.decodingError(decodingError)
        } catch {
            let errorMsg = "TV Network error: \(error.localizedDescription)"
            // print("❌ [StreamingService] \(errorMsg)")
            await MainActor.run {
                self.error = errorMsg
            }
            throw StreamingServiceError.networkError(error)
        }
    }
    
    /// Get supported streaming services for a country
    func getSupportedServices(country: String = "us") async throws -> StreamingServicesResponse {
        // print("🌍 [StreamingService] Getting supported services for country: \(country)")
        
        guard let url = URL(string: "\(baseURL)/countries/\(country)") else {
            // print("❌ [StreamingService] Invalid URL for countries endpoint")
            throw StreamingServiceError.invalidURL
        }
        
        // print("🌐 [StreamingService] Countries URL: \(url.absoluteString)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Use RapidAPI authentication
        guard !rapidAPIKey.isEmpty else {
            // print("❌ [StreamingService] API key is empty")
            throw StreamingServiceError.authenticationRequired
        }
        
        request.addValue(rapidAPIKey, forHTTPHeaderField: "X-RapidAPI-Key")
        request.addValue("streaming-availability.p.rapidapi.com", forHTTPHeaderField: "X-RapidAPI-Host")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                // print("❌ [StreamingService] Invalid response type for countries")
                throw StreamingServiceError.invalidResponse
            }
            
            // print("📥 [StreamingService] Countries HTTP Status: \(httpResponse.statusCode)")
            
            guard httpResponse.statusCode == 200 else {
                // print("❌ [StreamingService] Countries HTTP error: \(httpResponse.statusCode)")
                throw StreamingServiceError.httpError(httpResponse.statusCode)
            }
            
            let result = try decoder.decode(StreamingServicesResponse.self, from: data)
            // print("✅ [StreamingService] Successfully got \(result.services.count) services for \(country)")
            
            return result
            
        } catch {
            // print("❌ [StreamingService] Countries lookup failed: \(error.localizedDescription)")
            throw error
        }
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
        let services = streamingOptions?[country]?.map { $0.service.name } ?? []
        // print("📋 [StreamingService] Available services for \(country): \(services)")
        return services
    }
    
    /// Get streaming options for a specific service
    func getStreamingOptions(for serviceName: String, country: String = "us") -> [StreamingOption] {
        let options = streamingOptions?[country]?.filter { $0.service.name.lowercased() == serviceName.lowercased() } ?? []
        // print("🔍 [StreamingService] Options for \(serviceName) in \(country): \(options.count)")
        return options
    }
    
    /// Check if content is available on a specific service
    func isAvailableOn(_ serviceName: String, country: String = "us") -> Bool {
        let available = !getStreamingOptions(for: serviceName, country: country).isEmpty
        // print("❓ [StreamingService] Available on \(serviceName): \(available)")
        return available
    }
    
    /// Get all free streaming options
    func getFreeStreamingOptions(country: String = "us") -> [StreamingOption] {
        return streamingOptions?[country]?.filter { $0.price == nil || $0.price?.amount == "0" } ?? []
    }
    
    /// Get all paid streaming options
    func getPaidStreamingOptions(country: String = "us") -> [StreamingOption] {
        return streamingOptions?[country]?.filter { $0.price != nil && $0.price?.amount != "0" } ?? []
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
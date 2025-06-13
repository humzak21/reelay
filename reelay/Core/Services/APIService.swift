//
//  APIService.swift
//  reelay
//
//  Created by Humza Khalil on 6/11/25.
//

import Foundation
import Alamofire

class APIService: ObservableObject {
    static let shared = APIService()
    private let baseURL: String
    
    // Cache for API responses
    private let cache = NSCache<NSString, CachedResponse>()
    private let cacheQueue = DispatchQueue(label: "api.cache.queue", attributes: .concurrent)
    
    private init() {
        self.baseURL = Config.apiBaseURL
        setupCache()
        setupURLCache()
    }
    
    private func setupCache() {
        cache.countLimit = 100
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB
    }
    
    private func setupURLCache() {
        // Configure URL cache for network requests
        let urlCache = URLCache(
            memoryCapacity: 20 * 1024 * 1024, // 20MB memory
            diskCapacity: 100 * 1024 * 1024,  // 100MB disk
            diskPath: "api_cache"
        )
        URLCache.shared = urlCache
    }
    
    // MARK: - Movie Operations
    func getAllMovies(page: Int = 1, limit: Int = 50) async throws -> MovieResponse {
        let cacheKey = "movies_\(page)_\(limit)"
        
        // Check cache first
        if let cachedResponse = getCachedResponse(for: cacheKey),
           !cachedResponse.isExpired {
            return cachedResponse.data as! MovieResponse
        }
        
        let response = await AF.request("\(baseURL)/",
                                      parameters: ["page": page, "limit": limit])
            .cacheResponse(using: .cache)
            .serializingDecodable(MovieResponse.self)
            .response
        
        switch response.result {
        case .success(let movieResponse):
            // Cache the response for 5 minutes
            setCachedResponse(movieResponse, for: cacheKey, ttl: 300)
            return movieResponse
        case .failure(let error):
            print("API Error - getAllMovies: \(error)")
            throw error
        }
    }
    
    func addMovie(_ movieData: AddMovieRequest) async throws -> Movie {
        let response = await AF.request("\(baseURL)/add",
                                      method: .post,
                                      parameters: movieData,
                                      encoder: JSONParameterEncoder.default)
            .serializingDecodable(SingleMovieResponse.self)
            .response
        
        switch response.result {
        case .success(let response):
            // Invalidate movies cache when adding new movie
            invalidateMoviesCache()
            return response.data
        case .failure(let error):
            print("API Error - addMovie: \(error)")
            throw error
        }
    }
    
    func searchMovies(query: String) async throws -> [Movie] {
        let cacheKey = "search_\(query.lowercased())"
        
        // Check cache first (shorter TTL for search results)
        if let cachedResponse = getCachedResponse(for: cacheKey),
           !cachedResponse.isExpired {
            return (cachedResponse.data as! MovieResponse).data
        }
        
        let response = await AF.request("\(baseURL)/search",
                                      parameters: ["q": query])
            .cacheResponse(using: .cache)
            .serializingDecodable(MovieResponse.self)
            .response
        
        switch response.result {
        case .success(let movieResponse):
            // Cache search results for 2 minutes
            setCachedResponse(movieResponse, for: cacheKey, ttl: 120)
            return movieResponse.data
        case .failure(let error):
            print("API Error - searchMovies: \(error)")
            throw error
        }
    }
    
    // MARK: - Statistics
    func getDashboardStats() async throws -> DashboardStats {
        let cacheKey = "dashboard_stats"
        
        if let cachedResponse = getCachedResponse(for: cacheKey),
           !cachedResponse.isExpired {
            return cachedResponse.data as! DashboardStats
        }
        
        let response = await AF.request("\(baseURL)/stats/dashboard")
            .cacheResponse(using: .cache)
            .serializingDecodable(StatsResponse<DashboardStats>.self)
            .response
        
        switch response.result {
        case .success(let statsResponse):
            // Cache stats for 10 minutes
            setCachedResponse(statsResponse.data, for: cacheKey, ttl: 600)
            return statsResponse.data
        case .failure(let error):
            print("API Error - getDashboardStats: \(error)")
            throw error
        }
    }
    
    func getRatingDistribution() async throws -> [RatingDistribution] {
        let cacheKey = "rating_distribution"
        
        if let cachedResponse = getCachedResponse(for: cacheKey),
           !cachedResponse.isExpired {
            return cachedResponse.data as! [RatingDistribution]
        }
        
        let response = await AF.request("\(baseURL)/stats/rating-distribution")
            .cacheResponse(using: .cache)
            .serializingDecodable(StatsResponse<[RatingDistribution]>.self)
            .response
        
        switch response.result {
        case .success(let statsResponse):
            setCachedResponse(statsResponse.data, for: cacheKey, ttl: 600)
            return statsResponse.data
        case .failure(let error):
            print("API Error - getRatingDistribution: \(error)")
            throw error
        }
    }
    
    func getGenreStats() async throws -> [GenreStats] {
        let cacheKey = "genre_stats"
        
        if let cachedResponse = getCachedResponse(for: cacheKey),
           !cachedResponse.isExpired {
            return cachedResponse.data as! [GenreStats]
        }
        
        let response = await AF.request("\(baseURL)/stats/genres")
            .cacheResponse(using: .cache)
            .serializingDecodable(StatsResponse<[GenreStats]>.self)
            .response
        
        switch response.result {
        case .success(let statsResponse):
            setCachedResponse(statsResponse.data, for: cacheKey, ttl: 600)
            return statsResponse.data
        case .failure(let error):
            print("API Error - getGenreStats: \(error)")
            throw error
        }
    }
    
    func getFilmsPerYear() async throws -> [FilmsPerYear] {
        let cacheKey = "films_per_year"
        
        if let cachedResponse = getCachedResponse(for: cacheKey),
           !cachedResponse.isExpired {
            return cachedResponse.data as! [FilmsPerYear]
        }
        
        let response = await AF.request("\(baseURL)/stats/films-per-year")
            .cacheResponse(using: .cache)
            .serializingDecodable(StatsResponse<[FilmsPerYear]>.self)
            .response
        
        switch response.result {
        case .success(let statsResponse):
            setCachedResponse(statsResponse.data, for: cacheKey, ttl: 600)
            return statsResponse.data
        case .failure(let error):
            print("API Error - getFilmsPerYear: \(error)")
            throw error
        }
    }
    
    // MARK: - Cache Management
    private func getCachedResponse(for key: String) -> CachedResponse? {
        return cacheQueue.sync {
            cache.object(forKey: NSString(string: key))
        }
    }
    
    private func setCachedResponse(_ data: Any, for key: String, ttl: TimeInterval) {
        let cachedResponse = CachedResponse(data: data, expirationDate: Date().addingTimeInterval(ttl))
        cacheQueue.async(flags: .barrier) {
            self.cache.setObject(cachedResponse, forKey: NSString(string: key))
        }
    }
    
    private func invalidateMoviesCache() {
        cacheQueue.async(flags: .barrier) {
            // Remove all movie-related cache entries
            let keys = ["dashboard_stats", "rating_distribution", "genre_stats", "films_per_year"]
            keys.forEach { key in
                self.cache.removeObject(forKey: NSString(string: key))
            }
            
            // Remove paginated movie caches (this is a simplified approach)
            self.cache.removeAllObjects()
        }
    }
}

// MARK: - Cache Helper Classes
private class CachedResponse {
    let data: Any
    let expirationDate: Date
    
    init(data: Any, expirationDate: Date) {
        self.data = data
        self.expirationDate = expirationDate
    }
    
    var isExpired: Bool {
        return Date() > expirationDate
    }
}

struct StatsResponse<T: Codable>: Codable {
    let success: Bool
    let data: T
}

struct SingleMovieResponse: Codable {
    let success: Bool
    let data: Movie
}

struct AddMovieRequest: Codable {
    let title: String
    let year: Int?
    let userRating: Double?
    let detailedRating: Double?
    let watchDate: String?
    let isRewatch: Bool
    let tmdbId: Int?
    let overview: String?
    let posterUrl: String?
    let backdropUrl: String?
    let director: String?
    let runtime: Int?
    let voteAverage: Double?
    let genres: String? // Comma-separated genre names
    let reviews: String?
    
    enum CodingKeys: String, CodingKey {
        case title, year, isRewatch, overview, director, runtime, genres, reviews
        case userRating = "user_rating"
        case detailedRating = "detailed_rating"
        case watchDate = "watch_date"
        case tmdbId = "tmdb_id"
        case posterUrl = "poster_url"
        case backdropUrl = "backdrop_url"
        case voteAverage = "vote_average"
    }
}

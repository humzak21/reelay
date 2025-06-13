//
//  TMDBService.swift
//  reelay
//
//  Created by Humza Khalil on 6/11/25.
//

import Foundation
import Alamofire

class TMDBService: ObservableObject {
    static let shared = TMDBService()
    private let baseURL = "https://api.themoviedb.org/3"
    private let apiKey = Config.tmdbAPIKey
    
    // Cache for TMDB responses
    private let cache = NSCache<NSString, CachedTMDBResponse>()
    private let cacheQueue = DispatchQueue(label: "tmdb.cache.queue", attributes: .concurrent)
    
    private init() {
        setupCache()
    }
    
    private func setupCache() {
        cache.countLimit = 200 // Cache up to 200 responses
        cache.totalCostLimit = 30 * 1024 * 1024 // 30MB cache limit
    }
    
    func searchMovies(query: String) async throws -> [TMDBMovie] {
        guard !query.isEmpty else { return [] }
        
        let cacheKey = "search_\(query.lowercased())"
        
        // Check cache first
        if let cachedResponse = getCachedResponse(for: cacheKey),
           !cachedResponse.isExpired {
            return cachedResponse.data as! [TMDBMovie]
        }
        
        let response = await AF.request("\(baseURL)/search/movie",
                                      parameters: [
                                        "api_key": apiKey,
                                        "query": query,
                                        "page": 1
                                      ])
            .cacheResponse(using: .cache)
            .serializingDecodable(TMDBSearchResponse.self)
            .response
        
        switch response.result {
        case .success(let searchResponse):
            // Cache search results for 30 minutes
            setCachedResponse(searchResponse.results, for: cacheKey, ttl: 1800)
            return searchResponse.results
        case .failure(let error):
            print("TMDB Search Error: \(error)")
            throw error
        }
    }
    
    func getMovieDetails(movieId: Int) async throws -> TMDBMovieDetails {
        let cacheKey = "details_\(movieId)"
        
        // Check cache first
        if let cachedResponse = getCachedResponse(for: cacheKey),
           !cachedResponse.isExpired {
            return cachedResponse.data as! TMDBMovieDetails
        }
        
        let response = await AF.request("\(baseURL)/movie/\(movieId)",
                                      parameters: [
                                        "api_key": apiKey,
                                        "append_to_response": "credits"
                                      ])
            .cacheResponse(using: .cache)
            .serializingDecodable(TMDBMovieDetails.self)
            .response
        
        switch response.result {
        case .success(let movieDetails):
            // Cache movie details for 24 hours (they rarely change)
            setCachedResponse(movieDetails, for: cacheKey, ttl: 86400)
            return movieDetails
        case .failure(let error):
            print("TMDB Movie Details Error: \(error)")
            throw error
        }
    }
    
    // MARK: - Cache Management
    private func getCachedResponse(for key: String) -> CachedTMDBResponse? {
        return cacheQueue.sync {
            cache.object(forKey: NSString(string: key))
        }
    }
    
    private func setCachedResponse(_ data: Any, for key: String, ttl: TimeInterval) {
        let cachedResponse = CachedTMDBResponse(data: data, expirationDate: Date().addingTimeInterval(ttl))
        cacheQueue.async(flags: .barrier) {
            self.cache.setObject(cachedResponse, forKey: NSString(string: key))
        }
    }
}

// MARK: - Cache Helper Class
private class CachedTMDBResponse {
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
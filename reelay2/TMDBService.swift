//
//  TMDBService.swift
//  reelay2
//
//  Created by Humza Khalil on 8/1/25.
//

import Foundation
import Combine

class TMDBService: ObservableObject {
    static let shared = TMDBService()
    
    private let baseURL = "https://api.themoviedb.org/3"
    private let apiKey = Config.TMDB_API_KEY
    private let session = URLSession.shared
    
    private init() {}
    
    // MARK: - Search Movies
    func searchMovies(query: String, page: Int = 1) async throws -> TMDBSearchResponse {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw TMDBError.invalidQuery
        }
        
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "\(baseURL)/search/movie?api_key=\(apiKey)&query=\(encodedQuery)&page=\(page)"
        
        guard let url = URL(string: urlString) else {
            throw TMDBError.invalidURL
        }
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TMDBError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw TMDBError.httpError(httpResponse.statusCode)
        }
        
        do {
            let searchResponse = try JSONDecoder().decode(TMDBSearchResponse.self, from: data)
            return searchResponse
        } catch {
            throw TMDBError.decodingError(error)
        }
    }
    
    // MARK: - Get Movie Details
    func getMovieDetails(movieId: Int) async throws -> TMDBMovieDetails {
        let urlString = "\(baseURL)/movie/\(movieId)?api_key=\(apiKey)"
        
        guard let url = URL(string: urlString) else {
            throw TMDBError.invalidURL
        }
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TMDBError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw TMDBError.httpError(httpResponse.statusCode)
        }
        
        do {
            let movieDetails = try JSONDecoder().decode(TMDBMovieDetails.self, from: data)
            return movieDetails
        } catch {
            throw TMDBError.decodingError(error)
        }
    }
    
    // MARK: - Get Movie Credits (for director info)
    func getMovieCredits(movieId: Int) async throws -> TMDBCreditsResponse {
        let urlString = "\(baseURL)/movie/\(movieId)/credits?api_key=\(apiKey)"
        
        guard let url = URL(string: urlString) else {
            throw TMDBError.invalidURL
        }
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TMDBError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw TMDBError.httpError(httpResponse.statusCode)
        }
        
        do {
            let credits = try JSONDecoder().decode(TMDBCreditsResponse.self, from: data)
            return credits
        } catch {
            throw TMDBError.decodingError(error)
        }
    }
    
    // MARK: - Get Complete Movie Data
    func getCompleteMovieData(movieId: Int) async throws -> (details: TMDBMovieDetails, director: String?) {
        async let detailsTask = getMovieDetails(movieId: movieId)
        async let creditsTask = getMovieCredits(movieId: movieId)
        
        let (details, credits) = try await (detailsTask, creditsTask)
        
        // Find director from crew
        let director = credits.crew?.first { $0.job?.lowercased() == "director" }?.name
        
        return (details, director)
    }
}

// MARK: - TMDB Errors
enum TMDBError: LocalizedError {
    case invalidQuery
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case decodingError(Error)
    
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
        }
    }
}
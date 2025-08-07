//
//  TMDBModels.swift
//  reelay2
//
//  Created by Humza Khalil on 8/1/25.
//

import Foundation

// MARK: - TMDB Search Response
struct TMDBSearchResponse: Codable {
    let page: Int
    let results: [TMDBMovie]
    let totalPages: Int
    let totalResults: Int
    
    enum CodingKeys: String, CodingKey {
        case page, results
        case totalPages = "total_pages"
        case totalResults = "total_results"
    }
}

// MARK: - TMDB Movie
struct TMDBMovie: Codable, Identifiable {
    let id: Int
    let title: String
    let originalTitle: String?
    let overview: String?
    let releaseDate: String?
    let posterPath: String?
    let backdropPath: String?
    let voteAverage: Double?
    let voteCount: Int?
    let popularity: Double?
    let originalLanguage: String?
    let genreIds: [Int]?
    let adult: Bool?
    let video: Bool?
    
    enum CodingKeys: String, CodingKey {
        case id, title, overview, popularity, adult, video
        case originalTitle = "original_title"
        case releaseDate = "release_date"
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case voteAverage = "vote_average"
        case voteCount = "vote_count"
        case originalLanguage = "original_language"
        case genreIds = "genre_ids"
    }
}

// MARK: - TMDB Movie Details
struct TMDBMovieDetails: Codable {
    let id: Int
    let title: String
    let originalTitle: String?
    let overview: String?
    let releaseDate: String?
    let posterPath: String?
    let backdropPath: String?
    let voteAverage: Double?
    let voteCount: Int?
    let popularity: Double?
    let originalLanguage: String?
    let runtime: Int?
    let tagline: String?
    let status: String?
    let budget: Int?
    let revenue: Int?
    let imdbId: String?
    let homepage: String?
    let genres: [TMDBGenre]?
    let adult: Bool?
    let video: Bool?
    
    enum CodingKeys: String, CodingKey {
        case id, title, overview, popularity, adult, video, runtime, tagline, status, budget, revenue, homepage, genres
        case originalTitle = "original_title"
        case releaseDate = "release_date"
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case voteAverage = "vote_average"
        case voteCount = "vote_count"
        case originalLanguage = "original_language"
        case imdbId = "imdb_id"
    }
}

// MARK: - TMDB Genre
struct TMDBGenre: Codable {
    let id: Int
    let name: String
}

// MARK: - TMDB Credits Response
struct TMDBCreditsResponse: Codable {
    let id: Int
    let cast: [TMDBCastMember]?
    let crew: [TMDBCrewMember]?
}

struct TMDBCastMember: Codable {
    let id: Int
    let name: String
    let character: String?
    let order: Int?
    let profilePath: String?
    
    enum CodingKeys: String, CodingKey {
        case id, name, character, order
        case profilePath = "profile_path"
    }
}

struct TMDBCrewMember: Codable {
    let id: Int
    let name: String
    let job: String?
    let department: String?
    let profilePath: String?
    
    enum CodingKeys: String, CodingKey {
        case id, name, job, department
        case profilePath = "profile_path"
    }
}

// MARK: - Extensions
extension TMDBMovie {
    var posterURL: URL? {
        guard let posterPath = posterPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w500\(posterPath)")
    }
    
    var fullPosterURL: String? {
        guard let posterPath = posterPath else { return nil }
        return "https://image.tmdb.org/t/p/w500\(posterPath)"
    }
    
    var backdropURL: URL? {
        guard let backdropPath = backdropPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w1280\(backdropPath)")
    }
    
    var releaseYear: Int? {
        guard let dateString = releaseDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dateString)?.year
    }
}

extension TMDBMovieDetails {
    var posterURL: URL? {
        guard let posterPath = posterPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w500\(posterPath)")
    }
    
    var backdropURL: URL? {
        guard let backdropPath = backdropPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w1280\(backdropPath)")
    }
    
    var releaseYear: Int? {
        guard let dateString = releaseDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dateString)?.year
    }
    
    var genreNames: [String] {
        return genres?.map { $0.name } ?? []
    }
}

extension Date {
    var year: Int {
        return Calendar.current.component(.year, from: self)
    }
}
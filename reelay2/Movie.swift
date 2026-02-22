//
//  Movie.swift
//  reelay2
//
//  Created by Humza Khalil on 7/31/25.
//

import Foundation

enum TMDBPosterSize: String {
    case w92
    case w154
    case w185
    case w342
    case w500
    case w780
    case original
}

struct Movie: Codable, Identifiable, @unchecked Sendable {
    let id: Int
    let user_id: String?
    let title: String
    let release_year: Int?
    let release_date: String?
    let rating: Double?
    let detailed_rating: Double?
    let review: String?
    let tags: String?
    let watch_date: String?
    let is_rewatch: Bool?
    let tmdb_id: Int?
    let overview: String?
    let poster_url: String?
    let backdrop_path: String?
    let director: String?
    let runtime: Int?
    let vote_average: Double?
    let vote_count: Int?
    let popularity: Double?
    let original_language: String?
    let original_title: String?
    let tagline: String?
    let status: String?
    let budget: Int?
    let revenue: Int?
    let imdb_id: String?
    let homepage: String?
    let genres: [String]?
    let location_id: Int?
    let created_at: String?
    let updated_at: String?
    let favorited: Bool?
    
    init(id: Int, title: String, release_year: Int?, release_date: String?, rating: Double?, detailed_rating: Double?, review: String?, tags: String?, watch_date: String?, is_rewatch: Bool?, tmdb_id: Int?, overview: String?, poster_url: String?, backdrop_path: String?, director: String?, runtime: Int?, vote_average: Double?, vote_count: Int?, popularity: Double?, original_language: String?, original_title: String?, tagline: String?, status: String?, budget: Int?, revenue: Int?, imdb_id: String?, homepage: String?, genres: [String]?, created_at: String?, updated_at: String?, favorited: Bool? = nil, location_id: Int? = nil, user_id: String? = nil) {
        self.id = id
        self.user_id = user_id
        self.title = title
        self.release_year = release_year
        self.release_date = release_date
        self.rating = rating
        self.detailed_rating = detailed_rating
        self.review = review
        self.tags = tags
        self.watch_date = watch_date
        self.is_rewatch = is_rewatch
        self.tmdb_id = tmdb_id
        self.overview = overview
        self.poster_url = poster_url
        self.backdrop_path = backdrop_path
        self.director = director
        self.runtime = runtime
        self.vote_average = vote_average
        self.vote_count = vote_count
        self.popularity = popularity
        self.original_language = original_language
        self.original_title = original_title
        self.tagline = tagline
        self.status = status
        self.budget = budget
        self.revenue = revenue
        self.imdb_id = imdb_id
        self.homepage = homepage
        self.genres = genres
        self.location_id = location_id
        self.created_at = created_at
        self.updated_at = updated_at
        self.favorited = favorited
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case user_id
        case title
        case release_year
        case release_date
        case rating
        case detailed_rating = "ratings100"
        case review = "reviews"
        case tags
        case watch_date = "watched_date"
        case is_rewatch = "rewatch"
        case tmdb_id
        case overview
        case poster_url
        case backdrop_path
        case director
        case runtime
        case vote_average
        case vote_count
        case popularity
        case original_language
        case original_title
        case tagline
        case status
        case budget
        case revenue
        case imdb_id
        case homepage
        case genres
        case location_id
        case created_at
        case updated_at
        case favorited
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(Int.self, forKey: .id)
        user_id = try container.decodeIfPresent(String.self, forKey: .user_id)
        title = try container.decode(String.self, forKey: .title)
        release_year = try container.decodeIfPresent(Int.self, forKey: .release_year)
        release_date = try container.decodeIfPresent(String.self, forKey: .release_date)
        rating = try container.decodeIfPresent(Double.self, forKey: .rating)
        detailed_rating = try container.decodeIfPresent(Double.self, forKey: .detailed_rating)
        review = try container.decodeIfPresent(String.self, forKey: .review)
        tags = try container.decodeIfPresent(String.self, forKey: .tags)
        watch_date = try container.decodeIfPresent(String.self, forKey: .watch_date)
        tmdb_id = try container.decodeIfPresent(Int.self, forKey: .tmdb_id)
        overview = try container.decodeIfPresent(String.self, forKey: .overview)
        poster_url = try container.decodeIfPresent(String.self, forKey: .poster_url)
        backdrop_path = try container.decodeIfPresent(String.self, forKey: .backdrop_path)
        director = try container.decodeIfPresent(String.self, forKey: .director)
        runtime = try container.decodeIfPresent(Int.self, forKey: .runtime)
        vote_average = try container.decodeIfPresent(Double.self, forKey: .vote_average)
        vote_count = try container.decodeIfPresent(Int.self, forKey: .vote_count)
        popularity = try container.decodeIfPresent(Double.self, forKey: .popularity)
        original_language = try container.decodeIfPresent(String.self, forKey: .original_language)
        original_title = try container.decodeIfPresent(String.self, forKey: .original_title)
        tagline = try container.decodeIfPresent(String.self, forKey: .tagline)
        status = try container.decodeIfPresent(String.self, forKey: .status)
        budget = try container.decodeIfPresent(Int.self, forKey: .budget)
        revenue = try container.decodeIfPresent(Int.self, forKey: .revenue)
        imdb_id = try container.decodeIfPresent(String.self, forKey: .imdb_id)
        homepage = try container.decodeIfPresent(String.self, forKey: .homepage)
        genres = try container.decodeIfPresent([String].self, forKey: .genres)
        location_id = try container.decodeIfPresent(Int.self, forKey: .location_id)
        created_at = try container.decodeIfPresent(String.self, forKey: .created_at)
        updated_at = try container.decodeIfPresent(String.self, forKey: .updated_at)
        favorited = try container.decodeIfPresent(Bool.self, forKey: .favorited)
        
        // Handle rewatch field which can be "yes"/"no" string or boolean
        if let rewatchString = try? container.decodeIfPresent(String.self, forKey: .is_rewatch) {
            is_rewatch = rewatchString.lowercased() == "yes"
        } else if let rewatchBool = try? container.decodeIfPresent(Bool.self, forKey: .is_rewatch) {
            is_rewatch = rewatchBool
        } else {
            is_rewatch = nil
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(user_id, forKey: .user_id)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(release_year, forKey: .release_year)
        try container.encodeIfPresent(release_date, forKey: .release_date)
        try container.encodeIfPresent(rating, forKey: .rating)
        try container.encodeIfPresent(detailed_rating, forKey: .detailed_rating)
        try container.encodeIfPresent(review, forKey: .review)
        try container.encodeIfPresent(tags, forKey: .tags)
        try container.encodeIfPresent(watch_date, forKey: .watch_date)
        try container.encodeIfPresent(tmdb_id, forKey: .tmdb_id)
        try container.encodeIfPresent(overview, forKey: .overview)
        try container.encodeIfPresent(poster_url, forKey: .poster_url)
        try container.encodeIfPresent(backdrop_path, forKey: .backdrop_path)
        try container.encodeIfPresent(director, forKey: .director)
        try container.encodeIfPresent(runtime, forKey: .runtime)
        try container.encodeIfPresent(vote_average, forKey: .vote_average)
        try container.encodeIfPresent(vote_count, forKey: .vote_count)
        try container.encodeIfPresent(popularity, forKey: .popularity)
        try container.encodeIfPresent(original_language, forKey: .original_language)
        try container.encodeIfPresent(original_title, forKey: .original_title)
        try container.encodeIfPresent(tagline, forKey: .tagline)
        try container.encodeIfPresent(status, forKey: .status)
        try container.encodeIfPresent(budget, forKey: .budget)
        try container.encodeIfPresent(revenue, forKey: .revenue)
        try container.encodeIfPresent(imdb_id, forKey: .imdb_id)
        try container.encodeIfPresent(homepage, forKey: .homepage)
        try container.encodeIfPresent(genres, forKey: .genres)
        try container.encodeIfPresent(location_id, forKey: .location_id)
        try container.encodeIfPresent(created_at, forKey: .created_at)
        try container.encodeIfPresent(updated_at, forKey: .updated_at)
        try container.encodeIfPresent(favorited, forKey: .favorited)
        
        // Encode rewatch as string for Supabase compatibility
        if let isRewatch = is_rewatch {
            try container.encode(isRewatch ? "yes" : "no", forKey: .is_rewatch)
        }
    }
}

// MARK: - Computed Properties
extension Movie {
    var genreArray: [String] {
        return genres ?? []
    }
    
    var formattedReleaseYear: String {
        guard let year = release_year else { return "Unknown" }
        return String(year)
    }
    
    var formattedRating: String {
        guard let rating = rating else { return "Unrated" }
        return String(format: "%.1f", rating)
    }
    
    var formattedDetailedRating: String {
        guard let detailedRating = detailed_rating else { return "N/A" }
        return String(format: "%.0f", detailedRating)
    }
    
    var formattedRuntime: String {
        guard let runtime = runtime else { return "Unknown" }
        let hours = runtime / 60
        let minutes = runtime % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    var posterURL: URL? {
        guard let urlString = poster_url, !urlString.isEmpty else { return nil }
        
        // If it's already a full URL, use it
        if urlString.hasPrefix("http") {
            return URL(string: urlString)
        }
        
        // If it's a relative path, construct the full TMDB URL
        if urlString.hasPrefix("/") {
            return URL(string: "https://image.tmdb.org/t/p/w500\(urlString)")
        }
        
        // Fallback: try to use as-is
        return URL(string: urlString)
    }

    func posterURL(for size: TMDBPosterSize) -> URL? {
        guard let urlString = poster_url, !urlString.isEmpty else { return nil }

        if let relativePath = normalizedTMDBPosterPath(from: urlString) {
            return URL(string: "https://image.tmdb.org/t/p/\(size.rawValue)\(relativePath)")
        }

        if urlString.hasPrefix("http") {
            return URL(string: urlString)
        }

        return URL(string: urlString)
    }
    
    var backdropURL: URL? {
        guard let urlString = backdrop_path, !urlString.isEmpty else { return nil }
        
        // If it's already a full URL, use it
        if urlString.hasPrefix("http") {
            return URL(string: urlString)
        }
        
        // If it's a relative path, construct the full TMDB URL
        if urlString.hasPrefix("/") {
            return URL(string: "https://image.tmdb.org/t/p/w1280\(urlString)")
        }
        
        // Fallback: try to use as-is
        return URL(string: urlString)
    }
    
    var isRewatchMovie: Bool {
        return is_rewatch == true
    }
    
    var isFavorited: Bool {
        return favorited ?? false
    }

    private func normalizedTMDBPosterPath(from rawValue: String) -> String? {
        if rawValue.hasPrefix("/") {
            return rawValue
        }

        guard let components = URLComponents(string: rawValue),
              let host = components.host?.lowercased(),
              host.contains("image.tmdb.org") else {
            return nil
        }

        let path = components.path
        if let sizeRange = path.range(of: #"/t/p/(w\d+|original)/"#, options: .regularExpression) {
            return "/" + String(path[sizeRange.upperBound...])
        }

        if path.hasPrefix("/t/p/"), let lastSlash = path.lastIndex(of: "/") {
            return String(path[lastSlash...])
        }

        return nil
    }
}

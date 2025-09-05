//
//  Television.swift
//  reelay2
//
//  Created by Humza Khalil on 9/1/25.
//

import Foundation

struct Television: Codable, Identifiable, @unchecked Sendable {
    let id: Int
    let name: String
    let first_air_year: Int?
    let first_air_date: String?
    let last_air_date: String?
    let rating: Double?
    let detailed_rating: Double?
    let review: String?
    let tags: String?
    let current_season: Int?
    let current_episode: Int?
    let total_seasons: Int?
    let total_episodes: Int?
    let status: String? // "watching", "completed", "dropped", "plan_to_watch"
    let tmdb_id: Int?
    let overview: String?
    let poster_url: String?
    let backdrop_path: String?
    let vote_average: Double?
    let vote_count: Int?
    let popularity: Double?
    let original_language: String?
    let original_name: String?
    let tagline: String?
    let series_status: String? // "Ended", "Returning Series", etc.
    let homepage: String?
    let genres: [String]?
    let networks: [String]?
    let created_by: [String]?
    let episode_run_time: [Int]?
    let in_production: Bool?
    let number_of_episodes: Int?
    let number_of_seasons: Int?
    let origin_country: [String]?
    let type: String?
    let current_episode_name: String?
    let current_episode_overview: String?
    let current_episode_air_date: String?
    let current_episode_still_path: String?
    let current_episode_runtime: Int?
    let current_episode_vote_average: Double?
    let created_at: String?
    let updated_at: String?
    let favorited: Bool?
    
    init(id: Int, name: String, first_air_year: Int?, first_air_date: String?, last_air_date: String?, rating: Double?, detailed_rating: Double?, review: String?, tags: String?, current_season: Int?, current_episode: Int?, total_seasons: Int?, total_episodes: Int?, status: String?, tmdb_id: Int?, overview: String?, poster_url: String?, backdrop_path: String?, vote_average: Double?, vote_count: Int?, popularity: Double?, original_language: String?, original_name: String?, tagline: String?, series_status: String?, homepage: String?, genres: [String]?, networks: [String]?, created_by: [String]?, episode_run_time: [Int]?, in_production: Bool?, number_of_episodes: Int?, number_of_seasons: Int?, origin_country: [String]?, type: String?, current_episode_name: String?, current_episode_overview: String?, current_episode_air_date: String?, current_episode_still_path: String?, current_episode_runtime: Int?, current_episode_vote_average: Double?, created_at: String?, updated_at: String?, favorited: Bool? = nil) {
        self.id = id
        self.name = name
        self.first_air_year = first_air_year
        self.first_air_date = first_air_date
        self.last_air_date = last_air_date
        self.rating = rating
        self.detailed_rating = detailed_rating
        self.review = review
        self.tags = tags
        self.current_season = current_season
        self.current_episode = current_episode
        self.total_seasons = total_seasons
        self.total_episodes = total_episodes
        self.status = status
        self.tmdb_id = tmdb_id
        self.overview = overview
        self.poster_url = poster_url
        self.backdrop_path = backdrop_path
        self.vote_average = vote_average
        self.vote_count = vote_count
        self.popularity = popularity
        self.original_language = original_language
        self.original_name = original_name
        self.tagline = tagline
        self.series_status = series_status
        self.homepage = homepage
        self.genres = genres
        self.networks = networks
        self.created_by = created_by
        self.episode_run_time = episode_run_time
        self.in_production = in_production
        self.number_of_episodes = number_of_episodes
        self.number_of_seasons = number_of_seasons
        self.origin_country = origin_country
        self.type = type
        self.current_episode_name = current_episode_name
        self.current_episode_overview = current_episode_overview
        self.current_episode_air_date = current_episode_air_date
        self.current_episode_still_path = current_episode_still_path
        self.current_episode_runtime = current_episode_runtime
        self.current_episode_vote_average = current_episode_vote_average
        self.created_at = created_at
        self.updated_at = updated_at
        self.favorited = favorited
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case first_air_year
        case first_air_date
        case last_air_date
        case rating
        case detailed_rating = "ratings100"
        case review = "reviews"
        case tags
        case current_season
        case current_episode
        case total_seasons
        case total_episodes
        case status
        case tmdb_id
        case overview
        case poster_url
        case backdrop_path
        case vote_average
        case vote_count
        case popularity
        case original_language
        case original_name
        case tagline
        case series_status
        case homepage
        case genres
        case networks
        case created_by
        case episode_run_time
        case in_production
        case number_of_episodes
        case number_of_seasons
        case origin_country
        case type
        case current_episode_name
        case current_episode_overview
        case current_episode_air_date
        case current_episode_still_path
        case current_episode_runtime
        case current_episode_vote_average
        case created_at
        case updated_at
        case favorited
    }
}

// MARK: - Computed Properties
extension Television {
    var genreArray: [String] {
        return genres ?? []
    }
    
    var networkArray: [String] {
        return networks ?? []
    }
    
    var creatorArray: [String] {
        return created_by ?? []
    }
    
    var originCountryArray: [String] {
        return origin_country ?? []
    }
    
    var formattedFirstAirYear: String {
        guard let year = first_air_year else { return "Unknown" }
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
        guard let runtimes = episode_run_time, let runtime = runtimes.first else { return "Unknown" }
        if runtime >= 60 {
            let hours = runtime / 60
            let minutes = runtime % 60
            return "\(hours)h \(minutes)m"
        } else {
            return "\(runtime)m"
        }
    }
    
    var posterURL: URL? {
        guard let urlString = poster_url, !urlString.isEmpty else { return nil }
        
        if urlString.hasPrefix("http") {
            return URL(string: urlString)
        }
        
        if urlString.hasPrefix("/") {
            return URL(string: "https://image.tmdb.org/t/p/w500\(urlString)")
        }
        
        return URL(string: urlString)
    }
    
    var backdropURL: URL? {
        guard let urlString = backdrop_path, !urlString.isEmpty else { return nil }
        
        if urlString.hasPrefix("http") {
            return URL(string: urlString)
        }
        
        if urlString.hasPrefix("/") {
            return URL(string: "https://image.tmdb.org/t/p/w1280\(urlString)")
        }
        
        return URL(string: urlString)
    }
    
    var currentEpisodeStillURL: URL? {
        guard let urlString = current_episode_still_path, !urlString.isEmpty else { return nil }
        
        if urlString.hasPrefix("http") {
            return URL(string: urlString)
        }
        
        if urlString.hasPrefix("/") {
            return URL(string: "https://image.tmdb.org/t/p/w500\(urlString)")
        }
        
        return URL(string: urlString)
    }
    
    var formattedCurrentEpisodeAirDate: String? {
        guard let airDateString = current_episode_air_date else { return nil }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        guard let date = formatter.date(from: airDateString) else { return airDateString }
        
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    var formattedCurrentEpisodeRuntime: String? {
        guard let runtime = current_episode_runtime else { return nil }
        
        if runtime >= 60 {
            let hours = runtime / 60
            let minutes = runtime % 60
            return "\(hours)h \(minutes)m"
        } else {
            return "\(runtime)m"
        }
    }
    
    var formattedCurrentEpisodeRating: String? {
        guard let rating = current_episode_vote_average else { return nil }
        return String(format: "%.1f", rating)
    }
    
    var watchingStatus: WatchingStatus {
        return WatchingStatus(rawValue: status ?? "plan_to_watch") ?? .planToWatch
    }
    
    var progressText: String {
        guard let currentSeason = current_season, let currentEpisode = current_episode else {
            return "Not started"
        }
        return "S\(currentSeason) E\(currentEpisode)"
    }
    
    var progressPercentage: Double {
        guard let currentSeason = current_season,
              let currentEpisode = current_episode,
              let totalSeasons = total_seasons,
              let totalEpisodes = total_episodes,
              totalEpisodes > 0 else {
            return 0.0
        }
        
        // Calculate approximate progress based on seasons and episodes
        let seasonProgress = Double(currentSeason - 1) / Double(totalSeasons)
        let episodeProgress = Double(currentEpisode) / Double(totalEpisodes / totalSeasons)
        
        return min((seasonProgress + (episodeProgress / Double(totalSeasons))) * 100, 100.0)
    }
    
    var isCompleted: Bool {
        return status == "completed"
    }
    
    var isCurrentlyWatching: Bool {
        return status == "watching"
    }
    
    var isFavorited: Bool {
        return favorited == true
    }
}

// MARK: - Watching Status Enum
enum WatchingStatus: String, CaseIterable {
    case watching = "watching"
    case completed = "completed"
    case dropped = "dropped"
    case planToWatch = "plan_to_watch"
    
    var displayName: String {
        switch self {
        case .watching:
            return "Watching"
        case .completed:
            return "Completed"
        case .dropped:
            return "Dropped"
        case .planToWatch:
            return "Plan to Watch"
        }
    }
    
    var color: String {
        switch self {
        case .watching:
            return "green"
        case .completed:
            return "blue"
        case .dropped:
            return "red"
        case .planToWatch:
            return "orange"
        }
    }
}
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

// MARK: - TMDB Images Response
struct TMDBImagesResponse: Codable {
    let id: Int
    let posters: [TMDBImage]?
    let backdrops: [TMDBImage]?
}

struct TMDBImage: Codable, Identifiable {
    let aspectRatio: Double
    let height: Int
    let width: Int
    let filePath: String
    let voteAverage: Double
    let voteCount: Int
    
    enum CodingKeys: String, CodingKey {
        case height, width
        case aspectRatio = "aspect_ratio"
        case filePath = "file_path"
        case voteAverage = "vote_average"
        case voteCount = "vote_count"
    }
    
    var id: String {
        return filePath
    }
    
    var fullURL: String {
        return "https://image.tmdb.org/t/p/w500\(filePath)"
    }
    
    var fullImageURL: URL? {
        return URL(string: fullURL)
    }
    
    var fullBackdropURL: String {
        return "https://image.tmdb.org/t/p/w1280\(filePath)"
    }
    
    var fullBackdropImageURL: URL? {
        return URL(string: fullBackdropURL)
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

// MARK: - TV Models

// MARK: - TMDB TV Search Response
struct TMDBTVSearchResponse: Codable {
    let page: Int
    let results: [TMDBTVShow]
    let totalPages: Int
    let totalResults: Int
    
    enum CodingKeys: String, CodingKey {
        case page, results
        case totalPages = "total_pages"
        case totalResults = "total_results"
    }
}

// MARK: - TMDB TV Show
struct TMDBTVShow: Codable, Identifiable {
    let id: Int
    let name: String
    let originalName: String?
    let overview: String?
    let firstAirDate: String?
    let lastAirDate: String?
    let posterPath: String?
    let backdropPath: String?
    let voteAverage: Double?
    let voteCount: Int?
    let popularity: Double?
    let originalLanguage: String?
    let genreIds: [Int]?
    let adult: Bool?
    let originCountry: [String]?
    
    enum CodingKeys: String, CodingKey {
        case id, name, overview, popularity, adult
        case originalName = "original_name"
        case firstAirDate = "first_air_date"
        case lastAirDate = "last_air_date"
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case voteAverage = "vote_average"
        case voteCount = "vote_count"
        case originalLanguage = "original_language"
        case genreIds = "genre_ids"
        case originCountry = "origin_country"
    }
}

// MARK: - TMDB TV Series Details
struct TMDBTVSeriesDetails: Codable {
    let id: Int
    let name: String
    let originalName: String?
    let overview: String?
    let firstAirDate: String?
    let lastAirDate: String?
    let posterPath: String?
    let backdropPath: String?
    let voteAverage: Double?
    let voteCount: Int?
    let popularity: Double?
    let originalLanguage: String?
    let adult: Bool?
    let genres: [TMDBGenre]?
    let homepage: String?
    let inProduction: Bool?
    let languages: [String]?
    let numberOfEpisodes: Int?
    let numberOfSeasons: Int?
    let originCountry: [String]?
    let status: String?
    let tagline: String?
    let type: String?
    let seasons: [TMDBSeason]?
    let networks: [TMDBNetwork]?
    let productionCompanies: [TMDBProductionCompany]?
    let createdBy: [TMDBCreatedBy]?
    let episodeRunTime: [Int]?
    
    enum CodingKeys: String, CodingKey {
        case id, name, overview, popularity, adult, genres, homepage, languages, status, tagline, type, seasons, networks
        case originalName = "original_name"
        case firstAirDate = "first_air_date"
        case lastAirDate = "last_air_date"
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case voteAverage = "vote_average"
        case voteCount = "vote_count"
        case originalLanguage = "original_language"
        case inProduction = "in_production"
        case numberOfEpisodes = "number_of_episodes"
        case numberOfSeasons = "number_of_seasons"
        case originCountry = "origin_country"
        case productionCompanies = "production_companies"
        case createdBy = "created_by"
        case episodeRunTime = "episode_run_time"
    }
}

// MARK: - TMDB Season
struct TMDBSeason: Codable, Identifiable {
    let id: Int
    let name: String
    let overview: String?
    let posterPath: String?
    let seasonNumber: Int
    let episodeCount: Int
    let airDate: String?
    let voteAverage: Double?
    
    enum CodingKeys: String, CodingKey {
        case id, name, overview
        case posterPath = "poster_path"
        case seasonNumber = "season_number"
        case episodeCount = "episode_count"
        case airDate = "air_date"
        case voteAverage = "vote_average"
    }
}

// MARK: - TMDB Season Details
struct TMDBTVSeasonDetails: Codable {
    let id: Int
    let name: String
    let overview: String?
    let posterPath: String?
    let seasonNumber: Int
    let airDate: String?
    let episodes: [TMDBEpisode]?
    let voteAverage: Double?
    
    enum CodingKeys: String, CodingKey {
        case id, name, overview, episodes
        case posterPath = "poster_path"
        case seasonNumber = "season_number"
        case airDate = "air_date"
        case voteAverage = "vote_average"
    }
}

// MARK: - TMDB Episode
struct TMDBEpisode: Codable, Identifiable {
    let id: Int
    let name: String
    let overview: String?
    let airDate: String?
    let episodeNumber: Int
    let seasonNumber: Int
    let stillPath: String?
    let voteAverage: Double?
    let voteCount: Int?
    let runtime: Int?
    
    enum CodingKeys: String, CodingKey {
        case id, name, overview, runtime
        case airDate = "air_date"
        case episodeNumber = "episode_number"
        case seasonNumber = "season_number"
        case stillPath = "still_path"
        case voteAverage = "vote_average"
        case voteCount = "vote_count"
    }
}

// MARK: - TMDB Episode Details
struct TMDBTVEpisodeDetails: Codable {
    let id: Int
    let name: String
    let overview: String?
    let airDate: String?
    let episodeNumber: Int
    let seasonNumber: Int
    let stillPath: String?
    let voteAverage: Double?
    let voteCount: Int?
    let runtime: Int?
    let crew: [TMDBCrewMember]?
    let guestStars: [TMDBCastMember]?
    let productionCode: String?
    
    enum CodingKeys: String, CodingKey {
        case id, name, overview, runtime, crew
        case airDate = "air_date"
        case episodeNumber = "episode_number"
        case seasonNumber = "season_number"
        case stillPath = "still_path"
        case voteAverage = "vote_average"
        case voteCount = "vote_count"
        case guestStars = "guest_stars"
        case productionCode = "production_code"
    }
}

// MARK: - Supporting TV Models
struct TMDBNetwork: Codable, Identifiable {
    let id: Int
    let name: String
    let logoPath: String?
    let originCountry: String?
    
    enum CodingKeys: String, CodingKey {
        case id, name
        case logoPath = "logo_path"
        case originCountry = "origin_country"
    }
}

struct TMDBProductionCompany: Codable, Identifiable {
    let id: Int
    let name: String
    let logoPath: String?
    let originCountry: String?
    
    enum CodingKeys: String, CodingKey {
        case id, name
        case logoPath = "logo_path"
        case originCountry = "origin_country"
    }
}

struct TMDBCreatedBy: Codable, Identifiable {
    let id: Int
    let name: String
    let profilePath: String?
    let gender: Int?
    let creditId: String?
    
    enum CodingKeys: String, CodingKey {
        case id, name, gender
        case profilePath = "profile_path"
        case creditId = "credit_id"
    }
}

// MARK: - TV Extensions
extension TMDBTVShow {
    var posterURL: URL? {
        guard let posterPath = posterPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w500\(posterPath)")
    }
    
    var backdropURL: URL? {
        guard let backdropPath = backdropPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w1280\(backdropPath)")
    }
    
    var firstAirYear: Int? {
        guard let dateString = firstAirDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dateString)?.year
    }
}

extension TMDBTVSeriesDetails {
    var posterURL: URL? {
        guard let posterPath = posterPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w500\(posterPath)")
    }
    
    var backdropURL: URL? {
        guard let backdropPath = backdropPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w1280\(backdropPath)")
    }
    
    var firstAirYear: Int? {
        guard let dateString = firstAirDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dateString)?.year
    }
    
    var genreNames: [String] {
        return genres?.map { $0.name } ?? []
    }
}

extension TMDBSeason {
    var posterURL: URL? {
        guard let posterPath = posterPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w500\(posterPath)")
    }
    
    var airYear: Int? {
        guard let dateString = airDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dateString)?.year
    }
}

extension TMDBEpisode {
    var stillURL: URL? {
        guard let stillPath = stillPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w500\(stillPath)")
    }
    
    var airYear: Int? {
        guard let dateString = airDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dateString)?.year
    }
}

extension TMDBTVEpisodeDetails {
    var stillURL: URL? {
        guard let stillPath = stillPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w500\(stillPath)")
    }
    
    var airYear: Int? {
        guard let dateString = airDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dateString)?.year
    }
}

// MARK: - Movie to TMDBMovie Conversion
extension TMDBMovie {
    /// Create a TMDBMovie from a Movie diary entry for "Log Again" functionality
    init(from movie: Movie) {
        self.id = movie.tmdb_id ?? 0
        self.title = movie.title
        self.originalTitle = movie.original_title
        self.overview = movie.overview
        self.releaseDate = movie.release_date
        self.posterPath = movie.poster_url
        self.backdropPath = movie.backdrop_path
        self.voteAverage = movie.vote_average
        self.voteCount = movie.vote_count
        self.popularity = movie.popularity
        self.originalLanguage = movie.original_language
        self.genreIds = nil // Not stored in Movie model
        self.adult = nil // Not stored in Movie model
        self.video = nil // Not stored in Movie model
    }
}
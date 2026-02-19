//
//  TheaterVisit.swift
//  reelay2
//
//  Theater visit planning model
//

import Foundation

struct TheaterVisit: Codable, Identifiable {
    let id: Int
    let user_id: String?
    let tmdb_id: Int?
    let title: String
    let poster_url: String?
    let release_year: Int?
    let visit_date: String       // "yyyy-MM-dd"
    let showtime: String?        // "HH:mm:ss" from Supabase TIME column
    let location_name: String?
    let location_latitude: Double?
    let location_longitude: Double?
    let notes: String?
    let is_completed: Bool?
    let created_at: String?
    let updated_at: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case user_id
        case tmdb_id
        case title
        case poster_url
        case release_year
        case visit_date
        case showtime
        case location_name
        case location_latitude
        case location_longitude
        case notes
        case is_completed
        case created_at
        case updated_at
    }
}

// MARK: - Computed Properties
extension TheaterVisit {
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
    
    var visitDate: Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.date(from: visit_date)
    }
    
    var showtimeDate: Date? {
        guard let showtime = showtime else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        // Try HH:mm:ss first (Supabase TIME format)
        formatter.dateFormat = "HH:mm:ss"
        if let date = formatter.date(from: showtime) { return date }
        // Fallback to HH:mm
        formatter.dateFormat = "HH:mm"
        return formatter.date(from: showtime)
    }
    
    var formattedShowtime: String? {
        guard let date = showtimeDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
    
    var formattedVisitDate: String {
        guard let date = visitDate else { return visit_date }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: date)
    }
    
    var formattedReleaseYear: String {
        guard let year = release_year else { return "" }
        return String(year)
    }
    
    var completed: Bool {
        is_completed ?? false
    }
    
    var hasLocation: Bool {
        location_latitude != nil && location_longitude != nil && location_name != nil
    }
    
    /// Convert to a TMDBMovie for pre-populating AddMoviesView (e.g., "Complete & Log Film")
    func toTMDBMovie() -> TMDBMovie? {
        guard let tmdbId = tmdb_id else { return nil }
        // Build a release date string from release_year if available
        let releaseDateString: String? = release_year != nil ? "\(release_year!)-01-01" : nil
        return TMDBMovie(
            id: tmdbId,
            title: title,
            originalTitle: nil,
            overview: nil,
            releaseDate: releaseDateString,
            posterPath: poster_url,
            backdropPath: nil,
            voteAverage: nil,
            voteCount: nil,
            popularity: nil,
            originalLanguage: nil,
            genreIds: nil,
            adult: nil,
            video: nil
        )
    }
}

// MARK: - Insert/Update Request Models

struct AddTheaterVisitRequest: Codable {
    let tmdb_id: Int?
    let title: String
    let poster_url: String?
    let release_year: Int?
    let visit_date: String
    let showtime: String?
    let location_name: String?
    let location_latitude: Double?
    let location_longitude: Double?
    let notes: String?
    let is_completed: Bool?
}

struct UpdateTheaterVisitRequest: Codable {
    let tmdb_id: Int?
    let title: String?
    let poster_url: String?
    let release_year: Int?
    let visit_date: String?
    let showtime: String?
    let location_name: String?
    let location_latitude: Double?
    let location_longitude: Double?
    let notes: String?
    let is_completed: Bool?
    
    // Custom encoding to only include non-nil fields
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if let v = tmdb_id { try container.encode(v, forKey: .tmdb_id) }
        if let v = title { try container.encode(v, forKey: .title) }
        if let v = poster_url { try container.encode(v, forKey: .poster_url) }
        if let v = release_year { try container.encode(v, forKey: .release_year) }
        if let v = visit_date { try container.encode(v, forKey: .visit_date) }
        if let v = showtime { try container.encode(v, forKey: .showtime) }
        if let v = location_name { try container.encode(v, forKey: .location_name) }
        if let v = location_latitude { try container.encode(v, forKey: .location_latitude) }
        if let v = location_longitude { try container.encode(v, forKey: .location_longitude) }
        if let v = notes { try container.encode(v, forKey: .notes) }
        if let v = is_completed { try container.encode(v, forKey: .is_completed) }
    }
}

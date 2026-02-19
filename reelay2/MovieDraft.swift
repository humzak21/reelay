//
//  MovieDraft.swift
//  reelay2
//
//  Created for the Drafts feature
//

import Foundation
import SwiftData

/// SwiftData model for storing movie draft entries.
/// Allows users to resume partially filled movie entries.
@Model
class MovieDraft {
    /// TMDB ID of the movie - used as unique identifier (one draft per movie)
    @Attribute(.unique) var tmdbId: Int
    
    /// Movie metadata
    var title: String
    var releaseYear: Int?
    var posterUrl: String?
    
    /// User input fields
    var starRating: Double?
    var detailedRating: String?
    var review: String?
    var tags: String?
    var watchDate: Date
    var isRewatch: Bool
    var isFavorited: Bool
    var isShortFilm: Bool
    
    /// Timestamps
    var createdAt: Date
    var updatedAt: Date
    
    init(
        tmdbId: Int,
        title: String,
        releaseYear: Int? = nil,
        posterUrl: String? = nil,
        starRating: Double? = nil,
        detailedRating: String? = nil,
        review: String? = nil,
        tags: String? = nil,
        watchDate: Date = Date(),
        isRewatch: Bool = false,
        isFavorited: Bool = false,
        isShortFilm: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.tmdbId = tmdbId
        self.title = title
        self.releaseYear = releaseYear
        self.posterUrl = posterUrl
        self.starRating = starRating
        self.detailedRating = detailedRating
        self.review = review
        self.tags = tags
        self.watchDate = watchDate
        self.isRewatch = isRewatch
        self.isFavorited = isFavorited
        self.isShortFilm = isShortFilm
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    /// Computed property returning a human-readable "edited X ago" string
    var editedAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: updatedAt, relativeTo: Date())
    }
    
    /// Check if this draft has any meaningful data to save
    var hasData: Bool {
        return (starRating ?? 0) > 0 ||
               !(detailedRating ?? "").isEmpty ||
               !(review ?? "").isEmpty ||
               !(tags ?? "").isEmpty ||
               isRewatch ||
               isFavorited ||
               isShortFilm
    }
    
    /// Update this draft from user input values
    func update(
        starRating: Double?,
        detailedRating: String?,
        review: String?,
        tags: String?,
        watchDate: Date,
        isRewatch: Bool,
        isFavorited: Bool,
        isShortFilm: Bool
    ) {
        self.starRating = starRating
        self.detailedRating = detailedRating
        self.review = review
        self.tags = tags
        self.watchDate = watchDate
        self.isRewatch = isRewatch
        self.isFavorited = isFavorited
        self.isShortFilm = isShortFilm
        self.updatedAt = Date()
    }
}

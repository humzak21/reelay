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
    var selectedLocationId: Int?
    var selectedLocationName: String?
    var selectedLocationAddress: String?
    var selectedLocationLatitude: Double?
    var selectedLocationLongitude: Double?
    var selectedLocationNormalizedKey: String?
    var selectedLocationGroupId: Int?
    var selectedLocationGroupName: String?
    var isCreatingNewLocationGroup: Bool
    var newLocationGroupName: String?
    
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
        selectedLocationId: Int? = nil,
        selectedLocationName: String? = nil,
        selectedLocationAddress: String? = nil,
        selectedLocationLatitude: Double? = nil,
        selectedLocationLongitude: Double? = nil,
        selectedLocationNormalizedKey: String? = nil,
        selectedLocationGroupId: Int? = nil,
        selectedLocationGroupName: String? = nil,
        isCreatingNewLocationGroup: Bool = false,
        newLocationGroupName: String? = nil,
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
        self.selectedLocationId = selectedLocationId
        self.selectedLocationName = selectedLocationName
        self.selectedLocationAddress = selectedLocationAddress
        self.selectedLocationLatitude = selectedLocationLatitude
        self.selectedLocationLongitude = selectedLocationLongitude
        self.selectedLocationNormalizedKey = selectedLocationNormalizedKey
        self.selectedLocationGroupId = selectedLocationGroupId
        self.selectedLocationGroupName = selectedLocationGroupName
        self.isCreatingNewLocationGroup = isCreatingNewLocationGroup
        self.newLocationGroupName = newLocationGroupName
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
               isShortFilm ||
               selectedLocationId != nil ||
               !(selectedLocationName ?? "").isEmpty ||
               !(newLocationGroupName ?? "").isEmpty
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
        isShortFilm: Bool,
        selectedLocationId: Int?,
        selectedLocationName: String?,
        selectedLocationAddress: String?,
        selectedLocationLatitude: Double?,
        selectedLocationLongitude: Double?,
        selectedLocationNormalizedKey: String?,
        selectedLocationGroupId: Int?,
        selectedLocationGroupName: String?,
        isCreatingNewLocationGroup: Bool,
        newLocationGroupName: String?
    ) {
        self.starRating = starRating
        self.detailedRating = detailedRating
        self.review = review
        self.tags = tags
        self.watchDate = watchDate
        self.isRewatch = isRewatch
        self.isFavorited = isFavorited
        self.isShortFilm = isShortFilm
        self.selectedLocationId = selectedLocationId
        self.selectedLocationName = selectedLocationName
        self.selectedLocationAddress = selectedLocationAddress
        self.selectedLocationLatitude = selectedLocationLatitude
        self.selectedLocationLongitude = selectedLocationLongitude
        self.selectedLocationNormalizedKey = selectedLocationNormalizedKey
        self.selectedLocationGroupId = selectedLocationGroupId
        self.selectedLocationGroupName = selectedLocationGroupName
        self.isCreatingNewLocationGroup = isCreatingNewLocationGroup
        self.newLocationGroupName = newLocationGroupName
        self.updatedAt = Date()
    }
}

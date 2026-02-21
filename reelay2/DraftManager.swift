//
//  DraftManager.swift
//  reelay2
//
//  Created for the Drafts feature
//

import Foundation
import SwiftData

/// Singleton manager for movie draft operations.
/// Provides a clean API for saving, loading, and deleting drafts.
@MainActor
class DraftManager {
    static let shared = DraftManager()
    
    private var modelContext: ModelContext {
        ModelContainerManager.shared.modelContainer.mainContext
    }
    
    private init() {}
    
    // MARK: - Query Operations
    
    /// Get a draft by TMDB ID
    func getDraftByTmdbId(_ tmdbId: Int) -> MovieDraft? {
        let descriptor = FetchDescriptor<MovieDraft>(
            predicate: #Predicate { $0.tmdbId == tmdbId }
        )
        
        do {
            let results = try modelContext.fetch(descriptor)
            return results.first
        } catch {
            print("❌ Error fetching draft by tmdbId: \(error)")
            return nil
        }
    }
    
    /// Get all drafts, sorted by most recently updated
    func getAllDrafts() -> [MovieDraft] {
        let descriptor = FetchDescriptor<MovieDraft>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            print("❌ Error fetching all drafts: \(error)")
            return []
        }
    }
    
    /// Get the count of saved drafts
    func getDraftCount() -> Int {
        let descriptor = FetchDescriptor<MovieDraft>()
        
        do {
            return try modelContext.fetchCount(descriptor)
        } catch {
            print("❌ Error counting drafts: \(error)")
            return 0
        }
    }
    
    // MARK: - Save Operations
    
    /// Save or update a draft (upsert by tmdbId)
    func saveDraft(
        tmdbId: Int,
        title: String,
        releaseYear: Int?,
        posterUrl: String?,
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
        // Check if draft already exists
        if let existingDraft = getDraftByTmdbId(tmdbId) {
            // Update existing draft
            existingDraft.update(
                starRating: starRating,
                detailedRating: detailedRating,
                review: review,
                tags: tags,
                watchDate: watchDate,
                isRewatch: isRewatch,
                isFavorited: isFavorited,
                isShortFilm: isShortFilm,
                selectedLocationId: selectedLocationId,
                selectedLocationName: selectedLocationName,
                selectedLocationAddress: selectedLocationAddress,
                selectedLocationLatitude: selectedLocationLatitude,
                selectedLocationLongitude: selectedLocationLongitude,
                selectedLocationNormalizedKey: selectedLocationNormalizedKey,
                selectedLocationGroupId: selectedLocationGroupId,
                selectedLocationGroupName: selectedLocationGroupName,
                isCreatingNewLocationGroup: isCreatingNewLocationGroup,
                newLocationGroupName: newLocationGroupName
            )
        } else {
            // Create new draft
            let newDraft = MovieDraft(
                tmdbId: tmdbId,
                title: title,
                releaseYear: releaseYear,
                posterUrl: posterUrl,
                starRating: starRating,
                detailedRating: detailedRating,
                review: review,
                tags: tags,
                watchDate: watchDate,
                isRewatch: isRewatch,
                isFavorited: isFavorited,
                isShortFilm: isShortFilm,
                selectedLocationId: selectedLocationId,
                selectedLocationName: selectedLocationName,
                selectedLocationAddress: selectedLocationAddress,
                selectedLocationLatitude: selectedLocationLatitude,
                selectedLocationLongitude: selectedLocationLongitude,
                selectedLocationNormalizedKey: selectedLocationNormalizedKey,
                selectedLocationGroupId: selectedLocationGroupId,
                selectedLocationGroupName: selectedLocationGroupName,
                isCreatingNewLocationGroup: isCreatingNewLocationGroup,
                newLocationGroupName: newLocationGroupName
            )
            modelContext.insert(newDraft)
        }
        
        // Save changes
        do {
            try modelContext.save()
        } catch {
            print("❌ Error saving draft: \(error)")
        }
    }
    
    // MARK: - Delete Operations
    
    /// Delete a draft by TMDB ID
    func deleteDraftByTmdbId(_ tmdbId: Int) {
        if let draft = getDraftByTmdbId(tmdbId) {
            modelContext.delete(draft)
            
            do {
                try modelContext.save()
            } catch {
                print("❌ Error deleting draft: \(error)")
            }
        }
    }
    
    /// Delete a specific draft
    func deleteDraft(_ draft: MovieDraft) {
        modelContext.delete(draft)
        
        do {
            try modelContext.save()
        } catch {
            print("❌ Error deleting draft: \(error)")
        }
    }
}

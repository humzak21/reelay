import Foundation

struct AppliedMovieFilters: Equatable, Sendable {
    var selectedTags: Set<String> = []
    var minStarRating: Double? = nil
    var maxStarRating: Double? = nil
    var minDetailedRating: Double? = nil
    var maxDetailedRating: Double? = nil
    var selectedGenres: Set<String> = []
    var startDate: Date? = nil
    var endDate: Date? = nil
    var showRewatchesOnly: Bool = false
    var hideRewatches: Bool = false
    var minRuntime: Int? = nil
    var maxRuntime: Int? = nil
    var selectedDecades: Set<String> = []
    var hasReview: Bool? = nil
    var showFavoritesOnly: Bool = false

    var hasActiveFilters: Bool {
        !selectedTags.isEmpty
            || minStarRating != nil
            || maxStarRating != nil
            || minDetailedRating != nil
            || maxDetailedRating != nil
            || !selectedGenres.isEmpty
            || startDate != nil
            || endDate != nil
            || showRewatchesOnly
            || hideRewatches
            || minRuntime != nil
            || maxRuntime != nil
            || !selectedDecades.isEmpty
            || hasReview != nil
            || showFavoritesOnly
    }

    var activeFilterCount: Int {
        var count = 0
        if !selectedTags.isEmpty { count += 1 }
        if minStarRating != nil || maxStarRating != nil { count += 1 }
        if minDetailedRating != nil || maxDetailedRating != nil { count += 1 }
        if !selectedGenres.isEmpty { count += 1 }
        if startDate != nil || endDate != nil { count += 1 }
        if showRewatchesOnly || hideRewatches { count += 1 }
        if minRuntime != nil || maxRuntime != nil { count += 1 }
        if !selectedDecades.isEmpty { count += 1 }
        if hasReview != nil { count += 1 }
        if showFavoritesOnly { count += 1 }
        return count
    }

    func asFilterSet(dateFormatter: DateFormatter = DateFormatter.movieDateFormatter) -> MovieFilterSet {
        let start = startDate.map { dateFormatter.string(from: $0) }
        let end = endDate.map { dateFormatter.string(from: $0) }

        return MovieFilterSet(
            tags: Array(selectedTags).sorted(),
            genres: Array(selectedGenres).sorted(),
            decades: Array(selectedDecades).sorted(),
            startWatchDate: start,
            endWatchDate: end,
            showRewatchesOnly: showRewatchesOnly,
            hideRewatches: hideRewatches,
            minRating: minStarRating,
            maxRating: maxStarRating,
            minDetailedRating: minDetailedRating,
            maxDetailedRating: maxDetailedRating,
            minRuntime: minRuntime,
            maxRuntime: maxRuntime,
            hasReview: hasReview,
            favoritesOnly: showFavoritesOnly
        )
    }
}

struct FilterDraftState: Equatable {
    var selectedTags: Set<String>
    var minStarRating: Double?
    var maxStarRating: Double?
    var minDetailedRating: Double?
    var maxDetailedRating: Double?
    var selectedGenres: Set<String>
    var startDate: Date?
    var endDate: Date?
    var showRewatchesOnly: Bool
    var hideRewatches: Bool
    var minRuntime: Int?
    var maxRuntime: Int?
    var selectedDecades: Set<String>
    var hasReview: Bool?
    var showFavoritesOnly: Bool

    init(from filters: AppliedMovieFilters) {
        selectedTags = filters.selectedTags
        minStarRating = filters.minStarRating
        maxStarRating = filters.maxStarRating
        minDetailedRating = filters.minDetailedRating
        maxDetailedRating = filters.maxDetailedRating
        selectedGenres = filters.selectedGenres
        startDate = filters.startDate
        endDate = filters.endDate
        showRewatchesOnly = filters.showRewatchesOnly
        hideRewatches = filters.hideRewatches
        minRuntime = filters.minRuntime
        maxRuntime = filters.maxRuntime
        selectedDecades = filters.selectedDecades
        hasReview = filters.hasReview
        showFavoritesOnly = filters.showFavoritesOnly
    }

    init() {
        self.init(from: AppliedMovieFilters())
    }

    func toAppliedFilters() -> AppliedMovieFilters {
        AppliedMovieFilters(
            selectedTags: selectedTags,
            minStarRating: minStarRating,
            maxStarRating: maxStarRating,
            minDetailedRating: minDetailedRating,
            maxDetailedRating: maxDetailedRating,
            selectedGenres: selectedGenres,
            startDate: startDate,
            endDate: endDate,
            showRewatchesOnly: showRewatchesOnly,
            hideRewatches: hideRewatches,
            minRuntime: minRuntime,
            maxRuntime: maxRuntime,
            selectedDecades: selectedDecades,
            hasReview: hasReview,
            showFavoritesOnly: showFavoritesOnly
        )
    }

    mutating func clearAll() {
        self = FilterDraftState()
    }
}

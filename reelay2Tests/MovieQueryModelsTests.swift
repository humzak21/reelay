import Foundation
import Testing
@testable import reelay2

struct MovieQueryModelsTests {

    @Test
    func movieFilterSetEmptyState() {
        var filters = MovieFilterSet()
        #expect(filters.isEmpty)

        filters.tags = ["Sci-Fi"]
        #expect(!filters.isEmpty)

        filters.tags = []
        filters.favoritesOnly = true
        #expect(!filters.isEmpty)
    }

    @Test
    func appliedFiltersCountAndSerialization() {
        let calendar = Calendar(identifier: .gregorian)
        let start = calendar.date(from: DateComponents(year: 2024, month: 4, day: 12))!

        let applied = AppliedMovieFilters(
            selectedTags: ["Favorite", "Must Watch"],
            minStarRating: 4.0,
            maxStarRating: nil,
            minDetailedRating: nil,
            maxDetailedRating: nil,
            selectedGenres: ["Drama"],
            startDate: start,
            endDate: nil,
            showRewatchesOnly: false,
            hideRewatches: false,
            minRuntime: nil,
            maxRuntime: nil,
            selectedDecades: ["1990s"],
            hasReview: true,
            showFavoritesOnly: true
        )

        #expect(applied.hasActiveFilters)
        #expect(applied.activeFilterCount == 7)

        let serialized = applied.asFilterSet()
        #expect(serialized.tags == ["Favorite", "Must Watch"])
        #expect(serialized.genres == ["Drama"])
        #expect(serialized.decades == ["1990s"])
        #expect(serialized.minRating == 4.0)
        #expect(serialized.hasReview == true)
        #expect(serialized.favoritesOnly == true)
        #expect(serialized.startWatchDate == "2024-04-12")
    }

    @Test
    func filterDraftRoundTripsAndClears() {
        let calendar = Calendar(identifier: .gregorian)
        let end = calendar.date(from: DateComponents(year: 2025, month: 1, day: 4))!

        let applied = AppliedMovieFilters(
            selectedTags: ["TagA"],
            minStarRating: nil,
            maxStarRating: 5.0,
            minDetailedRating: 80,
            maxDetailedRating: 95,
            selectedGenres: ["Action", "Comedy"],
            startDate: nil,
            endDate: end,
            showRewatchesOnly: true,
            hideRewatches: false,
            minRuntime: 90,
            maxRuntime: 180,
            selectedDecades: [],
            hasReview: false,
            showFavoritesOnly: false
        )

        var draft = FilterDraftState(from: applied)
        #expect(draft.toAppliedFilters() == applied)

        draft.clearAll()
        #expect(draft == FilterDraftState())
        #expect(!draft.toAppliedFilters().hasActiveFilters)
    }

    @Test
    func movieQueryHashAndEquality() {
        let filters = MovieFilterSet(
            tags: ["a"],
            genres: ["b"],
            releaseYears: [1999],
            decades: ["1990s"],
            startWatchDate: "2024-01-01",
            endWatchDate: "2024-12-31",
            showRewatchesOnly: false,
            hideRewatches: false,
            minRating: 3.5,
            maxRating: 5.0,
            minDetailedRating: 70,
            maxDetailedRating: 100,
            minRuntime: 90,
            maxRuntime: 200,
            hasReview: true,
            favoritesOnly: true
        )

        let q1 = MovieBrowseQuery(sortBy: .watchDate, ascending: false, filters: filters, page: 2, pageSize: 50)
        let q2 = MovieBrowseQuery(sortBy: .watchDate, ascending: false, filters: filters, page: 2, pageSize: 50)
        let q3 = MovieBrowseQuery(sortBy: .watchDate, ascending: false, filters: filters, page: 3, pageSize: 50)

        #expect(q1 == q2)
        #expect(q1.hashValue == q2.hashValue)
        #expect(q1 != q3)

        var cache: [MovieBrowseQuery: String] = [:]
        cache[q1] = "page2"
        #expect(cache[q2] == "page2")
    }

    @Test
    func movieListItemDecodeAndProjection() throws {
        let json = """
        {
          "id": 42,
          "title": "Arrival",
          "release_year": 2016,
          "release_date": "2016-11-11",
          "rating": 4.5,
          "ratings100": 91,
          "tags": "Sci-Fi,Rewatch",
          "watched_date": "2025-02-14",
          "rewatch": "yes",
          "tmdb_id": 329865,
          "poster_url": "/x2FJsf1ElAgr63Y3PNPtJrcmpoe.jpg",
          "backdrop_path": "/5B0kNLiQfQFQri3khH0M2A8z4fA.jpg",
          "director": "Denis Villeneuve",
          "runtime": 116,
          "overview": "A linguist works with the military.",
          "genres": ["Science Fiction", "Drama"],
          "created_at": "2025-02-14T12:00:00Z",
          "updated_at": "2025-02-14T13:00:00Z",
          "favorited": true,
          "location_id": 7
        }
        """

        let data = Data(json.utf8)
        let decoded = try JSONDecoder().decode(MovieListItem.self, from: data)

        #expect(decoded.id == 42)
        #expect(decoded.detailed_rating == 91)
        #expect(decoded.watch_date == "2025-02-14")
        #expect(decoded.is_rewatch == true)
        #expect(decoded.isRewatchMovie)
        #expect(decoded.isFavorited)
        #expect(decoded.posterURL?.absoluteString == "https://image.tmdb.org/t/p/w500/x2FJsf1ElAgr63Y3PNPtJrcmpoe.jpg")

        let projected = decoded.toMovie()
        #expect(projected.id == decoded.id)
        #expect(projected.title == decoded.title)
        #expect(projected.watch_date == decoded.watch_date)
        #expect(projected.is_rewatch == decoded.is_rewatch)
        #expect(projected.favorited == decoded.favorited)
    }
}

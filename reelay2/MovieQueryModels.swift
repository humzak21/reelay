import Foundation

struct MovieFilterSet: Codable, Equatable, Sendable, Hashable {
    var tags: [String]
    var genres: [String]
    var releaseYears: [Int]
    var decades: [String]
    var startWatchDate: String?
    var endWatchDate: String?
    var showRewatchesOnly: Bool
    var hideRewatches: Bool
    var minRating: Double?
    var maxRating: Double?
    var minDetailedRating: Double?
    var maxDetailedRating: Double?
    var minRuntime: Int?
    var maxRuntime: Int?
    var hasReview: Bool?
    var favoritesOnly: Bool

    init(
        tags: [String] = [],
        genres: [String] = [],
        releaseYears: [Int] = [],
        decades: [String] = [],
        startWatchDate: String? = nil,
        endWatchDate: String? = nil,
        showRewatchesOnly: Bool = false,
        hideRewatches: Bool = false,
        minRating: Double? = nil,
        maxRating: Double? = nil,
        minDetailedRating: Double? = nil,
        maxDetailedRating: Double? = nil,
        minRuntime: Int? = nil,
        maxRuntime: Int? = nil,
        hasReview: Bool? = nil,
        favoritesOnly: Bool = false
    ) {
        self.tags = tags
        self.genres = genres
        self.releaseYears = releaseYears
        self.decades = decades
        self.startWatchDate = startWatchDate
        self.endWatchDate = endWatchDate
        self.showRewatchesOnly = showRewatchesOnly
        self.hideRewatches = hideRewatches
        self.minRating = minRating
        self.maxRating = maxRating
        self.minDetailedRating = minDetailedRating
        self.maxDetailedRating = maxDetailedRating
        self.minRuntime = minRuntime
        self.maxRuntime = maxRuntime
        self.hasReview = hasReview
        self.favoritesOnly = favoritesOnly
    }

    var isEmpty: Bool {
        tags.isEmpty
            && genres.isEmpty
            && releaseYears.isEmpty
            && decades.isEmpty
            && startWatchDate == nil
            && endWatchDate == nil
            && !showRewatchesOnly
            && !hideRewatches
            && minRating == nil
            && maxRating == nil
            && minDetailedRating == nil
            && maxDetailedRating == nil
            && minRuntime == nil
            && maxRuntime == nil
            && hasReview == nil
            && !favoritesOnly
    }
}

struct MovieBrowseQuery: Codable, Equatable, Sendable, Hashable {
    var sortBy: MovieSortField
    var ascending: Bool
    var filters: MovieFilterSet
    var page: Int
    var pageSize: Int

    init(
        sortBy: MovieSortField = .watchDate,
        ascending: Bool = false,
        filters: MovieFilterSet = .init(),
        page: Int = 1,
        pageSize: Int = 100
    ) {
        self.sortBy = sortBy
        self.ascending = ascending
        self.filters = filters
        self.page = max(1, page)
        self.pageSize = max(1, pageSize)
    }
}

struct MovieSearchPageQuery: Codable, Equatable, Sendable, Hashable {
    var searchText: String
    var sortBy: MovieSortField
    var ascending: Bool
    var filters: MovieFilterSet
    var page: Int
    var pageSize: Int

    init(
        searchText: String,
        sortBy: MovieSortField = .watchDate,
        ascending: Bool = false,
        filters: MovieFilterSet = .init(),
        page: Int = 1,
        pageSize: Int = 100
    ) {
        self.searchText = searchText
        self.sortBy = sortBy
        self.ascending = ascending
        self.filters = filters
        self.page = max(1, page)
        self.pageSize = max(1, pageSize)
    }
}

struct MoviePage<T: Codable & Sendable>: Codable, Sendable {
    let items: [T]
    let totalCount: Int
    let page: Int
    let pageSize: Int
    let hasNextPage: Bool
}

struct MovieFilterFacets: Codable, Equatable, Sendable {
    let availableTags: [String]
    let availableGenres: [String]
    let availableDecades: [String]
    let ratingMin: Double
    let ratingMax: Double
    let detailedRatingMin: Double
    let detailedRatingMax: Double
    let runtimeMin: Int
    let runtimeMax: Int
    let earliestWatchDate: String?
    let latestWatchDate: String?

    static let empty = MovieFilterFacets(
        availableTags: [],
        availableGenres: [],
        availableDecades: [],
        ratingMin: 0,
        ratingMax: 5,
        detailedRatingMin: 0,
        detailedRatingMax: 100,
        runtimeMin: 0,
        runtimeMax: 300,
        earliestWatchDate: nil,
        latestWatchDate: nil
    )
}

struct MovieListItem: Codable, Identifiable, Sendable, Hashable {
    let id: Int
    let user_id: String?
    let title: String
    let release_year: Int?
    let release_date: String?
    let rating: Double?
    let detailed_rating: Double?
    let tags: String?
    let watch_date: String?
    let is_rewatch: Bool?
    let tmdb_id: Int?
    let poster_url: String?
    let backdrop_path: String?
    let director: String?
    let runtime: Int?
    let overview: String?
    let genres: [String]?
    let created_at: String?
    let updated_at: String?
    let favorited: Bool?
    let location_id: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case user_id
        case title
        case release_year
        case release_date
        case rating
        case detailed_rating = "ratings100"
        case tags
        case watch_date = "watched_date"
        case is_rewatch = "rewatch"
        case tmdb_id
        case poster_url
        case backdrop_path
        case director
        case runtime
        case overview
        case genres
        case created_at
        case updated_at
        case favorited
        case location_id
    }

    init(
        id: Int,
        user_id: String? = nil,
        title: String,
        release_year: Int?,
        release_date: String?,
        rating: Double?,
        detailed_rating: Double?,
        tags: String?,
        watch_date: String?,
        is_rewatch: Bool?,
        tmdb_id: Int?,
        poster_url: String?,
        backdrop_path: String?,
        director: String?,
        runtime: Int?,
        overview: String?,
        genres: [String]?,
        created_at: String?,
        updated_at: String?,
        favorited: Bool?,
        location_id: Int?
    ) {
        self.id = id
        self.user_id = user_id
        self.title = title
        self.release_year = release_year
        self.release_date = release_date
        self.rating = rating
        self.detailed_rating = detailed_rating
        self.tags = tags
        self.watch_date = watch_date
        self.is_rewatch = is_rewatch
        self.tmdb_id = tmdb_id
        self.poster_url = poster_url
        self.backdrop_path = backdrop_path
        self.director = director
        self.runtime = runtime
        self.overview = overview
        self.genres = genres
        self.created_at = created_at
        self.updated_at = updated_at
        self.favorited = favorited
        self.location_id = location_id
    }

    init(from movie: Movie) {
        self.id = movie.id
        self.user_id = movie.user_id
        self.title = movie.title
        self.release_year = movie.release_year
        self.release_date = movie.release_date
        self.rating = movie.rating
        self.detailed_rating = movie.detailed_rating
        self.tags = movie.tags
        self.watch_date = movie.watch_date
        self.is_rewatch = movie.is_rewatch
        self.tmdb_id = movie.tmdb_id
        self.poster_url = movie.poster_url
        self.backdrop_path = movie.backdrop_path
        self.director = movie.director
        self.runtime = movie.runtime
        self.overview = movie.overview
        self.genres = movie.genres
        self.created_at = movie.created_at
        self.updated_at = movie.updated_at
        self.favorited = movie.favorited
        self.location_id = movie.location_id
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
        tags = try container.decodeIfPresent(String.self, forKey: .tags)
        watch_date = try container.decodeIfPresent(String.self, forKey: .watch_date)
        tmdb_id = try container.decodeIfPresent(Int.self, forKey: .tmdb_id)
        poster_url = try container.decodeIfPresent(String.self, forKey: .poster_url)
        backdrop_path = try container.decodeIfPresent(String.self, forKey: .backdrop_path)
        director = try container.decodeIfPresent(String.self, forKey: .director)
        runtime = try container.decodeIfPresent(Int.self, forKey: .runtime)
        overview = try container.decodeIfPresent(String.self, forKey: .overview)
        genres = try container.decodeIfPresent([String].self, forKey: .genres)
        created_at = try container.decodeIfPresent(String.self, forKey: .created_at)
        updated_at = try container.decodeIfPresent(String.self, forKey: .updated_at)
        favorited = try container.decodeIfPresent(Bool.self, forKey: .favorited)
        location_id = try container.decodeIfPresent(Int.self, forKey: .location_id)

        if let rewatchString = try? container.decodeIfPresent(String.self, forKey: .is_rewatch) {
            is_rewatch = rewatchString.lowercased() == "yes"
        } else if let rewatchBool = try? container.decodeIfPresent(Bool.self, forKey: .is_rewatch) {
            is_rewatch = rewatchBool
        } else {
            is_rewatch = nil
        }
    }

    func toMovie() -> Movie {
        Movie(
            id: id,
            title: title,
            release_year: release_year,
            release_date: release_date,
            rating: rating,
            detailed_rating: detailed_rating,
            review: nil,
            tags: tags,
            watch_date: watch_date,
            is_rewatch: is_rewatch,
            tmdb_id: tmdb_id,
            overview: overview,
            poster_url: poster_url,
            backdrop_path: backdrop_path,
            director: director,
            runtime: runtime,
            vote_average: nil,
            vote_count: nil,
            popularity: nil,
            original_language: nil,
            original_title: nil,
            tagline: nil,
            status: nil,
            budget: nil,
            revenue: nil,
            imdb_id: nil,
            homepage: nil,
            genres: genres,
            created_at: created_at,
            updated_at: updated_at,
            favorited: favorited,
            location_id: location_id,
            user_id: user_id
        )
    }
}

extension MovieListItem {
    var isRewatchMovie: Bool {
        is_rewatch == true
    }

    var isFavorited: Bool {
        favorited ?? false
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
}

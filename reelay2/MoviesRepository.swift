import Foundation

actor MoviesRepository {
    private let movieService: SupabaseMovieService

    private var browseCache: [MovieBrowseQuery: MoviePage<MovieListItem>] = [:]
    private var searchCache: [MovieSearchPageQuery: MoviePage<MovieListItem>] = [:]
    private var detailsCache: [Int: Movie] = [:]
    private var facetsCache: MovieFilterFacets?

    init(movieService: SupabaseMovieService = .shared) {
        self.movieService = movieService
    }

    func moviesPage(query: MovieBrowseQuery, forceRefresh: Bool = false) async throws -> MoviePage<MovieListItem> {
        if !forceRefresh, let cached = browseCache[query] {
            return cached
        }

        let page = try await movieService.getMoviesPage(query: query)
        browseCache[query] = page
        return page
    }

    func searchPage(query: MovieSearchPageQuery, forceRefresh: Bool = false) async throws -> MoviePage<MovieListItem> {
        if !forceRefresh, let cached = searchCache[query] {
            return cached
        }

        let page = try await movieService.searchMoviesPage(query: query)
        searchCache[query] = page
        return page
    }

    func filterFacets(forceRefresh: Bool = false) async throws -> MovieFilterFacets {
        if !forceRefresh, let cached = facetsCache {
            return cached
        }

        let facets = try await movieService.getMovieFilterFacets()
        facetsCache = facets
        return facets
    }

    func movieDetails(id: Int, forceRefresh: Bool = false) async throws -> Movie {
        if !forceRefresh, let cached = detailsCache[id] {
            return cached
        }

        let details = try await movieService.getMovieDetails(id: id)
        detailsCache[id] = details
        return details
    }

    func invalidateCaches() {
        browseCache.removeAll()
        searchCache.removeAll()
        detailsCache.removeAll()
        facetsCache = nil
    }

    func invalidateMovie(_ id: Int) {
        detailsCache.removeValue(forKey: id)
    }
}

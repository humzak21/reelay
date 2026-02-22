import Foundation
import SwiftUI
import Combine
import os

struct MovieSectionSnapshot: Identifiable {
    let monthYearKey: String
    let displayTitle: String
    let movies: [Movie]

    var id: String { monthYearKey }
}

enum MovieColorToken: String {
    case gray
    case yellow
    case orange
    case purple
    case cyan
    case red
    case pink
    case green
    case blue
    case mint
    case white

    var color: Color {
        switch self {
        case .gray: return .gray
        case .yellow: return .yellow
        case .orange: return .orange
        case .purple: return .purple
        case .cyan: return .cyan
        case .red: return .red
        case .pink: return .pink
        case .green: return .green
        case .blue: return .blue
        case .mint: return .mint
        case .white: return .white
        }
    }
}

struct MovieTagIconSnapshot {
    let icon: String
    let colorToken: MovieColorToken
}

struct MovieRowMetadata {
    let rewatchColorToken: MovieColorToken
    let shouldHighlightMustWatchTitle: Bool
    let shouldHighlightReleaseYearTitle: Bool
    let shouldHighlightReleaseYearOnYear: Bool
    let isCentennialUniqueFilm: Bool
    let isCentennialTotalLog: Bool
    let watchDay: String
    let watchDayOfWeek: String
    let tagIcons: [MovieTagIconSnapshot]
    let accessibilityLabel: String
    let accessibilityValue: String
}

@MainActor
final class MoviesViewModel: ObservableObject {
    @Published private(set) var allMovies: [Movie] = []
    @Published private(set) var filteredMovies: [Movie] = []
    @Published private(set) var visibleSections: [MovieSectionSnapshot] = []
    @Published private(set) var calendarDayCounts: [String: Int] = [:]
    @Published private(set) var selectedDateMovies: [Movie] = []
    @Published private(set) var rowMetadataByMovieID: [Int: MovieRowMetadata] = [:]
    @Published private(set) var monthFilteredCounts: [String: Int] = [:]
    @Published private(set) var monthTotalCounts: [String: Int] = [:]

    @Published private(set) var isLoading = false
    @Published private(set) var isRefreshing = false
    @Published private(set) var isInitialLoad = true
    @Published private(set) var hasLoadedInitially = false
    @Published private(set) var errorMessage: String?

    private let repository: MoviesRepository
    private let listService = SupabaseListService.shared
    private let monthDescriptorService = MonthDescriptorService.shared
    private let signposter = OSSignposter(subsystem: "reelay2", category: "MoviesViewModel")

    private var sortBy: MovieSortField = .watchDate
    private var sortAscending = false
    private var appliedFilters = AppliedMovieFilters()
    private var selectedDate = Date()
    private var currentCalendarMonth = Date()

    private var lastRefreshTime: Date = .distantPast
    private let refreshInterval: TimeInterval = 300

    init(repository: MoviesRepository = MoviesRepository()) {
        self.repository = repository
    }

    func configure(
        sortBy: MovieSortField,
        sortAscending: Bool,
        filters: AppliedMovieFilters,
        selectedDate: Date,
        currentCalendarMonth: Date
    ) {
        let shouldRebuild = self.sortBy != sortBy
            || self.sortAscending != sortAscending
            || self.appliedFilters != filters
            || !Calendar.current.isDate(self.selectedDate, inSameDayAs: selectedDate)
            || !Calendar.current.isDate(self.currentCalendarMonth, equalTo: currentCalendarMonth, toGranularity: .month)

        self.sortBy = sortBy
        self.sortAscending = sortAscending
        self.appliedFilters = filters
        self.selectedDate = selectedDate
        self.currentCalendarMonth = currentCalendarMonth

        guard shouldRebuild else { return }
        rebuildVisibleSnapshots()
    }

    func shouldRefreshData() -> Bool {
        Date().timeIntervalSince(lastRefreshTime) > refreshInterval || !hasLoadedInitially
    }

    func loadMoviesIfNeeded(force: Bool) async {
        if !force && !shouldRefreshData() && !allMovies.isEmpty {
            return
        }
        if isLoading { return }

        if !isInitialLoad {
            isLoading = true
        }
        errorMessage = nil

        let signpostState = signposter.beginInterval("load_movies")
        defer {
            signposter.endInterval("load_movies", signpostState)
        }

        do {
            if force {
                await repository.invalidateCaches()
            }

            let movies = try await loadAllMovies(forceRefresh: force)
            self.allMovies = movies
            self.lastRefreshTime = Date()

            await loadOptimizedCaches(for: movies)
            try? await monthDescriptorService.loadMonthDescriptors()

            rebuildAllSnapshots()
        } catch {
            errorMessage = error.localizedDescription
        }

        isInitialLoad = false
        hasLoadedInitially = true
        isLoading = false
    }

    func refreshMovies() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        errorMessage = nil

        do {
            await repository.invalidateCaches()
            allMovies = try await loadAllMovies(forceRefresh: true)
            lastRefreshTime = Date()
            await loadOptimizedCaches(for: allMovies)
            try? await monthDescriptorService.loadMonthDescriptors()
            rebuildAllSnapshots()
        } catch {
            errorMessage = error.localizedDescription
        }

        isRefreshing = false
    }

    func markDataStale() {
        lastRefreshTime = .distantPast
    }

    func clearForLogout() {
        allMovies = []
        filteredMovies = []
        visibleSections = []
        calendarDayCounts = [:]
        selectedDateMovies = []
        rowMetadataByMovieID = [:]
        monthFilteredCounts = [:]
        monthTotalCounts = [:]
        errorMessage = nil
        isLoading = false
        isRefreshing = false
        isInitialLoad = true
        hasLoadedInitially = false
        lastRefreshTime = .distantPast
        Task {
            await repository.invalidateCaches()
        }
    }

    func reloadMonthDescriptors() async {
        try? await monthDescriptorService.loadMonthDescriptors()
        rebuildVisibleSnapshots()
    }

    func updateMovieInPlace(_ updated: Movie) {
        if let index = allMovies.firstIndex(where: { $0.id == updated.id }) {
            allMovies[index] = updated
            rebuildAllSnapshots()
        }
    }

    func removeMovie(id: Int) {
        allMovies.removeAll { $0.id == id }
        rebuildAllSnapshots()
    }

    func replaceMovie(_ updated: Movie) {
        if let index = allMovies.firstIndex(where: { $0.id == updated.id }) {
            allMovies[index] = updated
        } else {
            allMovies.insert(updated, at: 0)
        }
        rebuildAllSnapshots()
    }

    func metadata(for movie: Movie) -> MovieRowMetadata {
        rowMetadataByMovieID[movie.id] ?? MovieRowMetadata(
            rewatchColorToken: .orange,
            shouldHighlightMustWatchTitle: false,
            shouldHighlightReleaseYearTitle: false,
            shouldHighlightReleaseYearOnYear: false,
            isCentennialUniqueFilm: false,
            isCentennialTotalLog: false,
            watchDay: "?",
            watchDayOfWeek: "?",
            tagIcons: [],
            accessibilityLabel: movie.title,
            accessibilityValue: ""
        )
    }

    func setErrorMessage(_ message: String?) {
        errorMessage = message
    }

    func moviesCountInMonth(for monthDate: Date, filtered: Bool) -> Int {
        let key = Self.monthKeyFormatter.string(from: monthDate)
        if filtered {
            return monthFilteredCounts[key] ?? 0
        }
        return monthTotalCounts[key] ?? 0
    }

    func moviesForDate(_ date: Date) -> [Movie] {
        let key = Self.dayKeyFormatter.string(from: date)
        return filteredMovies.filter { $0.watch_date == key }
    }

    func movieCountForDate(_ date: Date) -> Int {
        calendarDayCounts[Self.dayKeyFormatter.string(from: date)] ?? 0
    }

    // MARK: - Private

    private func loadAllMovies(forceRefresh: Bool) async throws -> [Movie] {
        let signpostState = signposter.beginInterval("fetch_all_pages")
        defer {
            signposter.endInterval("fetch_all_pages", signpostState)
        }

        var page = 1
        var output: [Movie] = []

        while true {
            let query = MovieBrowseQuery(
                sortBy: .watchDate,
                ascending: false,
                filters: .init(),
                page: page,
                pageSize: 500
            )

            let response = try await repository.moviesPage(query: query, forceRefresh: forceRefresh)
            output.append(contentsOf: response.items.map { $0.toMovie() })

            if !response.hasNextPage {
                break
            }
            page += 1
        }

        return output
    }

    private func loadOptimizedCaches(for movies: [Movie]) async {
        let rewatchTmdbIds = movies
            .filter { $0.isRewatchMovie }
            .compactMap { $0.tmdb_id }
        let uniqueRewatchIds = Array(Set(rewatchTmdbIds))

        async let firstWatchTask: Void = DataManager.shared.loadFirstWatchDates(for: uniqueRewatchIds)
        async let mustWatchesTask: Void = DataManager.shared.loadMustWatchesMapping()

        _ = await (firstWatchTask, mustWatchesTask)
    }

    private func rebuildAllSnapshots() {
        let signpostState = signposter.beginInterval("rebuild_snapshots")
        defer {
            signposter.endInterval("rebuild_snapshots", signpostState)
        }

        rebuildRowMetadata()
        rebuildVisibleSnapshots()
    }

    private func rebuildVisibleSnapshots() {
        let filtered = applyFilters(to: allMovies, using: appliedFilters)
        let sorted = sortMovies(filtered)

        filteredMovies = sorted
        selectedDateMovies = moviesForSelectedDate(from: sorted)
        calendarDayCounts = buildCalendarCounts(from: sorted)
        visibleSections = buildSections(from: sorted)
        monthTotalCounts = buildMonthCounts(from: allMovies)
        monthFilteredCounts = buildMonthCounts(from: sorted)
    }

    private func buildSections(from movies: [Movie]) -> [MovieSectionSnapshot] {
        let grouped = Dictionary(grouping: movies) { movie in
            monthKey(from: movie.watch_date)
        }

        let sortedKeys = grouped.keys.sorted { lhs, rhs in
            if lhs == Self.unknownMonthKey { return false }
            if rhs == Self.unknownMonthKey { return true }
            return lhs > rhs
        }

        return sortedKeys.map { key in
            let sectionMovies = grouped[key] ?? []
            return MovieSectionSnapshot(
                monthYearKey: key,
                displayTitle: displayTitle(forMonthKey: key),
                movies: sectionMovies
            )
        }
    }

    private func buildCalendarCounts(from movies: [Movie]) -> [String: Int] {
        var counts: [String: Int] = [:]
        for movie in movies {
            guard let key = movie.watch_date else { continue }
            counts[key, default: 0] += 1
        }
        return counts
    }

    private func moviesForSelectedDate(from movies: [Movie]) -> [Movie] {
        let key = Self.dayKeyFormatter.string(from: selectedDate)
        return movies
            .filter { $0.watch_date == key }
            .sorted { ($0.detailed_rating ?? 0) > ($1.detailed_rating ?? 0) }
    }

    private func buildMonthCounts(from movies: [Movie]) -> [String: Int] {
        var counts: [String: Int] = [:]
        for movie in movies {
            let key = monthKey(from: movie.watch_date)
            if key == Self.unknownMonthKey { continue }
            counts[key, default: 0] += 1
        }
        return counts
    }

    private func monthKey(from watchDate: String?) -> String {
        guard let watchDate, watchDate.count >= 7 else { return Self.unknownMonthKey }
        return String(watchDate.prefix(7))
    }

    private func displayTitle(forMonthKey monthKey: String) -> String {
        guard monthKey != Self.unknownMonthKey else { return "Unknown Date" }

        let descriptor = monthDescriptorService.getDescriptor(for: monthKey)
        return monthDescriptorService.formatMonthYearForDisplay(monthKey, with: descriptor)
    }

    private func applyFilters(to movies: [Movie], using filters: AppliedMovieFilters) -> [Movie] {
        guard filters.hasActiveFilters else { return movies }

        return movies.filter { movie in
            if !filters.selectedTags.isEmpty {
                guard let movieTags = movie.tags else { return false }
                let movieTagsArray = movieTags.components(separatedBy: CharacterSet(charactersIn: ", "))
                    .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
                let hasSelectedTag = filters.selectedTags.contains { selectedTag in
                    movieTagsArray.contains(selectedTag.lowercased())
                }
                if !hasSelectedTag { return false }
            }

            if let minRating = filters.minStarRating {
                guard let movieRating = movie.rating, movieRating >= minRating else { return false }
            }
            if let maxRating = filters.maxStarRating {
                guard let movieRating = movie.rating, movieRating <= maxRating else { return false }
            }

            if let minDetailed = filters.minDetailedRating {
                guard let movieDetailed = movie.detailed_rating, movieDetailed >= minDetailed else { return false }
            }
            if let maxDetailed = filters.maxDetailedRating {
                guard let movieDetailed = movie.detailed_rating, movieDetailed <= maxDetailed else { return false }
            }

            if !filters.selectedGenres.isEmpty {
                guard let movieGenres = movie.genres else { return false }
                let hasSelectedGenre = filters.selectedGenres.contains { selectedGenre in
                    movieGenres.contains(selectedGenre)
                }
                if !hasSelectedGenre { return false }
            }

            if let start = filters.startDate {
                guard let watchDateString = movie.watch_date,
                      let watchDate = DateFormatter.movieDateFormatter.date(from: watchDateString),
                      watchDate >= start else { return false }
            }
            if let end = filters.endDate {
                guard let watchDateString = movie.watch_date,
                      let watchDate = DateFormatter.movieDateFormatter.date(from: watchDateString),
                      watchDate <= end else { return false }
            }

            if filters.showRewatchesOnly && !movie.isRewatchMovie { return false }
            if filters.hideRewatches && movie.isRewatchMovie { return false }

            if let minTime = filters.minRuntime {
                guard let movieRuntime = movie.runtime, movieRuntime >= minTime else { return false }
            }
            if let maxTime = filters.maxRuntime {
                guard let movieRuntime = movie.runtime, movieRuntime <= maxTime else { return false }
            }

            if !filters.selectedDecades.isEmpty {
                guard let releaseYear = movie.release_year else { return false }
                let decade = "\(releaseYear / 10 * 10)s"
                if !filters.selectedDecades.contains(decade) { return false }
            }

            if let reviewFilter = filters.hasReview {
                let movieHasReview = movie.review != nil && !movie.review!.trimmingCharacters(in: .whitespaces).isEmpty
                if reviewFilter != movieHasReview { return false }
            }

            if filters.showFavoritesOnly && !movie.isFavorited { return false }

            return true
        }
    }

    private func sortMovies(_ movies: [Movie]) -> [Movie] {
        movies.sorted { movie1, movie2 in
            switch sortBy {
            case .title:
                let title1 = movie1.title.lowercased()
                let title2 = movie2.title.lowercased()
                if title1 == title2 {
                    return tieBreak(movie1, movie2)
                }
                return sortAscending ? title1 < title2 : title1 > title2

            case .watchDate:
                let date1 = movie1.watch_date ?? ""
                let date2 = movie2.watch_date ?? ""
                if date1 == date2 {
                    return tieBreak(movie1, movie2)
                }
                return sortAscending ? date1 < date2 : date1 > date2

            case .releaseDate:
                let year1 = movie1.release_year ?? 0
                let year2 = movie2.release_year ?? 0
                if year1 == year2 {
                    return tieBreak(movie1, movie2)
                }
                return sortAscending ? year1 < year2 : year1 > year2

            case .rating:
                let rating1 = movie1.rating ?? 0
                let rating2 = movie2.rating ?? 0
                if rating1 == rating2 {
                    return tieBreak(movie1, movie2)
                }
                return sortAscending ? rating1 < rating2 : rating1 > rating2

            case .detailedRating:
                let detailed1 = movie1.detailed_rating ?? 0
                let detailed2 = movie2.detailed_rating ?? 0
                if detailed1 == detailed2 {
                    return tieBreak(movie1, movie2)
                }
                return sortAscending ? detailed1 < detailed2 : detailed1 > detailed2

            case .dateAdded:
                let created1 = movie1.created_at ?? ""
                let created2 = movie2.created_at ?? ""
                if created1 == created2 {
                    return sortAscending ? movie1.id < movie2.id : movie1.id > movie2.id
                }
                return sortAscending ? created1 < created2 : created1 > created2
            }
        }
    }

    private func tieBreak(_ lhs: Movie, _ rhs: Movie) -> Bool {
        let created1 = lhs.created_at ?? ""
        let created2 = rhs.created_at ?? ""

        if created1 == created2 {
            return sortAscending ? lhs.id < rhs.id : lhs.id > rhs.id
        }
        return sortAscending ? created1 < created2 : created1 > created2
    }

    private func rebuildRowMetadata() {
        var metadataMap: [Int: MovieRowMetadata] = [:]

        let chronologicalMovies = allMovies.sorted { lhs, rhs in
            let lhsDate = lhs.watch_date ?? ""
            let rhsDate = rhs.watch_date ?? ""
            if lhsDate == rhsDate {
                let lhsCreated = lhs.created_at ?? ""
                let rhsCreated = rhs.created_at ?? ""
                if lhsCreated == rhsCreated {
                    return lhs.id < rhs.id
                }
                return lhsCreated < rhsCreated
            }
            return lhsDate < rhsDate
        }

        var centennialUniqueIDs: Set<Int> = []
        var centennialTotalIDs: Set<Int> = []
        var uniqueTitles: Set<String> = []

        for (index, movie) in chronologicalMovies.enumerated() {
            let totalPosition = index + 1
            if totalPosition % 100 == 0 {
                centennialTotalIDs.insert(movie.id)
            }

            let normalizedTitle = movie.title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            if !uniqueTitles.contains(normalizedTitle) {
                uniqueTitles.insert(normalizedTitle)
                if uniqueTitles.count % 100 == 0 {
                    centennialUniqueIDs.insert(movie.id)
                }
            }
        }

        let moviesByTmdbId = Dictionary(grouping: allMovies.compactMap { movie -> (Int, Movie)? in
            guard let tmdbId = movie.tmdb_id else { return nil }
            return (tmdbId, movie)
        }, by: { $0.0 }).mapValues { pairs in
            pairs.map { $0.1 }
                .sorted { lhs, rhs in
                    let lhsDate = lhs.watch_date ?? ""
                    let rhsDate = rhs.watch_date ?? ""
                    if lhsDate == rhsDate {
                        return (lhs.created_at ?? "") < (rhs.created_at ?? "")
                    }
                    return lhsDate < rhsDate
                }
        }

        for movie in allMovies {
            let watchDate = movie.watch_date.flatMap { DateFormatter.movieDateFormatter.date(from: $0) }
            let watchYear = watchDate.map { Calendar.current.component(.year, from: $0) }
            let isOnMustWatches = (watchYear != nil) ? isOnMustWatchesList(movie, for: watchYear!) : false
            let isWatchedInReleaseYear = (watchYear != nil && movie.release_year != nil) ? watchYear == movie.release_year : false

            let day = watchDate.map { Self.dayNumberFormatter.string(from: $0) } ?? "?"
            let dayOfWeek = watchDate.map { Self.dayOfWeekFormatter.string(from: $0) } ?? "?"

            let tagIcons = tagIconSnapshots(for: movie)
            let rewatchColor = rewatchColorToken(for: movie, moviesByTmdbId: moviesByTmdbId)

            let accessibilityValue = [
                movie.watch_date.map { "Watched \($0)" },
                movie.rating.map { "Star rating \(String(format: "%.1f", $0))" },
                movie.detailed_rating.map { "Detailed rating \(Int($0))" },
                movie.isRewatchMovie ? "Rewatch" : nil,
                movie.isFavorited ? "Favorite" : nil
            ]
            .compactMap { $0 }
            .joined(separator: ", ")

            metadataMap[movie.id] = MovieRowMetadata(
                rewatchColorToken: rewatchColor,
                shouldHighlightMustWatchTitle: isOnMustWatches,
                shouldHighlightReleaseYearTitle: isWatchedInReleaseYear && !isOnMustWatches,
                shouldHighlightReleaseYearOnYear: isWatchedInReleaseYear && isOnMustWatches,
                isCentennialUniqueFilm: centennialUniqueIDs.contains(movie.id),
                isCentennialTotalLog: centennialTotalIDs.contains(movie.id),
                watchDay: day,
                watchDayOfWeek: dayOfWeek,
                tagIcons: tagIcons,
                accessibilityLabel: movie.title,
                accessibilityValue: accessibilityValue
            )
        }

        rowMetadataByMovieID = metadataMap
    }

    private func rewatchColorToken(for movie: Movie, moviesByTmdbId: [Int: [Movie]]) -> MovieColorToken {
        guard movie.isRewatchMovie else { return .orange }

        if let tmdbId = movie.tmdb_id,
           let cached = FirstWatchDateCache.shared.getFirstWatch(for: tmdbId),
           let watchDateString = movie.watch_date,
           let movieWatchDate = DateFormatter.movieDateFormatter.date(from: watchDateString) {
            let movieYear = Calendar.current.component(.year, from: movieWatchDate)
            guard let firstWatchYear = cached.year else {
                return .gray
            }
            return movieYear == firstWatchYear ? .yellow : .orange
        }

        guard let tmdbId = movie.tmdb_id,
              let entries = moviesByTmdbId[tmdbId],
              let watchDateString = movie.watch_date,
              let movieWatchDate = DateFormatter.movieDateFormatter.date(from: watchDateString) else {
            return .orange
        }

        if entries.count == 1 {
            return .gray
        }

        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: movieWatchDate)
        let entriesInSameYear = entries.filter { entry in
            guard let watchDate = entry.watch_date,
                  let date = DateFormatter.movieDateFormatter.date(from: watchDate) else {
                return false
            }
            return calendar.component(.year, from: date) == currentYear
        }

        if entriesInSameYear.count >= 2,
           let first = entriesInSameYear.first,
           first.id != movie.id,
           !first.isRewatchMovie,
           movie.isRewatchMovie {
            return .yellow
        }

        let hasPreviousYearEntry = entries.contains { entry in
            guard let watchDate = entry.watch_date,
                  let date = DateFormatter.movieDateFormatter.date(from: watchDate) else {
                return false
            }
            return calendar.component(.year, from: date) < currentYear
        }

        return hasPreviousYearEntry ? .orange : .orange
    }

    private func isOnMustWatchesList(_ movie: Movie, for year: Int) -> Bool {
        guard let tmdbId = movie.tmdb_id else { return false }

        if !MustWatchesCache.shared.needsRefresh {
            return MustWatchesCache.shared.isOnMustWatches(tmdbId: tmdbId, year: year)
        }

        let listName = "Must Watches for \(year)"
        guard let mustWatchesList = listService.movieLists.first(where: { $0.name == listName }) else {
            return false
        }

        return listService.getListItems(mustWatchesList).contains(where: { $0.tmdbId == tmdbId })
    }

    private func tagIconSnapshots(for movie: Movie) -> [MovieTagIconSnapshot] {
        let iconData = TagConfiguration.getTagIconsWithColors(
            for: movie.tags,
            hasLocation: movie.location_id != nil
        )

        return iconData.map { data in
            MovieTagIconSnapshot(icon: data.icon, colorToken: colorToken(forTagIcon: data.icon))
        }
    }

    private func colorToken(forTagIcon icon: String) -> MovieColorToken {
        switch icon {
        case "film": return .red
        case "popcorn.fill": return .purple
        case "figure.2.and.child.holdinghands": return .yellow
        case "person.3.fill": return .green
        case "airplane": return .orange
        case "train.side.front.car": return .cyan
        case "movieclapper.fill": return .mint
        case "book.fill": return .pink
        case "magnifyingglass": return .white
        case "location.fill": return .blue
        default: return .blue
        }
    }

    private static let unknownMonthKey = "unknown"

    private static let monthKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    private static let dayKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    private static let dayNumberFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    private static let dayOfWeekFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
}

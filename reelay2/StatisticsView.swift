//
//  StatisticsView.swift
//  reelay2
//
//  Created by Humza Khalil on 7/21/25.
//

import SwiftUI
import Charts
import Auth
import MapKit
import Supabase
import PostgREST

private enum LocationCountMode: String, CaseIterable {
    case specific
    case grouped

    var title: String {
        switch self {
        case .specific: return "Specific Locations"
        case .grouped: return "Location Groups"
        }
    }
}

private enum FilmTypeMode: String, CaseIterable, Identifiable {
    case all
    case feature
    case short

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return "All"
        case .feature:
            return "Feature Films"
        case .short:
            return "Short Films"
        }
    }

    var iconName: String {
        switch self {
        case .all:
            return "square.stack.3d.up"
        case .feature:
            return "film"
        case .short:
            return "film.stack"
        }
    }

    var nextMode: FilmTypeMode {
        switch self {
        case .all:
            return .feature
        case .feature:
            return .short
        case .short:
            return .all
        }
    }
}

private struct YearMonthKey: Hashable {
    let year: Int
    let month: Int
}

// MARK: - Selection Info Row
private struct SelectionInfoRow: View {
    let text: String
    let color: Color
    
    var body: some View {
        HStack {
            Spacer()
            Text(text)
                .font(.caption)
                .foregroundColor(color)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(color.opacity(0.1))
                .cornerRadius(8)
            Spacer()
        }
        .padding(.horizontal, 12)
    }
}

struct StatisticsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var statisticsService = SupabaseStatisticsService.shared
    @ObservedObject private var movieService = SupabaseMovieService.shared
    
    @State private var dashboardStats: DashboardStats?
    @State private var ratingDistribution: [RatingDistribution] = []
    @State private var detailedRatingDistribution: [DetailedRatingDistribution] = []
    @State private var filmsByDecade: [FilmsByDecade] = []
    @State private var filmsByReleaseYear: [FilmsByReleaseYear] = []
    @State private var filmsPerYear: [FilmsPerYear] = []
    @State private var filmsPerMonth: [FilmsPerMonth] = []
    @State private var weeklyFilmsData: [WeeklyFilmsData] = []
    @State private var dayOfWeekPatterns: [DayOfWeekPattern] = []
    @State private var runtimeStats: RuntimeStats?
    @State private var uniqueFilmsCount: Int = 0
    @State private var watchSpan: WatchSpan?
    @State private var resolvedAverageRating: Double?
    @State private var rewatchStats: RewatchStats?
    @State private var streakStats: StreakStats?
    @State private var weeklyStreakStats: WeeklyStreakStats?
    @State private var yearReleaseStats: YearReleaseStats?
    @State private var topWatchedFilms: [TopWatchedFilm] = []
    @State private var advancedJourneyStats: AdvancedFilmJourneyStats?
    @State private var yearFilteredAdvancedStats: YearFilteredAdvancedJourneyStats?
    @State private var averageStarRatingsPerYear: [AverageStarRatingPerYear] = []
    @State private var averageDetailedRatingsPerYear: [AverageDetailedRatingPerYear] = []
    @State private var yearlyPaceStats: YearlyPaceStats?
    @State private var allFilmsPerMonth: [FilmsPerMonth] = []
    @State private var locationMapPoints: [LocationMapPoint] = []
    @State private var specificLocationCounts: [LocationCountRow] = []
    @State private var groupLocationCounts: [LocationCountRow] = []
    @State private var locationCountMode: LocationCountMode = .specific
    
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    // Year selection states
    @State private var availableYears: [Int] = []
    @State private var selectedYear: Int? = nil
    @State private var showingYearPicker = false
    @State private var selectedFilmTypeMode: FilmTypeMode = .all
    @State private var cachedMoviesByFilmType: [FilmTypeMode: [Movie]] = [:]
    
    // MARK: - Efficient Loading States
    @State private var hasLoadedInitially = false
    @State private var lastRefreshTime: Date = Date.distantPast
    @State private var isRefreshing = false
    @State private var cachedDataByYear: [String: CachedStatisticsData] = [:]
    
    private let refreshInterval: TimeInterval = 600 // 10 minutes for statistics
    private let maxCacheSize = 5 // Limit cache to 5 different year selections
    
    private struct CachedStatisticsData {
        let dashboardStats: DashboardStats?
        let ratingDistribution: [RatingDistribution]
        let detailedRatingDistribution: [DetailedRatingDistribution]
        let filmsByDecade: [FilmsByDecade]
        let filmsByReleaseYear: [FilmsByReleaseYear]
        let filmsPerYear: [FilmsPerYear]
        let filmsPerMonth: [FilmsPerMonth]
        let weeklyFilmsData: [WeeklyFilmsData]
        let dayOfWeekPatterns: [DayOfWeekPattern]
        let runtimeStats: RuntimeStats?
        let uniqueFilmsCount: Int
        let watchSpan: WatchSpan?
        let rewatchStats: RewatchStats?
        let streakStats: StreakStats?
        let yearReleaseStats: YearReleaseStats?
        let topWatchedFilms: [TopWatchedFilm]
        let advancedJourneyStats: AdvancedFilmJourneyStats?
        let yearFilteredAdvancedStats: YearFilteredAdvancedJourneyStats?
        let averageStarRatingsPerYear: [AverageStarRatingPerYear]
        let averageDetailedRatingsPerYear: [AverageDetailedRatingPerYear]
        let resolvedAverageRating: Double?
        let yearlyPaceStats: YearlyPaceStats?
        let allFilmsPerMonth: [FilmsPerMonth]
        let locationMapPoints: [LocationMapPoint]
        let specificLocationCounts: [LocationCountRow]
        let groupLocationCounts: [LocationCountRow]
        let cachedAt: Date
    }
    
    private var navigationTitle: String {
        if let year = selectedYear {
            return "\(year) Statistics"
        } else {
            return "Statistics"
        }
    }
    
    private var yearSelectionLabel: String {
        if let year = selectedYear {
            return String(year)
        } else {
            return "All Time"
        }
    }

    private struct DatedMovieEntry {
        let movie: Movie
        let date: Date
        let watchYear: Int
        let month: Int
        let weekday: Int
        let weekOfYear: Int
        let dateString: String
    }

    private struct StreakWindow {
        let start: Date
        let end: Date
        let length: Int
    }

    private static let watchDateParser: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let shortMonthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        return formatter
    }()
    
    var body: some View {
        #if os(iOS)
        NavigationStack {
            statisticsContent
        }
        .task {
            if !hasLoadedInitially {
                await loadAvailableYears()
                await loadStatisticsIfNeeded(force: true)
                hasLoadedInitially = true
            }
        }
        .onAppear {
            // Only load if we haven't loaded initially or data is stale
            if shouldRefreshData() {
                Task {
                    await loadStatisticsIfNeeded(force: false)
                }
            }
        }
        .onChange(of: selectedYear) {
            Task {
                await loadStatisticsIfNeeded(force: false)
            }
        }
        .onChange(of: selectedFilmTypeMode) {
            Task {
                await loadAvailableYears()
                if let currentYear = selectedYear, !availableYears.contains(currentYear) {
                    selectedYear = nil
                }
                await loadStatisticsIfNeeded(force: true)
            }
        }
        #else
        statisticsContent
        .task {
            if !hasLoadedInitially {
                await loadAvailableYears()
                await loadStatisticsIfNeeded(force: true)
                hasLoadedInitially = true
            }
        }
        .onAppear {
            // Only load if we haven't loaded initially or data is stale
            if shouldRefreshData() {
                Task {
                    await loadStatisticsIfNeeded(force: false)
                }
            }
        }
        .onChange(of: selectedYear) {
            Task {
                await loadStatisticsIfNeeded(force: false)
            }
        }
        .onChange(of: selectedFilmTypeMode) {
            Task {
                await loadAvailableYears()
                if let currentYear = selectedYear, !availableYears.contains(currentYear) {
                    selectedYear = nil
                }
                await loadStatisticsIfNeeded(force: true)
            }
        }
        #endif
    }
    
    // MARK: - Statistics Content (extracted for platform-specific wrapping)
    private var statisticsContent: some View {
        TabView(selection: Binding(
            get: { selectedYear ?? 9999 },
            set: { newValue in
                let newYear = newValue == 9999 ? nil : newValue
                if newYear != selectedYear {
                    #if canImport(UIKit)
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    #endif
                    selectedYear = newYear
                    Task {
                        await loadStatistics()
                    }
                }
            }
        )) {
            ScrollView {
                statisticsScrollContent
            }
            .tag(9999)
            
            ForEach(availableYears, id: \.self) { year in
                ScrollView {
                    statisticsScrollContent
                }
                .tag(year)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup {
                filmTypeFilterButton
            }

            ToolbarSpacer(.fixed)

            ToolbarItem(placement: .confirmationAction) {
                yearPickerButton
            }
        }
        .refreshable {
            await refreshStatistics()
        }
        .sheet(isPresented: $showingYearPicker) {
            yearPickerSheet
        }
    }

    @ViewBuilder
    private var statisticsScrollContent: some View {
        VStack(spacing: 20) {
            if isLoading {
                    VStack {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        Spacer()
                    }
                } else if let errorMessage = errorMessage {
                    ErrorView(message: errorMessage) {
                        Task {
                            await loadStatistics()
                        }
                    }
                } else {
                    // Main Statistics Content
                    LazyVStack(spacing: 24) {
                        // Your Film Journey Section
                        FilmJourneySection(
                            dashboardStats: dashboardStats,
                            uniqueFilmsCount: uniqueFilmsCount,
                            averageRatingResolved: resolvedAverageRating,
                            watchSpan: watchSpan,
                            selectedYear: selectedYear,
                            filmsPerMonth: filmsPerMonth,
                            advancedJourneyStats: advancedJourneyStats,
                            yearFilteredAdvancedStats: yearFilteredAdvancedStats
                        )
                        
                        // Modular Bar Chart
                        ModularBarChartView(
                            ratingDistribution: ratingDistribution,
                            detailedRatingDistribution: detailedRatingDistribution,
                            filmsPerYear: filmsPerYear,
                            dayOfWeekPatterns: dayOfWeekPatterns,
                            weeklyFilmsData: weeklyFilmsData,
                            averageStarRatingsPerYear: averageStarRatingsPerYear,
                            averageDetailedRatingsPerYear: averageDetailedRatingsPerYear,
                            filmsByReleaseYear: filmsByReleaseYear,
                            filmsByDecade: filmsByDecade,
                            filmsPerMonth: filmsPerMonth,
                            selectedYear: selectedYear
                        )
                        
                        // Top Watched Films Section - only show for all-time view
                        if selectedYear == nil && !topWatchedFilms.isEmpty {
                            TopWatchedFilmsSection(topWatchedFilms: topWatchedFilms)
                        }
                        
                        // Rewatch Pie Chart
                        if let rewatchStats = rewatchStats {
                            RewatchPieChart(rewatchStats: rewatchStats)
                        }
                        
                        // Total Runtime Section
                        TimeSinceFirstFilmSection(watchSpan: watchSpan, runtimeStats: runtimeStats)
                        
                        // Combined Streaks Section - only show for all-time view
                        if selectedYear == nil {
                            CombinedStreaksSection(
                                streakStats: streakStats,
                                weeklyStreakStats: weeklyStreakStats,
                                selectedYear: selectedYear
                            )
                        }
                        
                        // Year Release Date Pie Chart - only show for year-filtered views
                        if let year = selectedYear, let yearReleaseStats = yearReleaseStats {
                            YearReleasePieChart(yearReleaseStats: yearReleaseStats, selectedYear: year)
                        }
                        
                        if selectedYear != nil {
                            // On Pace Chart - for year-filtered views
                            if let paceStats = yearlyPaceStats {
                                OnPaceChart(yearlyPaceStats: paceStats)
                            }
                        }
                        
                        // Rating Distribution Chart
                        RatingDistributionChart(distribution: ratingDistribution)

                        // Detailed Rating Distribution Chart
                        DetailedRatingDistributionChart(distribution: detailedRatingDistribution)

                        LocationStatisticsSection(
                            mapPoints: locationMapPoints,
                            specificCounts: specificLocationCounts,
                            groupCounts: groupLocationCounts,
                            selectedMode: $locationCountMode,
                            selectedYear: selectedYear
                        )
                        
                        // Films Per Year Chart
                        if selectedYear == nil {
                            FilmsPerYearChart(filmsPerYear: filmsPerYear)
                        }
                        
                        // Films Per Month Chart
                        FilmsPerMonthChart(filmsPerMonth: filmsPerMonth)
                        
                        // Weekly Films Chart
                        if let year = selectedYear, !weeklyFilmsData.isEmpty {
                            WeeklyFilmsChart(weeklyData: weeklyFilmsData, selectedYear: year)
                        }
                        
                        // Day of Week Chart
                        DayOfWeekChart(dayOfWeekPatterns: dayOfWeekPatterns)
                        
                        // Average Rating Per Year Charts
                        if selectedYear == nil && !averageStarRatingsPerYear.isEmpty {
                            AverageStarRatingPerYearChart(averageStarRatings: averageStarRatingsPerYear)
                        }
                        
                        if selectedYear == nil && !averageDetailedRatingsPerYear.isEmpty {
                            AverageDetailedRatingPerYearChart(averageDetailedRatings: averageDetailedRatingsPerYear)
                        }
                        
                        // Films by Release Year Chart
                        if !filmsByReleaseYear.isEmpty {
                            if let year = selectedYear {
                                FilmsByReleaseYearChart(filmsByReleaseYear: filmsByReleaseYear, filteredYear: year)
                            } else {
                                FilmsByReleaseYearChart(filmsByReleaseYear: filmsByReleaseYear)
                            }
                        }
                        
                        // Films by Decade Chart
                        FilmsByDecadeChart(filmsByDecade: filmsByDecade)
                    }
                    .padding(.horizontal)
                }
            }
        }
    
    // MARK: - Year Picker UI Components

    private var filmTypeFilterButton: some View {
        Button {
            cycleFilmTypeMode()
        } label: {
            Image(systemName: selectedFilmTypeMode.nextMode.iconName)
                .font(.system(size: 16, weight: .medium))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("statistics.filmTypeSwapButton")
        .accessibilityLabel("Switch film mode")
        .accessibilityValue(selectedFilmTypeMode.title)
    }

    private func cycleFilmTypeMode() {
        selectedFilmTypeMode = selectedFilmTypeMode.nextMode
    }
    
    private var yearPickerButton: some View {
        Button(action: {
            showingYearPicker = true
        }) {
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.blue)
                
                Text(yearSelectionLabel)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.adaptiveText(scheme: colorScheme))
                
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.blue)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .scaleEffect(showingYearPicker ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: showingYearPicker)
    }
    
    private var yearPickerSheet: some View {
        NavigationStack {
            List {
                Section {
                    // All Time option
                    HStack {
                        Image(systemName: "infinity")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        
                        Text("All Time")
                            .font(.system(size: 17, weight: selectedYear == nil ? .semibold : .regular))
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        if selectedYear == nil {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.vertical, 2)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedYear = nil
                        showingYearPicker = false
                    }
                } header: {
                    Text("Time Period")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                // Available years section
                if !availableYears.isEmpty {
                    Section {
                        ForEach(availableYears, id: \.self) { year in
                            HStack {
                                Image(systemName: "calendar")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.green)
                                    .frame(width: 24)
                                
                                Text(String(year))
                                    .font(.system(size: 17, weight: selectedYear == year ? .semibold : .regular))
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                if selectedYear == year {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding(.vertical, 2)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedYear = year
                                showingYearPicker = false
                            }
                        }
                    } header: {
                        Text("Available Years")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
            }
            #if os(iOS)
            .listStyle(.insetGrouped)
            #endif
            .navigationTitle("Select Year")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showingYearPicker = false
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.blue)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
    
    // MARK: - Data Loading Functions
    
    private func shouldRefreshData() -> Bool {
        let cacheKey = getCacheKey()
        if let cachedData = cachedDataByYear[cacheKey] {
            return Date().timeIntervalSince(cachedData.cachedAt) > refreshInterval
        }
        return true
    }
    
    private func getCacheKey() -> String {
        let yearKey = selectedYear?.description ?? "all-time"
        return "\(yearKey)-\(selectedFilmTypeMode.rawValue)"
    }
    
    private func loadStatisticsIfNeeded(force: Bool) async {
        let cacheKey = getCacheKey()
        
        // Check if we have cached data and it's still fresh
        if !force, let cachedData = cachedDataByYear[cacheKey] {
            let timeElapsed = Date().timeIntervalSince(cachedData.cachedAt)
            if timeElapsed < refreshInterval {
                // Use cached data
                await applyCachedData(cachedData)
                return
            }
        }
        
        // Load fresh data
        await loadStatistics()
    }
    
    private func refreshStatistics() async {
        guard !isRefreshing else { return }
        
        isRefreshing = true
        cachedMoviesByFilmType.removeAll()
        
        // Clear cache for current selection to force fresh data
        let cacheKey = getCacheKey()
        cachedDataByYear.removeValue(forKey: cacheKey)
        
        await loadAvailableYears()
        await loadStatisticsForRefresh()
        
        isRefreshing = false
    }
    
    private func applyCachedData(_ cachedData: CachedStatisticsData) async {
        await MainActor.run {
            self.dashboardStats = cachedData.dashboardStats
            self.ratingDistribution = cachedData.ratingDistribution
            self.detailedRatingDistribution = cachedData.detailedRatingDistribution
            self.filmsByDecade = cachedData.filmsByDecade
            self.filmsByReleaseYear = cachedData.filmsByReleaseYear
            self.filmsPerYear = cachedData.filmsPerYear
            self.filmsPerMonth = cachedData.filmsPerMonth
            self.weeklyFilmsData = cachedData.weeklyFilmsData
            self.dayOfWeekPatterns = cachedData.dayOfWeekPatterns
            self.runtimeStats = cachedData.runtimeStats
            self.uniqueFilmsCount = cachedData.uniqueFilmsCount
            self.watchSpan = cachedData.watchSpan
            self.rewatchStats = cachedData.rewatchStats
            self.streakStats = cachedData.streakStats
            self.yearReleaseStats = cachedData.yearReleaseStats
            self.topWatchedFilms = cachedData.topWatchedFilms
            self.advancedJourneyStats = cachedData.advancedJourneyStats
            self.yearFilteredAdvancedStats = cachedData.yearFilteredAdvancedStats
            self.averageStarRatingsPerYear = cachedData.averageStarRatingsPerYear
            self.averageDetailedRatingsPerYear = cachedData.averageDetailedRatingsPerYear
            self.resolvedAverageRating = cachedData.resolvedAverageRating
            self.yearlyPaceStats = cachedData.yearlyPaceStats
            self.allFilmsPerMonth = cachedData.allFilmsPerMonth
            self.locationMapPoints = cachedData.locationMapPoints
            self.specificLocationCounts = cachedData.specificLocationCounts
            self.groupLocationCounts = cachedData.groupLocationCounts
            self.isLoading = false
        }
    }
    
    private func cacheCurrentData() {
        let cacheKey = getCacheKey()
        let cachedData = CachedStatisticsData(
            dashboardStats: dashboardStats,
            ratingDistribution: ratingDistribution,
            detailedRatingDistribution: detailedRatingDistribution,
            filmsByDecade: filmsByDecade,
            filmsByReleaseYear: filmsByReleaseYear,
            filmsPerYear: filmsPerYear,
            filmsPerMonth: filmsPerMonth,
            weeklyFilmsData: weeklyFilmsData,
            dayOfWeekPatterns: dayOfWeekPatterns,
            runtimeStats: runtimeStats,
            uniqueFilmsCount: uniqueFilmsCount,
            watchSpan: watchSpan,
            rewatchStats: rewatchStats,
            streakStats: streakStats,
            yearReleaseStats: yearReleaseStats,
            topWatchedFilms: topWatchedFilms,
            advancedJourneyStats: advancedJourneyStats,
            yearFilteredAdvancedStats: yearFilteredAdvancedStats,
            averageStarRatingsPerYear: averageStarRatingsPerYear,
            averageDetailedRatingsPerYear: averageDetailedRatingsPerYear,
            resolvedAverageRating: resolvedAverageRating,
            yearlyPaceStats: yearlyPaceStats,
            allFilmsPerMonth: allFilmsPerMonth,
            locationMapPoints: locationMapPoints,
            specificLocationCounts: specificLocationCounts,
            groupLocationCounts: groupLocationCounts,
            cachedAt: Date()
        )
        
        // Limit cache size to prevent memory buildup
        if cachedDataByYear.count >= maxCacheSize {
            // Remove oldest cache entry
            let oldestKey = cachedDataByYear.min { $0.value.cachedAt < $1.value.cachedAt }?.key
            if let keyToRemove = oldestKey {
                cachedDataByYear.removeValue(forKey: keyToRemove)
            }
        }
        
        cachedDataByYear[cacheKey] = cachedData
    }
    
    private func loadAvailableYears() async {
        if selectedFilmTypeMode != .all {
            do {
                let movies = try await getMoviesForSelectedFilmType(forceRefresh: false)
                let years = Array(Set(movies.compactMap { extractYear(from: $0.watch_date) })).sorted(by: >)
                await MainActor.run {
                    self.availableYears = years
                }
            } catch {
                await MainActor.run {
                    self.availableYears = []
                }
            }
            return
        }

        do {
            let years = try await statisticsService.getLoggedYears()
            
            // Filter out any invalid years (0, negative, or unreasonable values)
            let validYears = years.filter { $0 > 1900 && $0 <= 3000 }
            
            // Sort years in descending order (newest first) and remove duplicates
            let sortedUniqueYears = Array(Set(validYears)).sorted(by: >)
            
            await MainActor.run {
                self.availableYears = sortedUniqueYears
            }
        } catch {
            // Handle error silently or show user-friendly message
        }
    }
    
    private func loadStatistics() async {
        if selectedFilmTypeMode != .all {
            await loadLocalFilteredStatistics(showLoading: true)
            return
        }

        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        let startTime = Date()
        
        do {
            // Load all stats from Supabase
            async let dashboardTask = statisticsService.getDashboardStats(year: selectedYear)
            async let ratingTask = statisticsService.getRatingDistribution(year: selectedYear)
            async let detailedRatingTask = statisticsService.getDetailedRatingDistribution(year: selectedYear)
            async let decadeTask = statisticsService.getFilmsByDecade(year: selectedYear)
            async let releaseYearTask = statisticsService.getFilmsByReleaseYear(year: selectedYear)
            async let yearTask = statisticsService.getFilmsPerYear(year: selectedYear)
            async let monthTask = statisticsService.getFilmsPerMonth(year: selectedYear)
            async let weeklyTask = selectedYear != nil ? statisticsService.getWeeklyFilmsData(year: selectedYear!) : nil
            async let runtimeTask = statisticsService.getRuntimeStats(year: selectedYear)
            async let uniqueTask = statisticsService.getUniqueFilmsCount(year: selectedYear)
            async let spanTask = statisticsService.getWatchSpan(year: selectedYear)
            async let ratingStatsTask = statisticsService.getRatingStats(year: selectedYear)
            async let dayOfWeekTask = statisticsService.getDayOfWeekPatterns(year: selectedYear)
            async let rewatchTask = statisticsService.getRewatchStats(year: selectedYear)
            // Always use all-time streak stats (no year parameter)
            async let streakTask = statisticsService.getStreakStats(year: nil)
            // Get weekly streak stats only for all-time view
            async let weeklyStreakTask = selectedYear == nil ? statisticsService.getWeeklyStreakStats(year: nil) : nil
            // Get year release stats only for year-filtered views
            async let yearReleaseTask = selectedYear != nil ? statisticsService.getYearReleaseStats(year: selectedYear!) : nil
            // Get top watched films only for all-time view
            async let topWatchedTask = selectedYear == nil ? statisticsService.getTopWatchedFilms() : nil
            // Get advanced journey stats only for all-time view
            async let advancedJourneyTask = selectedYear == nil ? loadAdvancedJourneyStats() : nil
            // Get year-filtered advanced journey stats only for year-filtered views
            async let yearFilteredAdvancedJourneyTask = selectedYear != nil ? loadYearFilteredAdvancedJourneyStats(year: selectedYear!) : nil
            // Get average rating per year charts only for all-time view
            async let averageStarRatingsTask = selectedYear == nil ? statisticsService.getAverageStarRatingPerYear() : nil
            async let averageDetailedRatingsTask = selectedYear == nil ? statisticsService.getAverageDetailedRatingPerYear() : nil
            // Get all films per month (for historical pace calculation) only for year-filtered views
            async let allFilmsPerMonthTask = selectedYear != nil ? statisticsService.getFilmsPerMonth(year: nil) : nil
            async let locationMapPointsTask = statisticsService.getLocationMapPoints(year: selectedYear)
            async let specificLocationCountsTask = statisticsService.getLocationCounts(year: selectedYear, groupMode: false)
            async let groupLocationCountsTask = statisticsService.getLocationCounts(year: selectedYear, groupMode: true)
            
            let results = try await (
                dashboard: dashboardTask,
                rating: ratingTask,
                detailedRating: detailedRatingTask,
                decade: decadeTask,
                releaseYear: releaseYearTask,
                year: yearTask,
                month: monthTask,
                weekly: weeklyTask,
                runtime: runtimeTask,
                unique: uniqueTask,
                span: spanTask,
                ratingStats: ratingStatsTask,
                dayOfWeek: dayOfWeekTask,
                rewatch: rewatchTask,
                streak: streakTask,
                weeklyStreak: weeklyStreakTask,
                yearRelease: yearReleaseTask,
                topWatched: topWatchedTask,
                advancedJourney: advancedJourneyTask,
                yearFilteredAdvancedJourney: yearFilteredAdvancedJourneyTask,
                averageStarRatings: averageStarRatingsTask,
                averageDetailedRatings: averageDetailedRatingsTask,
                allFilmsPerMonth: allFilmsPerMonthTask,
                locationMapPoints: locationMapPointsTask,
                specificLocationCounts: specificLocationCountsTask,
                groupLocationCounts: groupLocationCountsTask
            )
            
            await MainActor.run {
                self.dashboardStats = results.dashboard
                self.ratingDistribution = results.rating
                self.detailedRatingDistribution = results.detailedRating
                self.filmsByDecade = results.decade
                self.filmsByReleaseYear = results.releaseYear
                self.filmsPerYear = results.year
                self.filmsPerMonth = results.month
                self.weeklyFilmsData = results.weekly ?? []
                self.dayOfWeekPatterns = results.dayOfWeek
                self.runtimeStats = results.runtime
                self.uniqueFilmsCount = results.unique
                self.watchSpan = results.span
                self.rewatchStats = results.rewatch
                self.streakStats = results.streak
                self.weeklyStreakStats = results.weeklyStreak
                self.yearReleaseStats = results.yearRelease
                self.topWatchedFilms = results.topWatched ?? []
                self.advancedJourneyStats = results.advancedJourney
                self.yearFilteredAdvancedStats = results.yearFilteredAdvancedJourney
                self.averageStarRatingsPerYear = results.averageStarRatings ?? []
                self.averageDetailedRatingsPerYear = results.averageDetailedRatings ?? []
                self.resolvedAverageRating = results.dashboard.averageRating ?? results.ratingStats.averageRating
                self.locationMapPoints = results.locationMapPoints
                self.specificLocationCounts = results.specificLocationCounts
                self.groupLocationCounts = results.groupLocationCounts
                
                // Calculate pace stats for year-filtered views
                if let year = self.selectedYear {
                    let allMonthData = results.allFilmsPerMonth ?? []
                    self.allFilmsPerMonth = allMonthData
                    self.yearlyPaceStats = self.statisticsService.calculateYearlyPaceStats(
                        targetYear: year,
                        allFilmsPerMonth: allMonthData,
                        allFilmsPerYear: results.year
                    )
                } else {
                    self.allFilmsPerMonth = []
                    self.yearlyPaceStats = nil
                }
                
                self.isLoading = false
                
                // Cache the loaded data
                self.cacheCurrentData()
                
                _ = Date().timeIntervalSince(startTime)
            }
            
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            print("❌ [STATISTICSVIEW] Statistics load FAILED after \(String(format: "%.3f", duration))s: \(error)")
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    private func loadStatisticsForRefresh() async {
        if selectedFilmTypeMode != .all {
            await loadLocalFilteredStatistics(showLoading: false)
            return
        }

        // Don't set isLoading = true during refresh to keep existing data visible
        await MainActor.run {
            errorMessage = nil
        }
        
        do {
            async let dashboardTask = statisticsService.getDashboardStats(year: selectedYear)
            async let ratingTask = statisticsService.getRatingDistribution(year: selectedYear)
            async let detailedRatingTask = statisticsService.getDetailedRatingDistribution(year: selectedYear)
            async let decadeTask = statisticsService.getFilmsByDecade(year: selectedYear)
            async let releaseYearRefreshTask = statisticsService.getFilmsByReleaseYear(year: selectedYear)
            async let yearTask = statisticsService.getFilmsPerYear(year: selectedYear)
            async let monthTask = statisticsService.getFilmsPerMonth(year: selectedYear)
            async let weeklyTask = selectedYear != nil ? statisticsService.getWeeklyFilmsData(year: selectedYear!) : nil
            async let runtimeTask = statisticsService.getRuntimeStats(year: selectedYear)
            async let uniqueTask = statisticsService.getUniqueFilmsCount(year: selectedYear)
            async let spanTask = statisticsService.getWatchSpan(year: selectedYear)
            async let ratingStatsTask = statisticsService.getRatingStats(year: selectedYear)
            async let dayOfWeekTask = statisticsService.getDayOfWeekPatterns(year: selectedYear)
            async let rewatchTask = statisticsService.getRewatchStats(year: selectedYear)
            // Always use all-time streak stats (no year parameter)
            async let streakTask = statisticsService.getStreakStats(year: nil)
            // Get year release stats only for year-filtered views
            async let yearReleaseTask = selectedYear != nil ? statisticsService.getYearReleaseStats(year: selectedYear!) : nil
            // Get top watched films only for all-time view
            async let topWatchedTask = selectedYear == nil ? statisticsService.getTopWatchedFilms() : nil
            // Get advanced journey stats only for all-time view
            async let advancedJourneyTask = selectedYear == nil ? loadAdvancedJourneyStats() : nil
            // Get year-filtered advanced journey stats only for year-filtered views
            async let yearFilteredAdvancedJourneyTask = selectedYear != nil ? loadYearFilteredAdvancedJourneyStats(year: selectedYear!) : nil
            // Get average rating per year charts only for all-time view
            async let averageStarRatingsTask = selectedYear == nil ? statisticsService.getAverageStarRatingPerYear() : nil
            async let averageDetailedRatingsTask = selectedYear == nil ? statisticsService.getAverageDetailedRatingPerYear() : nil
            // Get all films per month (for historical pace calculation) only for year-filtered views
            async let allFilmsPerMonthTask = selectedYear != nil ? statisticsService.getFilmsPerMonth(year: nil) : nil
            async let locationMapPointsTask = statisticsService.getLocationMapPoints(year: selectedYear)
            async let specificLocationCountsTask = statisticsService.getLocationCounts(year: selectedYear, groupMode: false)
            async let groupLocationCountsTask = statisticsService.getLocationCounts(year: selectedYear, groupMode: true)
            
            let results = try await (
                dashboard: dashboardTask,
                rating: ratingTask,
                detailedRating: detailedRatingTask,
                decade: decadeTask,
                releaseYear: releaseYearRefreshTask,
                year: yearTask,
                month: monthTask,
                weekly: weeklyTask,
                runtime: runtimeTask,
                unique: uniqueTask,
                span: spanTask,
                ratingStats: ratingStatsTask,
                dayOfWeek: dayOfWeekTask,
                rewatch: rewatchTask,
                streak: streakTask,
                yearRelease: yearReleaseTask,
                topWatched: topWatchedTask,
                advancedJourney: advancedJourneyTask,
                yearFilteredAdvancedJourney: yearFilteredAdvancedJourneyTask,
                averageStarRatings: averageStarRatingsTask,
                averageDetailedRatings: averageDetailedRatingsTask,
                allFilmsPerMonth: allFilmsPerMonthTask,
                locationMapPoints: locationMapPointsTask,
                specificLocationCounts: specificLocationCountsTask,
                groupLocationCounts: groupLocationCountsTask
            )
            
            await MainActor.run {
                self.dashboardStats = results.dashboard
                self.ratingDistribution = results.rating
                self.detailedRatingDistribution = results.detailedRating
                self.filmsByDecade = results.decade
                self.filmsByReleaseYear = results.releaseYear
                self.filmsPerYear = results.year
                self.filmsPerMonth = results.month
                self.weeklyFilmsData = results.weekly ?? []
                self.dayOfWeekPatterns = results.dayOfWeek
                self.runtimeStats = results.runtime
                self.uniqueFilmsCount = results.unique
                self.watchSpan = results.span
                self.rewatchStats = results.rewatch
                self.streakStats = results.streak
                self.yearReleaseStats = results.yearRelease
                self.topWatchedFilms = results.topWatched ?? []
                self.advancedJourneyStats = results.advancedJourney
                self.yearFilteredAdvancedStats = results.yearFilteredAdvancedJourney
                self.averageStarRatingsPerYear = results.averageStarRatings ?? []
                self.averageDetailedRatingsPerYear = results.averageDetailedRatings ?? []
                self.resolvedAverageRating = results.dashboard.averageRating ?? results.ratingStats.averageRating
                self.locationMapPoints = results.locationMapPoints
                self.specificLocationCounts = results.specificLocationCounts
                self.groupLocationCounts = results.groupLocationCounts
                
                // Calculate pace stats for year-filtered views
                if let year = self.selectedYear {
                    let allMonthData = results.allFilmsPerMonth ?? []
                    self.allFilmsPerMonth = allMonthData
                    self.yearlyPaceStats = self.statisticsService.calculateYearlyPaceStats(
                        targetYear: year,
                        allFilmsPerMonth: allMonthData,
                        allFilmsPerYear: results.year
                    )
                } else {
                    self.allFilmsPerMonth = []
                    self.yearlyPaceStats = nil
                }
                // Note: Don't set isLoading = false here during refresh
                
                // Cache the loaded data
                self.cacheCurrentData()
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                // Don't change isLoading state during refresh
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func loadAdvancedJourneyStats() async throws -> AdvancedFilmJourneyStats {
        async let daysWith2PlusTask = statisticsService.getDaysWith2PlusFilms()
        async let averagePerYearTask = statisticsService.getAverageMoviesPerYear()
        async let mustWatchTask = statisticsService.getMustWatchCompletionAllTime()
        async let unique5StarTask = statisticsService.getUnique5StarFilms()
        async let mostMoviesInDayTask = statisticsService.getMostMoviesInDay()
        async let highestMonthlyTask = statisticsService.getHighestMonthlyAverage()
        
        let results = try await (
            daysWith2Plus: daysWith2PlusTask,
            averagePerYear: averagePerYearTask,
            mustWatch: mustWatchTask,
            unique5Star: unique5StarTask,
            mostMoviesInDay: mostMoviesInDayTask,
            highestMonthly: highestMonthlyTask
        )
        
        return AdvancedFilmJourneyStats(
            daysWith2PlusFilms: results.daysWith2Plus,
            averageMoviesPerYear: results.averagePerYear,
            mustWatchCompletion: results.mustWatch,
            unique5StarFilms: results.unique5Star,
            mostMoviesInDay: results.mostMoviesInDay,
            highestMonthlyAverage: results.highestMonthly
        )
    }
    
    private func loadYearFilteredAdvancedJourneyStats(year: Int) async throws -> YearFilteredAdvancedJourneyStats {
        async let daysWith2PlusTask = statisticsService.getDaysWith2PlusFilmsByYear(year: year)
        async let mustWatchTask = statisticsService.getMustWatchCompletionByYear(year: year)
        async let unique5StarTask = statisticsService.getUnique5StarFilmsByYear(year: year)
        async let mostMoviesInDayTask = statisticsService.getMostMoviesInDayByYear(year: year)
        async let highestMonthlyTask = statisticsService.getHighestMonthlyAverageByYear(year: year)
        
        let results = try await (
            daysWith2Plus: daysWith2PlusTask,
            mustWatch: mustWatchTask,
            unique5Star: unique5StarTask,
            mostMoviesInDay: mostMoviesInDayTask,
            highestMonthly: highestMonthlyTask
        )
        
        return YearFilteredAdvancedJourneyStats(
            daysWith2PlusFilms: results.daysWith2Plus,
            mustWatchCompletion: results.mustWatch,
            unique5StarFilms: results.unique5Star,
            mostMoviesInDay: results.mostMoviesInDay,
            highestMonthlyAverage: results.highestMonthly
        )
    }

    private func loadLocalFilteredStatistics(showLoading: Bool) async {
        if showLoading {
            await MainActor.run {
                isLoading = true
                errorMessage = nil
            }
        } else {
            await MainActor.run {
                errorMessage = nil
            }
        }

        do {
            let modeMovies = try await getMoviesForSelectedFilmType(forceRefresh: false)
            let allEntries = buildDatedEntries(from: modeMovies)
            let scopedEntries: [DatedMovieEntry]
            if let year = selectedYear {
                scopedEntries = allEntries.filter { $0.watchYear == year }
            } else {
                scopedEntries = allEntries
            }

            let allYearsFilmsPerYear = computeFilmsPerYear(entries: allEntries)
            let allYearsFilmsPerMonth = computeFilmsPerMonth(entries: allEntries)
            let scopedFilmsPerMonth: [FilmsPerMonth]
            if let year = selectedYear {
                scopedFilmsPerMonth = allYearsFilmsPerMonth.filter { $0.year == year }
            } else {
                scopedFilmsPerMonth = allYearsFilmsPerMonth
            }

            let scopedWeeklyFilms: [WeeklyFilmsData]
            if let year = selectedYear {
                scopedWeeklyFilms = computeWeeklyFilmsData(entries: scopedEntries, year: year)
            } else {
                scopedWeeklyFilms = []
            }

            let dashboard = computeDashboardStats(entries: scopedEntries)
            let rating = computeRatingDistribution(entries: scopedEntries)
            let detailedRating = computeDetailedRatingDistribution(entries: scopedEntries)
            let decade = computeFilmsByDecade(entries: scopedEntries)
            let releaseYear = computeFilmsByReleaseYear(entries: scopedEntries)
            let dayOfWeek = computeDayOfWeekPatterns(entries: scopedEntries)
            let runtime = computeRuntimeStats(entries: scopedEntries)
            let unique = computeUniqueFilmsCount(entries: scopedEntries)
            let watchSpanData = computeWatchSpan(entries: scopedEntries)
            let ratingStats = computeRatingStats(entries: scopedEntries)
            let rewatch = computeRewatchStats(entries: scopedEntries)
            let streak = computeStreakStats(entries: allEntries)
            let weeklyStreak = selectedYear == nil ? computeWeeklyStreakStats(entries: allEntries) : nil
            let yearRelease = selectedYear == nil ? nil : computeYearReleaseStats(entries: scopedEntries, targetYear: selectedYear!)
            let topWatched = selectedYear == nil ? computeTopWatchedFilms(entries: allEntries) : []
            let advanced = selectedYear == nil ? computeAdvancedJourneyStats(entries: allEntries) : nil
            let yearAdvanced = selectedYear == nil ? nil : computeYearFilteredAdvancedJourneyStats(entries: scopedEntries)
            let averageStarRatings = selectedYear == nil ? computeAverageStarRatingsPerYear(entries: allEntries) : []
            let averageDetailedRatings = selectedYear == nil ? computeAverageDetailedRatingsPerYear(entries: allEntries) : []
            let locationData = try await computeLocationStatistics(entries: scopedEntries)

            await MainActor.run {
                self.dashboardStats = dashboard
                self.ratingDistribution = rating
                self.detailedRatingDistribution = detailedRating
                self.filmsByDecade = decade
                self.filmsByReleaseYear = releaseYear
                self.filmsPerYear = allYearsFilmsPerYear
                self.filmsPerMonth = scopedFilmsPerMonth
                self.weeklyFilmsData = scopedWeeklyFilms
                self.dayOfWeekPatterns = dayOfWeek
                self.runtimeStats = runtime
                self.uniqueFilmsCount = unique
                self.watchSpan = watchSpanData
                self.rewatchStats = rewatch
                self.streakStats = streak
                self.weeklyStreakStats = weeklyStreak
                self.yearReleaseStats = yearRelease
                self.topWatchedFilms = topWatched
                self.advancedJourneyStats = advanced
                self.yearFilteredAdvancedStats = yearAdvanced
                self.averageStarRatingsPerYear = averageStarRatings
                self.averageDetailedRatingsPerYear = averageDetailedRatings
                self.resolvedAverageRating = dashboard.averageRating ?? ratingStats.averageRating
                self.locationMapPoints = locationData.mapPoints
                self.specificLocationCounts = locationData.specificCounts
                self.groupLocationCounts = locationData.groupCounts

                if let year = self.selectedYear {
                    self.allFilmsPerMonth = allYearsFilmsPerMonth
                    self.yearlyPaceStats = self.statisticsService.calculateYearlyPaceStats(
                        targetYear: year,
                        allFilmsPerMonth: allYearsFilmsPerMonth,
                        allFilmsPerYear: allYearsFilmsPerYear
                    )
                } else {
                    self.allFilmsPerMonth = []
                    self.yearlyPaceStats = nil
                }

                if showLoading {
                    self.isLoading = false
                }
                self.cacheCurrentData()
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                if showLoading {
                    self.isLoading = false
                }
            }
        }
    }

    private func getMoviesForSelectedFilmType(forceRefresh: Bool) async throws -> [Movie] {
        if !forceRefresh, let cached = cachedMoviesByFilmType[selectedFilmTypeMode] {
            return cached
        }

        let allMovies: [Movie]
        if !forceRefresh, let cachedAllMovies = cachedMoviesByFilmType[.all] {
            allMovies = cachedAllMovies
        } else {
            allMovies = try await fetchAllDiaryMovies()
        }

        let shortMovies = allMovies.filter { hasShortTag(tags: $0.tags) }
        let featureMovies = allMovies.filter { !hasShortTag(tags: $0.tags) }

        await MainActor.run {
            self.cachedMoviesByFilmType[.all] = allMovies
            self.cachedMoviesByFilmType[.short] = shortMovies
            self.cachedMoviesByFilmType[.feature] = featureMovies
        }

        switch selectedFilmTypeMode {
        case .all:
            return allMovies
        case .feature:
            return featureMovies
        case .short:
            return shortMovies
        }
    }

    private func fetchAllDiaryMovies() async throws -> [Movie] {
        let batchSize = 2000
        var offset = 0
        var allMovies: [Movie] = []

        while true {
            let batch = try await movieService.getMovies(
                sortBy: .watchDate,
                ascending: false,
                limit: batchSize,
                offset: offset
            )
            allMovies.append(contentsOf: batch)

            if batch.count < batchSize {
                break
            }
            offset += batchSize
        }

        return allMovies
    }

    private func hasShortTag(tags: String?) -> Bool {
        normalizedTags(from: tags).contains("short")
    }

    private func normalizedTags(from tags: String?) -> Set<String> {
        guard let tags, !tags.isEmpty else { return [] }
        let primaryTokens = tags
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }

        var results: Set<String> = []
        for token in primaryTokens {
            results.insert(token)
            for nested in token.split(whereSeparator: \.isWhitespace) {
                let clean = nested.trimmingCharacters(in: .punctuationCharacters)
                if !clean.isEmpty {
                    results.insert(clean)
                }
            }
        }
        return results
    }

    private func extractYear(from watchedDate: String?) -> Int? {
        guard let watchedDate, watchedDate.count >= 4 else { return nil }
        return Int(watchedDate.prefix(4))
    }

    private func buildDatedEntries(from movies: [Movie]) -> [DatedMovieEntry] {
        let calendar = Calendar.current
        return movies.compactMap { movie in
            guard
                let dateString = movie.watch_date,
                let watchDate = Self.watchDateParser.date(from: dateString)
            else {
                return nil
            }

            return DatedMovieEntry(
                movie: movie,
                date: watchDate,
                watchYear: calendar.component(.year, from: watchDate),
                month: calendar.component(.month, from: watchDate),
                weekday: calendar.component(.weekday, from: watchDate),
                weekOfYear: calendar.component(.weekOfYear, from: watchDate),
                dateString: dateString
            )
        }
    }

    private func uniqueMovieKey(for movie: Movie) -> String {
        if let tmdbId = movie.tmdb_id {
            return "tmdb:\(tmdbId)"
        }

        let normalizedTitle = movie.title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        if normalizedTitle.isEmpty {
            return "id:\(movie.id)"
        }
        return "title:\(normalizedTitle)|year:\(movie.release_year ?? -1)"
    }

    private func computeDashboardStats(entries: [DatedMovieEntry]) -> DashboardStats {
        let totalFilms = entries.count
        let uniqueFilms = Set(entries.map { uniqueMovieKey(for: $0.movie) }).count
        let ratings = entries.compactMap(\.movie.rating)
        let averageRating = ratings.isEmpty ? nil : ratings.reduce(0, +) / Double(ratings.count)
        let currentYear = Calendar.current.component(.year, from: Date())
        let filmsThisYear = entries.filter { $0.watchYear == currentYear }.count

        var genreCounts: [String: Int] = [:]
        for entry in entries {
            for genre in entry.movie.genres ?? [] {
                let normalized = genre.trimmingCharacters(in: .whitespacesAndNewlines)
                if !normalized.isEmpty {
                    genreCounts[normalized, default: 0] += 1
                }
            }
        }
        let topGenre = genreCounts.max { lhs, rhs in
            lhs.value == rhs.value ? lhs.key > rhs.key : lhs.value < rhs.value
        }?.key

        var directorCounts: [String: Int] = [:]
        for entry in entries {
            let director = (entry.movie.director ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !director.isEmpty {
                directorCounts[director, default: 0] += 1
            }
        }
        let topDirector = directorCounts.max { lhs, rhs in
            lhs.value == rhs.value ? lhs.key > rhs.key : lhs.value < rhs.value
        }?.key

        var weekdayCounts: [Int: Int] = [:]
        for entry in entries {
            weekdayCounts[entry.weekday, default: 0] += 1
        }
        let favoriteDayNumber = weekdayCounts.max { lhs, rhs in
            lhs.value == rhs.value ? lhs.key > rhs.key : lhs.value < rhs.value
        }?.key
        let favoriteDay = favoriteDayNumber.map { Calendar.current.weekdaySymbols[$0 - 1] }

        return DashboardStats(
            totalFilms: totalFilms,
            uniqueFilms: uniqueFilms,
            averageRating: averageRating,
            filmsThisYear: filmsThisYear,
            topGenre: topGenre,
            topDirector: topDirector,
            favoriteDay: favoriteDay
        )
    }

    private func computeRatingDistribution(entries: [DatedMovieEntry]) -> [RatingDistribution] {
        let ratings = entries.compactMap(\.movie.rating)
        guard !ratings.isEmpty else { return [] }

        var counts: [Double: Int] = [:]
        for rating in ratings {
            counts[rating, default: 0] += 1
        }

        let total = ratings.count
        return counts.keys.sorted().map { key in
            let count = counts[key, default: 0]
            return RatingDistribution(
                ratingValue: key,
                countFilms: count,
                percentage: (Double(count) / Double(max(total, 1))) * 100.0
            )
        }
    }

    private func computeDetailedRatingDistribution(entries: [DatedMovieEntry]) -> [DetailedRatingDistribution] {
        let sorted = entries.sorted {
            if $0.date == $1.date {
                return $0.movie.id > $1.movie.id
            }
            return $0.date > $1.date
        }

        var seenKeys: Set<String> = []
        var counts = Array(repeating: 0, count: 101)

        for entry in sorted {
            guard let rating = entry.movie.detailed_rating else { continue }
            let key = uniqueMovieKey(for: entry.movie)
            if seenKeys.contains(key) {
                continue
            }
            seenKeys.insert(key)

            let index = min(100, max(0, Int(rating.rounded())))
            counts[index] += 1
        }

        return (0...100).map { value in
            DetailedRatingDistribution(ratingValue: value, countFilms: counts[value])
        }
    }

    private func computeFilmsByDecade(entries: [DatedMovieEntry]) -> [FilmsByDecade] {
        let releaseYears = entries.compactMap(\.movie.release_year)
        guard !releaseYears.isEmpty else { return [] }

        var counts: [Int: Int] = [:]
        for year in releaseYears {
            let decade = (year / 10) * 10
            counts[decade, default: 0] += 1
        }

        let total = releaseYears.count
        return counts.keys.sorted().map { decade in
            let count = counts[decade, default: 0]
            return FilmsByDecade(
                decade: decade,
                filmCount: count,
                percentage: (Double(count) / Double(max(total, 1))) * 100.0
            )
        }
    }

    private func computeFilmsByReleaseYear(entries: [DatedMovieEntry]) -> [FilmsByReleaseYear] {
        let releaseYears = entries.compactMap(\.movie.release_year)
        guard !releaseYears.isEmpty else { return [] }

        var counts: [Int: Int] = [:]
        for year in releaseYears {
            counts[year, default: 0] += 1
        }

        let total = releaseYears.count
        return counts.keys.sorted().map { year in
            let count = counts[year, default: 0]
            return FilmsByReleaseYear(
                releaseYear: year,
                filmCount: count,
                percentage: (Double(count) / Double(max(total, 1))) * 100.0
            )
        }
    }

    private func computeFilmsPerYear(entries: [DatedMovieEntry]) -> [FilmsPerYear] {
        let grouped = Dictionary(grouping: entries, by: \.watchYear)
        return grouped.keys.sorted().map { year in
            let yearEntries = grouped[year] ?? []
            let uniqueFilms = Set(yearEntries.map { uniqueMovieKey(for: $0.movie) }).count
            return FilmsPerYear(year: year, filmCount: yearEntries.count, uniqueFilms: uniqueFilms)
        }
    }

    private func computeFilmsPerMonth(entries: [DatedMovieEntry]) -> [FilmsPerMonth] {
        let grouped = Dictionary(grouping: entries) { YearMonthKey(year: $0.watchYear, month: $0.month) }

        let keys = grouped.keys.sorted {
            if $0.year == $1.year {
                return $0.month < $1.month
            }
            return $0.year < $1.year
        }

        return keys.map { key in
            let year = key.year
            let month = key.month
            let count = grouped[key]?.count ?? 0
            let monthName = shortMonthLabel(for: month)
            return FilmsPerMonth(year: year, month: month, monthName: monthName, filmCount: count)
        }
    }

    private func computeWeeklyFilmsData(entries: [DatedMovieEntry], year: Int) -> [WeeklyFilmsData] {
        let grouped = Dictionary(grouping: entries, by: \.weekOfYear)
        let sortedWeeks = grouped.keys.sorted()

        return sortedWeeks.map { week in
            let weekEntries = grouped[week] ?? []
            let sortedEntries = weekEntries.sorted { $0.date < $1.date }
            let startDate = sortedEntries.first?.dateString ?? ""
            let endDate = sortedEntries.last?.dateString ?? ""

            return WeeklyFilmsData(
                year: year,
                weekNumber: week,
                weekStartDate: startDate,
                weekEndDate: endDate,
                filmCount: weekEntries.count
            )
        }
    }

    private func computeDayOfWeekPatterns(entries: [DatedMovieEntry]) -> [DayOfWeekPattern] {
        var counts: [Int: Int] = [:] // backend format: 0=Sunday ... 6=Saturday
        for entry in entries {
            let backendDay = entry.weekday - 1
            counts[backendDay, default: 0] += 1
        }

        let total = entries.count
        let dayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

        return (0...6).map { day in
            let count = counts[day, default: 0]
            return DayOfWeekPattern(
                dayOfWeek: dayNames[day],
                dayNumber: day,
                filmCount: count,
                percentage: total == 0 ? 0.0 : (Double(count) / Double(total)) * 100.0
            )
        }
    }

    private func computeRuntimeStats(entries: [DatedMovieEntry]) -> RuntimeStats {
        let runtimeEntries = entries.compactMap { entry -> (Movie, Int)? in
            guard let runtime = entry.movie.runtime, runtime > 0 else { return nil }
            return (entry.movie, runtime)
        }

        guard !runtimeEntries.isEmpty else {
            return RuntimeStats(
                totalRuntime: 0,
                averageRuntime: 0.0,
                medianRuntime: 0.0,
                longestRuntime: 0,
                longestTitle: nil,
                shortestRuntime: 0,
                shortestTitle: nil
            )
        }

        let runtimes = runtimeEntries.map(\.1)
        let totalRuntime = runtimes.reduce(0, +)
        let averageRuntime = Double(totalRuntime) / Double(runtimes.count)
        let sorted = runtimes.sorted()
        let medianRuntime: Double
        if sorted.count.isMultiple(of: 2) {
            let mid = sorted.count / 2
            medianRuntime = Double(sorted[mid - 1] + sorted[mid]) / 2.0
        } else {
            medianRuntime = Double(sorted[sorted.count / 2])
        }

        let longest = runtimeEntries.max { $0.1 < $1.1 }
        let shortest = runtimeEntries.min { $0.1 < $1.1 }

        return RuntimeStats(
            totalRuntime: totalRuntime,
            averageRuntime: averageRuntime,
            medianRuntime: medianRuntime,
            longestRuntime: longest?.1,
            longestTitle: longest?.0.title,
            shortestRuntime: shortest?.1,
            shortestTitle: shortest?.0.title
        )
    }

    private func computeUniqueFilmsCount(entries: [DatedMovieEntry]) -> Int {
        Set(entries.map { uniqueMovieKey(for: $0.movie) }).count
    }

    private func computeWatchSpan(entries: [DatedMovieEntry]) -> WatchSpan {
        guard let first = entries.min(by: { $0.date < $1.date }),
              let last = entries.max(by: { $0.date < $1.date }) else {
            return WatchSpan(firstWatchDate: nil, lastWatchDate: nil, watchSpan: nil, totalDays: 0)
        }

        let days = Calendar.current.dateComponents([.day], from: first.date, to: last.date).day ?? 0
        let totalDays = max(0, days + 1)
        return WatchSpan(
            firstWatchDate: first.dateString,
            lastWatchDate: last.dateString,
            watchSpan: "\(totalDays) days",
            totalDays: totalDays
        )
    }

    private func computeRatingStats(entries: [DatedMovieEntry]) -> RatingStats {
        let ratings = entries.compactMap(\.movie.rating).sorted()
        guard !ratings.isEmpty else {
            return RatingStats(
                averageRating: nil,
                medianRating: nil,
                modeRating: nil,
                standardDeviation: nil,
                totalRated: 0,
                fiveStarPercentage: nil
            )
        }

        let total = ratings.count
        let average = ratings.reduce(0, +) / Double(total)
        let median: Double
        if total.isMultiple(of: 2) {
            median = (ratings[(total / 2) - 1] + ratings[total / 2]) / 2.0
        } else {
            median = ratings[total / 2]
        }

        var counts: [Double: Int] = [:]
        for rating in ratings {
            counts[rating, default: 0] += 1
        }
        let modeRating = counts.max { lhs, rhs in
            lhs.value == rhs.value ? lhs.key > rhs.key : lhs.value < rhs.value
        }?.key

        let variance = ratings.reduce(0.0) { partial, value in
            let delta = value - average
            return partial + (delta * delta)
        } / Double(total)

        let fiveStarCount = ratings.filter { $0 >= 5.0 }.count
        let fiveStarPercentage = (Double(fiveStarCount) / Double(total)) * 100.0

        return RatingStats(
            averageRating: average,
            medianRating: median,
            modeRating: modeRating.map { Int($0.rounded()) },
            standardDeviation: sqrt(variance),
            totalRated: total,
            fiveStarPercentage: fiveStarPercentage
        )
    }

    private func computeRewatchStats(entries: [DatedMovieEntry]) -> RewatchStats {
        let rewatchEntries = entries.filter { $0.movie.is_rewatch == true }
        let totalFilms = entries.count
        let totalRewatches = rewatchEntries.count
        let nonRewatches = max(0, totalFilms - totalRewatches)
        let rewatchPercentage = totalFilms == 0 ? 0.0 : (Double(totalRewatches) / Double(totalFilms)) * 100.0
        let uniqueFilmsRewatched = Set(rewatchEntries.map { uniqueMovieKey(for: $0.movie) }).count

        var rewatchCounts: [String: (title: String, count: Int)] = [:]
        for entry in rewatchEntries {
            let key = uniqueMovieKey(for: entry.movie)
            let current = rewatchCounts[key] ?? (title: entry.movie.title, count: 0)
            rewatchCounts[key] = (title: current.title, count: current.count + 1)
        }
        let topRewatchedMovie = rewatchCounts.max { lhs, rhs in
            lhs.value.count == rhs.value.count ? lhs.value.title > rhs.value.title : lhs.value.count < rhs.value.count
        }?.value.title

        return RewatchStats(
            totalRewatches: totalRewatches,
            totalFilms: totalFilms,
            nonRewatches: nonRewatches,
            rewatchPercentage: rewatchPercentage,
            uniqueFilmsRewatched: uniqueFilmsRewatched,
            topRewatchedMovie: topRewatchedMovie
        )
    }

    private func computeStreakStats(entries: [DatedMovieEntry]) -> StreakStats {
        let calendar = Calendar.current
        let groupedByDate = Dictionary(grouping: entries, by: \.dateString)
        let uniqueDates = Set(entries.map { calendar.startOfDay(for: $0.date) }).sorted()

        guard let lastDate = uniqueDates.last else {
            return StreakStats(
                longestStreakDays: 0,
                longestStreakStartDate: nil,
                longestStreakEndDate: nil,
                longestStreakStartTitle: nil,
                longestStreakStartPoster: nil,
                longestStreakEndTitle: nil,
                longestStreakEndPoster: nil,
                currentStreakDays: 0,
                currentStreakStartDate: nil,
                currentStreakEndDate: nil,
                currentStreakStartTitle: nil,
                currentStreakStartPoster: nil,
                currentStreakEndTitle: nil,
                currentStreakEndPoster: nil,
                isCurrentStreakActive: false
            )
        }

        var longest = StreakWindow(start: uniqueDates[0], end: uniqueDates[0], length: 1)
        var currentStart = uniqueDates[0]
        var currentLength = 1
        for index in 1..<uniqueDates.count {
            let previous = uniqueDates[index - 1]
            let current = uniqueDates[index]
            let daysBetween = calendar.dateComponents([.day], from: previous, to: current).day ?? 0
            if daysBetween == 1 {
                currentLength += 1
            } else {
                if currentLength > longest.length {
                    longest = StreakWindow(start: currentStart, end: previous, length: currentLength)
                }
                currentStart = current
                currentLength = 1
            }
        }
        if currentLength > longest.length {
            longest = StreakWindow(start: currentStart, end: uniqueDates.last ?? currentStart, length: currentLength)
        }

        var currentStreakLength = 1
        var currentStreakStart = lastDate
        if uniqueDates.count > 1 {
            for index in stride(from: uniqueDates.count - 1, to: 0, by: -1) {
                let current = uniqueDates[index]
                let previous = uniqueDates[index - 1]
                let daysBetween = calendar.dateComponents([.day], from: previous, to: current).day ?? 0
                if daysBetween == 1 {
                    currentStreakLength += 1
                    currentStreakStart = previous
                } else {
                    break
                }
            }
        }

        let today = calendar.startOfDay(for: Date())
        let daysSinceLast = calendar.dateComponents([.day], from: lastDate, to: today).day ?? Int.max
        let isCurrentActive = daysSinceLast <= 1

        let longestStartString = Self.watchDateParser.string(from: longest.start)
        let longestEndString = Self.watchDateParser.string(from: longest.end)
        let currentStartString = Self.watchDateParser.string(from: currentStreakStart)
        let currentEndString = Self.watchDateParser.string(from: lastDate)

        let longestStartMovie = groupedByDate[longestStartString]?.sorted(by: { $0.movie.id < $1.movie.id }).first?.movie
        let longestEndMovie = groupedByDate[longestEndString]?.sorted(by: { $0.movie.id > $1.movie.id }).first?.movie
        let currentStartMovie = groupedByDate[currentStartString]?.sorted(by: { $0.movie.id < $1.movie.id }).first?.movie
        let currentEndMovie = groupedByDate[currentEndString]?.sorted(by: { $0.movie.id > $1.movie.id }).first?.movie

        return StreakStats(
            longestStreakDays: longest.length,
            longestStreakStartDate: longestStartString,
            longestStreakEndDate: longestEndString,
            longestStreakStartTitle: longestStartMovie?.title,
            longestStreakStartPoster: longestStartMovie?.poster_url,
            longestStreakEndTitle: longestEndMovie?.title,
            longestStreakEndPoster: longestEndMovie?.poster_url,
            currentStreakDays: currentStreakLength,
            currentStreakStartDate: currentStartString,
            currentStreakEndDate: currentEndString,
            currentStreakStartTitle: currentStartMovie?.title,
            currentStreakStartPoster: currentStartMovie?.poster_url,
            currentStreakEndTitle: currentEndMovie?.title,
            currentStreakEndPoster: currentEndMovie?.poster_url,
            isCurrentStreakActive: isCurrentActive
        )
    }

    private func computeWeeklyStreakStats(entries: [DatedMovieEntry]) -> WeeklyStreakStats {
        var isoCalendar = Calendar(identifier: .iso8601)
        isoCalendar.locale = Locale(identifier: "en_US_POSIX")

        let uniqueWeekStarts = Set(entries.compactMap { isoCalendar.dateInterval(of: .weekOfYear, for: $0.date)?.start }).sorted()
        guard let lastWeekStart = uniqueWeekStarts.last else {
            return WeeklyStreakStats(
                longestWeeklyStreakWeeks: 0,
                longestWeeklyStreakStartDate: nil,
                longestWeeklyStreakEndDate: nil,
                currentWeeklyStreakWeeks: 0,
                currentWeeklyStreakStartDate: nil,
                currentWeeklyStreakEndDate: nil,
                isCurrentWeeklyStreakActive: false
            )
        }

        var longest = StreakWindow(start: uniqueWeekStarts[0], end: uniqueWeekStarts[0], length: 1)
        var currentStart = uniqueWeekStarts[0]
        var currentLength = 1
        for index in 1..<uniqueWeekStarts.count {
            let previous = uniqueWeekStarts[index - 1]
            let current = uniqueWeekStarts[index]
            let days = isoCalendar.dateComponents([.day], from: previous, to: current).day ?? 0
            if days == 7 {
                currentLength += 1
            } else {
                if currentLength > longest.length {
                    longest = StreakWindow(start: currentStart, end: previous, length: currentLength)
                }
                currentStart = current
                currentLength = 1
            }
        }
        if currentLength > longest.length {
            longest = StreakWindow(start: currentStart, end: uniqueWeekStarts.last ?? currentStart, length: currentLength)
        }

        var currentWeeklyLength = 1
        var currentWeeklyStart = lastWeekStart
        if uniqueWeekStarts.count > 1 {
            for index in stride(from: uniqueWeekStarts.count - 1, to: 0, by: -1) {
                let current = uniqueWeekStarts[index]
                let previous = uniqueWeekStarts[index - 1]
                let days = isoCalendar.dateComponents([.day], from: previous, to: current).day ?? 0
                if days == 7 {
                    currentWeeklyLength += 1
                    currentWeeklyStart = previous
                } else {
                    break
                }
            }
        }

        let currentWeekStart = isoCalendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        let daysSinceLastWeek = isoCalendar.dateComponents([.day], from: lastWeekStart, to: currentWeekStart).day ?? Int.max
        let isCurrentWeeklyActive = daysSinceLastWeek <= 7

        return WeeklyStreakStats(
            longestWeeklyStreakWeeks: longest.length,
            longestWeeklyStreakStartDate: Self.watchDateParser.string(from: longest.start),
            longestWeeklyStreakEndDate: Self.watchDateParser.string(from: longest.end),
            currentWeeklyStreakWeeks: currentWeeklyLength,
            currentWeeklyStreakStartDate: Self.watchDateParser.string(from: currentWeeklyStart),
            currentWeeklyStreakEndDate: Self.watchDateParser.string(from: lastWeekStart),
            isCurrentWeeklyStreakActive: isCurrentWeeklyActive
        )
    }

    private func computeYearReleaseStats(entries: [DatedMovieEntry], targetYear: Int) -> YearReleaseStats {
        let total = entries.count
        let fromYear = entries.filter { $0.movie.release_year == targetYear }.count
        let otherYears = max(0, total - fromYear)
        let yearPercentage = total == 0 ? 0.0 : (Double(fromYear) / Double(total)) * 100.0
        let otherPercentage = total == 0 ? 0.0 : (Double(otherYears) / Double(total)) * 100.0

        return YearReleaseStats(
            totalFilms: total,
            filmsFromYear: fromYear,
            filmsFromOtherYears: otherYears,
            yearPercentage: yearPercentage,
            otherYearsPercentage: otherPercentage
        )
    }

    private func computeTopWatchedFilms(entries: [DatedMovieEntry], limit: Int = 6) -> [TopWatchedFilm] {
        struct Aggregate {
            var title: String
            var posterUrl: String?
            var watchCount: Int
            var tmdbId: Int?
            var lastWatchedDate: String?
        }

        var grouped: [String: Aggregate] = [:]
        for entry in entries {
            let key = uniqueMovieKey(for: entry.movie)
            if var existing = grouped[key] {
                existing.watchCount += 1
                if (entry.movie.watch_date ?? "") > (existing.lastWatchedDate ?? "") {
                    existing.lastWatchedDate = entry.movie.watch_date
                    existing.posterUrl = entry.movie.poster_url ?? existing.posterUrl
                }
                grouped[key] = existing
            } else {
                grouped[key] = Aggregate(
                    title: entry.movie.title,
                    posterUrl: entry.movie.poster_url,
                    watchCount: 1,
                    tmdbId: entry.movie.tmdb_id,
                    lastWatchedDate: entry.movie.watch_date
                )
            }
        }

        return grouped.values
            .sorted { lhs, rhs in
                if lhs.watchCount == rhs.watchCount {
                    return (lhs.lastWatchedDate ?? "") > (rhs.lastWatchedDate ?? "")
                }
                return lhs.watchCount > rhs.watchCount
            }
            .prefix(limit)
            .map {
                TopWatchedFilm(
                    title: $0.title,
                    posterUrl: $0.posterUrl,
                    watchCount: $0.watchCount,
                    tmdbId: $0.tmdbId,
                    lastWatchedDate: $0.lastWatchedDate
                )
            }
    }

    private func computeMostMoviesInDay(entries: [DatedMovieEntry]) -> [MostMoviesInDayStat] {
        let grouped = Dictionary(grouping: entries, by: \.dateString)
        return grouped.map { key, value in
            MostMoviesInDayStat(watchDate: key, filmCount: value.count)
        }
        .sorted { lhs, rhs in
            if lhs.filmCount == rhs.filmCount {
                return lhs.watchDate > rhs.watchDate
            }
            return lhs.filmCount > rhs.filmCount
        }
    }

    private func computeHighestMonthlyAverage(entries: [DatedMovieEntry]) -> [HighestMonthlyAverage] {
        let ratedEntries = entries.filter { $0.movie.rating != nil }
        let grouped = Dictionary(grouping: ratedEntries) { YearMonthKey(year: $0.watchYear, month: $0.month) }

        return grouped.compactMap { key, values in
            let ratings = values.compactMap { $0.movie.rating }
            guard ratings.count >= 2 else { return nil }
            let average = ratings.reduce(0, +) / Double(ratings.count)

            return HighestMonthlyAverage(
                year: key.year,
                month: key.month,
                monthName: shortMonthLabel(for: key.month),
                averageRating: average,
                filmCount: ratings.count
            )
        }
        .sorted { lhs, rhs in
            if abs(lhs.averageRating - rhs.averageRating) < 0.0001 {
                if lhs.filmCount == rhs.filmCount {
                    if lhs.year == rhs.year {
                        return lhs.month > rhs.month
                    }
                    return lhs.year > rhs.year
                }
                return lhs.filmCount > rhs.filmCount
            }
            return lhs.averageRating > rhs.averageRating
        }
    }

    private func shortMonthLabel(for month: Int) -> String {
        let symbols = Self.shortMonthFormatter.shortMonthSymbols
            ?? ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        guard month >= 1 && month <= symbols.count else {
            return "M\(month)"
        }
        return symbols[month - 1]
    }

    private func computeAdvancedJourneyStats(entries: [DatedMovieEntry]) -> AdvancedFilmJourneyStats {
        let groupedByDate = Dictionary(grouping: entries, by: \.dateString)
        let daysWith2PlusFilms = groupedByDate.values.filter { $0.count >= 2 }.count
        let uniqueYears = Set(entries.map(\.watchYear)).count
        let averageMoviesPerYear = uniqueYears == 0 ? 0.0 : Double(entries.count) / Double(uniqueYears)

        let unique5StarFilms = Set(
            entries.filter { ($0.movie.rating ?? 0.0) >= 5.0 }.map { uniqueMovieKey(for: $0.movie) }
        ).count

        return AdvancedFilmJourneyStats(
            daysWith2PlusFilms: daysWith2PlusFilms,
            averageMoviesPerYear: averageMoviesPerYear,
            mustWatchCompletion: nil,
            unique5StarFilms: unique5StarFilms,
            mostMoviesInDay: computeMostMoviesInDay(entries: entries),
            highestMonthlyAverage: computeHighestMonthlyAverage(entries: entries)
        )
    }

    private func computeYearFilteredAdvancedJourneyStats(entries: [DatedMovieEntry]) -> YearFilteredAdvancedJourneyStats {
        let groupedByDate = Dictionary(grouping: entries, by: \.dateString)
        let daysWith2PlusFilms = groupedByDate.values.filter { $0.count >= 2 }.count
        let unique5StarFilms = Set(
            entries.filter { ($0.movie.rating ?? 0.0) >= 5.0 }.map { uniqueMovieKey(for: $0.movie) }
        ).count

        return YearFilteredAdvancedJourneyStats(
            daysWith2PlusFilms: daysWith2PlusFilms,
            mustWatchCompletion: nil,
            unique5StarFilms: unique5StarFilms,
            mostMoviesInDay: computeMostMoviesInDay(entries: entries),
            highestMonthlyAverage: computeHighestMonthlyAverage(entries: entries)
        )
    }

    private func computeAverageStarRatingsPerYear(entries: [DatedMovieEntry]) -> [AverageStarRatingPerYear] {
        let rated = entries.filter { $0.movie.rating != nil }
        let grouped = Dictionary(grouping: rated, by: \.watchYear)

        return grouped.keys.sorted().compactMap { year in
            let values = grouped[year] ?? []
            let ratings = values.compactMap(\.movie.rating)
            guard !ratings.isEmpty else { return nil }
            let average = ratings.reduce(0, +) / Double(ratings.count)
            return AverageStarRatingPerYear(year: year, averageStarRating: average, filmCount: ratings.count)
        }
    }

    private func computeAverageDetailedRatingsPerYear(entries: [DatedMovieEntry]) -> [AverageDetailedRatingPerYear] {
        let rated = entries.filter { $0.movie.detailed_rating != nil }
        let grouped = Dictionary(grouping: rated, by: \.watchYear)

        return grouped.keys.sorted().compactMap { year in
            let values = grouped[year] ?? []
            let ratings = values.compactMap(\.movie.detailed_rating)
            guard !ratings.isEmpty else { return nil }
            let average = ratings.reduce(0, +) / Double(ratings.count)
            return AverageDetailedRatingPerYear(year: year, averageDetailedRating: average, filmCount: ratings.count)
        }
    }

    private func computeLocationStatistics(entries: [DatedMovieEntry]) async throws -> (
        mapPoints: [LocationMapPoint],
        specificCounts: [LocationCountRow],
        groupCounts: [LocationCountRow]
    ) {
        let locationIds = entries.compactMap(\.movie.location_id)
        guard !locationIds.isEmpty else {
            return ([], [], [])
        }

        var countByLocationId: [Int: Int] = [:]
        for locationId in locationIds {
            countByLocationId[locationId, default: 0] += 1
        }

        let uniqueIds = Array(Set(locationIds))
        let selectColumns = "id,user_id,display_name,formatted_address,normalized_key,latitude,longitude,city,admin_area,country,postal_code,location_group_id,location_groups(name),created_at,updated_at"
        let response = try await movieService.client
            .from("locations")
            .select(selectColumns)
            .in("id", values: uniqueIds)
            .execute()

        let locations: [MovieLocation]
        if response.data.isEmpty {
            locations = []
        } else {
            locations = try JSONDecoder().decode([MovieLocation].self, from: response.data)
        }

        let locationsById = Dictionary(uniqueKeysWithValues: locations.map { ($0.id, $0) })

        let specificCounts = countByLocationId.map { locationId, count in
            let label = locationsById[locationId]?.display_name ?? "Location \(locationId)"
            return LocationCountRow(label: label, entry_count: count)
        }
        .sorted {
            if $0.entry_count == $1.entry_count {
                return $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending
            }
            return $0.entry_count > $1.entry_count
        }

        var groupedCountsMap: [String: Int] = [:]
        for (locationId, count) in countByLocationId {
            let location = locationsById[locationId]
            let groupName = location?.location_group_name?.trimmingCharacters(in: .whitespacesAndNewlines)
            let label = (groupName?.isEmpty == false) ? groupName! : "Ungrouped"
            groupedCountsMap[label, default: 0] += count
        }

        let groupedCounts = groupedCountsMap.map { label, count in
            LocationCountRow(label: label, entry_count: count)
        }
        .sorted {
            if $0.entry_count == $1.entry_count {
                return $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending
            }
            return $0.entry_count > $1.entry_count
        }

        let mapPoints = locations.compactMap { location -> LocationMapPoint? in
            guard
                let count = countByLocationId[location.id],
                let latitude = location.latitude,
                let longitude = location.longitude
            else {
                return nil
            }

            return LocationMapPoint(
                location_id: location.id,
                location_name: location.display_name,
                latitude: latitude,
                longitude: longitude,
                entry_count: count
            )
        }
        .sorted { $0.entry_count > $1.entry_count }

        return (mapPoints, specificCounts, groupedCounts)
    }
}

// MARK: - Time Since First Film Section

struct TimeSinceFirstFilmSection: View {
    @Environment(\.colorScheme) private var colorScheme
    let watchSpan: WatchSpan?
    let runtimeStats: RuntimeStats?
    
    // Calculate years, months, days since first film
    private var timeSinceFirstFilm: (years: Int, months: Int, days: Int) {
        guard let firstWatch = watchSpan?.firstWatch else {
            return (0, 0, 0)
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        guard let firstDate = formatter.date(from: firstWatch) else {
            return (0, 0, 0)
        }
        
        let now = Date()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: firstDate, to: now)
        
        return (
            years: components.year ?? 0,
            months: components.month ?? 0,
            days: components.day ?? 0
        )
    }
    
    private var timeText: String {
        let time = timeSinceFirstFilm
        var parts: [String] = []
        
        if time.years > 0 {
            parts.append("\(time.years) \(time.years == 1 ? "year" : "years")")
        }
        if time.months > 0 {
            parts.append("\(time.months) \(time.months == 1 ? "month" : "months")")
        }
        if time.days > 0 && time.years == 0 {  // Only show days if less than a year
            parts.append("\(time.days) \(time.days == 1 ? "day" : "days")")
        }
        
        if parts.isEmpty {
            return "Just started"
        }
        
        return parts.joined(separator: ", ") + " since first film logged"
    }
    
    private var totalHours: Int {
        (runtimeStats?.totalRuntime ?? 0) / 60
    }
    
    private var averageHours: Double {
        (runtimeStats?.averageRuntime ?? 0) / 60.0
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "clock")
                    .foregroundColor(.purple)
                    .font(.title3)
                Text("Total Runtime")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(Color.adaptiveText(scheme: colorScheme))
                Spacer()
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(totalHours.formatted(.number.grouping(.automatic)))")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.purple)
                    Text("Total Hours")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(String(format: "%.1f", averageHours))
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.purple)
                    Text("Avg per Film")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            
            // Enhanced Progress bar with glow
            RoundedRectangle(cornerRadius: 6)
                .fill(LinearGradient(
                    gradient: Gradient(colors: [.purple, .blue]),
                    startPoint: .leading,
                    endPoint: .trailing
                ))
                .frame(height: 8)
                .shadow(color: .purple.opacity(0.4), radius: 4, x: 0, y: 2)
            
            // Time since first film text
            HStack {
                Text(timeText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.purple.opacity(0.05),
                            Color.blue.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
 
        )

    }
}

// MARK: - Film Journey Section

struct FilmJourneySection: View {
    @Environment(\.colorScheme) private var colorScheme
    let dashboardStats: DashboardStats?
    let uniqueFilmsCount: Int
    let averageRatingResolved: Double?
    let watchSpan: WatchSpan?
    let selectedYear: Int?
    let filmsPerMonth: [FilmsPerMonth]
    let advancedJourneyStats: AdvancedFilmJourneyStats?
    let yearFilteredAdvancedStats: YearFilteredAdvancedJourneyStats?
    
    enum ExpandedStatType: Identifiable {
        case mostInDay
        case bestMonth
        case mostActiveMonth
        
        var id: String {
            switch self {
            case .mostInDay: return "mostInDay"
            case .bestMonth: return "bestMonth"
            case .mostActiveMonth: return "mostActiveMonth"
            }
        }
    }
    
    @State private var expandedStatType: ExpandedStatType?
    
    // Derived text for the small subtitle under the header
    private var watchSpanText: String {
        if let first = watchSpan?.firstWatch, let last = watchSpan?.lastWatch {
            let fYear = String(first.prefix(4))
            let lYear = String(last.prefix(4))
            return fYear == lYear ? "Spanning \(fYear)" : "Spanning \(fYear)–\(lYear)"
        }
        return "Spanning Unknown"
    }
    
    // Calculate average films per month for the selected year
    private var averageFilmsPerMonth: Double {
        guard !filmsPerMonth.isEmpty else { return 0.0 }
        let totalFilms = filmsPerMonth.reduce(0) { $0 + $1.filmCount }
        return Double(totalFilms) / Double(filmsPerMonth.count)
    }
    
    private func formatShortDate(_ dateString: String) -> String {
        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd"
        
        let formatter = DateFormatter()
        if selectedYear == nil {
            formatter.dateFormat = "MMM d, yyyy"
        } else {
            formatter.dateFormat = "MMM d"
        }
        
        if let date = parser.date(from: dateString) {
            return formatter.string(from: date)
        }
        
        return dateString
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.title2)
                        .gradientForeground([
                            .purple,
                            .blue
                        ], start: .topLeading, end: .bottomTrailing)
                    Text("Your Film Journey")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(Color.adaptiveText(scheme: colorScheme))
                }
                HStack(spacing: 4) {
                    Text(watchSpanText)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    if selectedYear != nil {
                        Text("•")
                            .font(.subheadline)
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("Filtered")
                            .font(.subheadline)
                            .foregroundColor(.blue.opacity(0.8))
                    }
                }
            }
            .padding(.horizontal, 16)
            
            // Stats Cards Grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                // 1. Total Films
                StatCard(
                    title: "Total Films",
                    value: "\(dashboardStats?.totalFilms ?? 0)",
                    icon: "film",
                    color: .blue
                )
                
                // 2. Unique Films
                StatCard(
                    title: "Unique Films",
                    value: "\(uniqueFilmsCount)",
                    icon: "sparkles",
                    color: .green
                )
                
                // 3. Films This Year / Avg Films/Month
                StatCard(
                    title: selectedYear != nil ? "Avg Films/Month" : "Films This Year",
                    value: selectedYear != nil ? String(format: "%.2f", averageFilmsPerMonth) : "\(dashboardStats?.filmsThisYear ?? 0)",
                    icon: selectedYear != nil ? "calendar.badge.clock" : "calendar",
                    color: .purple
                )
                
                // 4. Avg/Year (Only for All-Time)
                if selectedYear == nil {
                    if let advancedStats = advancedJourneyStats {
                        UniformStatCard(
                            title: "Avg/Year",
                            value: String(format: "%.1f", advancedStats.averageMoviesPerYear),
                            subtitle: nil,
                            icon: "chart.line.uptrend.xyaxis",
                            color: .green
                        )
                    }
                }
                
                // 5. Average Rating
                StatCard(
                    title: "Average Rating",
                    value: String(format: "%.2f", averageRatingResolved ?? dashboardStats?.averageRating ?? 0.0),
                    icon: "star.fill",
                    color: .yellow
                )
                
                // 6. 2+ Film Days
                if selectedYear == nil {
                    if let advancedStats = advancedJourneyStats {
                        UniformStatCard(
                            title: "2+ Film Days",
                            value: "\(advancedStats.daysWith2PlusFilms)",
                            subtitle: nil,
                            icon: "calendar.badge.plus",
                            color: .orange
                        )
                    }
                } else {
                    if let yearStats = yearFilteredAdvancedStats {
                        UniformStatCard(
                            title: "2+ Film Days",
                            value: "\(yearStats.daysWith2PlusFilms)",
                            subtitle: nil,
                            icon: "calendar.badge.plus",
                            color: .orange
                        )
                    }
                }
                
                // 7. Most in a Day
                Button {
                    expandedStatType = .mostInDay
                } label: {
                    if selectedYear == nil {
                        if let advancedStats = advancedJourneyStats, let mostInDayList = advancedStats.mostMoviesInDay, let mostInDay = mostInDayList.first {
                            UniformStatCard(
                                title: "Most in a Day",
                                value: "\(mostInDay.filmCount)",
                                subtitle: formatShortDate(mostInDay.watchDate),
                                icon: "calendar.badge.clock",
                                color: .mint
                            )
                        } else {
                            UniformStatCard(
                                title: "Most in a Day",
                                value: "N/A",
                                subtitle: nil,
                                icon: "calendar.badge.clock",
                                color: .mint
                            )
                        }
                    } else {
                        if let yearStats = yearFilteredAdvancedStats, let mostInDayList = yearStats.mostMoviesInDay, let mostInDay = mostInDayList.first {
                            UniformStatCard(
                                title: "Most in a Day",
                                value: "\(mostInDay.filmCount)",
                                subtitle: formatShortDate(mostInDay.watchDate),
                                icon: "calendar.badge.clock",
                                color: .mint
                            )
                        } else {
                            UniformStatCard(
                                title: "Most in a Day",
                                value: "N/A",
                                subtitle: nil,
                                icon: "calendar.badge.clock",
                                color: .mint
                            )
                        }
                    }
                }
                .buttonStyle(.plain)
                
                // 8. Best Month
                Button {
                    expandedStatType = .bestMonth
                } label: {
                    if selectedYear == nil {
                        if let advancedStats = advancedJourneyStats, let highestMonthList = advancedStats.highestMonthlyAverage, let highestMonth = highestMonthList.first {
                            UniformStatCard(
                                title: "Best Month",
                                value: String(format: "%.2f", highestMonth.averageRating),
                                subtitle: "\(highestMonth.monthName.trimmingCharacters(in: .whitespacesAndNewlines)) \(String(highestMonth.year))",
                                icon: "trophy.fill",
                                color: .purple
                            )
                        } else {
                            UniformStatCard(
                                title: "Best Month",
                                value: "N/A",
                                subtitle: nil,
                                icon: "trophy.fill",
                                color: .purple
                            )
                        }
                    } else {
                        if let yearStats = yearFilteredAdvancedStats, let highestMonthList = yearStats.highestMonthlyAverage, let highestMonth = highestMonthList.first {
                            UniformStatCard(
                                title: "Best Month",
                                value: String(format: "%.2f", highestMonth.averageRating),
                                subtitle: highestMonth.monthName.trimmingCharacters(in: .whitespacesAndNewlines),
                                icon: "trophy.fill",
                                color: .purple
                            )
                        } else {
                            UniformStatCard(
                                title: "Best Month",
                                value: "N/A",
                                subtitle: "Insuff. data",
                                icon: "trophy.fill",
                                color: .purple
                            )
                        }
                    }
                }
                .buttonStyle(.plain)
                
                // 9. Most Films
                Button {
                    expandedStatType = .mostActiveMonth
                } label: {
                    let sortedMonths = filmsPerMonth.sorted { $0.filmCount > $1.filmCount }
                    if let activeMonth = sortedMonths.first, activeMonth.filmCount > 0 {
                        UniformStatCard(
                            title: "Most Films",
                            value: "\(activeMonth.filmCount)",
                            subtitle: selectedYear == nil ? "\(activeMonth.monthName.trimmingCharacters(in: .whitespacesAndNewlines)) '\(String(activeMonth.year).suffix(2))" : activeMonth.monthName.trimmingCharacters(in: .whitespacesAndNewlines),
                            icon: "chart.bar.fill",
                            color: .mint
                        )
                    } else {
                        UniformStatCard(
                            title: "Most Films",
                            value: "N/A",
                            subtitle: "Insuff. data",
                            icon: "chart.bar.fill",
                            color: .mint
                        )
                    }
                }
                .buttonStyle(.plain)
                

                
                // 10. Must Watches
                if selectedYear == nil {
                    /* All-time must watches logic commented out to save space
                    if let advancedStats = advancedJourneyStats, let mustWatch = advancedStats.mustWatchCompletion {
                        UniformStatCard(
                            title: "Must Watches",
                            value: "\(Int(mustWatch.completionPercentage.rounded()))%",
                            subtitle: "\(mustWatch.watchedFilms)/\(mustWatch.totalFilms)",
                            icon: "checklist",
                            color: .blue
                        )
                    } else {
                        UniformStatCard(
                            title: "Must Watches",
                            value: "N/A",
                            subtitle: "No lists found",
                            icon: "checklist",
                            color: .blue
                        )
                    }
                    */
                } else {
                    if let yearStats = yearFilteredAdvancedStats, let mustWatch = yearStats.mustWatchCompletion {
                        UniformStatCard(
                            title: "Must Watches",
                            value: "\(Int(mustWatch.completionPercentage))%",
                            subtitle: "\(mustWatch.watchedFilms)/\(mustWatch.totalFilms)",
                            icon: "checklist",
                            color: .blue
                        )
                    } else {
                        UniformStatCard(
                            title: "Must Watches",
                            value: "N/A",
                            subtitle: "No list found",
                            icon: "checklist",
                            color: .blue
                        )
                    }
                }
                
                /*
                // 5-Star Films - Commented out as requested
                if selectedYear == nil {
                    if let advancedStats = advancedJourneyStats {
                        UniformStatCard(
                            title: "5-Star Films",
                            value: "\(advancedStats.unique5StarFilms)",
                            subtitle: nil,
                            icon: "star.fill",
                            color: .yellow
                        )
                    }
                } else {
                    if let yearStats = yearFilteredAdvancedStats {
                        UniformStatCard(
                            title: "New 5-Stars",
                            value: "\(yearStats.unique5StarFilms)",
                            subtitle: nil,
                            icon: "star.fill",
                            color: .yellow
                        )
                    }
                }
                */
            }
            .padding(.horizontal, 16)
            
            // bottom runtime widget intentionally removed; top header remains
        }
        .padding(.vertical, 8)
        .sheet(item: $expandedStatType) { type in
            TopEntriesListView(
                expandedStatType: $expandedStatType,
                type: type,
                selectedYear: selectedYear,
                advancedJourneyStats: advancedJourneyStats,
                yearFilteredAdvancedStats: yearFilteredAdvancedStats,
                filmsPerMonth: filmsPerMonth
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - Stat Card

struct StatCard: View {
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    let value: String
    let icon: String
    let color: Color

    private var borderGradient: [Color] {
        switch color {
        case .blue:   return [Color.blue, Color.cyan]
        case .green:  return [Color.green, Color.mint]
        case .yellow: return [Color.yellow, Color.orange]
        case .purple: return [Color.purple, Color.pink]
        default:      return [color, color.opacity(0.8)]
        }
    }
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(
                    LinearGradient(
                        colors: borderGradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .font(.title3)
            
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: borderGradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.gray.opacity(0.15))
        )
    }
}

// MARK: - Streak Components

struct StreakDetailCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let streakStats: StreakStats?
    let streakType: StreakType
    
    enum StreakType {
        case longest
        case current
        
        var icon: String {
            switch self {
            case .longest:
                return "trophy.fill"
            case .current:
                return "flame.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .longest:
                return .orange
            case .current:
                return .red
            }
        }
    }
    
    private var days: Int {
        switch streakType {
        case .longest:
            return streakStats?.longestStreak ?? 0
        case .current:
            return streakStats?.currentStreak ?? 0
        }
    }
    
    private var startDate: String {
        switch streakType {
        case .longest:
            return streakStats?.longestStart ?? ""
        case .current:
            return streakStats?.currentStart ?? ""
        }
    }
    
    private var endDate: String {
        switch streakType {
        case .longest:
            return streakStats?.longestEnd ?? ""
        case .current:
            return streakStats?.currentEnd ?? ""
        }
    }
    
    private var startFilmTitle: String? {
        switch streakType {
        case .longest:
            return streakStats?.longestStreakStartTitle
        case .current:
            return streakStats?.currentStreakStartTitle
        }
    }
    
    private var startFilmPoster: String? {
        switch streakType {
        case .longest:
            return streakStats?.longestStreakStartPoster
        case .current:
            return streakStats?.currentStreakStartPoster
        }
    }
    
    private var endFilmTitle: String? {
        switch streakType {
        case .longest:
            return streakStats?.longestStreakEndTitle
        case .current:
            return streakStats?.currentStreakEndTitle
        }
    }
    
    private var endFilmPoster: String? {
        switch streakType {
        case .longest:
            return streakStats?.longestStreakEndPoster
        case .current:
            return streakStats?.currentStreakEndPoster
        }
    }
    
    private var isActive: Bool {
        return streakStats?.isActive ?? false
    }
    
    private var effectiveColor: Color {
        if streakType == .current && !isActive {
            return .gray
        }
        return streakType.color
    }
    
    private var borderGradient: [Color] {
        let baseColor = effectiveColor
        switch streakType {
        case .longest:
            return [baseColor, .yellow]
        case .current:
            if isActive {
                return [baseColor, .pink]
            } else {
                return [.gray, .gray.opacity(0.5)]
            }
        }
    }
    
    private func formatDate(_ dateString: String) -> String {
        guard !dateString.isEmpty else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: dateString) {
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
        return dateString
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Header with icon and main stats
            VStack(spacing: 12) {
                HStack {
                    Spacer()
                    ZStack {
                        Image(systemName: streakType.icon)
                            .foregroundColor(effectiveColor)
                            .font(.title2)
                        
                        // Add sparkle effect for active current streaks
                        if streakType == .current && isActive && days > 0 {
                            Image(systemName: "sparkles")
                                .foregroundColor(.yellow)
                                .font(.caption)
                                .offset(x: 12, y: -8)
                        }
                    }
                    Spacer()
                }
                
                VStack(spacing: 4) {
                    Text("\(days)")
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .gradientForeground([
                            effectiveColor.opacity(0.95),
                            .white.opacity(0.1)
                        ], start: .leading, end: .trailing)
                    
                    Text(days == 1 ? "day" : "days")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(Color.adaptiveText(scheme: colorScheme))
                
                // Status line
                Text(streakType == .current ?
                     (isActive ? "🔥 Active" : "💤 Inactive") :
                     "🏆 Personal Record")
                    .font(.caption)
                    .foregroundColor(streakType == .current ?
                                   (isActive ? .orange : .gray) :
                                   .yellow)
            }
            
            // Date range
            if !startDate.isEmpty && !endDate.isEmpty && days > 0 {
                VStack(spacing: 6) {
                    Text("Duration")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fontWeight(.medium)
                    
                    HStack {
                        Text(formatDate(startDate))
                        Image(systemName: "arrow.right")
                            .font(.caption2)
                        Text(formatDate(endDate))
                    }
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(effectiveColor.opacity(0.1))
                )
            }
            
            // Film bookends
            if days > 0 && (startFilmTitle != nil || endFilmTitle != nil) {
                VStack(spacing: 8) {
                    Text("Films")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fontWeight(.medium)
                    
                    HStack(spacing: 12) {
                        // Start film
                        if let startTitle = startFilmTitle {
                            VStack(spacing: 4) {
                                AsyncImage(url: URL(string: startFilmPoster ?? "")) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(.gray.opacity(0.3))
                                        .overlay(
                                            Image(systemName: "film")
                                                .foregroundColor(.gray)
                                                .font(.caption)
                                        )
                                }
                                .frame(width: 30, height: 45)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                
                                Text(startTitle)
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.8))
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                                    .frame(width: 50)
                            }
                        }
                        
                        Spacer()
                        
                        // Arrow for streaks longer than 1 day
                        if days > 1 {
                            Image(systemName: "arrow.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        // End film (only show if different from start)
                        if let endTitle = endFilmTitle, days > 1 {
                            VStack(spacing: 4) {
                                AsyncImage(url: URL(string: endFilmPoster ?? "")) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(.gray.opacity(0.3))
                                        .overlay(
                                            Image(systemName: "film")
                                                .foregroundColor(.gray)
                                                .font(.caption)
                                        )
                                }
                                .frame(width: 30, height: 45)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                
                                Text(endTitle)
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.8))
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                                    .frame(width: 50)
                            }
                        }
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.black.opacity(0.2))
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.adaptiveCardBackground(scheme: colorScheme))
        )

        .shadow(
            color: effectiveColor.opacity(0.1),
            radius: 8,
            x: 0,
            y: 4
        )
    }
}

// MARK: - Combined Streaks Section

struct CombinedStreaksSection: View {
    @Environment(\.colorScheme) private var colorScheme
    let streakStats: StreakStats?
    let weeklyStreakStats: WeeklyStreakStats?
    let selectedYear: Int?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "flame.fill")
                        .font(.title2)
                        .gradientForeground([
                            .red,
                            .orange
                        ], start: .topLeading, end: .bottomTrailing)
                    Text("Watch Streaks")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(Color.adaptiveText(scheme: colorScheme))
                }
                Text("Consecutive days and weeks with logged films")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            
            // Headers for columns
            HStack {
                Text("Current")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                    .padding(.leading, 8)
                Spacer()
                Text("Longest")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                    .padding(.trailing, 8)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, -4)
            
            // Streak Cards Grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                if selectedYear == nil {
                    UniformStatCard(
                        title: formatStreakDateRange(start: streakStats?.currentStart, end: streakStats?.currentEnd),
                        value: "\(streakStats?.currentStreak ?? 0) days",
                        subtitle: nil,
                        icon: "flame.fill",
                        color: .orange
                    )
                }
                UniformStatCard(
                    title: formatStreakDateRange(start: streakStats?.longestStart, end: streakStats?.longestEnd),
                    value: "\(streakStats?.longestStreak ?? 0) days",
                    subtitle: nil,
                    icon: "trophy.fill",
                    color: .red
                )
                if selectedYear == nil {
                    UniformStatCard(
                        title: formatStreakDateRange(start: weeklyStreakStats?.currentStartDate, end: weeklyStreakStats?.currentEndDate),
                        value: "\(weeklyStreakStats?.currentStreak ?? 0) weeks",
                        subtitle: nil,
                        icon: "calendar.badge.clock",
                        color: .blue
                    )
                }
                UniformStatCard(
                    title: formatStreakDateRange(start: weeklyStreakStats?.longestStartDate, end: weeklyStreakStats?.longestEndDate),
                    value: "\(weeklyStreakStats?.longestStreak ?? 0) weeks",
                    subtitle: nil,
                    icon: "calendar.badge.checkmark",
                    color: .cyan
                )
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 8)
    }
    
    private func formatStreakDateRange(start: String?, end: String?) -> String {
        guard let startStr = start, !startStr.isEmpty, let endStr = end, !endStr.isEmpty else {
            return "No Streak"
        }
        
        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd"
        
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d/yy"
        
        if let startDate = parser.date(from: startStr), let endDate = parser.date(from: endStr) {
            return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
        }
        
        return "N/A"
    }
}

// MARK: - Total Runtime Section

struct TotalRuntimeSection: View {
    @Environment(\.colorScheme) private var colorScheme
    let runtimeStats: RuntimeStats
    
    var totalHours: Int {
        (runtimeStats.totalRuntime ?? 0) / 60
    }
    
    var averageHours: Double {
        (runtimeStats.averageRuntime ?? 0) / 60.0
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "clock")
                    .foregroundColor(.purple)
                    .font(.title3)
                Text("Total Runtime")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(Color.adaptiveText(scheme: colorScheme))
                Spacer()
            }
            
            HStack(spacing: 40) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(totalHours.formatted(.number.grouping(.automatic)))")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.purple)
                    Text("Total Hours")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(format: "%.1f", averageHours))
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.purple)
                    Text("Avg per Film")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
            }
            
            // Enhanced Progress bar with glow
            RoundedRectangle(cornerRadius: 6)
                .fill(LinearGradient(
                    gradient: Gradient(colors: [.purple, .blue]),
                    startPoint: .leading,
                    endPoint: .trailing
                ))
                .frame(height: 8)
                .shadow(color: .purple.opacity(0.4), radius: 4, x: 0, y: 2)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.purple.opacity(0.05),
                            Color.blue.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
 
        )

    }
}

// MARK: - Rewatch Pie Chart

struct RewatchPieChart: View {
    @Environment(\.colorScheme) private var colorScheme
    let rewatchStats: RewatchStats
    @State private var selectedSlice: String?
    @State private var chartProxy: ChartProxy?
    @State private var animationProgress: Double = 0
    @State private var showTooltip = false
    @State private var tooltipText = ""
    @State private var longPressLocation: CGPoint = .zero
    
    private struct PieSlice: Identifiable {
        let id = UUID()
        let label: String
        let value: Int
        let color: Color
        let startAngle: Angle
        let endAngle: Angle
    }
    
    private var pieData: [PieSlice] {
        let rewatchCount = rewatchStats.totalRewatches
        let nonRewatchCount = rewatchStats.nonRewatches
        let totalFilms = rewatchStats.totalFilms
        
        
        // If we have no data at all, show a placeholder
        if totalFilms == 0 {
            return [
                PieSlice(
                    label: "No Data",
                    value: 1,
                    color: .gray,
                    startAngle: .degrees(0),
                    endAngle: .degrees(360)
                )
            ]
        }
        
        // Calculate angles based on the actual counts
        let total = max(rewatchCount + nonRewatchCount, 1)
        let nonRewatchAngle = Double(nonRewatchCount) / Double(total) * 360
        
        return [
            PieSlice(
                label: "Non-Rewatches",
                value: nonRewatchCount,
                color: .blue,
                startAngle: .degrees(0),
                endAngle: .degrees(nonRewatchAngle)
            ),
            PieSlice(
                label: "Rewatches",
                value: rewatchCount,
                color: .orange,
                startAngle: .degrees(nonRewatchAngle),
                endAngle: .degrees(360)
            )
        ]
    }
    
    private var totalFilms: Int {
        return max(rewatchStats.totalFilms, 1) // Ensure minimum of 1 to avoid division by zero
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            pieChartHeader
            
            // Pie Chart Container
            pieChartContainer
                .frame(height: 240)
                .frame(maxWidth: .infinity)
            
            // Legend
            legendView
                .padding(.horizontal, 12)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.orange.opacity(0.05),
                            Color.blue.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )

        .onAppear {
            withAnimation(.easeOut(duration: 1.0)) {
                animationProgress = 1.0
            }
        }
    }
    
    // MARK: - Subviews
    
    private var pieChartHeader: some View {
        HStack {
            Image(systemName: "arrow.triangle.2.circlepath")
                .foregroundColor(.orange)
                .font(.title2)
            Text("Rewatches")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(Color.adaptiveText(scheme: colorScheme))
            Spacer()
            Text("\(totalFilms) total")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
    }
    
    private var pieChartContainer: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(Color.white.opacity(0.02))
                .frame(width: 240, height: 240)
            
            // Pie Chart
            pieChart
                .frame(width: 220, height: 220)
            
            // Tooltip overlay
            tooltipOverlay
            
            // Center text
            centerTextView
        }
    }
    
    private var pieChart: some View {
        Chart(pieData) { slice in
            SectorMark(
                angle: .value("Count", slice.value),
                innerRadius: .ratio(0.5),
                angularInset: 1.5
            )
            .foregroundStyle(sliceGradient(for: slice))
            .cornerRadius(4)
            .opacity(selectedSlice == nil || selectedSlice == slice.label ? 1.0 : 0.5)
        }
        .chartAngleSelection(value: .constant(nil as Double?))
        .chartBackground { proxy in
            chartBackgroundView(proxy: proxy)
        }
        .animation(.easeInOut(duration: 0.3), value: selectedSlice)
    }
    
    private func sliceGradient(for slice: PieSlice) -> LinearGradient {
        let colors = slice.label == "Rewatches"
            ? [slice.color, slice.color.opacity(0.8)]
            : [slice.color.opacity(0.9), slice.color]
        
        return LinearGradient(
            colors: colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private func chartBackgroundView(proxy: ChartProxy) -> some View {
        GeometryReader { geometry in
            Rectangle()
                .fill(Color.clear)
                .contentShape(Rectangle())
                .onTapGesture { location in
                    handlePieTap(at: location, in: geometry)
                }
                .gesture(longPressGesture(in: geometry))
                .onAppear {
                    chartProxy = proxy
                }
        }
    }
    
    private func longPressGesture(in geometry: GeometryProxy) -> some Gesture {
        LongPressGesture(minimumDuration: 0.5)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .onChanged { value in
                switch value {
                case .first(true):
                    handleLongPressStart(at: longPressLocation, in: geometry)
                case .second(true, let drag):
                    if let drag = drag {
                        longPressLocation = drag.location
                        handleLongPressStart(at: drag.location, in: geometry)
                    }
                default:
                    break
                }
            }
            .onEnded { _ in
                showTooltip = false
            }
    }
    
    @ViewBuilder
    private var tooltipOverlay: some View {
        if showTooltip && !tooltipText.isEmpty {
            VStack(spacing: 4) {
                Text(tooltipText)
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(tooltipBackground)
                    .shadow(color: .orange.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .position(x: longPressLocation.x, y: max(40, longPressLocation.y - 60))
            .allowsHitTesting(false)
            .animation(.easeInOut(duration: 0.2), value: longPressLocation)
        }
    }
    
    private var tooltipBackground: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.black.opacity(0.9))

    }
    
    @ViewBuilder
    private var centerTextView: some View {
        VStack(spacing: 4) {
            if let selected = selectedSlice,
               let slice = pieData.first(where: { $0.label == selected }) {
                selectedSliceText(slice: slice)
            } else if totalFilms > 0 {
                defaultCenterText
            } else {
                Text("No Data")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func selectedSliceText(slice: PieSlice) -> some View {
        Group {
            Text(slice.label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text("\(slice.value)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(slice.color)
            Text("\(Int((Double(slice.value) / Double(totalFilms)) * 100))%")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var defaultCenterText: some View {
        let rewatchPercentage = Int(rewatchStats.rewatchPercentage ?? 0.0)
        
        return Group {
            Text("Rewatches")
                .font(.caption)
                .foregroundColor(.secondary)
            Text("\(rewatchPercentage)%")
                .font(.title)
                .fontWeight(.bold)
                .gradientForeground([.orange, .red], start: .top, end: .bottom)
            Text("of total")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    private var legendView: some View {
        HStack(spacing: 32) {
            Spacer()
            legendItem(
                label: "Non-Rewatches",
                count: rewatchStats.nonRewatches,
                colors: [.blue.opacity(0.9), .blue]
            )
            legendItem(
                label: "Rewatches",
                count: rewatchStats.totalRewatches,
                colors: [.orange, .orange.opacity(0.8)]
            )
            Spacer()
        }
    }
    
    private func legendItem(label: String, count: Int, colors: [Color]) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(LinearGradient(
                    colors: colors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 12, height: 12)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.primary)
                Text("\(count) films")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    
    private func handlePieTap(at location: CGPoint, in geometry: GeometryProxy) {
        let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
        let dx = location.x - center.x
        let dy = location.y - center.y
        let distance = sqrt(dx * dx + dy * dy)
        
        // Check if tap is within the pie chart radius
        guard distance <= 110 && distance >= 55 else { // 55 is inner radius (110 * 0.5)
            selectedSlice = nil
            return
        }
        
        // Calculate angle from center
        var angle = atan2(dy, dx) * 180 / .pi
        angle = angle < 0 ? angle + 360 : angle
        // Adjust for chart starting at top (rotate by 90 degrees)
        angle = angle + 90
        if angle >= 360 { angle -= 360 }
        
        // Determine which slice was tapped
        for slice in pieData {
            let startDegrees = slice.startAngle.degrees
            let endDegrees = slice.endAngle.degrees
            
            if angle >= startDegrees && angle < endDegrees {
                selectedSlice = selectedSlice == slice.label ? nil : slice.label
                return
            }
        }
        
        selectedSlice = nil
    }
    
    private func handleLongPressStart(at location: CGPoint, in geometry: GeometryProxy) {
        let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
        let dx = location.x - center.x
        let dy = location.y - center.y
        let distance = sqrt(dx * dx + dy * dy)
        
        // Check if tap is within the pie chart radius
        guard distance <= 110 && distance >= 55 else {
            showTooltip = false
            return
        }
        
        // Calculate angle from center
        var angle = atan2(dy, dx) * 180 / .pi
        angle = angle < 0 ? angle + 360 : angle
        // Adjust for chart starting at top (rotate by 90 degrees)
        angle = angle + 90
        if angle >= 360 { angle -= 360 }
        
        // Determine which slice was pressed and show tooltip
        for slice in pieData {
            let startDegrees = slice.startAngle.degrees
            let endDegrees = slice.endAngle.degrees
            
            if angle >= startDegrees && angle < endDegrees {
                let percentage = Int((Double(slice.value) / Double(totalFilms)) * 100)
                tooltipText = "\(slice.label): \(slice.value) films (\(percentage)%)"
                showTooltip = true
                longPressLocation = location
                
                return
            }
        }
        
        showTooltip = false
    }
}

// MARK: - Rating Distribution Chart

struct RatingDistributionChart: View {
    @Environment(\.colorScheme) private var colorScheme
    let distribution: [RatingDistribution]
    @State private var selectedRating: Double?

    private var totalFilms: Int {
        distribution.reduce(0) { $0 + $1.count }
    }
    
    private var maxCount: Int {
        distribution.map { $0.count }.max() ?? 0
    }

    // Create a complete range from 0.5 to 5.0 in 0.5 increments
    private var completeDistribution: [RatingDistribution] {
        let ratings: [Double] = stride(from: 0.5, through: 5.0, by: 0.5).map { Double($0) }
        return ratings.map { rating in
            let existing = distribution.first { abs($0.ratingValue - rating) < 0.0001 }
            if let foundRating = existing {
                return foundRating
            } else {
                return RatingDistribution(ratingValue: rating, countFilms: 0, percentage: 0.0)
            }
        }
    }

    private var selectedItem: RatingDistribution? {
        guard let rating = snappedSelectedRating else { return nil }
        return completeDistribution.first { abs($0.ratingValue - rating) < 0.001 }
    }

    private var snappedSelectedRating: Double? {
        guard let rating = selectedRating else { return nil }
        return (rating * 2).rounded() / 2
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.bar")
                    .foregroundColor(.blue)
                Text("Rating Distribution")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(Color.adaptiveText(scheme: colorScheme))
                Spacer()
                Text("\(totalFilms) films")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)

            Chart(completeDistribution, id: \.ratingValue) { item in
                BarMark(
                    x: .value("Rating", item.ratingValue),
                    y: .value("Count", item.count)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .cyan],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .cornerRadius(4)
                .opacity(snappedSelectedRating == item.ratingValue ? 0.7 : 1.0)

                // Add visual indicator on selected bar
                if let selectedRating = snappedSelectedRating, abs(item.ratingValue - selectedRating) < 0.001 {
                    RuleMark(x: .value("Selected", item.ratingValue))
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .foregroundStyle(.blue.opacity(0.5))
                        .annotation(position: .top, spacing: 1) {
                            Text("\(item.count)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                        }
                }
            }
            .frame(height: 200)
            .chartXAxis {
                AxisMarks(values: stride(from: 0.5, through: 5.0, by: 0.5).map { $0 }) { value in
                    AxisValueLabel {
                        if let rating = value.as(Double.self) {
                            VStack(spacing: 2) {
                                Text(String(format: "%.1f", rating))
                                    .font(.system(size: 10, weight: .medium, design: .rounded))
                                    .foregroundColor(.primary)
                                Image(systemName: "star.fill")
                                    .font(.system(size: 8))
                                    .foregroundColor(.yellow)
                            }
                            .offset(x: -12)
                        }
                    }
                }
            }
            .chartXScale(domain: 0.0...5.5)
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                        .foregroundStyle(.gray.opacity(0.2))
                    AxisValueLabel()
                        .font(.system(size: 10, design: .rounded))
                }
            }
            .chartYScale(domain: 0...(maxCount + 50))
            .chartXSelection(value: $selectedRating)
            .padding(.horizontal, 12)

            // Highest rating indicator
            if let highestRating = completeDistribution.max(by: { $0.count < $1.count }) {
                HStack {
                    Spacer()
                    Text("\(String(format: "%.1f", highestRating.ratingValue))★ - \(highestRating.count) films")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(
                                    LinearGradient(
                                        colors: [.blue.opacity(0.8), .cyan.opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                    Spacer()
                }
                .padding(.horizontal, 12)
            }

        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.cyan.opacity(0.05),
                            Color.blue.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )

    }
}

// MARK: - Films by Decade Chart

struct FilmsByDecadeChart: View {
    @Environment(\.colorScheme) private var colorScheme
    let filmsByDecade: [FilmsByDecade]
    @State private var selectedDecade: Double?

    private var maxCount: Int {
        filmsByDecade.map { $0.count }.max() ?? 0
    }

    // Create complete decade range from 1920s to 2020s
    private var completeDecadeRange: [FilmsByDecade] {
        let decades = Array(stride(from: 1920, through: 2020, by: 10))
        return decades.map { decade in
            if let existing = filmsByDecade.first(where: { $0.decade == decade }) {
                return existing
            } else {
                return FilmsByDecade(decade: decade, filmCount: 0, percentage: 0.0)
            }
        }
    }

    private var selectedItem: FilmsByDecade? {
        guard let decade = selectedDecade else { return nil }
        return completeDecadeRange.first { $0.decade == Int(decade) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.orange)
                Text("Films by Decade")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(Color.adaptiveText(scheme: colorScheme))
                Spacer()
            }
            .padding(.horizontal, 12)

            Chart(completeDecadeRange, id: \.decade) { item in
                BarMark(
                    x: .value("Decade", item.decade),
                    y: .value("Count", item.count)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [.orange, .red],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .cornerRadius(4)
                .opacity(selectedDecade == Double(item.decade) ? 0.7 : 1.0)

                // Add visual indicator on selected bar
                if let selectedDecade = selectedDecade, Int(selectedDecade) == item.decade {
                    RuleMark(x: .value("Selected", item.decade))
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .foregroundStyle(.orange.opacity(0.5))
                        .annotation(position: .top, spacing: 1) {
                            Text("\(item.count)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.orange)
                        }
                }
            }
            .frame(height: 200)
            .chartXAxis {
                AxisMarks(values: Array(stride(from: 1920, through: 2020, by: 10))) { value in
                    AxisValueLabel {
                        if let decade = value.as(Int.self) {
                            Text("'\(String(decade).suffix(2))")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundColor(.primary)
                                .offset(x: -12)
                        }
                    }
                }
            }
            .chartXScale(domain: 1910...2030)
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                        .foregroundStyle(.gray.opacity(0.2))
                    AxisValueLabel()
                        .font(.system(size: 10, design: .rounded))
                }
            }
            .chartYScale(domain: 0...(maxCount + 50))
            .chartXSelection(value: $selectedDecade)
            .padding(.horizontal, 12)

            // Highest decade indicator
            if let highestDecade = completeDecadeRange.max(by: { $0.count < $1.count }) {
                HStack {
                    Spacer()
                    Text("\(highestDecade.decade)s - \(highestDecade.count) films")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(
                                    LinearGradient(
                                        colors: [.orange.opacity(0.8), .red.opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                    Spacer()
                }
                .padding(.horizontal, 12)
            }

        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.red.opacity(0.05),
                            Color.orange.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )

    }
}

// MARK: - Day of Week Chart

struct DayOfWeekChart: View {
    @Environment(\.colorScheme) private var colorScheme
    let dayOfWeekPatterns: [DayOfWeekPattern]
    @State private var selectedDay: Double?

    private var totalFilms: Int {
        dayOfWeekPatterns.reduce(0) { $0 + $1.count }
    }
    
    private var maxCount: Int {
        dayOfWeekPatterns.map { $0.count }.max() ?? 0
    }

    // Create complete day range ordered from Monday to Sunday with day initials
    // Backend uses 0-6 (0=Sunday, 6=Saturday), frontend uses 1-7 (1=Monday, 7=Sunday)
    private var completeDayRange: [DayOfWeekPattern] {
        let dayMappings = [
            (1, "MON", 1), (2, "TUE", 2), (3, "WED", 3), (4, "THU", 4), (5, "FRI", 5), (6, "SAT", 6), (7, "SUN", 0)
        ]

        return dayMappings.map { frontendDayNumber, initial, backendDayNumber in
            if let existing = dayOfWeekPatterns.first(where: { $0.dayNumber == backendDayNumber }) {
                // Create new pattern with day initial for display and frontend day number
                return DayOfWeekPattern(dayOfWeek: initial, dayNumber: frontendDayNumber, filmCount: existing.filmCount, percentage: existing.percentage)
            } else {
                return DayOfWeekPattern(dayOfWeek: initial, dayNumber: frontendDayNumber, filmCount: 0, percentage: 0.0)
            }
        }
    }

    private var selectedItem: DayOfWeekPattern? {
        guard let day = selectedDay else { return nil }
        return completeDayRange.first { $0.dayNumber == Int(day) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "calendar.day.timeline.left")
                    .foregroundColor(.yellow)
                Text("Films by Day of Week")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(Color.adaptiveText(scheme: colorScheme))
                Spacer()
                Text("\(totalFilms) films")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)

            Chart(completeDayRange, id: \.dayNumber) { item in
                BarMark(
                    x: .value("Day", item.dayNumber),
                    y: .value("Count", item.count)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [.yellow, .orange],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .cornerRadius(4)
                .opacity(selectedDay == Double(item.dayNumber) ? 0.7 : 1.0)

                // Add visual indicator on selected bar
                if let selectedDay = selectedDay, Int(selectedDay) == item.dayNumber {
                    RuleMark(x: .value("Selected", item.dayNumber))
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .foregroundStyle(.yellow.opacity(0.5))
                        .annotation(position: .top, spacing: 1) {
                            Text("\(item.count)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.yellow)
                        }
                }
            }
            .frame(height: 200)
            .chartXAxis {
                AxisMarks(values: completeDayRange.map { $0.dayNumber }) { value in
                    AxisValueLabel {
                        if let dayNum = value.as(Int.self),
                           let dayItem = completeDayRange.first(where: { $0.dayNumber == dayNum }) {
                            Text(dayItem.dayOfWeek)
                                .font(.system(size: 9, weight: .semibold, design: .rounded))
                                .foregroundColor(.primary)
                                .offset(x: -14)
                        }
                    }
                }
            }
            .chartXScale(domain: 0...8)
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                        .foregroundStyle(.gray.opacity(0.2))
                    AxisValueLabel()
                        .font(.system(size: 10, design: .rounded))
                }
            }
            .chartYScale(domain: 0...(maxCount + 50))
            .chartXSelection(value: $selectedDay)
            .padding(.horizontal, 12)

            // Highest day indicator
            if let highestDay = completeDayRange.max(by: { $0.count < $1.count }) {
                HStack {
                    Spacer()
                    Text("\(highestDay.dayOfWeek) - \(highestDay.count) films")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(
                                    LinearGradient(
                                        colors: [.yellow.opacity(0.8), .orange.opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                    Spacer()
                }
                .padding(.horizontal, 12)
            }

        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.orange.opacity(0.05),
                            Color.yellow.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )

    }
}

// MARK: - Films Per Year Chart

struct FilmsPerYearChart: View {
    @Environment(\.colorScheme) private var colorScheme
    let filmsPerYear: [FilmsPerYear]
    @State private var selectedYear: Double?

    private var totalFilms: Int {
        let counts: [Int] = filmsPerYear.map { $0.count }
        return counts.reduce(0, +)
    }
    
    private var maxCount: Int {
        filmsPerYear.map { $0.count }.max() ?? 0
    }

    private var yearRange: (min: Int, max: Int) {
        guard !filmsPerYear.isEmpty else { return (2020, 2025) }
        let years = filmsPerYear.map { $0.year }
        return (years.min() ?? 2020, years.max() ?? 2025)
    }

    private var yearAxisValues: [Int] {
        let range = yearRange
        let span = range.max - range.min

        // Determine appropriate interval based on span
        let interval: Int
        if span <= 3 {
            interval = 1  // Show every year for very small spans
        } else if span <= 6 {
            interval = 2  // Show every other year
        } else if span <= 12 {
            interval = 3  // Show every 3 years
        } else if span <= 20 {
            interval = 5  // Show every 5 years
        } else {
            interval = 10  // Show every 10 years for large spans
        }

        // Generate values starting from the minimum year
        var values: [Int] = []
        var currentYear = range.min
        while currentYear <= range.max {
            values.append(currentYear)
            currentYear += interval
        }

        // Always include the max year if it's not already included
        if let lastValue = values.last, lastValue < range.max {
            values.append(range.max)
        }

        return values
    }

    private var selectedItem: FilmsPerYear? {
        guard let year = selectedYear else { return nil }
        return filmsPerYear.first { $0.year == Int(year) }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.green)
                Text("Films Per Year")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(Color.adaptiveText(scheme: colorScheme))
                Spacer()
                Text("\(totalFilms) films")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            
            Chart(filmsPerYear, id: \.year) { item in
                BarMark(
                    x: .value("Year", item.year),
                    y: .value("Count", item.count)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [.green, .mint],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .cornerRadius(4)
                .opacity(selectedYear == Double(item.year) ? 0.7 : 1.0)

                // Add visual indicator on selected bar
                if let selectedYear = selectedYear, Int(selectedYear) == item.year {
                    RuleMark(x: .value("Selected", item.year))
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .foregroundStyle(.green.opacity(0.5))
                        .annotation(position: .top, spacing: 1) {
                            Text("\(item.count)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                        }
                }
            }
            .frame(height: 200)
            .chartXAxis {
                AxisMarks(values: filmsPerYear.map { $0.year }) { value in
                    AxisValueLabel {
                        if let year = value.as(Int.self) {
                            Text("'\(String(year).suffix(2))")
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundColor(.primary)
                                .offset(x: -12)
                        }
                    }
                }
            }
            .chartXScale(domain: (yearRange.min - 1)...(yearRange.max + 1))
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                        .foregroundStyle(.gray.opacity(0.2))
                    AxisValueLabel()
                        .font(.system(size: 10, design: .rounded))
                }
            }
            .chartYScale(domain: 0...(maxCount + 50))
            .chartXSelection(value: $selectedYear)
            .padding(.horizontal, 12)
            
            // Highest year indicator
            if let highestYear = filmsPerYear.max(by: { $0.count < $1.count }) {
                HStack {
                    Spacer()
                    Text("\(String(highestYear.year)) - \(highestYear.count) films")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(
                                    LinearGradient(
                                        colors: [.green.opacity(0.8), .mint.opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                    Spacer()
                }
                .padding(.horizontal, 12)
            }
            
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.mint.opacity(0.05),
                            Color.green.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )

    }
}

// MARK: - On Pace Chart

struct OnPaceChart: View {
    @Environment(\.colorScheme) private var colorScheme
    let yearlyPaceStats: YearlyPaceStats
    
    @State private var projectionMethod: PaceProjectionMethod = .linear
    @State private var selectedMonth: Double?
    
    private var chartData: [MonthlyPaceData] {
        if yearlyPaceStats.isCurrentYear {
            return projectionMethod == .linear 
                ? (yearlyPaceStats.projectedLinear ?? yearlyPaceStats.monthlyData)
                : (yearlyPaceStats.projectedSeasonal ?? yearlyPaceStats.monthlyData)
        }
        return yearlyPaceStats.monthlyData
    }
    
    private var projectedEndOfYear: Int? {
        if yearlyPaceStats.isCurrentYear {
            return projectionMethod == .linear
                ? yearlyPaceStats.projectedEndOfYearLinear
                : yearlyPaceStats.projectedEndOfYearSeasonal
        }
        return nil
    }
    
    private var maxCount: Int {
        let actualMax = chartData.map { $0.cumulativeCount }.max() ?? 0
        let historicalMax = yearlyPaceStats.historicalAverage.map { $0.cumulativeCount }.max() ?? 0
        return max(actualMax, historicalMax)
    }
    
    private var currentMonthCutoff: Int {
        if yearlyPaceStats.isCurrentYear {
            let calendar = Calendar.current
            return calendar.component(.month, from: Date())
        }
        return 12
    }
    
    private var selectedItem: (actual: MonthlyPaceData?, historical: MonthlyPaceData?)? {
        guard let month = selectedMonth else { return nil }
        let monthInt = Int(month)
        let actual = chartData.first { $0.month == monthInt }
        let historical = yearlyPaceStats.historicalAverage.first { $0.month == monthInt }
        return (actual, historical)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with algorithm toggle
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.orange)
                Text("On Pace")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(Color.adaptiveText(scheme: colorScheme))
                Spacer()
                
                if yearlyPaceStats.isCurrentYear {
                    Picker("Method", selection: $projectionMethod) {
                        ForEach(PaceProjectionMethod.allCases) { method in
                            Text(method.rawValue).tag(method)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 140)
                }
            }
            .padding(.horizontal, 12)
            
            // Chart
            Chart {
                // Historical average line (dashed)
                ForEach(yearlyPaceStats.historicalAverage) { item in
                    LineMark(
                        x: .value("Month", item.month),
                        y: .value("Cumulative", item.cumulativeCount),
                        series: .value("Series", "Historical")
                    )
                    .foregroundStyle(.gray.opacity(0.7))
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                    .interpolationMethod(.catmullRom)
                }
                
                // Actual data line
                ForEach(yearlyPaceStats.monthlyData) { item in
                    LineMark(
                        x: .value("Month", item.month),
                        y: .value("Cumulative", item.cumulativeCount),
                        series: .value("Series", "Actual")
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .cyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .lineStyle(StrokeStyle(lineWidth: 3))
                    .interpolationMethod(.catmullRom)
                    
                    // Area under actual line
                    AreaMark(
                        x: .value("Month", item.month),
                        y: .value("Cumulative", item.cumulativeCount),
                        series: .value("Series", "Actual")
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue.opacity(0.3), .blue.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                }
                
                // Projection line (current year only)
                if yearlyPaceStats.isCurrentYear {
                    let projectionData = projectionMethod == .linear
                        ? yearlyPaceStats.projectedLinear
                        : yearlyPaceStats.projectedSeasonal
                    
                    if let projection = projectionData {
                        ForEach(projection.filter { $0.month > currentMonthCutoff }) { item in
                            LineMark(
                                x: .value("Month", item.month),
                                y: .value("Cumulative", item.cumulativeCount),
                                series: .value("Series", "Projected")
                            )
                            .foregroundStyle(.orange.opacity(0.8))
                            .lineStyle(StrokeStyle(lineWidth: 2, dash: [3, 3]))
                            .interpolationMethod(.catmullRom)
                        }
                    }
                }
                
                // Selection indicator
                if let month = selectedMonth {
                    RuleMark(x: .value("Selected", month))
                        .lineStyle(StrokeStyle(lineWidth: 1.5))
                        .foregroundStyle(.gray.opacity(0.5))
                }
            }
            .frame(height: 220)
            .chartXAxis {
                AxisMarks(values: Array(1...12)) { value in
                    AxisValueLabel {
                        if let month = value.as(Int.self) {
                            Text(monthShort(month))
                                .font(.system(size: 9, weight: .medium, design: .rounded))
                                .foregroundColor(.primary)
                        }
                    }
                }
            }
            .chartXScale(domain: 0.5...12.5)
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                        .foregroundStyle(.gray.opacity(0.2))
                    AxisValueLabel()
                        .font(.system(size: 10, design: .rounded))
                }
            }
            .chartYScale(domain: 0...(maxCount + 20))
            .chartXSelection(value: $selectedMonth)
            .sensoryFeedback(.selection, trigger: selectedMonth)
            .padding(.horizontal, 12)
            
            // Legend
            HStack(spacing: 16) {
                LegendItem(color: .blue, label: yearlyPaceStats.isCurrentYear ? "Actual" : String(yearlyPaceStats.year))
                LegendItem(color: .gray, label: "Historical Avg", isDashed: true)
                if yearlyPaceStats.isCurrentYear {
                    LegendItem(color: .orange, label: "Projected", isDashed: true)
                }
            }
            .font(.caption2)
            .padding(.horizontal, 12)
            
            // Projection summary (current year only)
            if let projectedEnd = projectedEndOfYear {
                HStack {
                    Spacer()
                    VStack(spacing: 2) {
                        Text("Projected Year End")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("\(projectedEnd) films")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.orange.opacity(0.1))
                    )
                    Spacer()
                }
                .padding(.horizontal, 12)
            }
            
            // Selection info
            if let selection = selectedItem, let actual = selection.actual {
                let historicalText = selection.historical.map { " | Hist: \($0.cumulativeCount)" } ?? ""
                let labelText = "\(actual.monthName): \(actual.cumulativeCount) films\(historicalText)"
                SelectionInfoRow(text: labelText, color: .blue)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.orange.opacity(0.05),
                            Color.blue.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )

    }
    
    private func monthShort(_ month: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        return String(formatter.shortMonthSymbols[month - 1].prefix(1))
    }
}

// Helper view for chart legend
private struct LegendItem: View {
    let color: Color
    let label: String
    var isDashed: Bool = false
    
    var body: some View {
        HStack(spacing: 4) {
            if isDashed {
                DashedLine()
                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [3, 3]))
                    .foregroundColor(color)
                    .frame(width: 16, height: 2)
            } else {
                Rectangle()
                    .fill(color)
                    .frame(width: 16, height: 3)
                    .cornerRadius(1.5)
            }
            Text(label)
                .foregroundColor(.secondary)
        }
    }
}

private struct DashedLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}

// MARK: - Films per Month Chart

struct FilmsPerMonthChart: View {
    @Environment(\.colorScheme) private var colorScheme
    let filmsPerMonth: [FilmsPerMonth]
    @State private var selectedMonth: Double?

    private var aggregatedFilms: [(month: Int, count: Int)] {
        var dict: [Int: Int] = [:]
        for item in filmsPerMonth {
            dict[item.month, default: 0] += item.count
        }
        return (1...12).map { (month: $0, count: dict[$0, default: 0]) }
    }

    private var totalFilms: Int {
        aggregatedFilms.map { $0.count }.reduce(0, +)
    }
    
    private var maxCount: Int {
        aggregatedFilms.map { $0.count }.max() ?? 0
    }

    private var monthAxisValues: [Int] {
        return Array(1...12)
    }

    private func monthName(for monthNumber: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        return formatter.shortMonthSymbols[monthNumber - 1]
    }

    private var selectedItem: (month: Int, count: Int)? {
        guard let month = selectedMonth else { return nil }
        return aggregatedFilms.first { $0.month == Int(month) }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.blue)
                Text("Films Per Month")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(Color.adaptiveText(scheme: colorScheme))
                Spacer()
                Text("\(totalFilms) films")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            
            Chart(aggregatedFilms, id: \.month) { item in
                BarMark(
                    x: .value("Month", item.month),
                    y: .value("Count", item.count)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .cyan],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .cornerRadius(4)
                .opacity(selectedMonth == Double(item.month) ? 0.7 : 1.0)

                // Add visual indicator on selected bar
                if let selectedMonth = selectedMonth, Int(selectedMonth) == item.month {
                    RuleMark(x: .value("Selected", item.month))
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .foregroundStyle(.blue.opacity(0.5))
                        .annotation(position: .top, spacing: 4) {
                            Text("\(item.count)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                        }
                }
            }
            .frame(height: 200)
            .chartXAxis {
                AxisMarks(values: monthAxisValues) { value in
                    AxisValueLabel {
                        if let month = value.as(Int.self) {
                            Text(monthName(for: month))
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundColor(.primary)
                                .offset(x: -12)
                        }
                    }
                }
            }
            .chartXScale(domain: 0.5...12.5)
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                        .foregroundStyle(.gray.opacity(0.2))
                    AxisValueLabel()
                        .font(.system(size: 10, design: .rounded))
                }
            }
            .chartYScale(domain: 0...(maxCount + 50))
            .chartXSelection(value: $selectedMonth)
            .padding(.horizontal, 12)
            
            // Highest month indicator
            if let highestMonth = aggregatedFilms.max(by: { $0.count < $1.count }) {
                HStack {
                    Spacer()
                    Text("\(monthName(for: highestMonth.month)) - \(highestMonth.count) films")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(
                                    LinearGradient(
                                        colors: [.blue.opacity(0.8), .cyan.opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                    Spacer()
                }
                .padding(.horizontal, 12)
            }
            
            if let selectedItem = selectedItem {
                let labelText = "\(monthName(for: selectedItem.month)): \(selectedItem.count) films"
                SelectionInfoRow(text: labelText, color: .blue)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.cyan.opacity(0.05),
                            Color.blue.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )

    }
}

// MARK: - Weekly Films Chart

struct WeeklyFilmsChart: View {
    @Environment(\.colorScheme) private var colorScheme
    let weeklyData: [WeeklyFilmsData]
    let selectedYear: Int
    @State private var selectedWeek: Double?

    private var totalFilms: Int {
        weeklyData.reduce(0) { $0 + $1.count }
    }
    
    private var maxCount: Int {
        weeklyData.map { $0.count }.max() ?? 0
    }

    private var chartXDomain: ClosedRange<Double> {
        let weekNumbers: [Int] = weeklyData.map { $0.weekNumber }
        let maxWeek: Int = weekNumbers.max() ?? 52
        let maxWeekPlusOne: Int = maxWeek + 1
        let upperBound: Double = Double(maxWeekPlusOne)
        let lowerBound: Double = 0
        return lowerBound...upperBound
    }

    private var selectedItem: WeeklyFilmsData? {
        guard let week = selectedWeek else { return nil }
        return weeklyData.first { $0.weekNumber == Int(week) || abs(Double($0.weekNumber) + 0.5 - week) < 0.6 }
    }
    
    var body: some View {
        weeklyChartMainContainer
    }
    
    private var weeklyChartMainContainer: some View {
        VStack(alignment: .leading, spacing: 16) {
            weeklyChartHeader
            weeklyChart
            weeklySelectionInfo
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.pink.opacity(0.05),
                            Color.purple.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )

    }
    
    // MARK: - Weekly Chart Subviews
    
    private var weeklyChartHeader: some View {
        HStack {
            Image(systemName: "calendar.badge.clock")
                .foregroundColor(.purple)
            Text("Weekly Film Activity")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(Color.adaptiveText(scheme: colorScheme))
            Spacer()
            Text("\(totalFilms) films")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
    }
    
    private var weeklyChart: some View {
        VStack(spacing: 8) {
            Chart(weeklyData, id: \.weekNumber) { item in
                weeklyBarMark(for: item)

                // Add visual indicator on selected bar
                if let selectedWeek = selectedWeek,
                   abs(Double(item.weekNumber) + 0.5 - selectedWeek) < 0.6 {
                    RuleMark(x: .value("Selected", Double(item.weekNumber) + 0.5))
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .foregroundStyle(.purple.opacity(0.5))
                        .annotation(position: .top, spacing: 4) {
                            Text("\(item.count)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.purple)
                        }
                }
            }
            .chartXScale(domain: chartXDomain)
            .frame(height: 200)
            .chartXAxis {
                weeklyXAxis
            }
            .chartYAxis {
                weeklyYAxis
            }
            .chartYScale(domain: 0...(maxCount + 50))
            .chartXSelection(value: $selectedWeek)
            .padding(.horizontal, 12)
            
            // Highest week indicator
            if let highestWeek = weeklyData.max(by: { $0.count < $1.count }) {
                HStack {
                    Spacer()
                    Text("\(highestWeek.weekLabel) - \(highestWeek.count) films")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(
                                    LinearGradient(
                                        colors: [.purple.opacity(0.8), .pink.opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                    Spacer()
                }
                .padding(.horizontal, 12)
            }
        }
    }
    
    private func weeklyBarMark(for item: WeeklyFilmsData) -> some ChartContent {
        BarMark(
            x: .value("Week", Double(item.weekNumber) + 0.5),
            y: .value("Count", item.count),
            width: .fixed(3)
        )
        .foregroundStyle(weeklyBarGradient)
        .cornerRadius(1)
        .opacity(weeklyBarOpacity(for: item))
    }
    
    private var weeklyBarGradient: LinearGradient {
        LinearGradient(
            colors: [.purple, .pink],
            startPoint: .bottom,
            endPoint: .top
        )
    }
    
    private func weeklyBarOpacity(for item: WeeklyFilmsData) -> Double {
        guard let selectedWeek = selectedWeek else { return 1.0 }
        let isSelected = abs(Double(item.weekNumber) + 0.5 - selectedWeek) < 0.6
        return isSelected ? 0.7 : 1.0
    }
    
    private var weeklyXAxis: some AxisContent {
        AxisMarks(position: .bottom) { _ in
            AxisValueLabel {
                Text("")
            }
        }
    }
    
    private var weeklyYAxis: some AxisContent {
        AxisMarks(position: .leading) { _ in
            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                .foregroundStyle(.gray.opacity(0.2))
            AxisValueLabel()
                .font(.system(size: 10, design: .rounded))
        }
    }
    
    @ViewBuilder
    private var weeklySelectionInfo: some View {
        if let selectedItem = selectedItem {
            let labelText = "\(selectedItem.weekLabel): \(selectedItem.count) films"
            SelectionInfoRow(text: labelText, color: .purple)
        }
    }

    private var weeklyChartBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.black.opacity(0.85))
    }

    private var weeklyChartOverlay: some View {
        RoundedRectangle(cornerRadius: 16)
            .stroke(weeklyOverlayGradient, lineWidth: 0.5)
    }

    private var weeklyOverlayGradient: LinearGradient {
        LinearGradient(
            colors: [.white.opacity(0.1), .white.opacity(0.05)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Error View

struct ErrorView: View {
    let message: String
    let retry: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)
            
            Text("Error Loading Statistics")
                .font(.headline)
            
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Retry", action: retry)
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

// MARK: - Year Release Pie Chart

struct YearReleasePieChart: View {
    @Environment(\.colorScheme) private var colorScheme
    let yearReleaseStats: YearReleaseStats
    let selectedYear: Int
    @State private var selectedSlice: String?
    @State private var chartProxy: ChartProxy?
    @State private var animationProgress: Double = 0
    @State private var showTooltip = false
    @State private var tooltipText = ""
    @State private var longPressLocation: CGPoint = .zero
    
    private struct PieSlice: Identifiable {
        let id = UUID()
        let label: String
        let value: Int
        let color: Color
        let startAngle: Angle
        let endAngle: Angle
    }
    
    private var pieData: [PieSlice] {
        let filmsFromYear = yearReleaseStats.filmsFromYear
        let filmsFromOtherYears = yearReleaseStats.filmsFromOtherYears
        let totalFilms = yearReleaseStats.totalFilms
        
        // If we have no data at all, show a placeholder
        if totalFilms == 0 {
            return [
                PieSlice(
                    label: "No Data",
                    value: 1,
                    color: .gray,
                    startAngle: .degrees(0),
                    endAngle: .degrees(360)
                )
            ]
        }
        
        // Calculate angles based on the actual counts
        let total = max(filmsFromYear + filmsFromOtherYears, 1)
        let otherYearsAngle = Double(filmsFromOtherYears) / Double(total) * 360
        
        return [
            PieSlice(
                label: "Other Years",
                value: filmsFromOtherYears,
                color: .cyan,
                startAngle: .degrees(0),
                endAngle: .degrees(otherYearsAngle)
            ),
            PieSlice(
                label: "\(String(selectedYear)) Films",
                value: filmsFromYear,
                color: .green,
                startAngle: .degrees(otherYearsAngle),
                endAngle: .degrees(360)
            )
        ]
    }
    
    private var totalFilms: Int {
        return max(yearReleaseStats.totalFilms, 1) // Ensure minimum of 1 to avoid division by zero
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            pieChartHeader
            
            // Pie Chart Container
            pieChartContainer
                .frame(height: 240)
                .frame(maxWidth: .infinity)
            
            // Legend
            legendView
                .padding(.horizontal, 12)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.green.opacity(0.05),
                            Color.cyan.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )

        .onAppear {
            withAnimation(.easeOut(duration: 1.0)) {
                animationProgress = 1.0
            }
        }
    }
    
    // MARK: - Subviews
    
    private var pieChartHeader: some View {
        HStack {
            Image(systemName: "calendar.badge.clock")
                .foregroundColor(.green)
                .font(.title2)
            Text("Release Year Distribution")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(Color.adaptiveText(scheme: colorScheme))
            Spacer()
            Text("\(totalFilms) total")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
    }
    
    private var pieChartContainer: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(Color.white.opacity(0.02))
                .frame(width: 240, height: 240)
            
            // Pie Chart
            pieChart
                .frame(width: 220, height: 220)
            
            // Tooltip overlay
            tooltipOverlay
            
            // Center text
            centerTextView
        }
    }
    
    private var pieChart: some View {
        Chart(pieData) { slice in
            SectorMark(
                angle: .value("Count", slice.value),
                innerRadius: .ratio(0.5),
                angularInset: 1.5
            )
            .foregroundStyle(sliceGradient(for: slice))
            .cornerRadius(4)
            .opacity(selectedSlice == nil || selectedSlice == slice.label ? 1.0 : 0.5)
        }
        .chartAngleSelection(value: .constant(nil as Double?))
        .chartBackground { proxy in
            chartBackgroundView(proxy: proxy)
        }
        .animation(.easeInOut(duration: 0.3), value: selectedSlice)
    }
    
    private func sliceGradient(for slice: PieSlice) -> LinearGradient {
        let colors = slice.label.contains("\(selectedYear)")
            ? [slice.color, slice.color.opacity(0.8)]
            : [slice.color.opacity(0.9), slice.color]
        
        return LinearGradient(
            colors: colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private func chartBackgroundView(proxy: ChartProxy) -> some View {
        GeometryReader { geometry in
            Rectangle()
                .fill(Color.clear)
                .contentShape(Rectangle())
                .onTapGesture { location in
                    handlePieTap(at: location, in: geometry)
                }
                .gesture(longPressGesture(in: geometry))
                .onAppear {
                    chartProxy = proxy
                }
        }
    }
    
    private func longPressGesture(in geometry: GeometryProxy) -> some Gesture {
        LongPressGesture(minimumDuration: 0.5)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .onChanged { value in
                switch value {
                case .first(true):
                    handleLongPressStart(at: longPressLocation, in: geometry)
                case .second(true, let drag):
                    if let drag = drag {
                        longPressLocation = drag.location
                        handleLongPressStart(at: drag.location, in: geometry)
                    }
                default:
                    break
                }
            }
            .onEnded { _ in
                showTooltip = false
            }
    }
    
    @ViewBuilder
    private var tooltipOverlay: some View {
        if showTooltip && !tooltipText.isEmpty {
            VStack(spacing: 4) {
                Text(tooltipText)
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(tooltipBackground)
                    .shadow(color: .green.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .position(x: longPressLocation.x, y: max(40, longPressLocation.y - 60))
            .allowsHitTesting(false)
            .animation(.easeInOut(duration: 0.2), value: longPressLocation)
        }
    }
    
    private var tooltipBackground: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.black.opacity(0.9))

    }
    
    @ViewBuilder
    private var centerTextView: some View {
        VStack(spacing: 4) {
            if let selected = selectedSlice,
               let slice = pieData.first(where: { $0.label == selected }) {
                selectedSliceText(slice: slice)
            } else if totalFilms > 0 {
                defaultCenterText
            } else {
                Text("No Data")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func selectedSliceText(slice: PieSlice) -> some View {
        Group {
            Text(slice.label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text("\(slice.value)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(slice.color)
            Text("\(Int((Double(slice.value) / Double(totalFilms)) * 100))%")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var defaultCenterText: some View {
        let yearPercentage = Int(yearReleaseStats.yearPercentage ?? 0.0)
        
        return Group {
            Text("\(String(selectedYear)) Films")
                .font(.caption)
                .foregroundColor(.secondary)
            Text("\(yearPercentage)%")
                .font(.title)
                .fontWeight(.bold)
                .gradientForeground([.green, .mint], start: .top, end: .bottom)
            Text("of total")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    private var legendView: some View {
        HStack(spacing: 32) {
            Spacer()
            legendItem(
                label: "Other Years",
                count: yearReleaseStats.filmsFromOtherYears,
                colors: [.cyan.opacity(0.9), .cyan]
            )
            legendItem(
                label: "\(String(selectedYear)) Films",
                count: yearReleaseStats.filmsFromYear,
                colors: [.green, .green.opacity(0.8)]
            )
            Spacer()
        }
    }
    
    private func legendItem(label: String, count: Int, colors: [Color]) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(LinearGradient(
                    colors: colors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 12, height: 12)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.primary)
                Text("\(count) films")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func handlePieTap(at location: CGPoint, in geometry: GeometryProxy) {
        let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
        let dx = location.x - center.x
        let dy = location.y - center.y
        let distance = sqrt(dx * dx + dy * dy)
        
        // Check if tap is within the pie chart radius
        guard distance <= 110 && distance >= 55 else { // 55 is inner radius (110 * 0.5)
            selectedSlice = nil
            return
        }
        
        // Calculate angle from center
        var angle = atan2(dy, dx) * 180 / .pi
        angle = angle < 0 ? angle + 360 : angle
        // Adjust for chart starting at top (rotate by 90 degrees)
        angle = angle + 90
        if angle >= 360 { angle -= 360 }
        
        // Determine which slice was tapped
        for slice in pieData {
            let startDegrees = slice.startAngle.degrees
            let endDegrees = slice.endAngle.degrees
            
            if angle >= startDegrees && angle < endDegrees {
                selectedSlice = selectedSlice == slice.label ? nil : slice.label
                return
            }
        }
        
        selectedSlice = nil
    }
    
    private func handleLongPressStart(at location: CGPoint, in geometry: GeometryProxy) {
        let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
        let dx = location.x - center.x
        let dy = location.y - center.y
        let distance = sqrt(dx * dx + dy * dy)
        
        // Check if tap is within the pie chart radius
        guard distance <= 110 && distance >= 55 else {
            showTooltip = false
            return
        }
        
        // Calculate angle from center
        var angle = atan2(dy, dx) * 180 / .pi
        angle = angle < 0 ? angle + 360 : angle
        // Adjust for chart starting at top (rotate by 90 degrees)
        angle = angle + 90
        if angle >= 360 { angle -= 360 }
        
        // Determine which slice was pressed and show tooltip
        for slice in pieData {
            let startDegrees = slice.startAngle.degrees
            let endDegrees = slice.endAngle.degrees
            
            if angle >= startDegrees && angle < endDegrees {
                let percentage = Int((Double(slice.value) / Double(totalFilms)) * 100)
                tooltipText = "\(slice.label): \(slice.value) films (\(percentage)%)"
                showTooltip = true
                longPressLocation = location
                
                return
            }
        }
        
        showTooltip = false
    }
}

// MARK: - Top Watched Films Section

struct TopWatchedFilmsSection: View {
    @Environment(\.colorScheme) private var colorScheme
    let topWatchedFilms: [TopWatchedFilm]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "star.fill")
                        .font(.title2)
                        .gradientForeground([
                            .yellow,
                            .orange
                        ], start: .topLeading, end: .bottomTrailing)
                    Text("Most Watched Films")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(Color.adaptiveText(scheme: colorScheme))
                }
                Text("Your top 6 most logged films of all time")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            
            // Films Grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ForEach(Array(topWatchedFilms.enumerated()), id: \.element.title) { index, film in
                    TopWatchedFilmCard(film: film, rank: index + 1)
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.orange.opacity(0.05),
                            Color.red.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(
                    color: .white.opacity(0.1),
                    radius: 8,
                    x: 0,
                    y: 2
                )
        )

    }
}

// MARK: - Top Watched Film Card

struct TopWatchedFilmCard: View {
    let film: TopWatchedFilm
    let rank: Int
    @State private var selectedMovie: Movie?
    @State private var showingMovieDetails = false
    @ObservedObject private var movieService = SupabaseMovieService.shared
    
    private var rankColor: Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return .blue
        }
    }
    
    private var rankIcon: String {
        switch rank {
        case 1: return "crown.fill"
        case 2: return "medal.fill"
        case 3: return "medal.fill"
        default: return "star.fill"
        }
    }
    
    var body: some View {
        Button(action: {
            Task {
                await loadMostRecentMovieEntry()
            }
        }) {
            VStack(spacing: 6) {
                // Movie poster
                AsyncImage(url: URL(string: film.posterUrl ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: "film")
                                .foregroundColor(.gray)
                                .font(.title2)
                        )
                }
                .frame(width: 85, height: 128)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // Watch count
                HStack(spacing: 4) {
                    Image(systemName: "eye.fill")
                        .font(.system(size: 8))
                        .foregroundColor(rankColor)
                    Text("\(film.watchCount)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(rankColor)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(rankColor.opacity(0.1))
                )
            }
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingMovieDetails) {
            if let selectedMovie = selectedMovie {
                MovieDetailsView(movie: selectedMovie)
            }
        }
    }
    
    private func loadMostRecentMovieEntry() async {
        guard let tmdbId = film.tmdbId else { return }
        
        do {
            let movies = try await movieService.getMoviesByTmdbId(tmdbId: tmdbId)
            if let mostRecentMovie = movies.first {
                await MainActor.run {
                    selectedMovie = mostRecentMovie
                    showingMovieDetails = true
                }
            }
        } catch {
            // Handle error silently
        }
    }
}


// MARK: - Uniform Stat Card

struct UniformStatCard: View {
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    let value: String
    let subtitle: String?
    let icon: String
    let color: Color

    private var borderGradient: [Color] {
        switch color {
        case .orange:  return [Color.orange, Color.red]
        case .green:   return [Color.green, Color.mint]
        case .yellow:  return [Color.yellow, Color.orange]
        case .purple:  return [Color.purple, Color.pink]
        default:       return [color, color.opacity(0.8)]
        }
    }
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(
                    LinearGradient(
                        colors: borderGradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .font(.title3)
            
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: borderGradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            
            VStack(spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 9))
                        .foregroundColor(color)
                        .fontWeight(.medium)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            }
            .frame(minHeight: subtitle != nil ? 24 : 12) // Ensure consistent height
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.gray.opacity(0.15))
        )
    }
}

// MARK: - Average Star Rating Per Year Chart

struct AverageStarRatingPerYearChart: View {
    let averageStarRatings: [AverageStarRatingPerYear]
    @State private var selectedYear: Double?

    private var totalFilms: Int {
        averageStarRatings.reduce(0) { $0 + $1.count }
    }

    private var yearRange: (min: Int, max: Int) {
        guard !averageStarRatings.isEmpty else { return (2020, 2025) }
        let years = averageStarRatings.map { $0.year }
        return (years.min() ?? 2020, years.max() ?? 2025)
    }

    private var selectedItem: AverageStarRatingPerYear? {
        guard let year = selectedYear else { return nil }
        return averageStarRatings.first { $0.year == Int(year) }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                Text("Average Star Rating Per Year")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                Spacer()
                Text("\(totalFilms) films")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            
            Chart(averageStarRatings, id: \.year) { item in
                BarMark(
                    x: .value("Year", item.year),
                    y: .value("Average Rating", item.averageRating)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [.orange, .blue],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .cornerRadius(4)
                .opacity(selectedYear == Double(item.year) ? 0.7 : 1.0)

                // Add visual indicator on selected bar
                if let selectedYear = selectedYear, Int(selectedYear) == item.year {
                    RuleMark(x: .value("Selected", item.year))
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .foregroundStyle(.yellow.opacity(0.5))
                        .annotation(position: .top, spacing: 1) {
                            Text("\(String(format: "%.2f", item.averageRating))★")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.yellow)
                        }
                }
            }
            .frame(height: 200)
            .chartXAxis {
                AxisMarks(values: averageStarRatings.map { $0.year }) { value in
                    AxisValueLabel {
                        if let year = value.as(Int.self) {
                            Text("'\(String(year).suffix(2))")
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundColor(.primary)
                                .offset(x: -12)
                        }
                    }
                }
            }
            .chartXScale(domain: (yearRange.min - 1)...(yearRange.max + 1))
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                        .foregroundStyle(.gray.opacity(0.2))
                    AxisValueLabel()
                        .font(.system(size: 10, design: .rounded))
                }
            }
            .chartYScale(domain: 0...5)
            .chartXSelection(value: $selectedYear)
            .sensoryFeedback(.selection, trigger: selectedYear)
            .padding(.horizontal, 12)
            
            // Highest average rating year indicator
            if let highestAvgYear = averageStarRatings.max(by: { $0.averageRating < $1.averageRating }) {
                HStack {
                    Spacer()
                    Text("\(String(highestAvgYear.year)) - \(String(format: "%.2f", highestAvgYear.averageRating))★")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(
                                    LinearGradient(
                                        colors: [.yellow.opacity(0.8), .orange.opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                    Spacer()
                }
                .padding(.horizontal, 12)
            }
            
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.blue.opacity(0.05),
                            Color.orange.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )

    }
}

// MARK: - Average Detailed Rating Per Year Chart

struct AverageDetailedRatingPerYearChart: View {
    let averageDetailedRatings: [AverageDetailedRatingPerYear]
    @State private var selectedYear: Double?

    private var totalFilms: Int {
        averageDetailedRatings.reduce(0) { $0 + $1.count }
    }

    private var yearRange: (min: Int, max: Int) {
        guard !averageDetailedRatings.isEmpty else { return (2020, 2025) }
        let years = averageDetailedRatings.map { $0.year }
        return (years.min() ?? 2020, years.max() ?? 2025)
    }

    private var selectedItem: AverageDetailedRatingPerYear? {
        guard let year = selectedYear else { return nil }
        return averageDetailedRatings.first { $0.year == Int(year) }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "percent")
                    .foregroundColor(.cyan)
                Text("Average Detailed Rating Per Year")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                Spacer()
                Text("\(totalFilms) films")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            
            Chart(averageDetailedRatings, id: \.year) { item in
                BarMark(
                    x: .value("Year", item.year),
                    y: .value("Average Rating", item.averageRating)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [.purple, .cyan],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .cornerRadius(4)
                .opacity(selectedYear == Double(item.year) ? 0.7 : 1.0)

                // Add visual indicator on selected bar
                if let selectedYear = selectedYear, Int(selectedYear) == item.year {
                    RuleMark(x: .value("Selected", item.year))
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .foregroundStyle(.cyan.opacity(0.5))
                        .annotation(position: .top, spacing: 1) {
                            Text("\(String(format: "%.1f", item.averageRating))/100")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.cyan)
                        }
                }
            }
            .frame(height: 200)
            .chartXAxis {
                AxisMarks(values: averageDetailedRatings.map { $0.year }) { value in
                    AxisValueLabel {
                        if let year = value.as(Int.self) {
                            Text("'\(String(year).suffix(2))")
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundColor(.primary)
                                .offset(x: -12)
                        }
                    }
                }
            }
            .chartXScale(domain: (yearRange.min - 1)...(yearRange.max + 1))
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                        .foregroundStyle(.gray.opacity(0.2))
                    AxisValueLabel()
                        .font(.system(size: 10, design: .rounded))
                }
            }
            .chartYScale(domain: 0...100)
            .chartXSelection(value: $selectedYear)
            .sensoryFeedback(.selection, trigger: selectedYear)
            .padding(.horizontal, 12)
            
            // Highest average detailed rating year indicator
            if let highestAvgDetailedYear = averageDetailedRatings.max(by: { $0.averageRating < $1.averageRating }) {
                HStack {
                    Image(systemName: "trophy")
                        .foregroundColor(.yellow)
                    Text("Highest: '\(String(highestAvgDetailedYear.year).suffix(2)) with \(String(format: "%.1f", highestAvgDetailedYear.averageRating))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 4)
                .padding(.horizontal, 12)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.purple.opacity(0.05),
                            Color.cyan.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }
}

private struct LocationStatisticsSection: View {
    @Environment(\.colorScheme) private var colorScheme

    let mapPoints: [LocationMapPoint]
    let specificCounts: [LocationCountRow]
    let groupCounts: [LocationCountRow]
    @Binding var selectedMode: LocationCountMode
    let selectedYear: Int?

    @State private var showingFullScreenMap = false

    private var activeCounts: [LocationCountRow] {
        switch selectedMode {
        case .specific:
            return specificCounts
        case .grouped:
            return groupCounts
        }
    }

    private var mapRegion: MKCoordinateRegion {
        guard !mapPoints.isEmpty else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 20, longitude: 0),
                span: MKCoordinateSpan(latitudeDelta: 140, longitudeDelta: 140)
            )
        }

        let lats = mapPoints.map(\.latitude)
        let lons = mapPoints.map(\.longitude)
        let minLat = lats.min() ?? 0
        let maxLat = lats.max() ?? 0
        let minLon = lons.min() ?? 0
        let maxLon = lons.max() ?? 0

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2.0,
            longitude: (minLon + maxLon) / 2.0
        )
        let latDelta = max(12.0, (maxLat - minLat) * 1.8)
        let lonDelta = max(12.0, (maxLon - minLon) * 1.8)
        return MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: min(latDelta, 170), longitudeDelta: min(lonDelta, 170))
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "globe.americas.fill")
                        .foregroundColor(.blue)
                    Text(selectedYear == nil ? "Watch Locations (All Time)" : "Watch Locations (\(selectedYear!))")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(Color.adaptiveText(scheme: colorScheme))
                }
                Spacer()
            }

            if !mapPoints.isEmpty {
                ZStack(alignment: .topTrailing) {
                    Map(initialPosition: .region(mapRegion)) {
                        ForEach(mapPoints) { point in
                            Marker(
                                "\(point.location_name) (\(point.count))",
                                coordinate: CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude)
                            )
                            .tint(.blue)
                        }
                    }
                    .frame(height: 250)
                    .cornerRadius(14)
                    .onTapGesture {
                        showingFullScreenMap = true
                    }

                    Button {
                        showingFullScreenMap = true
                    } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.caption.weight(.semibold))
                            .padding(8)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .padding(10)
                }
            } else {
                Text("No location map data for this period.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 16)
            }

            Picker("Location Count Mode", selection: $selectedMode) {
                ForEach(LocationCountMode.allCases, id: \.self) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            if activeCounts.isEmpty {
                Text("No location counts available.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                LocationCountsList(
                    counts: activeCounts,
                    colorScheme: colorScheme
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.blue.opacity(0.08),
                            Color.cyan.opacity(0.06)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .sheet(isPresented: $showingFullScreenMap) {
            FullscreenLocationMapView(region: mapRegion, mapPoints: mapPoints)
        }
    }
}

private struct FullscreenLocationMapView: View {
    @Environment(\.dismiss) private var dismiss

    let region: MKCoordinateRegion
    let mapPoints: [LocationMapPoint]

    var body: some View {
        NavigationStack {
            Map(initialPosition: .region(region)) {
                ForEach(mapPoints) { point in
                    Marker(
                        "\(point.location_name) (\(point.count))",
                        coordinate: CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude)
                    )
                    .tint(.blue)
                }
            }
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle("Locations Map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Paginated Location Counts List

private struct LocationCountsList: View {
    let counts: [LocationCountRow]
    let colorScheme: ColorScheme

    private let pageSize = 5

    @State private var isExpanded = false

    private var displayedCounts: [LocationCountRow] {
        isExpanded ? counts : Array(counts.prefix(pageSize))
    }

    private var hasMore: Bool {
        counts.count > pageSize
    }

    private var remainingCount: Int {
        max(0, counts.count - pageSize)
    }

    var body: some View {
        VStack(spacing: 8) {
            LazyVStack(spacing: 8) {
                ForEach(displayedCounts) { row in
                    HStack {
                        Text(row.label)
                            .font(.subheadline)
                            .foregroundColor(Color.adaptiveText(scheme: colorScheme))
                            .lineLimit(1)
                        Spacer()
                        Text("\(row.count)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(10)
                }
            }

            if hasMore {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption.weight(.semibold))
                        Text(isExpanded ? "Show fewer" : "Show \(remainingCount) more location\(remainingCount == 1 ? "" : "s")")
                            .font(.subheadline.weight(.medium))
                    }
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.blue.opacity(0.08))
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }
        }
        .onChange(of: counts.map(\.id)) { _ in
            // Reset expansion when the data set changes (mode toggle or year change)
            isExpanded = false
        }
    }
}

// MARK: - Expanded Top Entries List View

struct TopEntriesListView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var expandedStatType: FilmJourneySection.ExpandedStatType?
    let type: FilmJourneySection.ExpandedStatType
    let selectedYear: Int?
    let advancedJourneyStats: AdvancedFilmJourneyStats?
    let yearFilteredAdvancedStats: YearFilteredAdvancedJourneyStats?
    let filmsPerMonth: [FilmsPerMonth]?
    
    private var mostInDayEntries: [MostMoviesInDayStat] {
        if selectedYear == nil {
            return advancedJourneyStats?.mostMoviesInDay ?? []
        } else {
            return yearFilteredAdvancedStats?.mostMoviesInDay ?? []
        }
    }
    
    private var bestMonthEntries: [HighestMonthlyAverage] {
        if selectedYear == nil {
            return advancedJourneyStats?.highestMonthlyAverage ?? []
        } else {
            return yearFilteredAdvancedStats?.highestMonthlyAverage ?? []
        }
    }
    
    private var mostActiveMonthEntries: [FilmsPerMonth] {
        return (filmsPerMonth ?? []).filter { $0.filmCount > 0 }.sorted { $0.filmCount > $1.filmCount }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 8) {
                    if type == .mostInDay {
                        if mostInDayEntries.isEmpty {
                            ContentUnavailableView("No Data", systemImage: "chart.bar.doc.horizontal")
                                .padding(.top, 40)
                        } else {
                            ForEach(Array(mostInDayEntries.prefix(10).enumerated()), id: \.element.id) { index, entry in
                                TopMostInDayRow(index: index + 1, entry: entry)
                            }
                        }
                    } else if type == .bestMonth {
                        if bestMonthEntries.isEmpty {
                            ContentUnavailableView("No Data", systemImage: "chart.bar.doc.horizontal")
                                .padding(.top, 40)
                        } else {
                            ForEach(Array(bestMonthEntries.prefix(10).enumerated()), id: \.element.id) { index, entry in
                                TopBestMonthRow(index: index + 1, entry: entry)
                            }
                        }
                    } else if type == .mostActiveMonth {
                        if mostActiveMonthEntries.isEmpty {
                            ContentUnavailableView("No Data", systemImage: "chart.bar.doc.horizontal")
                                .padding(.top, 40)
                        } else {
                            ForEach(Array(mostActiveMonthEntries.prefix(10).enumerated()), id: \.offset) { index, entry in
                                TopMostActiveMonthRow(index: index + 1, entry: entry, selectedYear: selectedYear)
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle(
                type == .mostInDay ? "Most in a Day" :
                type == .bestMonth ? "Best Month" : "Most Films"
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        expandedStatType = nil
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
        }
    }
}

struct TopMostInDayRow: View {
    let index: Int
    let entry: MostMoviesInDayStat
    
    private func formatFullDate(_ dateString: String) -> String {
        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd"
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        if let date = parser.date(from: dateString) {
            return formatter.string(from: date)
        }
        return dateString
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Text("\(index)")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(.mint)
                .frame(width: 24, alignment: .leading)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(formatFullDate(entry.watchDate))
                    .font(.subheadline)
                    .foregroundColor(.white)
                Text("\(entry.filmCount) Films")
                    .font(.caption)
                    .foregroundColor(.mint.opacity(0.8))
            }
            Spacer()
        }
        .padding(12)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
}

struct TopBestMonthRow: View {
    let index: Int
    let entry: HighestMonthlyAverage
    
    var body: some View {
        HStack(spacing: 12) {
            Text("\(index)")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(.purple)
                .frame(width: 24, alignment: .leading)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("\(entry.monthName.trimmingCharacters(in: .whitespacesAndNewlines)) \(String(entry.year))")
                    .font(.subheadline)
                    .foregroundColor(.white)
                Text(String(format: "%.2f Avg. Rating", entry.averageRating))
                    .font(.caption)
                    .foregroundColor(.purple.opacity(0.8))
            }
            Spacer()
            
            Text("\(entry.filmCount) films")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
}

struct TopMostActiveMonthRow: View {
    let index: Int
    let entry: FilmsPerMonth
    let selectedYear: Int?
    
    var body: some View {
        HStack(spacing: 12) {
            Text("\(index)")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(.mint)
                .frame(width: 24, alignment: .leading)
            
            VStack(alignment: .leading, spacing: 2) {
                if let year = selectedYear {
                    Text("\(entry.monthName.trimmingCharacters(in: .whitespacesAndNewlines)) \(String(year))")
                        .font(.subheadline)
                        .foregroundColor(.white)
                } else {
                    Text("\(entry.monthName.trimmingCharacters(in: .whitespacesAndNewlines)) '\(String(entry.year).suffix(2))")
                        .font(.subheadline)
                        .foregroundColor(.white)
                }
                Text("\(entry.filmCount)")
                    .font(.caption)
                    .foregroundColor(.mint.opacity(0.8))
            }
            Spacer()
        }
        .padding(12)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
}

#Preview {
    StatisticsView()
}

//
//  StatisticsView.swift
//  reelay2
//
//  Created by Humza Khalil on 7/21/25.
//

import SwiftUI
import Charts
import Auth

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
    @StateObject private var statisticsService = SupabaseStatisticsService.shared
    @StateObject private var movieService = SupabaseMovieService.shared
    
    @State private var dashboardStats: DashboardStats?
    @State private var ratingDistribution: [RatingDistribution] = []
    @State private var filmsByDecade: [FilmsByDecade] = []
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
    @State private var yearReleaseStats: YearReleaseStats?
    @State private var topWatchedFilms: [TopWatchedFilm] = []
    @State private var advancedJourneyStats: AdvancedFilmJourneyStats?
    @State private var yearFilteredAdvancedStats: YearFilteredAdvancedJourneyStats?
    @State private var averageStarRatingsPerYear: [AverageStarRatingPerYear] = []
    @State private var averageDetailedRatingsPerYear: [AverageDetailedRatingPerYear] = []
    
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    // Year selection states
    @State private var availableYears: [Int] = []
    @State private var selectedYear: Int? = nil
    @State private var showingYearPicker = false
    
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
        let filmsByDecade: [FilmsByDecade]
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
    
    var body: some View {
        NavigationStack {
            ScrollView {
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
                                filmsPerMonth: filmsPerMonth
                            )
                            
                            // Advanced Film Journey Section - only show for all-time view
                            if selectedYear == nil && advancedJourneyStats != nil {
                                AdvancedFilmJourneySection(advancedStats: advancedJourneyStats!)
                            }
                            
                            // Year-Filtered Advanced Film Journey Section - only show for year-filtered views
                            if let year = selectedYear, let yearFilteredStats = yearFilteredAdvancedStats {
                                YearFilteredAdvancedJourneySection(yearFilteredStats: yearFilteredStats, selectedYear: year)
                            }
                            
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
                            
                            // Streak Statistics Section - only show for all-time view
                            if selectedYear == nil {
                                StreakSection(streakStats: streakStats, selectedYear: selectedYear)
                            }
                            
                            // Year Release Date Pie Chart - only show for year-filtered views
                            if let year = selectedYear, let yearReleaseStats = yearReleaseStats {
                                YearReleasePieChart(yearReleaseStats: yearReleaseStats, selectedYear: year)
                            }
                            
                            // Rating Distribution Chart
                            RatingDistributionChart(distribution: ratingDistribution)
                            
                            // Films Per Year Chart (all-time) or Films Per Month Chart (year-filtered)
                            if selectedYear != nil {
                                FilmsPerMonthChart(filmsPerMonth: filmsPerMonth)
                            } else {
                                FilmsPerYearChart(filmsPerYear: filmsPerYear)
                            }
                            
                            // Weekly Films Chart - only show for year-filtered views
                            if let year = selectedYear, !weeklyFilmsData.isEmpty {
                                WeeklyFilmsChart(weeklyData: weeklyFilmsData, selectedYear: year)
                            }
                            
                            // Day of Week Chart
                            DayOfWeekChart(dayOfWeekPatterns: dayOfWeekPatterns)
                            
                            // Average Rating Per Year Charts - only show for all-time view
                            if selectedYear == nil && !averageStarRatingsPerYear.isEmpty {
                                AverageStarRatingPerYearChart(averageStarRatings: averageStarRatingsPerYear)
                            }
                            
                            if selectedYear == nil && !averageDetailedRatingsPerYear.isEmpty {
                                AverageDetailedRatingPerYearChart(averageDetailedRatings: averageDetailedRatingsPerYear)
                            }
                            
                            // Films by Decade Chart - moved to bottom
                            FilmsByDecadeChart(filmsByDecade: filmsByDecade)
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
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
    }
    
    // MARK: - Year Picker UI Components
    
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
                    .foregroundColor(.white)
                
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.blue)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(.regularMaterial)
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            )
            .overlay(
                Capsule()
                    .stroke(
                        LinearGradient(
                            colors: [.blue.opacity(0.3), .blue.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
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
            .listStyle(.insetGrouped)
            .navigationTitle("Select Year")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
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
        return selectedYear?.description ?? "all-time"
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
            self.filmsByDecade = cachedData.filmsByDecade
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
            self.isLoading = false
        }
    }
    
    private func cacheCurrentData() {
        let cacheKey = getCacheKey()
        let cachedData = CachedStatisticsData(
            dashboardStats: dashboardStats,
            ratingDistribution: ratingDistribution,
            filmsByDecade: filmsByDecade,
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
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        let startTime = Date()
        
        do {
            // Load all stats from Supabase
            async let dashboardTask = statisticsService.getDashboardStats(year: selectedYear)
            async let ratingTask = statisticsService.getRatingDistribution(year: selectedYear)
            async let decadeTask = statisticsService.getFilmsByDecade(year: selectedYear)
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
            
            let results = try await (
                dashboard: dashboardTask,
                rating: ratingTask,
                decade: decadeTask,
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
                averageDetailedRatings: averageDetailedRatingsTask
            )
            
            await MainActor.run {
                self.dashboardStats = results.dashboard
                self.ratingDistribution = results.rating
                self.filmsByDecade = results.decade
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
        // Don't set isLoading = true during refresh to keep existing data visible
        await MainActor.run {
            errorMessage = nil
        }
        
        do {
            async let dashboardTask = statisticsService.getDashboardStats(year: selectedYear)
            async let ratingTask = statisticsService.getRatingDistribution(year: selectedYear)
            async let decadeTask = statisticsService.getFilmsByDecade(year: selectedYear)
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
            
            let results = try await (
                dashboard: dashboardTask,
                rating: ratingTask,
                decade: decadeTask,
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
                averageDetailedRatings: averageDetailedRatingsTask
            )
            
            await MainActor.run {
                self.dashboardStats = results.dashboard
                self.ratingDistribution = results.rating
                self.filmsByDecade = results.decade
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
        async let unique5StarTask = statisticsService.getUnique5StarFilms()
        async let highestMonthlyTask = statisticsService.getHighestMonthlyAverage()
        
        let results = try await (
            daysWith2Plus: daysWith2PlusTask,
            averagePerYear: averagePerYearTask,
            unique5Star: unique5StarTask,
            highestMonthly: highestMonthlyTask
        )
        
        return AdvancedFilmJourneyStats(
            daysWith2PlusFilms: results.daysWith2Plus,
            averageMoviesPerYear: results.averagePerYear,
            unique5StarFilms: results.unique5Star,
            highestMonthlyAverage: results.highestMonthly
        )
    }
    
    private func loadYearFilteredAdvancedJourneyStats(year: Int) async throws -> YearFilteredAdvancedJourneyStats {
        async let daysWith2PlusTask = statisticsService.getDaysWith2PlusFilmsByYear(year: year)
        async let mustWatchTask = statisticsService.getMustWatchCompletionByYear(year: year)
        async let unique5StarTask = statisticsService.getUnique5StarFilmsByYear(year: year)
        async let highestMonthlyTask = statisticsService.getHighestMonthlyAverageByYear(year: year)
        
        let results = try await (
            daysWith2Plus: daysWith2PlusTask,
            mustWatch: mustWatchTask,
            unique5Star: unique5StarTask,
            highestMonthly: highestMonthlyTask
        )
        
        return YearFilteredAdvancedJourneyStats(
            daysWith2PlusFilms: results.daysWith2Plus,
            mustWatchCompletion: results.mustWatch,
            unique5StarFilms: results.unique5Star,
            highestMonthlyAverage: results.highestMonthly
        )
    }
}

// MARK: - Time Since First Film Section

struct TimeSinceFirstFilmSection: View {
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
                    .foregroundColor(.white)
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
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.purple.opacity(0.5),
                            Color.blue.opacity(0.5)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
    }
}

// MARK: - Film Journey Section

struct FilmJourneySection: View {
    let dashboardStats: DashboardStats?
    let uniqueFilmsCount: Int
    let averageRatingResolved: Double?
    let watchSpan: WatchSpan?
    let selectedYear: Int?
    let filmsPerMonth: [FilmsPerMonth]
    
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
                        .foregroundColor(.white)
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
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                StatCard(
                    title: "Total Films",
                    value: "\(dashboardStats?.totalFilms ?? 0)",
                    icon: "film",
                    color: .blue
                )
                
                StatCard(
                    title: "Unique Films",
                    value: "\(uniqueFilmsCount)",
                    icon: "sparkles",
                    color: .green
                )
                
                StatCard(
                    title: "Average Rating",
                    value: String(format: "%.2f", averageRatingResolved ?? dashboardStats?.averageRating ?? 0.0),
                    icon: "star.fill",
                    color: .yellow
                )
                
                StatCard(
                    title: selectedYear != nil ? "Avg Films/Month" : "Films This Year",
                    value: selectedYear != nil ? String(format: "%.2f", averageFilmsPerMonth) : "\(dashboardStats?.filmsThisYear ?? 0)",
                    icon: selectedYear != nil ? "calendar.badge.clock" : "calendar",
                    color: .purple
                )
            }
            .padding(.horizontal, 16)
            
            // bottom runtime widget intentionally removed; top header remains
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.blue.opacity(0.05),
                            Color.purple.opacity(0.05)
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
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.blue.opacity(0.5),
                            Color.purple.opacity(0.5)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
    }
}

// MARK: - Stat Card

struct StatCard: View {
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
        VStack(spacing: 10) {
            HStack {
                Spacer()
                Image(systemName: icon)
                    .foregroundStyle(
                        LinearGradient(
                            colors: borderGradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .font(.title2)
                Spacer()
            }
            
            Text(value)
                .font(.system(size: 36, weight: .heavy, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: borderGradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial.opacity(0.4))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: borderGradient.map { $0.opacity(0.4) },
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
        )
    }
}

// MARK: - Streak Components

struct StreakDetailCard: View {
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
                    .foregroundColor(.white)
                
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
                .fill(.ultraThinMaterial.opacity(0.4))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: borderGradient.map { $0.opacity(0.3) },
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.8
                )
        )
        .shadow(
            color: effectiveColor.opacity(0.1),
            radius: 8,
            x: 0,
            y: 4
        )
    }
}

struct StreakSection: View {
    let streakStats: StreakStats?
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
                        .foregroundColor(.white)
                }
                Text("Consecutive days with at least one film")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            
            // Streak Cards
            VStack(spacing: 16) {
                StreakDetailCard(
                    title: "Longest Streak",
                    streakStats: streakStats,
                    streakType: .longest
                )
                
                // Only show current streak for all-time view
                if selectedYear == nil {
                    StreakDetailCard(
                        title: "Current Streak",
                        streakStats: streakStats,
                        streakType: .current
                    )
                }
            }
            .padding(.horizontal, 16)
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
 
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.orange.opacity(0.5),
                            Color.red.opacity(0.5)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
    }
}

// MARK: - Total Runtime Section

struct TotalRuntimeSection: View {
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
                    .foregroundColor(.white)
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
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.purple.opacity(0.5),
                            Color.blue.opacity(0.5)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
    }
}

// MARK: - Rewatch Pie Chart

struct RewatchPieChart: View {
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
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.orange.opacity(0.5),
                            Color.blue.opacity(0.5)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
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
                .foregroundColor(.white)
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
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.orange.opacity(0.5), lineWidth: 1)
            )
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
                
                // Trigger haptic feedback
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
                return
            }
        }
        
        showTooltip = false
    }
}

// MARK: - Rating Distribution Chart

struct RatingDistributionChart: View {
    let distribution: [RatingDistribution]
    @State private var selectedBar: RatingDistribution?
    @State private var chartProxy: ChartProxy?
    
    private var totalFilms: Int {
        distribution.reduce(0) { $0 + $1.count }
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.bar")
                    .foregroundColor(.blue)
                Text("Rating Distribution")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
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
                .opacity(((selectedBar?.ratingValue) ?? -1) == item.ratingValue ? 0.8 : 1.0)
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
            .chartBackground { proxy in
                GeometryReader { geometry in
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .onTapGesture { location in
                            if let plotFrame = proxy.plotFrame {
                                handleRatingTap(at: location, in: geometry, plotFrame: plotFrame)
                            }
                        }
                        .onAppear {
                            chartProxy = proxy
                        }
                }
            }
            .chartLongPress(data: completeDistribution, color: .blue, chartProxy: chartProxy)
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
            
            if let selectedBar = selectedBar {
                let labelText = "\(String(format: "%.1f", selectedBar.ratingValue))★: \(selectedBar.count) films"
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
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.cyan.opacity(0.5),
                            Color.blue.opacity(0.5)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
    }
    
    private func handleRatingTap(at location: CGPoint, in geometry: GeometryProxy, plotFrame: Anchor<CGRect>) {
        let frame = geometry[plotFrame]
        let relativeX = location.x - frame.origin.x
        guard relativeX >= 0, relativeX <= frame.width, completeDistribution.count > 0 else { return }
        
        let step = frame.width / CGFloat(completeDistribution.count)
        let index = Int(floor(relativeX / max(step, 1)))
        
        guard index >= 0, index < completeDistribution.count else { return }
        let tappedItem = completeDistribution[index]
        let same = (selectedBar?.ratingValue ?? -1) == tappedItem.ratingValue
        selectedBar = same ? nil : tappedItem
    }
}

// MARK: - Films by Decade Chart

struct FilmsByDecadeChart: View {
    let filmsByDecade: [FilmsByDecade]
    @State private var selectedBar: FilmsByDecade?
    @State private var chartProxy: ChartProxy?
    
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.orange)
                Text("Films by Decade")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
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
                .opacity(((selectedBar?.decade) ?? -1) == item.decade ? 0.8 : 1.0)
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
            .chartBackground { proxy in
                GeometryReader { geometry in
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .onTapGesture { location in
                            if let plotFrame = proxy.plotFrame {
                                handleDecadeTap(at: location, in: geometry, plotFrame: plotFrame)
                            }
                        }
                        .onAppear {
                            chartProxy = proxy
                        }
                }
            }
            .chartLongPress(data: completeDecadeRange, color: .orange, chartProxy: chartProxy)
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
            
            if let selectedBar = selectedBar {
                let labelText = "\(selectedBar.decade)s: \(selectedBar.count) films"
                SelectionInfoRow(text: labelText, color: .orange)
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
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.red.opacity(0.5),
                            Color.orange.opacity(0.5)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
    }
    
    private func handleDecadeTap(at location: CGPoint, in geometry: GeometryProxy, plotFrame: Anchor<CGRect>) {
        let frame = geometry[plotFrame]
        let relativeX = location.x - frame.origin.x
        guard relativeX >= 0, relativeX <= frame.width, completeDecadeRange.count > 0 else { return }
        
        let step = frame.width / CGFloat(completeDecadeRange.count)
        let index = Int(floor(relativeX / max(step, 1)))
        
        guard index >= 0, index < completeDecadeRange.count else { return }
        let tappedItem = completeDecadeRange[index]
        let same = (selectedBar?.decade ?? -1) == tappedItem.decade
        selectedBar = same ? nil : tappedItem
    }
}

// MARK: - Day of Week Chart

struct DayOfWeekChart: View {
    let dayOfWeekPatterns: [DayOfWeekPattern]
    @State private var selectedBar: DayOfWeekPattern?
    @State private var chartProxy: ChartProxy?
    
    private var totalFilms: Int {
        dayOfWeekPatterns.reduce(0) { $0 + $1.count }
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "calendar.day.timeline.left")
                    .foregroundColor(.yellow)
                Text("Films by Day of Week")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
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
                .opacity(((selectedBar?.dayNumber) ?? -1) == item.dayNumber ? 0.8 : 1.0)
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
            .chartBackground { proxy in
                GeometryReader { geometry in
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .onTapGesture { location in
                            if let plotFrame = proxy.plotFrame {
                                handleDayTap(at: location, in: geometry, plotFrame: plotFrame)
                            }
                        }
                        .onAppear {
                            chartProxy = proxy
                        }
                }
            }
            .chartLongPress(data: completeDayRange, color: .yellow, chartProxy: chartProxy)
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
            
            if let selectedBar = selectedBar {
                let labelText = "\(selectedBar.dayOfWeek): \(selectedBar.count) films"
                SelectionInfoRow(text: labelText, color: .yellow)
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
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.orange.opacity(0.5),
                            Color.yellow.opacity(0.5)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
    }
    
    private func handleDayTap(at location: CGPoint, in geometry: GeometryProxy, plotFrame: Anchor<CGRect>) {
        let frame = geometry[plotFrame]
        let relativeX = location.x - frame.origin.x
        guard relativeX >= 0, relativeX <= frame.width, completeDayRange.count > 0 else { return }
        
        let step = frame.width / CGFloat(completeDayRange.count)
        let index = Int(floor(relativeX / max(step, 1)))
        
        guard index >= 0, index < completeDayRange.count else { return }
        let tappedItem = completeDayRange[index]
        let same = (selectedBar?.dayNumber ?? -1) == tappedItem.dayNumber
        selectedBar = same ? nil : tappedItem
    }
}

// MARK: - Films Per Year Chart

struct FilmsPerYearChart: View {
    let filmsPerYear: [FilmsPerYear]
    @State private var selectedBar: FilmsPerYear?
    @State private var chartProxy: ChartProxy?
    
    private var totalFilms: Int {
        let counts: [Int] = filmsPerYear.map { $0.count }
        return counts.reduce(0, +)
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.green)
                Text("Films Per Year")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
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
                .opacity(((selectedBar?.year) ?? -1) == item.year ? 0.8 : 1.0)
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
            .chartBackground { proxy in
                GeometryReader { geometry in
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .onTapGesture { location in
                            if let plotFrame = proxy.plotFrame {
                                handleYearTap(at: location, in: geometry, plotFrame: plotFrame)
                            }
                        }
                        .onAppear {
                            chartProxy = proxy
                        }
                }
            }
            .chartLongPress(data: filmsPerYear, color: .green, chartProxy: chartProxy)
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
            
            if let selectedBar = selectedBar {
                let labelText = "\(selectedBar.year): \(selectedBar.count) films"
                SelectionInfoRow(text: labelText, color: .green)
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
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.mint.opacity(0.5),
                            Color.green.opacity(0.5)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
    }
    
    private func handleYearTap(at location: CGPoint, in geometry: GeometryProxy, plotFrame: Anchor<CGRect>) {
        let frame = geometry[plotFrame]
        let relativeX = location.x - frame.origin.x
        guard relativeX >= 0, relativeX <= frame.width, filmsPerYear.count > 0 else { return }
        
        let step = frame.width / CGFloat(filmsPerYear.count)
        let index = Int(floor(relativeX / max(step, 1)))
        
        guard index >= 0, index < filmsPerYear.count else { return }
        let tappedItem = filmsPerYear[index]
        let same = (selectedBar?.year ?? -1) == tappedItem.year
        selectedBar = same ? nil : tappedItem
    }
}

// MARK: - Films per Month Chart

struct FilmsPerMonthChart: View {
    let filmsPerMonth: [FilmsPerMonth]
    @State private var selectedBar: FilmsPerMonth?
    @State private var chartProxy: ChartProxy?
    
    private var totalFilms: Int {
        let counts: [Int] = filmsPerMonth.map { $0.count }
        return counts.reduce(0, +)
    }
    
    private var monthAxisValues: [Int] {
        guard !filmsPerMonth.isEmpty else { return Array(1...12) }
        return filmsPerMonth.map { $0.month }.sorted()
    }
    
    private func monthName(for monthNumber: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        return formatter.shortMonthSymbols[monthNumber - 1]
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.blue)
                Text("Films Per Month")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                Spacer()
                Text("\(totalFilms) films")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            
            Chart(filmsPerMonth, id: \.month) { item in
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
                .opacity(((selectedBar?.month) ?? -1) == item.month ? 0.8 : 1.0)
            }
            .frame(height: 200)
            .chartXAxis(.hidden)
            .chartXScale(domain: 0.5...12.5)
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                        .foregroundStyle(.gray.opacity(0.2))
                    AxisValueLabel()
                        .font(.system(size: 10, design: .rounded))
                }
            }
            .chartBackground { proxy in
                GeometryReader { geometry in
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .onTapGesture { location in
                            if let plotFrame = proxy.plotFrame {
                                handleMonthTap(at: location, in: geometry, plotFrame: plotFrame)
                            }
                        }
                        .onAppear {
                            chartProxy = proxy
                        }
                }
            }
            .chartLongPress(data: filmsPerMonth, color: .blue, chartProxy: chartProxy)
            .padding(.horizontal, 12)
            
            // Highest month indicator
            if let highestMonth = filmsPerMonth.max(by: { $0.count < $1.count }) {
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
            
            if let selectedBar = selectedBar {
                let labelText = "\(monthName(for: selectedBar.month)): \(selectedBar.count) films"
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
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.cyan.opacity(0.5),
                            Color.blue.opacity(0.5)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
    }
    
    private func handleMonthTap(at location: CGPoint, in geometry: GeometryProxy, plotFrame: Anchor<CGRect>) {
        let frame = geometry[plotFrame]
        let relativeX = location.x - frame.origin.x
        guard relativeX >= 0, relativeX <= frame.width, filmsPerMonth.count > 0 else { return }
        
        let step = frame.width / 12.0  // 12 months
        let month = Int(round(relativeX / step)) + 1
        
        guard month >= 1, month <= 12 else { return }
        guard let tappedItem = filmsPerMonth.first(where: { $0.month == month }) else { return }
        
        let same = (selectedBar?.month ?? -1) == tappedItem.month
        selectedBar = same ? nil : tappedItem
    }
}

// MARK: - Weekly Films Chart

struct WeeklyFilmsChart: View {
    let weeklyData: [WeeklyFilmsData]
    let selectedYear: Int
    @State private var selectedBar: WeeklyFilmsData?
    @State private var chartProxy: ChartProxy?
    
    private var totalFilms: Int {
        weeklyData.reduce(0) { $0 + $1.count }
    }
    
    private var chartXDomain: ClosedRange<Double> {
        let weekNumbers: [Int] = weeklyData.map { $0.weekNumber }
        let maxWeek: Int = weekNumbers.max() ?? 52
        let maxWeekPlusOne: Int = maxWeek + 1
        let upperBound: Double = Double(maxWeekPlusOne)
        let lowerBound: Double = 0
        return lowerBound...upperBound
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
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.pink.opacity(0.5),
                            Color.purple.opacity(0.5)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
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
                .foregroundColor(.white)
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
            }
            .chartXScale(domain: chartXDomain)
            .frame(height: 200)
            .chartXAxis {
                weeklyXAxis
            }
            .chartYAxis {
                weeklyYAxis
            }
            .chartBackground { proxy in
                weeklyChartBackground(proxy: proxy)
            }
            .chartLongPress(data: weeklyData, color: .purple, chartProxy: chartProxy)
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
            width: .fixed(8)
        )
        .foregroundStyle(weeklyBarGradient)
        .cornerRadius(4)
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
        let isSelected = (selectedBar?.weekNumber ?? -1) == item.weekNumber
        return isSelected ? 0.8 : 1.0
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
    
    private func weeklyChartBackground(proxy: ChartProxy) -> some View {
        GeometryReader { geometry in
            Rectangle()
                .fill(Color.clear)
                .contentShape(Rectangle())
                .onTapGesture { location in
                    handleWeeklyTap(at: location, in: geometry, proxy: proxy)
                }
                .onAppear {
                    chartProxy = proxy
                }
        }
    }
    
    private func handleWeeklyTap(at location: CGPoint, in geometry: GeometryProxy, proxy: ChartProxy) {
        if let plotFrame = proxy.plotFrame {
            handleWeekTap(at: location, in: geometry, plotFrame: plotFrame)
        }
    }
    
    @ViewBuilder
    private var weeklySelectionInfo: some View {
        if let selectedBar = selectedBar {
            let labelText = "\(selectedBar.weekLabel): \(selectedBar.count) films"
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
    
    private func handleWeekTap(at location: CGPoint, in geometry: GeometryProxy, plotFrame: Anchor<CGRect>) {
        let frame = geometry[plotFrame]
        let relativeX = location.x - frame.origin.x
        guard relativeX >= 0, relativeX <= frame.width, weeklyData.count > 0 else { return }
        
        let step = frame.width / CGFloat(weeklyData.count)
        let index = Int(floor(relativeX / max(step, 1)))
        
        guard index >= 0, index < weeklyData.count else { return }
        let tappedItem = weeklyData[index]
        let same = (selectedBar?.weekNumber ?? -1) == tappedItem.weekNumber
        selectedBar = same ? nil : tappedItem
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
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.green.opacity(0.5),
                            Color.cyan.opacity(0.5)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
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
                .foregroundColor(.white)
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
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.green.opacity(0.5), lineWidth: 1)
            )
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
                
                // Trigger haptic feedback
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
                return
            }
        }
        
        showTooltip = false
    }
}

// MARK: - Top Watched Films Section

struct TopWatchedFilmsSection: View {
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
                        .foregroundColor(.white)
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
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.orange.opacity(0.5),
                            Color.red.opacity(0.5)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
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
    @StateObject private var movieService = SupabaseMovieService.shared
    
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

// MARK: - Advanced Film Journey Section

struct AdvancedFilmJourneySection: View {
    let advancedStats: AdvancedFilmJourneyStats
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "chart.bar.doc.horizontal")
                        .font(.title2)
                        .gradientForeground([
                            .indigo,
                            .cyan
                        ], start: .topLeading, end: .bottomTrailing)
                    Text("More Statistics")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                Text("Additional insights into your viewing patterns")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            
            // Stats Cards Grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                UniformStatCard(
                    title: "2+ Film Days",
                    value: "\(advancedStats.daysWith2PlusFilms)",
                    subtitle: nil,
                    icon: "calendar.badge.plus",
                    color: .orange
                )
                
                UniformStatCard(
                    title: "Avg/Year",
                    value: String(format: "%.1f", advancedStats.averageMoviesPerYear),
                    subtitle: nil,
                    icon: "chart.line.uptrend.xyaxis",
                    color: .green
                )
                
                UniformStatCard(
                    title: "5-Star Films",
                    value: "\(advancedStats.unique5StarFilms)",
                    subtitle: nil,
                    icon: "star.fill",
                    color: .yellow
                )
                
                // Highest Monthly Average
                if let highestMonth = advancedStats.highestMonthlyAverage {
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
            }
            .padding(.horizontal, 16)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.blue.opacity(0.05),
                            Color.purple.opacity(0.05)
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
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.blue.opacity(0.5),
                            Color.purple.opacity(0.5)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
    }
}

// MARK: - Year-Filtered Advanced Film Journey Section

struct YearFilteredAdvancedJourneySection: View {
    let yearFilteredStats: YearFilteredAdvancedJourneyStats
    let selectedYear: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "calendar.badge.clock")
                        .font(.title2)
                        .gradientForeground([
                            .teal,
                            .cyan
                        ], start: .topLeading, end: .bottomTrailing)
                    Text("More Statistics")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                Text("Additional insights into your viewing patterns")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            
            // Stats Cards Grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                UniformStatCard(
                    title: "2+ Film Days",
                    value: "\(yearFilteredStats.daysWith2PlusFilms)",
                    subtitle: nil,
                    icon: "calendar.badge.plus",
                    color: .orange
                )
                
                // Must Watch Completion
                if let mustWatch = yearFilteredStats.mustWatchCompletion {
                    UniformStatCard(
                        title: "Must Watches",
                        value: "\(Int(mustWatch.completionPercentage))%",
                        subtitle: "\(mustWatch.watchedFilms)/\(mustWatch.totalFilms) completed",
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
                
                UniformStatCard(
                    title: "New 5-Stars",
                    value: "\(yearFilteredStats.unique5StarFilms)",
                    subtitle: "First time rated",
                    icon: "star.fill",
                    color: .yellow
                )
                
                // Highest Monthly Average
                if let highestMonth = yearFilteredStats.highestMonthlyAverage {
                    UniformStatCard(
                        title: "Best Month",
                        value: String(format: "%.2f", highestMonth.averageRating),
                        subtitle: "\(highestMonth.monthName.trimmingCharacters(in: .whitespacesAndNewlines)) (\(highestMonth.filmCount) films)",
                        icon: "trophy.fill",
                        color: .purple
                    )
                } else {
                    UniformStatCard(
                        title: "Best Month",
                        value: "N/A",
                        subtitle: "Insufficient data",
                        icon: "trophy.fill",
                        color: .purple
                    )
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.blue.opacity(0.05),
                            Color.purple.opacity(0.05)
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
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.blue.opacity(0.5),
                            Color.purple.opacity(0.5)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
    }
}

// MARK: - Uniform Stat Card

struct UniformStatCard: View {
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
        VStack(spacing: 10) {
            HStack {
                Spacer()
                Image(systemName: icon)
                    .foregroundStyle(
                        LinearGradient(
                            colors: borderGradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .font(.title2)
                Spacer()
            }
            
            Text(value)
                .font(.system(size: 36, weight: .heavy, design: .rounded))
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
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundColor(color)
                        .fontWeight(.medium)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            }
            .frame(minHeight: subtitle != nil ? 32 : 16) // Ensure consistent height
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial.opacity(0.4))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: borderGradient.map { $0.opacity(0.4) },
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
        )
        .aspectRatio(1.0, contentMode: .fit) // Force square aspect ratio
    }
}

// MARK: - Average Star Rating Per Year Chart

struct AverageStarRatingPerYearChart: View {
    let averageStarRatings: [AverageStarRatingPerYear]
    @State private var selectedBar: AverageStarRatingPerYear?
    @State private var chartProxy: ChartProxy?
    
    private var totalFilms: Int {
        averageStarRatings.reduce(0) { $0 + $1.count }
    }
    
    private var yearRange: (min: Int, max: Int) {
        guard !averageStarRatings.isEmpty else { return (2020, 2025) }
        let years = averageStarRatings.map { $0.year }
        return (years.min() ?? 2020, years.max() ?? 2025)
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
                .opacity(((selectedBar?.year) ?? -1) == item.year ? 0.8 : 1.0)
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
            .chartBackground { proxy in
                GeometryReader { geometry in
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .onTapGesture { location in
                            if let plotFrame = proxy.plotFrame {
                                handleYearTap(at: location, in: geometry, plotFrame: plotFrame)
                            }
                        }
                        .onAppear {
                            chartProxy = proxy
                        }
                }
            }
            .chartLongPress(data: averageStarRatings, color: .yellow, chartProxy: chartProxy)
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
            
            if let selectedBar = selectedBar {
                let labelText = "\(selectedBar.year): \(String(format: "%.2f", selectedBar.averageRating))★ (\(selectedBar.count) films)"
                SelectionInfoRow(text: labelText, color: .yellow)
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
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.blue.opacity(0.5),
                            Color.orange.opacity(0.5)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
    }
    
    private func handleYearTap(at location: CGPoint, in geometry: GeometryProxy, plotFrame: Anchor<CGRect>) {
        let frame = geometry[plotFrame]
        let relativeX = location.x - frame.origin.x
        guard relativeX >= 0, relativeX <= frame.width, averageStarRatings.count > 0 else { return }
        
        let step = frame.width / CGFloat(averageStarRatings.count)
        let index = Int(floor(relativeX / max(step, 1)))
        
        guard index >= 0, index < averageStarRatings.count else { return }
        let tappedItem = averageStarRatings[index]
        let same = (selectedBar?.year ?? -1) == tappedItem.year
        selectedBar = same ? nil : tappedItem
    }
}

// MARK: - Average Detailed Rating Per Year Chart

struct AverageDetailedRatingPerYearChart: View {
    let averageDetailedRatings: [AverageDetailedRatingPerYear]
    @State private var selectedBar: AverageDetailedRatingPerYear?
    @State private var chartProxy: ChartProxy?
    
    private var totalFilms: Int {
        averageDetailedRatings.reduce(0) { $0 + $1.count }
    }
    
    private var yearRange: (min: Int, max: Int) {
        guard !averageDetailedRatings.isEmpty else { return (2020, 2025) }
        let years = averageDetailedRatings.map { $0.year }
        return (years.min() ?? 2020, years.max() ?? 2025)
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
                .opacity(((selectedBar?.year) ?? -1) == item.year ? 0.8 : 1.0)
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
            .chartBackground { proxy in
                GeometryReader { geometry in
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .onTapGesture { location in
                            if let plotFrame = proxy.plotFrame {
                                handleYearTap(at: location, in: geometry, plotFrame: plotFrame)
                            }
                        }
                        .onAppear {
                            chartProxy = proxy
                        }
                }
            }
            .chartLongPress(data: averageDetailedRatings, color: .cyan, chartProxy: chartProxy)
            .padding(.horizontal, 12)
            
            // Highest average detailed rating year indicator
            if let highestAvgDetailedYear = averageDetailedRatings.max(by: { $0.averageRating < $1.averageRating }) {
                HStack {
                    Spacer()
                    Text("\(String(highestAvgDetailedYear.year)) - \(String(format: "%.1f", highestAvgDetailedYear.averageRating))/100")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(
                                    LinearGradient(
                                        colors: [.cyan.opacity(0.8), .purple.opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                    Spacer()
                }
                .padding(.horizontal, 12)
            }
            
            if let selectedBar = selectedBar {
                let labelText = "\(selectedBar.year): \(String(format: "%.1f", selectedBar.averageRating))/100 (\(selectedBar.count) films)"
                SelectionInfoRow(text: labelText, color: .cyan)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.cyan.opacity(0.05),
                            Color.purple.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.cyan.opacity(0.5),
                            Color.purple.opacity(0.5)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
    }
    
    private func handleYearTap(at location: CGPoint, in geometry: GeometryProxy, plotFrame: Anchor<CGRect>) {
        let frame = geometry[plotFrame]
        let relativeX = location.x - frame.origin.x
        guard relativeX >= 0, relativeX <= frame.width, averageDetailedRatings.count > 0 else { return }
        
        let step = frame.width / CGFloat(averageDetailedRatings.count)
        let index = Int(floor(relativeX / max(step, 1)))
        
        guard index >= 0, index < averageDetailedRatings.count else { return }
        let tappedItem = averageDetailedRatings[index]
        let same = (selectedBar?.year ?? -1) == tappedItem.year
        selectedBar = same ? nil : tappedItem
    }
}

#Preview {
    StatisticsView()
}

//
//  HomeView.swift
//  reelay2
//
//  Created by Humza Khalil on 8/28/25.
//

import SwiftUI
import SDWebImageSwiftUI

struct HomeView: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var movieService = SupabaseMovieService.shared
    @ObservedObject private var statisticsService = SupabaseStatisticsService.shared
    @ObservedObject private var dataManager = DataManager.shared
    @State private var recentMovies: [Movie] = []
    @State private var isLoading = false
    @State private var isInitialLoad = true
    @State private var showingAddMovie = false
    @State private var showingAddTelevision = false
    @State private var showingAddAlbum = false
    @State private var showingAddToWatchlist = false
    @State private var selectedMovie: Movie?
    @State private var movieToEdit: Movie?
    @State private var movieToDelete: Movie?
    @State private var showingDeleteMovieAlert: Bool = false
    @State private var movieToLogAgain: Movie?
    @State private var showingLogAgain = false
    @State private var movieToAddToLists: Movie?
    @State private var movieToChangePoster: Movie?
    @State private var movieToChangeBackdrop: Movie?
    @State private var showingGoalsSettings = false
    @State private var selectedUpcomingMovie: Movie?
    @State private var showingRandomizer = false
    @State private var showingMustWatchesList = false
    @State private var showingLookingForwardList = false
    @State private var showingThemedList = false
    @State private var selectedThemedList: MovieList?
    
    // Theater Planner (Fantastical-style three-state)
    @State private var plannerDetent: PlannerDetent = .compact
    @State private var plannerSelectedDate: Date = Date()
    @State private var plannerCalendarMonth: Date = Date()
    
    // Television Data
    @State private var currentlyWatchingShows: [Television] = []
    @State private var selectedTelevisionShow: Television?
    @State private var televisionService = SupabaseTelevisionService.shared
    @State private var showingDeleteTelevisionAlert: Bool = false
    @State private var televisionToDelete: Television?
    
    // Upcoming Films Data
    @State private var upcomingFilms: [ListItem] = []

    // On This Day Data
    @State private var onThisDayMovies: [OnThisDayMovie] = []

    // Quick Stats Data
    @State private var filmsThisMonth: Int = 0
    @State private var highestRatedFilmThisMonth: Movie?
    @State private var highestRatedFilmValue: String = "—"
    @State private var highestRatedFilmTitle: String = ""
    @State private var currentStreak: Int = 0
    
    // Year Stats Data (for top static stats boxes)
    @State private var filmsThisYear: Int = 0
    @State private var averageRatingThisYear: Double = 0.0
    @State private var formattedAverageRating: String = "0.00"
    @State private var currentYearReleasesWatched: Int = 0
    
    // Caching mechanism
    @State private var lastDataLoadTime: Date?
    @State private var hasLoadedInitially = false
    private let cacheRefreshInterval: TimeInterval = 300 // 5 minutes
    private let homeHorizontalPadding: CGFloat = 20
    
    // Planner detent heights
    private let compactPlannerHeight: CGFloat = 60
    
    #if os(macOS)
    @EnvironmentObject private var navigationCoordinator: NavigationCoordinator
    #endif
    
    // Static formatters to avoid recreation
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
    
    private static let displayDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    private var appBackground: Color {
        #if os(macOS)
        colorScheme == .dark ? .black : Color(NSColor.windowBackgroundColor)
        #else
        colorScheme == .dark ? .black : Color(.systemGroupedBackground)
        #endif
    }

    var body: some View {
        GeometryReader { geometry in
            let fullPlannerHeight = geometry.size.height * 0.85
            
            VStack(spacing: 0) {
                // Theater Planner (variable height based on detent)
                TheaterPlannerView(
                    selectedDate: $plannerSelectedDate,
                    currentCalendarMonth: $plannerCalendarMonth,
                    plannerDetent: plannerDetent
                )
                .frame(height: plannerDetentHeight(full: fullPlannerHeight), alignment: .top)
                .clipped()
                .animation(.spring(response: 0.4, dampingFraction: 0.85), value: plannerDetent)
                
                // Drag handle / chevron
                plannerDragHandle
                    .gesture(
                        DragGesture(minimumDistance: 5)
                            .onEnded { value in
                                let verticalMovement = value.translation.height
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                    if plannerDetent == .compact && verticalMovement > 40 {
                                        plannerDetent = .full
                                        Task { await dataManager.refreshTheaterVisits() }
                                    } else if plannerDetent == .full && verticalMovement < -40 {
                                        plannerDetent = .compact
                                    }
                                }
                            }
                    )
                
                // Home content
                ZStack {
                    if isInitialLoad {
                        SkeletonHomeContent()
                    } else if isLoading {
                        ZStack {
                            Color.clear

                            VStack(spacing: 20) {
                                ProgressView()
                                    .scaleEffect(1.5)
                                    .progressViewStyle(CircularProgressViewStyle(tint: Color.adaptiveText(scheme: colorScheme)))

                                Text("Finishing a film...")
                                    .font(.headline)
                                    .foregroundColor(Color.adaptiveText(scheme: colorScheme))
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.adaptiveOverlay(scheme: colorScheme, intensity: 0.3))
                        }
                    } else {
                        ScrollView {
                            VStack(spacing: 0) {
                                yearStatsSection
                                
                                if dataManager.yearlyFilmGoal > 0 || !dataManager.movieLists.isEmpty {
                                    goalsSection
                                }

                                if !onThisDayMovies.isEmpty {
                                    OnThisDayView(
                                        movies: onThisDayMovies,
                                        onMovieTapped: { movie in
                                            selectedMovie = movie
                                        }
                                    )
                                }

                                if !currentlyWatchingShows.isEmpty {
                                    currentlyWatchingShowsSection
                                }

                                if !recentMovies.isEmpty {
                                    recentlyLoggedSection
                                }

                                if !upcomingFilms.isEmpty {
                                    upcomingFilmsSection
                                }

                                Spacer()
                            }
                            .padding(.top, 20)
                            .padding(.horizontal, homeHorizontalPadding)
                        }
                        .refreshable {
                            await refreshAllData()
                        }
                    }
                }
            }
        }
        .navigationTitle("Home")
        #if canImport(UIKit)
        .toolbarTitleDisplayMode(.inlineLarge)
        #endif
        .toolbar {
            ToolbarItemGroup {
                Button(action: {
                    showingRandomizer = true
                }) {
                    Image(systemName: "dice")
                }
                
                Button(action: {
                    showingGoalsSettings = true
                }) {
                    Image(systemName: "target")
                }
            }
            
            ToolbarSpacer(.fixed)
            
            ToolbarItem(placement: .automatic) {
                Menu {
                    Button(action: {
                        showingAddMovie = true
                    }) {
                        Label("Add Movie", systemImage: "film")
                    }
                    
                    Button(action: {
                        showingAddTelevision = true
                    }) {
                        Label("Add TV Show", systemImage: "tv")
                    }
                    
                    Button(action: {
                        showingAddAlbum = true
                    }) {
                        Label("Add Album", systemImage: "music.note")
                    }
                    
                    Button(action: {
                        showingAddToWatchlist = true
                    }) {
                        Label("Add to Watchlist", systemImage: "bookmark")
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddMovie) {
            AddMoviesView()
        }
        .sheet(isPresented: $showingAddTelevision) {
            AddTelevisionView()
        }
        .sheet(isPresented: $showingAddAlbum) {
            AddAlbumsView()
        }
        .sheet(isPresented: $showingAddToWatchlist) {
            WatchlistEditView()
        }
        .sheet(isPresented: $showingGoalsSettings) {
            GoalsSettingsView()
        }
        .sheet(isPresented: $showingRandomizer) {
            WatchlistRandomizerView()
        }
        #if os(iOS)
        .sheet(isPresented: $showingMustWatchesList) {
            if let mustWatchesList = dataManager.movieLists.first(where: { $0.name == "Must Watches for \(Calendar.current.component(.year, from: Date()))" }) {
                ListDetailsView(list: mustWatchesList)
            } else {
                Text("Must Watches list not found")
                    .foregroundColor(.secondary)
            }
        }
        .sheet(isPresented: $showingLookingForwardList) {
            if let lookingForwardList = dataManager.movieLists.first(where: { $0.name == "Looking Forward in \(Calendar.current.component(.year, from: Date()))" }) {
                ListDetailsView(list: lookingForwardList)
            } else {
                Text("Looking Forward list not found")
                    .foregroundColor(.secondary)
            }
        }
        #else
        .onChange(of: showingMustWatchesList) { _, showing in
            if showing, let mustWatchesList = dataManager.movieLists.first(where: { $0.name == "Must Watches for \(Calendar.current.component(.year, from: Date()))" }) {
                navigationCoordinator.showListDetails(mustWatchesList)
                showingMustWatchesList = false
            }
        }
        .onChange(of: showingLookingForwardList) { _, showing in
            if showing, let lookingForwardList = dataManager.movieLists.first(where: { $0.name == "Looking Forward in \(Calendar.current.component(.year, from: Date()))" }) {
                navigationCoordinator.showListDetails(lookingForwardList)
                showingLookingForwardList = false
            }
        }
        #endif
        #if os(iOS)
        .sheet(isPresented: $showingThemedList) {
            if let themedList = selectedThemedList {
                ListDetailsView(list: themedList)
            }
        }
        .sheet(item: $selectedUpcomingMovie) { movie in
            MovieDetailsView(movie: movie)
        }
        .sheet(item: $selectedTelevisionShow) { show in
            TelevisionDetailsView(televisionShow: show)
        }
        .sheet(item: $selectedMovie) { movie in
            MovieDetailsView(movie: movie)
        }
        #else
        .onChange(of: showingThemedList) { _, showing in
            if showing, let themedList = selectedThemedList {
                navigationCoordinator.showListDetails(themedList)
                showingThemedList = false
            }
        }
        .onChange(of: selectedUpcomingMovie) { _, movie in
            if let movie = movie {
                navigationCoordinator.showMovieDetails(movie)
                selectedUpcomingMovie = nil
            }
        }
        .onChange(of: selectedTelevisionShow) { _, show in
            if let show = show {
                navigationCoordinator.showTelevisionDetails(show)
                selectedTelevisionShow = nil
            }
        }
        .onChange(of: selectedMovie) { _, movie in
            if let movie = movie {
                navigationCoordinator.showMovieDetails(movie)
                selectedMovie = nil
            }
        }
        #endif
        .sheet(item: $movieToEdit) { movie in
            EditMovieView(movie: movie) { updated in
                updateMovieInPlace(updated)
            }
        }
        .sheet(isPresented: $showingLogAgain) {
            if let movie = movieToLogAgain, movie.tmdb_id != nil {
                AddMoviesView(preSelectedMovie: TMDBMovie(from: movie))
            }
        }
        .sheet(item: $movieToAddToLists) { movie in
            AddToListsView(movie: movie)
        }
        .sheet(item: $movieToChangePoster) { movie in
            if let tmdbId = movie.tmdb_id {
                PosterChangeView(
                    tmdbId: tmdbId,
                    currentPosterUrl: movie.poster_url,
                    movieTitle: movie.title
                ) { newPosterUrl in
                    // Refresh data from backend
                    Task {
                        await loadAllDataIfNeeded(force: true)
                    }
                }
            }
        }
        .sheet(item: $movieToChangeBackdrop) { movie in
            if let tmdbId = movie.tmdb_id {
                BackdropChangeView(
                    tmdbId: tmdbId,
                    currentBackdropUrl: movie.backdrop_path,
                    movieTitle: movie.title
                ) { newBackdropUrl in
                    // Refresh data from backend
                    Task {
                        await loadAllDataIfNeeded(force: true)
                    }
                }
            }
        }
        .alert("Delete Entry", isPresented: $showingDeleteMovieAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let movie = movieToDelete {
                    Task { await deleteMovie(movie) }
                }
            }
        } message: {
            if let movie = movieToDelete {
                Text("Remove '\(movie.title)' from your diary?")
            } else {
                Text("")
            }
        }
        .alert("Delete TV Show", isPresented: $showingDeleteTelevisionAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let show = televisionToDelete {
                    Task { await deleteTelevisionShow(show) }
                }
            }
        } message: {
            if let show = televisionToDelete {
                Text("Remove '\(show.name)' from your TV shows?")
            } else {
                Text("")
            }
        }
        .task {
            if movieService.isLoggedIn {
                await loadAllDataIfNeeded(force: false)
            }
        }
        .onChange(of: movieService.isLoggedIn) { _, isLoggedIn in
            if isLoggedIn {
                Task {
                    await loadAllDataIfNeeded(force: true)
                }
            } else {
                isLoading = false
                isInitialLoad = true
                recentMovies = []
                currentlyWatchingShows = []
                upcomingFilms = []
                onThisDayMovies = []
                filmsThisMonth = 0
                highestRatedFilmThisMonth = nil
                highestRatedFilmValue = "—"
                highestRatedFilmTitle = ""
                currentStreak = 0
                filmsThisYear = 0
                averageRatingThisYear = 0.0
                formattedAverageRating = "0.00"
                currentYearReleasesWatched = 0
                lastDataLoadTime = nil
                hasLoadedInitially = false
            }
        }
        .onChange(of: showingAddMovie) { _, isShowing in
            if !isShowing && movieService.isLoggedIn {
                // Only refresh data that is affected by adding a movie
                Task {
                    async let recentTask = loadRecentMovies()
                    async let quickStatsTask = loadQuickStats()
                    async let yearStatsTask = loadYearStats()
                    await recentTask
                    await quickStatsTask
                    await yearStatsTask
                }
            }
        }
        .onChange(of: showingAddTelevision) { _, isShowing in
            if !isShowing && movieService.isLoggedIn {
                // Only refresh television data
                Task {
                    await loadCurrentlyWatchingShows()
                }
            }
        }
        .onChange(of: showingAddAlbum) { _, isShowing in
            if !isShowing && movieService.isLoggedIn {
                // Refresh data when add album sheet is dismissed
                Task {
                    await DataManager.shared.refreshAlbums()
                }
            }
        }
        .onChange(of: showingLogAgain) { _, isShowing in
            if !isShowing && movieService.isLoggedIn {
                // Only refresh movie-related data for log again
                Task {
                    async let recentTask = loadRecentMovies()
                    async let quickStatsTask = loadQuickStats()
                    async let yearStatsTask = loadYearStats()
                    await recentTask
                    await quickStatsTask
                    await yearStatsTask
                }
            }
        }
    }
    

    
    // MARK: - Planner Height Helper
    
    private func plannerDetentHeight(full: CGFloat) -> CGFloat {
        switch plannerDetent {
        case .compact:
            return compactPlannerHeight
        case .full:
            return full
        }
    }
    
    // MARK: - Planner Drag Handle
    
    @ViewBuilder
    private var plannerDragHandle: some View {
        Button(action: {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                if plannerDetent == .compact {
                    plannerDetent = .full
                    Task { await dataManager.refreshTheaterVisits() }
                } else {
                    plannerDetent = .compact
                }
            }
        }) {
            // Single grabber: pill when compact, up-chevron when expanded
            Group {
                if plannerDetent == .full {
                    Image(systemName: "chevron.compact.up")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(Color.gray.opacity(0.45))
                } else {
                    RoundedRectangle(cornerRadius: 2.5)
                        .fill(Color.gray.opacity(0.45))
                        .frame(width: 40, height: 5)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 26)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Upcoming Films Section
    
    @ViewBuilder
    private var upcomingFilmsSection: some View {
        VStack(spacing: 0) {
            // Section header
            HStack {
                Text("Upcoming Films")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(Color.adaptiveText(scheme: colorScheme))
                Spacer()
            }
            .padding(.top, 12)
            .padding(.bottom, 16)
            
            // Horizontal scrollable movie posters row
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(upcomingFilms.prefix(15)) { item in
                        upcomingMoviePosterView(for: item)
                    }
                }
            }
            .padding(.bottom, 20)
        }
    }
    
    @ViewBuilder
    private func upcomingMoviePosterView(for item: ListItem) -> some View {
        Button(action: {
            // Check if this movie is already logged
            Task {
                await checkIfMovieIsLoggedAndNavigate(item: item)
            }
        }) {
            VStack(spacing: 8) {
                WebImage(url: item.posterURL) { image in
                    image
                        .resizable()
                        .aspectRatio(2/3, contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .aspectRatio(2/3, contentMode: .fill)
                }
                .frame(width: 100, height: 150)
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                
                // Release date below poster
                if let releaseDateString = item.movieReleaseDate {
                    Text(formatReleaseDate(releaseDateString))
                        .font(.caption2)
                        .foregroundColor(Color.adaptiveText(scheme: colorScheme))
                        .lineLimit(1)
                        .frame(height: 16, alignment: .top)
                } else {
                    Text("TBA")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .frame(height: 16, alignment: .top)
                }
            }
            .frame(width: 100)
        }
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            // Create a temporary Movie object for context menu actions
            let tempMovie = createTempMovieFromListItem(item)
            
            Button("Log Movie", systemImage: "plus.circle") {
                // Navigate to add movie with this item pre-selected
                let tmdbMovie = createTMDBMovieFromListItem(item)
                // We need to trigger the add movie sheet with pre-selected movie
                // This would require modifying AddMoviesView to accept a pre-selected movie
                showingAddMovie = true
            }
            
            Button("Add to List", systemImage: "list.bullet") {
                movieToAddToLists = tempMovie
            }
            
            Button("View Details", systemImage: "info.circle") {
                selectedUpcomingMovie = tempMovie
            }
        }
    }
    
    // MARK: - Currently Watching TV Shows Section
    
    @ViewBuilder
    private var currentlyWatchingShowsSection: some View {
        VStack(spacing: 0) {
            // Section header
            HStack {
                Text("Currently Watching")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(Color.adaptiveText(scheme: colorScheme))
                Spacer()
            }
            .padding(.top, 12)
            .padding(.bottom, 16)
            
            // Horizontal scrollable TV show posters row
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(currentlyWatchingShows.prefix(15)) { show in
                        televisionPosterView(for: show)
                    }
                }
            }
            .padding(.bottom, 20)
        }
    }
    
    @ViewBuilder
    private func televisionPosterView(for show: Television) -> some View {
        Button(action: {
            selectedTelevisionShow = show
        }) {
            VStack(spacing: 8) {
                WebImage(url: show.posterURL) { image in
                    image
                        .resizable()
                        .aspectRatio(2/3, contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .aspectRatio(2/3, contentMode: .fill)
                }
                .frame(width: 100, height: 150)
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)

                // Episode progress below poster
                Text(show.progressText)
                    .font(.caption2)
                    .foregroundColor(Color.adaptiveText(scheme: colorScheme))
                    .lineLimit(1)
                    .frame(height: 16, alignment: .top)
            }
        }
        .frame(width: 100)
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            // Next Episode
            if let currentSeason = show.current_season,
               let currentEpisode = show.current_episode {
                Button("Next Episode", systemImage: "forward.fill") {
                    Task {
                        await updateTelevisionProgress(show: show, season: currentSeason, episode: currentEpisode + 1)
                    }
                }
                
                // Previous Episode (only if not at episode 1)
                if currentEpisode > 1 {
                    Button("Previous Episode", systemImage: "backward.fill") {
                        Task {
                            await updateTelevisionProgress(show: show, season: currentSeason, episode: currentEpisode - 1)
                        }
                    }
                }
            }
            
            // Mark as Complete
            if show.status != "completed" {
                Button("Mark Complete", systemImage: "checkmark.circle") {
                    Task {
                        await updateTelevisionStatus(show: show, status: .completed)
                    }
                }
            }
            
            // Mark as Watching (if not currently watching)
            if show.status != "watching" {
                Button("Mark as Watching", systemImage: "play.circle") {
                    Task {
                        await updateTelevisionStatus(show: show, status: .watching)
                    }
                }
            }
            
            Button("Remove Show", systemImage: "trash", role: .destructive) {
                televisionToDelete = show
                showingDeleteTelevisionAlert = true
            }
        }
    }
    
    // MARK: - Recently Logged Section
    
    @ViewBuilder
    private var recentlyLoggedSection: some View {
        VStack(spacing: 0) {
            // Section header (similar to Month/Year header in MoviesView)
            HStack {
                Text("Recently Logged")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(Color.adaptiveText(scheme: colorScheme))
                Spacer()
            }
            .padding(.top, 12)
            .padding(.bottom, 16)
            
            // Horizontal scrollable movie posters row
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(recentMovies.prefix(15)) { movie in
                        moviePosterView(for: movie)
                    }
                }
            }
            .padding(.bottom, 20)
        }
    }
    
    @ViewBuilder
    private func moviePosterView(for movie: Movie) -> some View {
        Button(action: {
            selectedMovie = movie
        }) {
            VStack(spacing: 8) {
                WebImage(url: movie.posterURL) { image in
                    image
                        .resizable()
                        .aspectRatio(2/3, contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .aspectRatio(2/3, contentMode: .fill)
                }
                .frame(width: 100, height: 150)
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)

                // Movie title below poster
                Text(movie.title)
                    .font(.caption2)
                    .foregroundColor(Color.adaptiveText(scheme: colorScheme))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(height: 32, alignment: .top)
            }
        }
        .frame(width: 100)
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            Button("Log Again", systemImage: "plus.circle") {
                movieToLogAgain = movie
                showingLogAgain = true
            }
            Button("Add to List", systemImage: "list.bullet") {
                movieToAddToLists = movie
            }
            Button("Edit Entry", systemImage: "pencil") {
                movieToEdit = movie
            }
            if movie.tmdb_id != nil {
                Button("Change Poster", systemImage: "photo") {
                    movieToChangePoster = movie
                }
                Button("Change Backdrop", systemImage: "rectangle.on.rectangle") {
                    movieToChangeBackdrop = movie
                }
            }
            Button("Remove Entry", systemImage: "trash", role: .destructive) {
                movieToDelete = movie
                showingDeleteMovieAlert = true
            }
        }
    }
    
    // MARK: - Data Loading Functions
    
    private func loadCurrentlyWatchingShows() async {
        do {
            // Refresh television data first
            await dataManager.refreshTelevision()
            
            // Get currently watching shows and sort by last updated (most recent first)
            let watchingShows = dataManager.getCurrentlyWatchingShows()
            let sortedShows = sortCurrentlyWatchingShows(watchingShows)
            
            await MainActor.run {
                currentlyWatchingShows = Array(sortedShows.prefix(15))
            }
        } catch {
            await MainActor.run {
                currentlyWatchingShows = []
            }
        }
    }
    
    private func loadUpcomingFilms() async {
        do {
            let currentYear = Calendar.current.component(.year, from: Date())
            let lookingForwardListName = "Looking Forward in \(currentYear)"
            
            // Find the "Looking Forward" list for current year
            let allLists = dataManager.movieLists
            guard let lookingForwardList = allLists.first(where: { $0.name == lookingForwardListName }) else {
                await MainActor.run {
                    upcomingFilms = []
                }
                return
            }
            
            // Get items from the list
            let listItems = dataManager.getListItems(lookingForwardList)
            
            // Filter items that have release dates and are in the future or recently released
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let today = Date()
            
            let upcomingItems = listItems.compactMap { item -> (ListItem, Date)? in
                guard let releaseDateString = item.movieReleaseDate,
                      let releaseDate = dateFormatter.date(from: releaseDateString) else {
                    return nil
                }
                return (item, releaseDate)
            }
            .filter { (_, releaseDate) in
                // Show films releasing from today forward within the next year
                let startOfToday = Calendar.current.startOfDay(for: today)
                let nextYear = Calendar.current.date(byAdding: .year, value: 1, to: today) ?? today
                return releaseDate >= startOfToday && releaseDate <= nextYear
            }
            .sorted { $0.1 < $1.1 } // Sort by release date, earliest first
            .map { $0.0 }
            
            await MainActor.run {
                upcomingFilms = upcomingItems
            }
        }
    }
    
    private func loadRecentMovies() async {
        do {
            // Refresh DataManager movies for goals progress tracking
            await dataManager.refreshMovies()
            
            // Get the 15 most recent movies sorted by creation date
            let movies = try await movieService.getMovies(
                sortBy: .dateAdded,
                ascending: false,
                limit: 15
            )
            await MainActor.run {
                recentMovies = movies
            }
        } catch {
        }
    }
    
    private func loadQuickStats() async {
        do {
            // Get current month's films count and streak data
            let currentYear = Calendar.current.component(.year, from: Date())
            let currentMonth = Calendar.current.component(.month, from: Date())

            async let filmsThisMonthTask = statisticsService.getFilmsPerMonth(year: currentYear)
            async let streakTask = statisticsService.getStreakStats(year: nil)
            async let recentMoviesTask = movieService.getMovies(sortBy: .watchDate, ascending: false, limit: 500)

            let results = try await (
                filmsPerMonth: filmsThisMonthTask,
                streakStats: streakTask,
                recentMovies: recentMoviesTask
            )

            await MainActor.run {
                // Films this month
                if let thisMonthData = results.filmsPerMonth.first(where: { $0.month == currentMonth }) {
                    self.filmsThisMonth = thisMonthData.filmCount
                } else {
                    self.filmsThisMonth = 0
                }

                // Current streak
                self.currentStreak = results.streakStats.currentStreakDays

                // Highest rated film this month - filter recent movies by current month
                let calendar = Calendar.current
                let allMovies = results.recentMovies
                var currentMonthMovies: [Movie] = []

                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"

                for movie in allMovies {
                    if let watchDateString = movie.watch_date,
                       let watchDate = dateFormatter.date(from: watchDateString) {
                        let movieComponents = calendar.dateComponents([.year, .month], from: watchDate)
                        if movieComponents.year == currentYear && movieComponents.month == currentMonth {
                            currentMonthMovies.append(movie)
                        }
                    }
                }

                if !currentMonthMovies.isEmpty {
                    let ratedMovies = currentMonthMovies.compactMap { movie -> (Movie, Double)? in
                        guard let detailedRating = movie.detailed_rating else { return nil }
                        return (movie, detailedRating)
                    }

                    if let highestRated = ratedMovies.max(by: { $0.1 < $1.1 }) {
                        self.highestRatedFilmThisMonth = highestRated.0
                        let detailedRating = highestRated.1
                        self.highestRatedFilmValue = String(Int(detailedRating))
                        self.highestRatedFilmTitle = highestRated.0.title
                    } else {
                        self.highestRatedFilmThisMonth = nil
                        self.highestRatedFilmValue = "—"
                        self.highestRatedFilmTitle = ""
                    }
                } else {
                    self.highestRatedFilmThisMonth = nil
                    self.highestRatedFilmValue = "—"
                    self.highestRatedFilmTitle = ""
                }
            }
        } catch {
            await MainActor.run {
                self.filmsThisMonth = 0
                self.highestRatedFilmThisMonth = nil
                self.highestRatedFilmValue = "—"
                self.highestRatedFilmTitle = ""
                self.currentStreak = 0
            }
        }
    }
    
    private func loadYearStats() async {
        let currentYear = Calendar.current.component(.year, from: Date())
        
        do {
            // Load dashboard stats for average rating and year release stats concurrently
            async let yearDashboardTask = statisticsService.getDashboardStats(year: currentYear)
            async let globalDashboardTask = statisticsService.getDashboardStats(year: nil)
            async let yearReleaseTask = statisticsService.getYearReleaseStats(year: currentYear)
            
            let (yearDashboard, globalDashboard, yearRelease) = try await (yearDashboardTask, globalDashboardTask, yearReleaseTask)
            
            await MainActor.run {
                self.filmsThisYear = yearDashboard.totalFilms > 0 ? yearDashboard.totalFilms : globalDashboard.filmsThisYear

                // Average rating this year - ensure it's a valid, finite number
                let rawAverage = yearDashboard.averageRating ?? 0.0
                let safeAverage = rawAverage.isFinite ? rawAverage : 0.0
                self.averageRatingThisYear = safeAverage

                // Format the average rating string safely
                self.formattedAverageRating = String(format: "%.2f", safeAverage)

                // Films released in current year that were watched
                self.currentYearReleasesWatched = yearRelease.filmsFromYear
            }
        } catch {
            await MainActor.run {
                self.filmsThisYear = 0
                self.averageRatingThisYear = 0.0
                self.formattedAverageRating = "0.00"
                self.currentYearReleasesWatched = 0
            }
        }
    }

    private func loadOnThisDayMovies() async {
        let calendar = Calendar.current
        let today = Date()
        let month = calendar.component(.month, from: today)
        let day = calendar.component(.day, from: today)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        let todayString = dateFormatter.string(from: today)

        do {
            let movies = try await movieService.getFilmsOnThisDay(month: month, day: day)
            let filteredMovies = movies
                .filter { ($0.watched_date ?? "") != todayString }
                .sorted { lhs, rhs in
                    if lhs.resolvedWatchedYear != rhs.resolvedWatchedYear {
                        return lhs.resolvedWatchedYear > rhs.resolvedWatchedYear
                    }
                    return (lhs.watched_date ?? "") > (rhs.watched_date ?? "")
                }

            await MainActor.run {
                onThisDayMovies = filteredMovies
            }

            if filteredMovies.isEmpty {
                await loadOnThisDayMoviesFallback(month: month, day: day, todayString: todayString)
            }
        } catch {
            await loadOnThisDayMoviesFallback(month: month, day: day, todayString: todayString)
        }
    }

    private func loadOnThisDayMoviesFallback(month: Int, day: Int, todayString: String) async {
        await dataManager.refreshMovies()

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")

        let matches: [OnThisDayMovie] = dataManager.allMovies.compactMap { movie in
            guard let watchDateString = movie.watch_date, !watchDateString.isEmpty else { return nil }
            guard watchDateString != todayString else { return nil }
            guard let watchDate = formatter.date(from: watchDateString) else { return nil }

            let calendar = Calendar.current
            let components = calendar.dateComponents([.year, .month, .day], from: watchDate)
            guard components.month == month, components.day == day, let year = components.year else { return nil }

            return OnThisDayMovie(from: movie, watchedYear: year)
        }
        .sorted { lhs, rhs in
            if lhs.resolvedWatchedYear != rhs.resolvedWatchedYear {
                return lhs.resolvedWatchedYear > rhs.resolvedWatchedYear
            }
            return (lhs.watched_date ?? "") > (rhs.watched_date ?? "")
        }

        await MainActor.run {
            onThisDayMovies = matches
        }
    }
    
    // MARK: - Caching Functions
    
    private func shouldRefreshData() -> Bool {
        guard let lastLoadTime = lastDataLoadTime else { return true }
        return Date().timeIntervalSince(lastLoadTime) > cacheRefreshInterval || !hasLoadedInitially
    }
    
    private func loadAllDataIfNeeded(force: Bool) async {
        // If force is false and data is still fresh, skip loading
        if !force && !shouldRefreshData() && hasLoadedInitially {
            return
        }

        // Only show loading spinner on non-initial loads
        if !isInitialLoad {
            isLoading = true
        }

        // Load all data concurrently using optimized methods where available
        async let recentMoviesTask = loadRecentMovies()
        async let currentlyWatchingTask = loadCurrentlyWatchingShows()
        async let upcomingFilmsTask = loadUpcomingFilms()
        async let quickStatsTask = loadQuickStats()
        async let yearStatsTask = loadYearStats()
        async let onThisDayTask = loadOnThisDayMovies()
        async let listsTask = dataManager.refreshListsOptimized()

        // Wait for all tasks to complete
        await recentMoviesTask
        await currentlyWatchingTask
        await upcomingFilmsTask
        await quickStatsTask
        await yearStatsTask
        await onThisDayTask
        await listsTask

        lastDataLoadTime = Date()
        hasLoadedInitially = true

        // Mark initial load as complete
        await MainActor.run {
            isInitialLoad = false
            isLoading = false
        }
    }
    
    // MARK: - Refresh Function
    
    @MainActor
    private func refreshAllData() async {
        guard movieService.isLoggedIn else { return }

        isLoading = true

        // Refresh all data sources concurrently using optimized methods
        async let recentMoviesTask = loadRecentMovies()
        async let currentlyWatchingTask = loadCurrentlyWatchingShows()
        async let upcomingFilmsTask = loadUpcomingFilms()
        async let quickStatsTask = loadQuickStats()
        async let yearStatsTask = loadYearStats()
        async let onThisDayTask = loadOnThisDayMovies()
        async let listsRefreshTask = dataManager.refreshListsOptimized()
        async let moviesRefreshTask = dataManager.refreshMovies()
        async let televisionRefreshTask = dataManager.refreshTelevision()
        async let albumsRefreshTask = dataManager.refreshAlbums()

        // Wait for all tasks to complete
        await recentMoviesTask
        await currentlyWatchingTask
        await upcomingFilmsTask
        await quickStatsTask
        await yearStatsTask
        await onThisDayTask
        await listsRefreshTask
        await moviesRefreshTask
        await televisionRefreshTask
        await albumsRefreshTask

        lastDataLoadTime = Date()
        hasLoadedInitially = true

        isLoading = false
    }
    
    // MARK: - Helper Functions
    
    private func checkIfMovieIsLoggedAndNavigate(item: ListItem) async {
        do {
            // Check if this movie is already logged by searching for entries with this TMDB ID
            let existingMovies = try await movieService.getMoviesByTmdbId(tmdbId: item.tmdbId)
            
            await MainActor.run {
                if let firstLoggedMovie = existingMovies.first {
                    // Movie is logged - open the logged version
                    selectedUpcomingMovie = firstLoggedMovie
                } else {
                    // Movie is not logged - create an unlogged Movie object
                    let unloggedMovie = Movie(
                        id: -1, // Special ID to indicate unlogged movie
                        title: item.movieTitle,
                        release_year: item.movieYear,
                        release_date: item.movieReleaseDate,
                        rating: nil,
                        detailed_rating: nil,
                        review: nil,
                        tags: nil,
                        watch_date: nil,
                        is_rewatch: false,
                        tmdb_id: item.tmdbId,
                        overview: nil,
                        poster_url: item.moviePosterUrl,
                        backdrop_path: item.movieBackdropPath,
                        director: nil,
                        runtime: nil,
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
                        genres: nil,
                        created_at: nil,
                        updated_at: nil,
                        favorited: nil
                    )
                    selectedUpcomingMovie = unloggedMovie
                }
            }
        } catch {
            // On error, still show the unlogged version
            await MainActor.run {
                let unloggedMovie = Movie(
                    id: -1, // Special ID to indicate unlogged movie
                    title: item.movieTitle,
                    release_year: item.movieYear,
                    release_date: item.movieReleaseDate,
                    rating: nil,
                    detailed_rating: nil,
                    review: nil,
                    tags: nil,
                    watch_date: nil,
                    is_rewatch: false,
                    tmdb_id: item.tmdbId,
                    overview: nil,
                    poster_url: item.moviePosterUrl,
                    backdrop_path: item.movieBackdropPath,
                    director: nil,
                    runtime: nil,
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
                    genres: nil,
                    created_at: nil,
                    updated_at: nil,
                    favorited: nil
                )
                selectedUpcomingMovie = unloggedMovie
            }
        }
    }
    
    private func formatReleaseDate(_ dateString: String) -> String {
        guard let date = Self.dateFormatter.date(from: dateString) else {
            return dateString
        }
        return Self.displayDateFormatter.string(from: date)
    }
    
    private func updateMovieInPlace(_ updated: Movie) {
        if let index = recentMovies.firstIndex(where: { $0.id == updated.id }) {
            recentMovies[index] = updated
        } else {
            // If not found in recent movies, refresh the list
            Task { await loadRecentMovies() }
        }
    }
    
    private func deleteMovie(_ movie: Movie) async {
        do {
            try await movieService.deleteMovie(id: movie.id)
            await MainActor.run {
                recentMovies.removeAll { $0.id == movie.id }
                movieToDelete = nil
                showingDeleteMovieAlert = false
            }
        } catch {
            await MainActor.run {
                movieToDelete = nil
                showingDeleteMovieAlert = false
            }
        }
    }
    
    // MARK: - Television Helper Functions
    
    private func updateTelevisionProgress(show: Television, season: Int, episode: Int) async {
        do {
            try await dataManager.updateTelevisionProgress(id: show.id, season: season, episode: episode)
            // The onChange listener for dataManager.allTelevision will handle refreshing currentlyWatchingShows
        } catch {
        }
    }
    
    private func updateTelevisionStatus(show: Television, status: WatchingStatus) async {
        do {
            try await dataManager.updateTelevisionStatus(id: show.id, status: status)
            // The onChange listener for dataManager.allTelevision will handle refreshing currentlyWatchingShows
        } catch {
        }
    }
    
    // Helper function to sort currently watching shows by last updated
    private func sortCurrentlyWatchingShows(_ shows: [Television]) -> [Television] {
        return shows.sorted { show1, show2 in
            // Sort by updated_at date, most recent first
            guard let date1String = show1.updated_at,
                  let date2String = show2.updated_at else {
                // If one doesn't have updated_at, prioritize the one that does
                if show1.updated_at != nil { return true }
                if show2.updated_at != nil { return false }
                // If neither has updated_at, fall back to alphabetical by name
                return show1.name < show2.name
            }
            
            let formatter = ISO8601DateFormatter()
            guard let date1 = formatter.date(from: date1String),
                  let date2 = formatter.date(from: date2String) else {
                // If date parsing fails, fall back to string comparison (most recent first)
                return date1String > date2String
            }
            
            // Most recently updated first
            return date1 > date2
        }
    }
    
    private func deleteTelevisionShow(_ show: Television) async {
        do {
            try await televisionService.deleteTelevision(id: show.id)
            await MainActor.run {
                currentlyWatchingShows.removeAll { $0.id == show.id }
                televisionToDelete = nil
                showingDeleteTelevisionAlert = false
            }
        } catch {
            await MainActor.run {
                televisionToDelete = nil
                showingDeleteTelevisionAlert = false
            }
        }
    }
    
    // MARK: - Upcoming Films Helper Functions
    
    private func createTempMovieFromListItem(_ item: ListItem) -> Movie {
        return Movie(
            id: -1, // Special ID to indicate unlogged movie
            title: item.movieTitle,
            release_year: item.movieYear,
            release_date: item.movieReleaseDate,
            rating: nil,
            detailed_rating: nil,
            review: nil,
            tags: nil,
            watch_date: nil,
            is_rewatch: false,
            tmdb_id: item.tmdbId,
            overview: nil,
            poster_url: item.moviePosterUrl,
            backdrop_path: item.movieBackdropPath,
            director: nil,
            runtime: nil,
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
            genres: nil,
            created_at: nil,
            updated_at: nil,
            favorited: nil
        )
    }
    
    private func createTMDBMovieFromListItem(_ item: ListItem) -> TMDBMovie {
        // Create a basic TMDBMovie structure
        return TMDBMovie(
            id: item.tmdbId,
            title: item.movieTitle,
            originalTitle: nil,
            overview: nil,
            releaseDate: item.movieReleaseDate,
            posterPath: item.moviePosterUrl?.replacingOccurrences(of: "https://image.tmdb.org/t/p/w500", with: ""),
            backdropPath: item.movieBackdropPath?.replacingOccurrences(of: "https://image.tmdb.org/t/p/w1280", with: ""),
            voteAverage: nil,
            voteCount: nil,
            popularity: nil,
            originalLanguage: nil,
            genreIds: nil,
            adult: nil,
            video: nil
        )
    }
    
    // MARK: - Year Stats Section
    
    @ViewBuilder
    private var yearStatsSection: some View {
        // Only render when data is loaded and not in loading state
        if !isInitialLoad && !isLoading && hasLoadedInitially {
            let currentYear = Calendar.current.component(.year, from: Date())

            VStack(spacing: 0) {
                // Section header
                HStack {
                    Text("\(String(currentYear)) Stats")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(Color.adaptiveText(scheme: colorScheme))
                    Spacer()
                }
                .padding(.top, 12)
                .padding(.bottom, 16)

                // Stats grid - 3x2 uniform layout
                VStack(spacing: 12) {
                    // First row - Year stats
                    HStack(spacing: 12) {
                        NavigationLink {
                            LazyView { StatisticsView() }
                        } label: {
                            UnifiedStatTile(
                                title: "Films This Year",
                                value: "\(filmsThisYear)",
                                icon: "film",
                                color: .purple,
                                colorScheme: colorScheme
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        NavigationLink {
                            LazyView { StatisticsView() }
                        } label: {
                            UnifiedStatTile(
                                title: "Avg Rating",
                                value: formattedAverageRating,
                                icon: "star.fill",
                                color: .green,
                                colorScheme: colorScheme
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        NavigationLink {
                            LazyView { StatisticsView() }
                        } label: {
                            UnifiedStatTile(
                                title: "\(String(currentYear)) Releases",
                                value: "\(currentYearReleasesWatched)",
                                icon: "eye",
                                color: .cyan,
                                colorScheme: colorScheme
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                
                    // Second row - Monthly/streak stats
                    HStack(spacing: 12) {
                        NavigationLink {
                            LazyView { StatisticsView() }
                        } label: {
                            UnifiedStatTile(
                                title: "Films This Month",
                                value: "\(filmsThisMonth)",
                                icon: "calendar",
                                color: .blue,
                                colorScheme: colorScheme
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        NavigationLink {
                            LazyView { StatisticsView() }
                        } label: {
                            UnifiedStatTile(
                                title: highestRatedFilmTitle.isEmpty ? "Top Rated" : highestRatedFilmTitle,
                                value: highestRatedFilmValue,
                                icon: "trophy.fill",
                                color: .yellow,
                                colorScheme: colorScheme
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        NavigationLink {
                            LazyView { StatisticsView() }
                        } label: {
                            UnifiedStatTile(
                                title: "Streak",
                                value: "\(currentStreak)",
                                icon: "flame.fill",
                                color: .red,
                                colorScheme: colorScheme
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.bottom, 20)
            }
        }
    }

    // MARK: - Goals Section
    
    @ViewBuilder
    private var goalsSection: some View {
        VStack(spacing: 0) {
            // Section header
            HStack {
                Text("Goals")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(Color.adaptiveText(scheme: colorScheme))
                Spacer()
            }
            .padding(.top, 12)
            .padding(.bottom, 16)
            
            VStack(spacing: 12) {
                let currentYear = Calendar.current.component(.year, from: Date())
                
                // Yearly film goal
                if dataManager.yearlyFilmGoal > 0 {
                    goalProgressCard(
                        title: "Films Watched in \(currentYear)",
                        current: dataManager.getCurrentYearWatchedMoviesCount(),
                        total: dataManager.yearlyFilmGoal,
                        systemImage: "film",
                        color: .red
                    )
                }
                
                // Must watches progress
                let mustWatchesProgress = dataManager.getMustWatchesProgress(for: currentYear)
                if mustWatchesProgress.total > 0 {
                    Button(action: {
                        Task {
                            await dataManager.refreshLists()
                            showingMustWatchesList = true
                        }
                    }) {
                        goalProgressCard(
                            title: "Must Watches for \(currentYear)",
                            current: mustWatchesProgress.watched,
                            total: mustWatchesProgress.total,
                            systemImage: "star.fill",
                            color: .purple
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // Looking forward progress
                let lookingForwardProgress = dataManager.getLookingForwardProgress(for: currentYear)
                if lookingForwardProgress.total > 0 {
                    Button(action: {
                        Task {
                            await dataManager.refreshLists()
                            showingLookingForwardList = true
                        }
                    }) {
                        goalProgressCard(
                            title: "Looking Forward in \(currentYear)",
                            current: lookingForwardProgress.watched,
                            total: lookingForwardProgress.total,
                            systemImage: "arrow.right",
                            color: .cyan
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // Themed lists progress
                ForEach(dataManager.getThemedLists(), id: \.id) { themedList in
                    Button(action: {
                        Task {
                            await dataManager.refreshLists()
                            selectedThemedList = themedList
                            showingThemedList = true
                        }
                    }) {
                        let progress = dataManager.getThemedListProgress(for: themedList)
                        goalProgressCard(
                            title: themedList.name,
                            current: progress.watched,
                            total: progress.total,
                            systemImage: "calendar.badge.checkmark",
                            color: .orange
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(.bottom, 20)
    }
    
    @ViewBuilder
    private func goalProgressCard(title: String, current: Int, total: Int, systemImage: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(Color.adaptiveText(scheme: colorScheme))

                HStack(spacing: 8) {
                    Text("\(current) / \(total)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(Color.adaptiveText(scheme: colorScheme))

                    Spacer()

                    Text(String(format: "%.0f%%", (Double(current) / Double(total)) * 100))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(Color.adaptiveSecondaryText(scheme: colorScheme))
                }
                
                ProgressView(value: Double(current), total: Double(total))
                    .progressViewStyle(LinearProgressViewStyle(tint: color))
                    .scaleEffect(y: 0.8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color.gray.opacity(0.15) : .white)
        )
    }
}

// MARK: - Unified Stat Tile Component

struct UnifiedStatTile: View {
    let title: String
    let value: String
    var subtitle: String?
    let icon: String
    let color: Color
    let colorScheme: ColorScheme
    
    private var borderGradient: [Color] {
        switch color {
        case .blue:   return [Color.blue, Color.cyan]
        case .green:  return [Color.green, Color.mint]
        case .yellow: return [Color.yellow, Color.orange]
        case .purple: return [Color.purple, Color.pink]
        case .red:    return [Color.red, Color.pink]
        case .cyan:   return [Color.cyan, Color.teal]
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
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(Color.adaptiveText(scheme: colorScheme))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.8))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 90)
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color.gray.opacity(0.15) : .white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
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

// MARK: - Lazy View Wrapper
// Prevents NavigationLink from eagerly instantiating destination views
// which can cause EXC_BAD_ACCESS when navigating away via tab bar

struct LazyView<Content: View>: View {
    let build: () -> Content
    
    init(_ build: @autoclosure @escaping () -> Content) {
        self.build = build
    }
    
    init(@ViewBuilder _ build: @escaping () -> Content) {
        self.build = build
    }
    
    var body: Content {
        build()
    }
}

#Preview {
    HomeView()
}

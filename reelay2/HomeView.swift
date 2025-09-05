//
//  HomeView.swift
//  reelay2
//
//  Created by Humza Khalil on 8/28/25.
//

import SwiftUI

struct HomeView: View {
    @StateObject private var movieService = SupabaseMovieService.shared
    @StateObject private var statisticsService = SupabaseStatisticsService.shared
    @StateObject private var dataManager = DataManager.shared
    @State private var recentMovies: [Movie] = []
    @State private var isLoading = false
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
    
    // Television Data
    @State private var currentlyWatchingShows: [Television] = []
    @State private var selectedTelevisionShow: Television?
    @State private var televisionService = SupabaseTelevisionService.shared
    @State private var showingDeleteTelevisionAlert: Bool = false
    @State private var televisionToDelete: Television?
    
    // Upcoming Films Data
    @State private var upcomingFilms: [ListItem] = []
    
    // Quick Stats Data
    @State private var filmsThisMonth: Int = 0
    @State private var highestRatedFilmThisMonth: Movie?
    @State private var currentStreak: Int = 0
    
    // Caching mechanism
    @State private var lastDataLoadTime: Date?
    @State private var hasLoadedInitially = false
    private let cacheRefreshInterval: TimeInterval = 300 // 5 minutes
    
    var body: some View {
        ZStack {
            if isLoading {
                // Loading Screen
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    
                    Text("Loading...")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.1))
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        // Goals Section
                        if dataManager.yearlyFilmGoal > 0 || !dataManager.movieLists.isEmpty {
                            goalsSection
                        }
                        
                        // Recently Logged Section
                        if !recentMovies.isEmpty {
                            recentlyLoggedSection
                        }
                        
                        // Currently Watching TV Shows Section
                        if !currentlyWatchingShows.isEmpty {
                            currentlyWatchingShowsSection
                        }
                        
                        // Upcoming Films Section
                        if !upcomingFilms.isEmpty {
                            upcomingFilmsSection
                        }
                        
                        // Quick Stats Section
                        quickStatsSection
                        
                        Spacer()
                    }
                    .padding(.top, 20)
                }
                .refreshable {
                    await refreshAllData()
                }
            }
        }
        .navigationTitle("Home")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                HStack {
                    Button(action: {
                        showingGoalsSettings = true
                    }) {
                        Image(systemName: "target")
                    }
                    
                    Button(action: {
                        showingRandomizer = true
                    }) {
                        Image(systemName: "dice")
                    }
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
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
        .sheet(isPresented: $showingMustWatchesList) {
            if let mustWatchesList = dataManager.movieLists.first(where: { $0.name == "Must Watches for \(Calendar.current.component(.year, from: Date()))" }) {
                ListDetailsView(list: mustWatchesList)
            } else {
                // Fallback view if list is not found
                Text("Must Watches list not found")
                    .foregroundColor(.secondary)
            }
        }
        .sheet(isPresented: $showingLookingForwardList) {
            if let lookingForwardList = dataManager.movieLists.first(where: { $0.name == "Looking Forward in \(Calendar.current.component(.year, from: Date()))" }) {
                ListDetailsView(list: lookingForwardList)
            } else {
                // Fallback view if list is not found
                Text("Looking Forward list not found")
                    .foregroundColor(.secondary)
            }
        }
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
                recentMovies = []
                currentlyWatchingShows = []
                upcomingFilms = []
                filmsThisMonth = 0
                highestRatedFilmThisMonth = nil
                currentStreak = 0
                lastDataLoadTime = nil
                hasLoadedInitially = false
            }
        }
        .onChange(of: showingAddMovie) { _, isShowing in
            if !isShowing && movieService.isLoggedIn {
                // Refresh data when add movie sheet is dismissed
                Task {
                    await loadAllDataIfNeeded(force: true)
                }
            }
        }
        .onChange(of: showingAddTelevision) { _, isShowing in
            if !isShowing && movieService.isLoggedIn {
                // Refresh data when add television sheet is dismissed
                Task {
                    await loadAllDataIfNeeded(force: true)
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
                // Refresh data when log again sheet is dismissed
                Task {
                    await loadAllDataIfNeeded(force: true)
                }
            }
        }
    }
    
    // MARK: - Quick Stats Section
    
    @ViewBuilder
    private var quickStatsSection: some View {
        VStack(spacing: 0) {
            // Section header
            HStack {
                Text("Quick Stats")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 16)
            
            // Horizontal scrollable stats tiles
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    NavigationLink(destination: StatisticsView()) {
                        QuickStatTile(
                            title: "Films This Month",
                            value: "\(filmsThisMonth)",
                            icon: "calendar",
                            color: .blue
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    NavigationLink(destination: StatisticsView()) {
                        if let highestRatedFilm = highestRatedFilmThisMonth {
                            QuickStatTile(
                                title: "Highest Rated This Month",
                                value: String(format: "%.1f", highestRatedFilm.rating ?? 0.0),
                                subtitle: highestRatedFilm.title,
                                icon: "star.fill",
                                color: .yellow
                            )
                        } else {
                            QuickStatTile(
                                title: "Highest Rated This Month",
                                value: "—",
                                icon: "star.fill",
                                color: .yellow
                            )
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    NavigationLink(destination: StatisticsView()) {
                        QuickStatTile(
                            title: "Current Streak",
                            value: "\(currentStreak)",
                            // subtitle: currentStreak == 1 ? "day" : "days",
                            icon: "flame.fill",
                            color: .red
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
            }
            .frame(height: 140)
            .padding(.bottom, 20)
        }
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
                    .foregroundColor(.white)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 16)
            
            // Horizontal scrollable movie posters row
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(upcomingFilms.prefix(15)) { item in
                        upcomingMoviePosterView(for: item)
                    }
                }
                .padding(.horizontal, 20)
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
                AsyncImage(url: item.posterURL) { image in
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
                        .foregroundColor(.white)
                        .lineLimit(1)
                } else {
                    Text("TBA")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
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
                    .foregroundColor(.white)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 16)
            
            // Horizontal scrollable TV show posters row
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(currentlyWatchingShows.prefix(15)) { show in
                        televisionPosterView(for: show)
                    }
                }
                .padding(.horizontal, 20)
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
                AsyncImage(url: show.posterURL) { image in
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
                    .foregroundColor(.white)
                    .lineLimit(1)
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
                    .foregroundColor(.white)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 16)
            
            // Horizontal scrollable movie posters row
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(recentMovies.prefix(15)) { movie in
                        moviePosterView(for: movie)
                    }
                }
                .padding(.horizontal, 20)
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
                AsyncImage(url: movie.posterURL) { image in
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
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
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
            print("Error loading currently watching shows: \(error)")
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
                upcomingFilms = Array(upcomingItems.prefix(15))
            }
        } catch {
            print("Error loading upcoming films: \(error)")
            await MainActor.run {
                upcomingFilms = []
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
            print("Error loading recent movies: \(error)")
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
                        guard let rating = movie.rating else { return nil }
                        return (movie, rating)
                    }
                    self.highestRatedFilmThisMonth = ratedMovies.max { $0.1 < $1.1 }?.0
                } else {
                    self.highestRatedFilmThisMonth = nil
                }
            }
        } catch {
            print("Error loading quick stats: \(error)")
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
        
        isLoading = true
        
        // Load all data concurrently
        async let recentMoviesTask = loadRecentMovies()
        async let currentlyWatchingTask = loadCurrentlyWatchingShows()
        async let upcomingFilmsTask = loadUpcomingFilms()
        async let quickStatsTask = loadQuickStats()
        
        // Wait for all tasks to complete
        await recentMoviesTask
        await currentlyWatchingTask
        await upcomingFilmsTask
        await quickStatsTask
        
        lastDataLoadTime = Date()
        hasLoadedInitially = true
        isLoading = false
    }
    
    // MARK: - Refresh Function
    
    private func refreshAllData() async {
        guard movieService.isLoggedIn else { return }
        
        isLoading = true
        
        // Refresh all data sources concurrently for better performance
        async let recentMoviesTask = loadRecentMovies()
        async let currentlyWatchingTask = loadCurrentlyWatchingShows()
        async let upcomingFilmsTask = loadUpcomingFilms()
        async let quickStatsTask = loadQuickStats()
        async let listsRefreshTask = dataManager.refreshLists()
        async let moviesRefreshTask = dataManager.refreshMovies()
        async let televisionRefreshTask = dataManager.refreshTelevision()
        async let albumsRefreshTask = dataManager.refreshAlbums()
        
        // Wait for all tasks to complete
        await recentMoviesTask
        await currentlyWatchingTask
        await upcomingFilmsTask
        await quickStatsTask
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
            print("Error checking if movie is logged: \(error)")
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
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        guard let date = dateFormatter.date(from: dateString) else {
            return dateString
        }
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "MMM d"
        return displayFormatter.string(from: date)
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
                print("Error deleting movie: \(error)")
                movieToDelete = nil
                showingDeleteMovieAlert = false
            }
        }
    }
    
    // MARK: - Television Helper Functions
    
    private func updateTelevisionProgress(show: Television, season: Int, episode: Int) async {
        do {
            let updatedShow = try await televisionService.updateProgress(id: show.id, season: season, episode: episode)
            await MainActor.run {
                // Update the show in the currentlyWatchingShows array
                if let index = currentlyWatchingShows.firstIndex(where: { $0.id == show.id }) {
                    currentlyWatchingShows[index] = updatedShow
                    // Re-sort the array to move the updated show to the top
                    currentlyWatchingShows = sortCurrentlyWatchingShows(currentlyWatchingShows)
                }
            }
        } catch {
            print("Error updating television progress: \(error)")
        }
    }
    
    private func updateTelevisionStatus(show: Television, status: WatchingStatus) async {
        do {
            let updatedShow = try await televisionService.updateStatus(id: show.id, status: status)
            await MainActor.run {
                // Update the show in the currentlyWatchingShows array
                if let index = currentlyWatchingShows.firstIndex(where: { $0.id == show.id }) {
                    currentlyWatchingShows[index] = updatedShow
                    // Re-sort the array to move the updated show to the top
                    currentlyWatchingShows = sortCurrentlyWatchingShows(currentlyWatchingShows)
                }
                // If marked as completed or not watching, remove from currently watching list
                if status != .watching {
                    currentlyWatchingShows.removeAll { $0.id == show.id }
                }
            }
        } catch {
            print("Error updating television status: \(error)")
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
                print("Error deleting television show: \(error)")
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
    
    // MARK: - Goals Section
    
    @ViewBuilder
    private var goalsSection: some View {
        VStack(spacing: 0) {
            // Section header
            HStack {
                Text("Goals")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                Spacer()
            }
            .padding(.horizontal, 20)
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
            .padding(.horizontal, 20)
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
                    .foregroundColor(.white)
                
                HStack(spacing: 8) {
                    Text("\(current) / \(total)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text(String(format: "%.0f%%", (Double(current) / Double(total)) * 100))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white.opacity(0.8))
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
                .fill(Color.gray.opacity(0.15))
        )
    }
}

// MARK: - Quick Stat Tile Component

struct QuickStatTile: View {
    let title: String
    let value: String
    var subtitle: String?
    let icon: String
    let color: Color
    
    private var borderGradient: [Color] {
        switch color {
        case .blue:   return [Color.blue, Color.cyan]
        case .green:  return [Color.green, Color.mint]
        case .yellow: return [Color.yellow, Color.orange]
        case .purple: return [Color.purple, Color.pink]
        case .red:    return [Color.red, Color.pink]
        default:      return [color, color.opacity(0.8)]
        }
    }
    
    var body: some View {
        VStack(spacing: 6) {
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
            
            Text(title)
                .font(.caption)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.8))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .frame(width: 120, height: 110)
        .padding(12)
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

#Preview {
    HomeView()
}
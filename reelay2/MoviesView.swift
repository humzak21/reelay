//
//  MoviesView.swift
//  reelay2
//
//  Created by Humza Khalil on 7/21/25.
//

import SDWebImageSwiftUI
import SwiftUI

struct MoviesView: View {
  @StateObject private var movieService = SupabaseMovieService.shared
  @State private var movies: [Movie] = []
  @State private var isLoading = false
  @State private var errorMessage: String?
  @State private var showingAddMovie = false
  @State private var showingFilters = false
  @State private var sortBy: MovieSortField = .watchDate
  @State private var sortAscending = false
  @State private var showingSortOptions = false
  @State private var searchText = ""
  @State private var selectedMovie: Movie?
  @State private var movieToEdit: Movie?
  @State private var movieToDelete: Movie?
  @State private var showingDeleteMovieAlert: Bool = false
  @State private var movieToLogAgain: Movie?
  @State private var showingLogAgain = false
  @State private var tappedMovieId: Int?
  @State private var viewMode: ViewMode = .list
  @State private var selectedDate: Date = Date()
  @State private var currentCalendarMonth: Date = Date()
  @State private var longPressedMovieId: Int?
  @StateObject private var listService = SupabaseListService.shared
  @StateObject private var filterViewModel = FilterViewModel()
  @State private var movieToAddToLists: Movie?
  @State private var movieToChangePoster: Movie?
  @State private var movieToChangeBackdrop: Movie?
  
  // MARK: - Efficient Loading States
  @State private var hasLoadedInitially = false
  @State private var lastRefreshTime: Date = Date.distantPast
  @State private var isRefreshing = false
  
  private let refreshInterval: TimeInterval = 300 // 5 minutes

  enum ViewMode {
    case list, tile, calendar
  }

  private var filteredMovies: [Movie] {
    let filtered = filterViewModel.filterMovies(movies)
    return sortMovies(filtered)
  }

  private var groupedMovies: [(String, [Movie])] {
    let grouped = Dictionary(grouping: filteredMovies) { movie in
      getMonthYearFromWatchDate(movie.watch_date)
    }
    return grouped.sorted { first, second in
      let date1 = getDateFromMonthYear(first.key)
      let date2 = getDateFromMonthYear(second.key)
      return date1 > date2  // Most recent first
    }
  }
  
  private var viewModeIcon: String {
    switch viewMode {
    case .list:
      return "square.grid.3x3"
    case .tile:
      return "calendar"
    case .calendar:
      return "list.bullet"
    }
  }
  
  private var navigationTitle: String {
    switch viewMode {
    case .list, .tile:
      return "Movies"
    case .calendar:
      return "Calendar"
    }
  }
  
  // MARK: - Local Sorting Logic
  
  private func sortMovies(_ movies: [Movie]) -> [Movie] {
    return movies.sorted { movie1, movie2 in
      switch sortBy {
      case .title:
        let title1 = movie1.title.lowercased()
        let title2 = movie2.title.lowercased()
        return sortAscending ? title1 < title2 : title1 > title2
        
      case .watchDate:
        let date1 = movie1.watch_date ?? ""
        let date2 = movie2.watch_date ?? ""
        return sortAscending ? date1 < date2 : date1 > date2
        
      case .releaseDate:
        let year1 = movie1.release_year ?? 0
        let year2 = movie2.release_year ?? 0
        return sortAscending ? year1 < year2 : year1 > year2
        
      case .rating:
        let rating1 = movie1.rating ?? 0
        let rating2 = movie2.rating ?? 0
        return sortAscending ? rating1 < rating2 : rating1 > rating2
        
      case .detailedRating:
        let detailed1 = movie1.detailed_rating ?? 0
        let detailed2 = movie2.detailed_rating ?? 0
        return sortAscending ? detailed1 < detailed2 : detailed1 > detailed2
        
      case .dateAdded:
        let created1 = movie1.created_at ?? ""
        let created2 = movie2.created_at ?? ""
        return sortAscending ? created1 < created2 : created1 > created2
      }
    }
  }

  var body: some View {
    VStack(spacing: 0) {
      // Filter summary bar
      if filterViewModel.hasActiveFilters {
        filterSummaryBar
      }
      
      // Main content
    contentView
    }
      .navigationTitle(navigationTitle)
      .navigationBarTitleDisplayMode(.large)
      .background(Color(.systemBackground))
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          HStack(spacing: 16) {
            Button(action: {
              showingFilters = true
            }) {
              ZStack {
              Image(systemName: "line.3.horizontal.decrease")
                if filterViewModel.hasActiveFilters {
                  Circle()
                    .fill(.red)
                    .frame(width: 8, height: 8)
                    .offset(x: 8, y: -8)
                }
              }
            }
            
            Button(action: {
              showingSortOptions = true
            }) {
              Image(systemName: sortAscending ? "arrow.up" : "arrow.down")
                .font(.system(size: 16, weight: .medium))
            }

            Button(action: {
              withAnimation(.easeInOut(duration: 0.3)) {
                switch viewMode {
                case .list:
                  viewMode = .tile
                case .tile:
                  viewMode = .calendar
                case .calendar:
                  viewMode = .list
                }
              }
            }) {
              Image(systemName: viewModeIcon)
                .font(.system(size: 16, weight: .medium))
            }
          }
        }

        ToolbarItem(placement: .navigationBarTrailing) {
          Button(action: {
            showingAddMovie = true
          }) {
            Image(systemName: "plus")
          }
        }
      }
      .task {
        if movieService.isLoggedIn && !hasLoadedInitially {
          // Test Railway cache performance and health
          Task {
            print("🔍 [MOVIESVIEW] Running comprehensive Railway cache diagnostics...")
            await DataManagerRailway.shared.enableDetailedLogging()
            
            let healthStatus = await DataManagerRailway.shared.testCacheHealth()
            print("🏥 [MOVIESVIEW] Cache Health: \(healthStatus.isConnected ? "✅ Connected" : "❌ Disconnected")")
            print("🏥 [MOVIESVIEW] Response Time: \(String(format: "%.3f", healthStatus.responseTime))s")
            
            if let performanceReport = await DataManagerRailway.shared.runCachePerformanceTest() {
              print("⚡ [MOVIESVIEW] Cache Performance Report:")
              print("📊 [MOVIESVIEW] Average Response: \(String(format: "%.3f", performanceReport.averageResponseTime))s")
              print("🎯 [MOVIESVIEW] Cache Hit Rate: \(String(format: "%.1f", performanceReport.cacheHitRate * 100))%")
              print("📦 [MOVIESVIEW] Data Transferred: \(performanceReport.totalDataTransferred) bytes")
            }
          }
          
          await loadMoviesIfNeeded(force: true)
          // Ensure lists are loaded for border detection
          await listService.syncListsFromSupabase()
          hasLoadedInitially = true
        }
      }
      .onChange(of: movieService.isLoggedIn) { _, isLoggedIn in
        if isLoggedIn {
          Task {
            await loadMoviesIfNeeded(force: true)
            hasLoadedInitially = true
          }
        } else {
          movies = []
          errorMessage = nil
          hasLoadedInitially = false
          lastRefreshTime = Date.distantPast
        }
      }
      .onAppear {
        // Only load if we haven't loaded initially or data is stale
        if movieService.isLoggedIn && shouldRefreshData() {
          Task {
            await loadMoviesIfNeeded(force: false)
          }
        }
      }
      .sheet(isPresented: $showingAddMovie) {
        AddMoviesView()
      }
      .onChange(of: showingAddMovie) { _, isShowing in
        if !isShowing && movieService.isLoggedIn {
          // Refresh movies list when add movie sheet is dismissed
          Task {
            await loadMoviesIfNeeded(force: true)
          }
        }
      }
      .onChange(of: showingLogAgain) { _, isShowing in
        if !isShowing && movieService.isLoggedIn {
          // Refresh movies list when log again sheet is dismissed
          Task {
            await loadMoviesIfNeeded(force: true)
          }
        }
      }
      .onChange(of: sortBy) { _, _ in
        // Trigger UI refresh when sort field changes
      }
      .onChange(of: sortAscending) { _, _ in
        // Trigger UI refresh when sort direction changes
      }
      .sheet(isPresented: $showingFilters) {
        FilterSortView(sortBy: $sortBy, filterViewModel: filterViewModel, movies: movies)
          .onAppear {
            filterViewModel.loadCurrentFiltersToStaging()
          }
      }
      .sheet(isPresented: $showingSortOptions) {
        SortOptionsView(sortBy: $sortBy, sortAscending: $sortAscending)
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
            // Simply refresh the movies list from backend
            // The PosterChangeView has already updated the backend data
            Task {
              await loadMoviesIfNeeded(force: true)
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
            // Simply refresh the movies list from backend
            // The BackdropChangeView has already updated the backend data
            Task {
              await loadMoviesIfNeeded(force: true)
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
  }
  
  @ViewBuilder
  private var filterSummaryBar: some View {
    HStack(spacing: 8) {
      Image(systemName: "line.3.horizontal.decrease")
        .foregroundColor(.blue)
        .font(.system(size: 14, weight: .medium))
      
      Text("\(filterViewModel.activeFilterCount) filter\(filterViewModel.activeFilterCount == 1 ? "" : "s") active")
        .font(.system(size: 14, weight: .medium))
        .foregroundColor(.white)
      
      Text("•")
        .foregroundColor(.gray)
      
      Text("\(filteredMovies.count) of \(movies.count) movies")
        .font(.system(size: 14, weight: .medium))
        .foregroundColor(.gray)
      
      Spacer()
      
      Button(action: {
        withAnimation(.easeInOut(duration: 0.3)) {
          filterViewModel.clearAllFilters()
        }
      }) {
        Text("Clear")
          .font(.system(size: 14, weight: .medium))
          .foregroundColor(.red)
      }
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 8)
    .background(Color(.secondarySystemFill))
  }

  @ViewBuilder
  private var contentView: some View {
    Group {
      if !movieService.isLoggedIn {
        notLoggedInView
      } else if isLoading {
        loadingView
      } else if filteredMovies.isEmpty && !isLoading {
        emptyStateView
      } else {
        switch viewMode {
        case .list:
          moviesListView
        case .tile:
          moviesTileView
        case .calendar:
          moviesCalendarView
        }
      }
    }
  }

  @ViewBuilder
  private var notLoggedInView: some View {
    VStack(spacing: 16) {
      Spacer()

      Image(systemName: "person.crop.circle.badge.exclamationmark")
        .font(.system(size: 64))
        .foregroundColor(.gray)

      Text("Sign In Required")
        .font(.title2)
        .fontWeight(.semibold)
        .foregroundColor(.white)

      Text("Please sign in to view and manage your movie diary.")
        .font(.body)
        .foregroundColor(.gray)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 40)

      Spacer()

      Text("Go to the Profile tab to sign in")
        .font(.caption)
        .foregroundColor(.blue)
        .padding(.bottom, 100)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  @ViewBuilder
  private var loadingView: some View {
    VStack {
      Spacer()
      ProgressView()
        .progressViewStyle(CircularProgressViewStyle(tint: .white))
      Spacer()
    }
  }

  @ViewBuilder
  private var emptyStateView: some View {
    VStack(spacing: 16) {
      if let errorMessage = errorMessage {
        errorStateView(errorMessage: errorMessage)
      } else {
        noMoviesView
      }
      Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding(.top, 100)
  }

  @ViewBuilder
  private func errorStateView(errorMessage: String) -> some View {
    VStack(spacing: 8) {
      Image(systemName: "exclamationmark.triangle")
        .font(.system(size: 48))
        .foregroundColor(.orange)
      Text("Error Loading Movies")
        .font(.title2)
        .fontWeight(.semibold)
        .foregroundColor(.white)
      Text(errorMessage)
        .font(.body)
        .foregroundColor(.gray)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 40)
    }
  }

  @ViewBuilder
  private var noMoviesView: some View {
    VStack(spacing: 8) {
      if filterViewModel.hasActiveFilters && !movies.isEmpty {
        Image(systemName: "line.3.horizontal.decrease.circle")
          .font(.system(size: 48))
          .foregroundColor(.blue)
        Text("No Movies Match Filters")
          .font(.title2)
          .fontWeight(.semibold)
          .foregroundColor(.white)
        Text("Try adjusting your filters to see more movies.")
          .font(.body)
          .foregroundColor(.gray)
          .multilineTextAlignment(.center)
          .padding(.horizontal, 40)
        
        Button(action: {
          withAnimation(.easeInOut(duration: 0.3)) {
            filterViewModel.clearAllFilters()
          }
        }) {
          Text("Clear All Filters")
            .font(.headline)
            .foregroundColor(.blue)
            .padding(.top, 8)
        }
      } else {
      Image(systemName: "film")
        .font(.system(size: 48))
        .foregroundColor(.gray)
      Text("No Movies Yet")
        .font(.title2)
        .fontWeight(.semibold)
        .foregroundColor(.white)
      Text("Start logging your movie diary by adding your first film.")
        .font(.body)
        .foregroundColor(.gray)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 40)
      }
    }
  }

  @ViewBuilder
  private var moviesListView: some View {
    ScrollView {
      LazyVStack(spacing: 0) {
        // Add some top padding to ensure large title space
        Color.clear
          .frame(height: 1)

        // Grouped movie sections
        ForEach(groupedMovies, id: \.0) { monthYear, monthMovies in
          movieMonthSection(monthYear: monthYear, movies: monthMovies)
        }
      }
    }
    .scrollContentBackground(.hidden)
    .refreshable {
      await refreshMovies()
    }
  }

  @ViewBuilder
  private var moviesTileView: some View {
    ScrollView {
      LazyVStack(spacing: 0) {
        // Add some top padding to ensure large title space
        Color.clear
          .frame(height: 1)

        // Grouped movie sections for tile view
        ForEach(groupedMovies, id: \.0) { monthYear, monthMovies in
          movieTileMonthSection(monthYear: monthYear, movies: monthMovies)
        }
      }
    }
    .scrollContentBackground(.hidden)
    .refreshable {
      await refreshMovies()
    }
  }

  @ViewBuilder
  private func movieMonthSection(monthYear: String, movies: [Movie]) -> some View {
    VStack(spacing: 0) {
      // Month/Year header
      HStack {
        Text(monthYear)
          .font(.title2)
          .fontWeight(.semibold)
          .foregroundColor(.white)
        Spacer()
      }
      .padding(.horizontal, 20)
      .padding(.top, 12)
      .padding(.bottom, 16)

      // Movies for this month
      LazyVStack(spacing: 12) {
        ForEach(
          movies.sorted {
            ($0.watch_date ?? "") > ($1.watch_date ?? "")
          }
        ) { movie in
          movieButton(for: movie)
        }
      }
      .padding(.bottom, 8)
    }
  }

  @ViewBuilder
  private func movieButton(for movie: Movie) -> some View {
    Button(action: {
      selectedMovie = movie
    }) {
      let isUniqueFilm = isCentennialUniqueFilm(movie)
      let isTotalLog = isCentennialTotalLog(movie)
      
      MovieRowView(movie: movie, rewatchIconColor: getRewatchIconColor(for: movie), shouldHighlightMustWatchTitle: shouldHighlightMustWatchTitle(movie), shouldHighlightReleaseYearTitle: shouldHighlightReleaseYearTitle(movie), shouldHighlightReleaseYearOnYear: shouldHighlightReleaseYearOnYear(movie))
        .padding(.horizontal, 20)
        .background(
          RoundedRectangle(cornerRadius: 24)
            .fill(Color(.secondarySystemFill))
            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
        )
        .overlay(
          Group {
            // Prioritize red (total log) over yellow (unique film) if both apply
            if isTotalLog {
              RoundedRectangle(cornerRadius: 24)
                .stroke(
                  LinearGradient(
                    colors: [.red, .pink, .purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                  ),
                  lineWidth: 3
                )
            } else if isUniqueFilm {
              RoundedRectangle(cornerRadius: 24)
                .stroke(
                  LinearGradient(
                    colors: [.yellow, .orange, .green],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                  ),
                  lineWidth: 3
                )
            }
          }
        )
        .cornerRadius(24)
        .padding(.horizontal, 20)
        // MARK: - Temporarily disabled animated border feature
        // .overlay(
        //   AnimatedBorderOverlay(
        //     isVisible: longPressedMovieId == movie.id,
        //     colors: getBorderColors(for: movie),
        //     cornerRadius: 24
        //   )
        // )
    }
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
    // MARK: - Temporarily disabled long press gesture
    // .onLongPressGesture(minimumDuration: 0.3, maximumDistance: 20) {
    //   // Long press completed - could add haptic feedback here
    //   print("Long press completed for movie: \(movie.title)")
    // } onPressingChanged: { isPressing in
    //   print("Long press pressing changed: \(isPressing) for movie: \(movie.title)")
    //   withAnimation(.easeInOut(duration: 0.2)) {
    //     longPressedMovieId = isPressing ? movie.id : nil
    //   }
    // }
  }

  @ViewBuilder
  private func movieTileMonthSection(monthYear: String, movies: [Movie]) -> some View {
    VStack(spacing: 0) {
      // Month/Year header
      HStack {
        Text(monthYear)
          .font(.title2)
          .fontWeight(.semibold)
          .foregroundColor(.white)
        Spacer()
      }
      .padding(.horizontal, 20)
      .padding(.top, 12)
      .padding(.bottom, 16)

      // Movies grid for this month
      let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)
      LazyVGrid(columns: columns, spacing: 12) {
        ForEach(
          movies.sorted {
            ($0.watch_date ?? "") > ($1.watch_date ?? "")
          }
        ) { movie in
          movieTileButton(for: movie)
        }
      }
      .padding(.horizontal, 16)
      .padding(.bottom, 8)
    }
  }

  @ViewBuilder
  private var moviesCalendarView: some View {
    ScrollView {
      LazyVStack(spacing: 20) {
        // Calendar month navigation
        calendarHeader
        
        // Calendar grid
        calendarGrid
          .gesture(
            DragGesture()
              .onEnded { value in
                let threshold: CGFloat = 50
                if value.translation.width > threshold {
                  // Swipe right - previous month
                  withAnimation(.easeInOut(duration: 0.3)) {
                    currentCalendarMonth = Calendar.current.date(byAdding: .month, value: -1, to: currentCalendarMonth) ?? currentCalendarMonth
                  }
                } else if value.translation.width < -threshold {
                  // Swipe left - next month
                  withAnimation(.easeInOut(duration: 0.3)) {
                    currentCalendarMonth = Calendar.current.date(byAdding: .month, value: 1, to: currentCalendarMonth) ?? currentCalendarMonth
                  }
                }
              }
          )
        
        // Selected date movies list
        selectedDateMoviesList
      }
      .padding(.horizontal, 20)
    }
    .scrollContentBackground(.hidden)
    .refreshable {
      await refreshMovies()
    }
  }
  
  @ViewBuilder
  private var calendarHeader: some View {
    HStack(alignment: .center) {
      Button(action: {
        withAnimation(.easeInOut(duration: 0.2)) {
          currentCalendarMonth = Calendar.current.date(byAdding: .month, value: -1, to: currentCalendarMonth) ?? currentCalendarMonth
        }
      }) {
        Image(systemName: "chevron.left")
          .foregroundColor(.white)
          .font(.title2)
      }
      
      Spacer()
      
      VStack(spacing: 6) {
        Text(monthYearFormatter.string(from: currentCalendarMonth))
          .font(.title2)
          .fontWeight(.semibold)
          .foregroundColor(.white)
          .onTapGesture(count: 2) {
            returnToCurrentDate()
          }
        monthCountPill
      }
      
      Spacer()
      
      Button(action: {
        withAnimation(.easeInOut(duration: 0.2)) {
          currentCalendarMonth = Calendar.current.date(byAdding: .month, value: 1, to: currentCalendarMonth) ?? currentCalendarMonth
        }
      }) {
        Image(systemName: "chevron.right")
          .foregroundColor(.white)
          .font(.title2)
      }
    }
    .padding(.horizontal, 8)
  }
  
  @ViewBuilder
  private var calendarGrid: some View {
    
    VStack(spacing: 8) {
      // Weekday headers
      HStack {
        ForEach(["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"], id: \.self) { day in
          Text(day)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(.gray)
            .frame(maxWidth: .infinity)
        }
      }
      
      // Calendar days
      LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
        ForEach(calendarDays, id: \.self) { date in
          calendarDayView(for: date)
        }
      }
    }
    .padding(.vertical, 12)
    .background(Color(.secondarySystemFill))
    .cornerRadius(16)
  }
  
  private var calendarDays: [Date] {
    let calendar = Calendar.current
    let startOfMonth = calendar.dateInterval(of: .month, for: currentCalendarMonth)?.start ?? currentCalendarMonth
    let startOfCalendar = calendar.dateInterval(of: .weekOfYear, for: startOfMonth)?.start ?? startOfMonth
    
    var days: [Date] = []
    var currentDate = startOfCalendar
    
    // Generate 42 days (6 weeks) to fill the calendar grid
    for _ in 0..<42 {
      days.append(currentDate)
      currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
    }
    
    return days
  }
  
  @ViewBuilder
  private func calendarDayView(for date: Date) -> some View {
    let calendar = Calendar.current
    let isCurrentMonth = calendar.isDate(date, equalTo: currentCalendarMonth, toGranularity: .month)
    let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
    let isToday = calendar.isDateInToday(date)
    let moviesForDay = moviesForDate(date)
    let movieCount = moviesForDay.count
    
    Button(action: {
      withAnimation(.easeInOut(duration: 0.2)) {
        selectedDate = date
      }
    }) {
      VStack(spacing: 2) {
        // Day number
        Text("\(calendar.component(.day, from: date))")
          .font(.system(size: 14, weight: isSelected ? .bold : .medium))
          .foregroundColor(dayTextColor(isCurrentMonth: isCurrentMonth, isSelected: isSelected, isToday: isToday))
        
        // Movie dots (max 3)
        HStack(spacing: 2) {
          ForEach(0..<min(movieCount, 3), id: \.self) { _ in
            Circle()
              .fill(Color.white.opacity(0.8))
              .frame(width: 3, height: 3)
          }
          if movieCount > 3 {
            Text("+")
              .font(.system(size: 6, weight: .bold))
              .foregroundColor(.white.opacity(0.8))
          }
        }
        .frame(height: 6)
      }
      .frame(width: 36, height: 36)
      .background(
        RoundedRectangle(cornerRadius: 8)
          .fill(dayBackgroundColor(movieCount: movieCount, isSelected: isSelected, isToday: isToday))
      )
    }
    .buttonStyle(PlainButtonStyle())
    .opacity(isCurrentMonth ? 1.0 : 0.3)
  }
  
  @ViewBuilder
  private var selectedDateMoviesList: some View {
    let moviesForSelectedDate = moviesForDate(selectedDate).sorted { movie1, movie2 in
      (movie1.detailed_rating ?? 0) > (movie2.detailed_rating ?? 0)
    }
    
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text("Movies watched on \(selectedDateFormatter.string(from: selectedDate))")
          .font(.headline)
          .fontWeight(.semibold)
          .foregroundColor(.white)
        Spacer()
      }
      
      if moviesForSelectedDate.isEmpty {
        Text("No movies watched on this day")
          .font(.body)
          .foregroundColor(.gray)
          .padding(.vertical, 20)
      } else {
        LazyVStack(spacing: 8) {
          ForEach(moviesForSelectedDate) { movie in
            Button(action: {
              selectedMovie = movie
            }) {
              let isUniqueFilm = isCentennialUniqueFilm(movie)
              let isTotalLog = isCentennialTotalLog(movie)
              
              selectedDateMovieRow(movie: movie, rewatchIconColor: getRewatchIconColor(for: movie), shouldHighlightMustWatchTitle: shouldHighlightMustWatchTitle(movie), shouldHighlightReleaseYearTitle: shouldHighlightReleaseYearTitle(movie), shouldHighlightReleaseYearOnYear: shouldHighlightReleaseYearOnYear(movie), isUniqueFilm: isUniqueFilm, isTotalLog: isTotalLog)
                // MARK: - Temporarily disabled animated border feature
                // .overlay(
                //   AnimatedBorderOverlay(
                //     isVisible: longPressedMovieId == movie.id,
                //     colors: getBorderColors(for: movie),
                //     cornerRadius: 12
                //   )
                // )
            }
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
                Button("Remove Entry", systemImage: "trash", role: .destructive) {
                movieToDelete = movie
                showingDeleteMovieAlert = true
              }
            }
            // MARK: - Temporarily disabled long press gesture
            // .onLongPressGesture(minimumDuration: 0.3, maximumDistance: 20) {
            //   // Long press completed
            //   print("Long press completed for movie: \(movie.title)")
            // } onPressingChanged: { isPressing in
            //   print("Long press pressing changed: \(isPressing) for movie: \(movie.title)")
            //   withAnimation(.easeInOut(duration: 0.2)) {
            //     longPressedMovieId = isPressing ? movie.id : nil
            //   }
            // }
          }
        }
      }
    }
    .padding(.top, 8)
  }
  
  @ViewBuilder
  private func selectedDateMovieRow(movie: Movie, rewatchIconColor: Color, shouldHighlightMustWatchTitle: Bool, shouldHighlightReleaseYearTitle: Bool, shouldHighlightReleaseYearOnYear: Bool, isUniqueFilm: Bool, isTotalLog: Bool) -> some View {
    HStack(spacing: 12) {
      // Movie poster
      AsyncImage(url: movie.posterURL) { image in
        image
          .resizable()
          .aspectRatio(contentMode: .fill)
      } placeholder: {
        Rectangle()
          .fill(Color.gray.opacity(0.3))
      }
      .frame(width: 40, height: 60)
      .cornerRadius(6)
      
      // Movie details
      VStack(alignment: .leading, spacing: 2) {
        Text(movie.title)
          .font(.subheadline)
          .fontWeight(.semibold)
          .foregroundColor(shouldHighlightMustWatchTitle ? .purple : shouldHighlightReleaseYearTitle ? .cyan : .white)
          .shadow(color: shouldHighlightMustWatchTitle ? .purple.opacity(0.6) : shouldHighlightReleaseYearTitle ? .cyan.opacity(0.6) : .clear, radius: 2, x: 0, y: 0)
          .lineLimit(2)
        
        Text(movie.formattedReleaseYear)
          .font(.caption)
          .foregroundColor(shouldHighlightReleaseYearOnYear ? .cyan : .gray)
          .shadow(color: shouldHighlightReleaseYearOnYear ? .cyan.opacity(0.6) : .clear, radius: 2, x: 0, y: 0)
        
        // Star rating and detailed rating
        HStack(spacing: 6) {
          HStack(spacing: 1) {
            ForEach(0..<5) { index in
              Image(systemName: starType(for: index, rating: movie.rating))
                .foregroundColor(starColor(for: movie.rating))
                .font(.system(size: 10, weight: .regular))
            }
          }
          
          if let detailedRating = movie.detailed_rating {
            Text(String(format: "%.0f", detailedRating))
              .font(.system(size: 11, weight: .medium, design: .rounded))
              .foregroundColor(.purple)
          }
          
          if movie.isRewatchMovie {
            Image(systemName: "arrow.clockwise")
              .foregroundColor(rewatchIconColor)
              .font(.system(size: 12, weight: .semibold))
          }
        }
        
        // Tag icons
        if !tagIconsWithColors(for: movie.tags).isEmpty {
          HStack(spacing: 3) {
            ForEach(tagIconsWithColors(for: movie.tags), id: \.icon) { iconData in
              Image(systemName: iconData.icon)
                .foregroundColor(iconData.color)
                .font(.system(size: 9, weight: .regular))
            }
          }
        }
      }
      
      Spacer()
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .background(
      RoundedRectangle(cornerRadius: 12)
        .fill(Color(.secondarySystemFill))
    )
    .overlay(
      Group {
        // Prioritize red (total log) over yellow (unique film) if both apply
        if isTotalLog {
          RoundedRectangle(cornerRadius: 12)
            .stroke(
              LinearGradient(
                colors: [.red, .pink, .purple],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              ),
              lineWidth: 3
            )
        } else if isUniqueFilm {
          RoundedRectangle(cornerRadius: 12)
            .stroke(
              LinearGradient(
                colors: [.yellow, .orange, .green],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              ),
              lineWidth: 3
            )
        }
      }
    )
    .cornerRadius(12)
  }
  
  // Helper computed properties and functions
  private var monthYearFormatter: DateFormatter {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMMM yyyy"
    return formatter
  }
  
  @ViewBuilder
  private var monthCountPill: some View {
    let filteredCount = moviesCountInMonth(for: currentCalendarMonth, in: filteredMovies)
    let totalCount = moviesCountInMonth(for: currentCalendarMonth, in: movies)
    
    HStack(spacing: 6) {
      Image(systemName: "film.fill")
        .font(.system(size: 12, weight: .semibold))
      Text(
        filterViewModel.hasActiveFilters && filteredCount != totalCount
        ? "\(filteredCount) of \(totalCount) watched"
        : "\(totalCount) watched"
      )
      .font(.system(size: 12, weight: .semibold))
    }
    .foregroundColor(.black)
    .padding(.horizontal, 10)
    .padding(.vertical, 6)
    .background(Color.white)
    .clipShape(Capsule())
    .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
  }
  
  private var selectedDateFormatter: DateFormatter {
    let formatter = DateFormatter()
    formatter.dateFormat = "EEEE, MMMM d"
    return formatter
  }
  
  private func moviesCountInMonth(for monthDate: Date, in source: [Movie]) -> Int {
    let calendar = Calendar.current
    var total = 0
    for movie in source {
      guard let dateString = movie.watch_date,
            let date = DateFormatter.movieDateFormatter.date(from: dateString)
      else { continue }
      if calendar.isDate(date, equalTo: monthDate, toGranularity: .month) {
        total += 1
      }
    }
    return total
  }
  
  private func moviesForDate(_ date: Date) -> [Movie] {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    let dateString = formatter.string(from: date)
    
    return filteredMovies.filter { movie in
      movie.watch_date == dateString
    }
  }
  
  private func dayTextColor(isCurrentMonth: Bool, isSelected: Bool, isToday: Bool) -> Color {
    if isSelected {
      return .black
    } else if isToday {
      return .white
    } else if isCurrentMonth {
      return .white
    } else {
      return .gray
    }
  }
  
  private func dayBackgroundColor(movieCount: Int, isSelected: Bool, isToday: Bool) -> Color {
    if isSelected {
      return .white
    } else if isToday {
      return .blue.opacity(0.7)
    } else if movieCount > 0 {
      // Heatmap colors: yellow -> orange -> red based on movie count
      switch movieCount {
      case 1:
        return .yellow.opacity(0.4)
      case 2:
        return .orange.opacity(0.6)
      case 3:
        return .orange.opacity(0.8)
      case 4:
        return .red.opacity(0.7)
      default:
        return .red.opacity(0.9)
      }
    } else {
      return .clear
    }
  }
  
  private func starType(for index: Int, rating: Double?) -> String {
    guard let rating = rating else { return "star" }

    let adjustedRating = rating  // Assuming rating is already on 5-star scale

    if adjustedRating >= Double(index + 1) {
      return "star.fill"
    } else if adjustedRating >= Double(index) + 0.5 {
      return "star.leadinghalf.filled"
    } else {
      return "star"
    }
  }

  private func starColor(for rating: Double?) -> Color {
    guard let rating = rating else { return .blue }
    return rating == 5.0 ? .yellow : .blue
  }
  
  private func tagIconsWithColors(for tagsString: String?) -> [(icon: String, color: Color)] {
    guard let tagsString = tagsString, !tagsString.isEmpty else { return [] }

    let tagIconColorMap: [String: (icon: String, color: Color)] = [
      "IMAX": ("film", .red),
      "theater": ("popcorn", .purple),
      "family": ("person.3.fill", .yellow),
      "theboys": ("person.2.fill", .green),
      "airplane": ("airplane", .orange),
      "train": ("train.side.front.car", .cyan),
      "short": ("movieclapper.fill", .pink),
    ]

    // Parse tags - assuming they're comma-separated or space-separated
    let tags = tagsString.components(separatedBy: CharacterSet(charactersIn: ", ")).compactMap {
      tag in
      tag.trimmingCharacters(in: .whitespaces).lowercased()
    }

    return tags.compactMap { tag in
      // Check both lowercase and original case for matching
      return tagIconColorMap[tag] ?? tagIconColorMap[tag.capitalized]
        ?? tagIconColorMap[tag.uppercased()]
    }
  }

  @ViewBuilder
  private func movieTileButton(for movie: Movie) -> some View {
    Button(action: {
      // Trigger animation
      withAnimation(.spring(response: 0.3, dampingFraction: 0.6, blendDuration: 0)) {
        tappedMovieId = movie.id
      }

      // Show movie details after brief delay
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        selectedMovie = movie
        tappedMovieId = nil
      }
    }) {
      let isUniqueFilm = isCentennialUniqueFilm(movie)
      let isTotalLog = isCentennialTotalLog(movie)
      
      MovieTileView(movie: movie, rewatchIconColor: getRewatchIconColor(for: movie))
        .overlay(
          Group {
            // Prioritize red (total log) over yellow (unique film) if both apply
            if isTotalLog {
              RoundedRectangle(cornerRadius: 12)
                .stroke(
                  LinearGradient(
                    colors: [.red, .pink, .purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                  ),
                  lineWidth: 3
                )
            } else if isUniqueFilm {
              RoundedRectangle(cornerRadius: 12)
                .stroke(
                  LinearGradient(
                    colors: [.yellow, .orange, .green],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                  ),
                  lineWidth: 3
                )
            }
          }
        )
        .scaleEffect(tappedMovieId == movie.id ? 1.05 : 1.0)
        .animation(
          .spring(response: 0.3, dampingFraction: 0.6, blendDuration: 0), value: tappedMovieId)
        // MARK: - Temporarily disabled animated border feature
        // .overlay(
        //   AnimatedBorderOverlay(
        //     isVisible: longPressedMovieId == movie.id,
        //     colors: getBorderColors(for: movie),
        //     cornerRadius: 12
        //   )
        // )
    }
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
    // MARK: - Temporarily disabled long press gesture
    // .onLongPressGesture(minimumDuration: 0.3, maximumDistance: 20) {
    //   // Long press completed - could add haptic feedback here
    //   print("Long press completed for movie: \(movie.title)")
    // } onPressingChanged: { isPressing in
    //   print("Long press pressing changed: \(isPressing) for movie: \(movie.title)")
    //   withAnimation(.easeInOut(duration: 0.2)) {
    //     longPressedMovieId = isPressing ? movie.id : nil
    //   }
    // }
  }

  private func getMonthYearFromWatchDate(_ dateString: String?) -> String {
    guard let dateString = dateString else { return "Unknown Date" }
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    guard let date = formatter.date(from: dateString) else { return "Unknown Date" }

    let monthYearFormatter = DateFormatter()
    monthYearFormatter.dateFormat = "MMMM yyyy"
    return monthYearFormatter.string(from: date)
  }

  private func getDateFromMonthYear(_ monthYearString: String) -> Date {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMMM yyyy"
    return formatter.date(from: monthYearString) ?? Date.distantPast
  }

  // MARK: - Efficient Loading Functions
  
  private func shouldRefreshData() -> Bool {
    return Date().timeIntervalSince(lastRefreshTime) > refreshInterval || !hasLoadedInitially
  }
  
  private func loadMoviesIfNeeded(force: Bool) async {
    // If force is false and data is still fresh, skip loading
    if !force && !shouldRefreshData() && !movies.isEmpty {
      print("🔄 [MOVIESVIEW] Skipping load - data is fresh (last refresh: \(lastRefreshTime))")
      return
    }
    
    guard !isLoading else { 
      print("⏳ [MOVIESVIEW] Already loading movies, skipping duplicate request")
      return 
    }
    
    let startTime = Date()
    print("🚀 [MOVIESVIEW] Starting movie load - force: \(force)")
    print("🚂 [MOVIESVIEW] Testing Railway cache first...")
    
    isLoading = true
    errorMessage = nil
    
    do {
      // First try Railway cache
      await DataManagerRailway.shared.loadMoviesFromCache()
      let railwayMovies = DataManagerRailway.shared.allMovies
      
      if !railwayMovies.isEmpty {
        let duration = Date().timeIntervalSince(startTime)
        print("✅ [MOVIESVIEW] SUCCESS: Got \(railwayMovies.count) movies from Railway cache in \(String(format: "%.3f", duration))s")
        print("🎯 [MOVIESVIEW] Railway cache HIT - No Supabase fallback needed")
        movies = railwayMovies
        lastRefreshTime = Date()
      } else {
        print("⚠️ [MOVIESVIEW] Railway cache returned empty - falling back to direct Supabase")
        let fallbackStart = Date()
        movies = try await movieService.getMovies(sortBy: sortBy, ascending: sortAscending, limit: 3000)
        let fallbackDuration = Date().timeIntervalSince(fallbackStart)
        print("🔄 [MOVIESVIEW] Supabase fallback completed in \(String(format: "%.3f", fallbackDuration))s with \(movies.count) movies")
        lastRefreshTime = Date()
      }
      
      let totalDuration = Date().timeIntervalSince(startTime)
      print("📊 [MOVIESVIEW] Total load operation completed in \(String(format: "%.3f", totalDuration))s")
      
    } catch {
      let duration = Date().timeIntervalSince(startTime)
      print("❌ [MOVIESVIEW] FAILED after \(String(format: "%.3f", duration))s: \(error)")
      print("🔄 [MOVIESVIEW] Attempting direct Supabase as last resort...")
      
      do {
        let fallbackStart = Date()
        movies = try await movieService.getMovies(sortBy: sortBy, ascending: sortAscending, limit: 3000)
        let fallbackDuration = Date().timeIntervalSince(fallbackStart)
        print("✅ [MOVIESVIEW] Supabase rescue completed in \(String(format: "%.3f", fallbackDuration))s")
        lastRefreshTime = Date()
      } catch {
        errorMessage = error.localizedDescription
        print("💥 [MOVIESVIEW] CRITICAL: Both Railway and Supabase failed: \(error)")
      }
    }
    isLoading = false
  }
  
  private func refreshMovies() async {
    guard !isRefreshing else { 
      print("⏳ [MOVIESVIEW] Already refreshing, skipping duplicate refresh request")
      return 
    }
    
    let startTime = Date()
    print("🔄 [MOVIESVIEW] Manual refresh triggered by user pull-to-refresh")
    print("🚂 [MOVIESVIEW] Attempting Railway cache refresh...")
    
    isRefreshing = true
    errorMessage = nil
    
    do {
      // First try Railway cache
      await DataManagerRailway.shared.loadMoviesFromCache()
      let railwayMovies = DataManagerRailway.shared.allMovies
      
      if !railwayMovies.isEmpty {
        let duration = Date().timeIntervalSince(startTime)
        print("✅ [MOVIESVIEW] REFRESH SUCCESS: Got \(railwayMovies.count) movies from Railway cache in \(String(format: "%.3f", duration))s")
        print("🎯 [MOVIESVIEW] Railway cache HIT during refresh - No Supabase needed")
        movies = railwayMovies
        lastRefreshTime = Date()
      } else {
        print("⚠️ [MOVIESVIEW] Railway cache refresh returned empty - falling back to Supabase")
        let fallbackStart = Date()
        movies = try await movieService.getMovies(sortBy: sortBy, ascending: sortAscending, limit: 3000)
        let fallbackDuration = Date().timeIntervalSince(fallbackStart)
        print("🔄 [MOVIESVIEW] Supabase refresh fallback completed in \(String(format: "%.3f", fallbackDuration))s")
        lastRefreshTime = Date()
      }
      
      let totalDuration = Date().timeIntervalSince(startTime)
      print("📊 [MOVIESVIEW] Total refresh operation completed in \(String(format: "%.3f", totalDuration))s")
      
    } catch {
      let duration = Date().timeIntervalSince(startTime)
      print("❌ [MOVIESVIEW] REFRESH FAILED after \(String(format: "%.3f", duration))s: \(error)")
      print("🔄 [MOVIESVIEW] Attempting direct Supabase refresh as last resort...")
      
      do {
        let fallbackStart = Date()
        movies = try await movieService.getMovies(sortBy: sortBy, ascending: sortAscending, limit: 3000)
        let fallbackDuration = Date().timeIntervalSince(fallbackStart)
        print("✅ [MOVIESVIEW] Supabase refresh rescue completed in \(String(format: "%.3f", fallbackDuration))s")
        lastRefreshTime = Date()
      } catch {
        errorMessage = error.localizedDescription
        print("💥 [MOVIESVIEW] CRITICAL: Both Railway and Supabase refresh failed: \(error)")
      }
    }
    isRefreshing = false
  }
  
  private func loadMovies() async {
    await loadMoviesIfNeeded(force: true)
  }
  
  private func updateMovieInPlace(_ updated: Movie) {
    if let index = movies.firstIndex(where: { $0.id == updated.id }) {
      movies[index] = updated
    } else {
      Task { await loadMoviesIfNeeded(force: true) }
    }
  }
  
  private func deleteMovie(_ movie: Movie) async {
    do {
      try await movieService.deleteMovie(id: movie.id)
      await MainActor.run {
        movies.removeAll { $0.id == movie.id }
        movieToDelete = nil
        showingDeleteMovieAlert = false
      }
    } catch {
      await MainActor.run {
        errorMessage = error.localizedDescription
        movieToDelete = nil
        showingDeleteMovieAlert = false
      }
    }
  }
  
  private func returnToCurrentDate() {
    withAnimation(.easeInOut(duration: 0.3)) {
      currentCalendarMonth = Date()
      selectedDate = Date()
    }
  }

  private func getCurrentMonthYear() -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMMM yyyy"
    return formatter.string(from: Date())
  }
  
  // MARK: - Movie Border Category Logic
  
  // MARK: - Border calculation logic (temporarily disabled)
  private func getBorderColors(for movie: Movie) -> [Color] {
    var borderColors: [Color] = []
    
    guard let watchDate = movie.watch_date else { 
      // print("No watch date for movie: \(movie.title)")
      return borderColors 
    }
    
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    guard let movieWatchDate = dateFormatter.date(from: watchDate) else { 
      // print("Could not parse watch date: \(watchDate) for movie: \(movie.title)")
      return borderColors 
    }
    
    let calendar = Calendar.current
    let movieYear = calendar.component(.year, from: movieWatchDate)
    let currentYear = calendar.component(.year, from: Date())
    
    // print("Checking borders for movie: \(movie.title), year: \(movieYear), current year: \(currentYear)")
    
    // Check for grey border: rewatch but never had entry before
    if movie.isRewatchMovie && isFirstEntryForMovie(movie) {
      borderColors.append(.gray)
      // print("Added grey border for \(movie.title)")
    }
    
    // Check for yellow border: first watched then rewatched in same calendar year
    if movie.isRewatchMovie && wasFirstWatchedInSameYear(movie) {
      borderColors.append(.yellow)
      // print("Added yellow border for \(movie.title)")
    }
    
    // Check for orange border: watched or rewatched in previous year
    if movieYear < currentYear {
      borderColors.append(.orange)
      // print("Added orange border for \(movie.title)")
    }
    
    // Check for purple border: part of "must watches" list
    if isOnMustWatchesList(movie, for: movieYear) {
      borderColors.append(.purple)
      // print("Added purple border for \(movie.title)")
    }
    
    // Check for cyan border: on "looking forward" list and watched in same year
    if isOnLookingForwardList(movie) && movieYear == currentYear {
      borderColors.append(.cyan)
      // print("Added cyan border for \(movie.title)")
    }
    
    // If no specific borders, add a default blue border for testing
    if borderColors.isEmpty {
      borderColors.append(.blue)
      // print("Added default blue border for \(movie.title)")
    }
    
    // print("Final border colors for \(movie.title): \(borderColors)")
    return borderColors
  }
  
  private func isFirstEntryForMovie(_ movie: Movie) -> Bool {
    // Find all entries for this TMDB ID
    let entriesForMovie = movies.filter { $0.tmdb_id == movie.tmdb_id && $0.tmdb_id != nil }
    
    // Check if this is the first entry (by watch_date) and it's marked as rewatch
    guard let sortedEntries = entriesForMovie.sorted(by: { ($0.watch_date ?? "") < ($1.watch_date ?? "") }).first else {
      return false
    }
    
    return sortedEntries.id == movie.id && movie.isRewatchMovie
  }
  
  private func wasFirstWatchedInSameYear(_ movie: Movie) -> Bool {
    guard let watchDate = movie.watch_date,
          let movieWatchDate = DateFormatter.movieDateFormatter.date(from: watchDate),
          let tmdbId = movie.tmdb_id else { return false }
    
    let calendar = Calendar.current
    let movieYear = calendar.component(.year, from: movieWatchDate)
    
    // Find all entries for this movie
    let entriesForMovie = movies.filter { $0.tmdb_id == tmdbId }
      .compactMap { movie -> (Movie, Date)? in
        guard let dateString = movie.watch_date,
              let date = DateFormatter.movieDateFormatter.date(from: dateString) else { return nil }
        return (movie, date)
      }
      .sorted { $0.1 < $1.1 }
    
    // Check if there are at least 2 entries in the same year
    let entriesInSameYear = entriesForMovie.filter {
      calendar.component(.year, from: $0.1) == movieYear
    }
    
    if entriesInSameYear.count >= 2 {
      // Check if the first was not a rewatch and current one is a rewatch
      let firstEntry = entriesInSameYear[0].0
      return !firstEntry.isRewatchMovie && movie.isRewatchMovie && movie.id != firstEntry.id
    }
    
    return false
  }
  
  private func isOnMustWatchesList(_ movie: Movie, for year: Int) -> Bool {
    guard let tmdbId = movie.tmdb_id else { return false }
    
    // Look for list named exactly "Must Watches for xxxx"
    let mustWatchesListName = "Must Watches for \(year)"
    guard let mustWatchesList = listService.movieLists.first(where: { $0.name == mustWatchesListName }) else {
      return false
    }
    
    let listItems = listService.getListItems(mustWatchesList)
    return listItems.contains(where: { $0.tmdbId == tmdbId })
  }
  
  private func isOnLookingForwardList(_ movie: Movie) -> Bool {
    guard let tmdbId = movie.tmdb_id else { return false }
    
    // Look for lists named "Looking Forward in xxxx"
    let lookingForwardLists = listService.movieLists.filter { list in
      list.name.hasPrefix("Looking Forward in ")
    }
    
    for list in lookingForwardLists {
      let listItems = listService.getListItems(list)
      if listItems.contains(where: { $0.tmdbId == tmdbId }) {
        return true
      }
    }
    
    return false
  }
  
  // MARK: - Rewatch Icon Color Logic
  
  private func getRewatchIconColor(for movie: Movie) -> Color {
    guard movie.isRewatchMovie else { return .orange }
    
    // Grey: First entry in DB but marked as rewatch
    if isFirstEntryButMarkedAsRewatch(movie) {
      return .gray
    }
    
    // Yellow: First watched and rewatched in same calendar year
    if wasFirstWatchedInSameYearAsRewatch(movie) {
      return .yellow
    }
    
    // Orange: Movie was logged in a previous year
    if wasLoggedInPreviousYear(movie) {
      return .orange
    }
    
    // Default orange for any other rewatch scenario
    return .orange
  }
  
  private func isFirstEntryButMarkedAsRewatch(_ movie: Movie) -> Bool {
    guard let tmdbId = movie.tmdb_id else { return false }
    
    // Find all entries for this TMDB ID
    let entriesForMovie = movies.filter { $0.tmdb_id == tmdbId }
    
    // If this is the only entry and it's marked as rewatch, then it's grey
    return entriesForMovie.count == 1 && movie.isRewatchMovie
  }
  
  private func wasFirstWatchedInSameYearAsRewatch(_ movie: Movie) -> Bool {
    guard let watchDate = movie.watch_date,
          let movieWatchDate = DateFormatter.movieDateFormatter.date(from: watchDate),
          let tmdbId = movie.tmdb_id else { return false }
    
    let calendar = Calendar.current
    let movieYear = calendar.component(.year, from: movieWatchDate)
    
    // Find all entries for this movie
    let entriesForMovie = movies.filter { $0.tmdb_id == tmdbId }
      .compactMap { movie -> (Movie, Date)? in
        guard let dateString = movie.watch_date,
              let date = DateFormatter.movieDateFormatter.date(from: dateString) else { return nil }
        return (movie, date)
      }
      .sorted { $0.1 < $1.1 }
    
    // Check if there are at least 2 entries in the same year
    let entriesInSameYear = entriesForMovie.filter {
      calendar.component(.year, from: $0.1) == movieYear
    }
    
    if entriesInSameYear.count >= 2 {
      // Check if the first was not a rewatch and current one is a rewatch
      let firstEntry = entriesInSameYear[0].0
      return !firstEntry.isRewatchMovie && movie.isRewatchMovie && movie.id != firstEntry.id
    }
    
    return false
  }
  
  private func wasLoggedInPreviousYear(_ movie: Movie) -> Bool {
    guard let watchDate = movie.watch_date,
          let movieWatchDate = DateFormatter.movieDateFormatter.date(from: watchDate),
          let tmdbId = movie.tmdb_id else { return false }
    
    let calendar = Calendar.current
    let movieYear = calendar.component(.year, from: movieWatchDate)
    
    // Find all entries for this movie
    let entriesForMovie = movies.filter { $0.tmdb_id == tmdbId }
      .compactMap { movie -> Date? in
        guard let dateString = movie.watch_date,
              let date = DateFormatter.movieDateFormatter.date(from: dateString) else { return nil }
        return date
      }
    
    // Check if any entry was in a previous year
    return entriesForMovie.contains { date in
      calendar.component(.year, from: date) < movieYear
    }
  }
  
  private func wasWatchedInReleaseYear(_ movie: Movie) -> Bool {
    guard let watchDate = movie.watch_date,
          let movieWatchDate = DateFormatter.movieDateFormatter.date(from: watchDate),
          let releaseYear = movie.release_year else { return false }
    
    let calendar = Calendar.current
    let watchYear = calendar.component(.year, from: movieWatchDate)
    
    return watchYear == releaseYear
  }
  
  private func shouldHighlightMustWatchTitle(_ movie: Movie) -> Bool {
    guard let watchDate = movie.watch_date,
          let movieWatchDate = DateFormatter.movieDateFormatter.date(from: watchDate) else { return false }
    
    let calendar = Calendar.current
    let watchYear = calendar.component(.year, from: movieWatchDate)
    
    let isOnMustWatches = isOnMustWatchesList(movie, for: watchYear)
    let isWatchedInReleaseYear = wasWatchedInReleaseYear(movie)
    
    // Highlight title for must watches when there's no overlap with release year highlighting
    // OR when there is overlap (both conditions true), prioritize must watch on title
    return isOnMustWatches && (!isWatchedInReleaseYear || isWatchedInReleaseYear)
  }
  
  private func shouldHighlightReleaseYearTitle(_ movie: Movie) -> Bool {
    guard let watchDate = movie.watch_date,
          let movieWatchDate = DateFormatter.movieDateFormatter.date(from: watchDate) else { return false }
    
    let calendar = Calendar.current
    let watchYear = calendar.component(.year, from: movieWatchDate)
    
    let isOnMustWatches = isOnMustWatchesList(movie, for: watchYear)
    let isWatchedInReleaseYear = wasWatchedInReleaseYear(movie)
    
    // Highlight title for release year only when there's no must watch overlap
    return isWatchedInReleaseYear && !isOnMustWatches
  }
  
  private func shouldHighlightReleaseYearOnYear(_ movie: Movie) -> Bool {
    guard let watchDate = movie.watch_date,
          let movieWatchDate = DateFormatter.movieDateFormatter.date(from: watchDate) else { return false }
    
    let calendar = Calendar.current
    let watchYear = calendar.component(.year, from: movieWatchDate)
    
    let isOnMustWatches = isOnMustWatchesList(movie, for: watchYear)
    let isWatchedInReleaseYear = wasWatchedInReleaseYear(movie)
    
    // Fallback: highlight year only when both conditions are true (overlap scenario)
    return isWatchedInReleaseYear && isOnMustWatches
  }
  
  // MARK: - Centennial Milestone Logic
  
  private func isCentennialUniqueFilm(_ movie: Movie) -> Bool {
    // Sort movies by watch date to get chronological order
    let sortedMovies = movies.sorted { movie1, movie2 in
      guard let date1 = movie1.watch_date, let date2 = movie2.watch_date else { return false }
      return date1 < date2
    }
    
    // Track unique titles encountered
    var uniqueTitles: Set<String> = []
    var centennialPositions: Set<Int> = []
    
    for (index, sortedMovie) in sortedMovies.enumerated() {
      let title = sortedMovie.title.lowercased().trimmingCharacters(in: .whitespaces)
      if !uniqueTitles.contains(title) {
        uniqueTitles.insert(title)
        let uniqueCount = uniqueTitles.count
        
        // Check if this is a centennial milestone (100, 200, 300, etc.)
        if uniqueCount % 100 == 0 {
          centennialPositions.insert(index)
        }
      }
    }
    
    // Check if current movie is at a centennial position
    if let movieIndex = sortedMovies.firstIndex(where: { $0.id == movie.id }) {
      return centennialPositions.contains(movieIndex)
    }
    
    return false
  }
  
  private func isCentennialTotalLog(_ movie: Movie) -> Bool {
    // Sort movies by watch date to get chronological order
    let sortedMovies = movies.sorted { movie1, movie2 in
      guard let date1 = movie1.watch_date, let date2 = movie2.watch_date else { return false }
      return date1 < date2
    }
    
    // Find the position of this movie in the sorted list
    if let movieIndex = sortedMovies.firstIndex(where: { $0.id == movie.id }) {
      let position = movieIndex + 1 // 1-based indexing
      return position % 100 == 0
    }
    
    return false
  }
}

// MARK: - DateFormatter Extension
extension DateFormatter {
  static let movieDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
  }()
}

struct MovieRowView: View {
  let movie: Movie
  let rewatchIconColor: Color
  let shouldHighlightMustWatchTitle: Bool
  let shouldHighlightReleaseYearTitle: Bool
  let shouldHighlightReleaseYearOnYear: Bool

  var body: some View {
    HStack(spacing: 16) {
      // Movie poster
      AsyncImage(url: movie.posterURL) { image in
        image
          .resizable()
          .aspectRatio(contentMode: .fill)
      } placeholder: {
        Rectangle()
          .fill(Color.gray.opacity(0.3))
      }
      .frame(width: 60, height: 90)
      .cornerRadius(8)

      // Movie details - give it more space
      VStack(alignment: .leading, spacing: 4) {
        Text(movie.title)
          .font(.headline)
          .fontWeight(.semibold)
          .foregroundColor(shouldHighlightMustWatchTitle ? .purple : shouldHighlightReleaseYearTitle ? .cyan : .white)
          .shadow(color: shouldHighlightMustWatchTitle ? .purple.opacity(0.6) : shouldHighlightReleaseYearTitle ? .cyan.opacity(0.6) : .clear, radius: 3, x: 0, y: 0)
          .lineLimit(3)
          .frame(maxWidth: .infinity, alignment: .leading)

        Text(movie.formattedReleaseYear)
          .font(.subheadline)
          .foregroundColor(shouldHighlightReleaseYearOnYear ? .cyan : .gray)
          .shadow(color: shouldHighlightReleaseYearOnYear ? .cyan.opacity(0.6) : .clear, radius: 3, x: 0, y: 0)

        // Star rating and score in same row
        HStack(alignment: .firstTextBaseline, spacing: 8) {
          // Stars container with fixed alignment
          HStack(spacing: 2) {
            ForEach(0..<5) { index in
              Image(systemName: starType(for: index, rating: movie.rating))
                .foregroundColor(starColor(for: movie.rating))
                .font(.system(size: 12, weight: .regular))
            }
          }

          // Numerical rating with baseline alignment
          if let detailedRating = movie.detailed_rating {
            Text(String(format: "%.0f", detailedRating))
              .font(.system(size: 13, weight: .medium, design: .rounded))
              .foregroundColor(.purple)
              .frame(minWidth: 30, alignment: .leading)
              .baselineOffset(-1)  // Slight downward adjustment
          }

        }

        // Tag icons
        if !tagIconsWithColors(for: movie.tags).isEmpty {
          HStack(spacing: 4) {
            ForEach(tagIconsWithColors(for: movie.tags), id: \.icon) { iconData in
              Image(systemName: iconData.icon)
                .foregroundColor(iconData.color)
                .font(.system(size: 11, weight: .regular))
            }
          }
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      // Watch date and rewatch indicator - fixed width
      VStack {
        HStack(spacing: 6) {
          if movie.isRewatchMovie {
            Image(systemName: "arrow.clockwise")
              .foregroundColor(rewatchIconColor)
              .font(.system(size: 16, weight: .bold))
          }
          
          VStack(spacing: 2) {
            Text(getDayFromWatchDate(movie.watch_date))
              .font(.title)
              .fontWeight(.bold)
              .foregroundColor(.white)

            Text(getDayOfWeekFromWatchDate(movie.watch_date))
              .font(.caption)
              .foregroundColor(.gray)
              .textCase(.uppercase)
          }
        }
      }
      .frame(width: 80, alignment: .trailing)
    }
    .padding(.vertical, 12)
  }

  private func starType(for index: Int, rating: Double?) -> String {
    guard let rating = rating else { return "star" }

    let adjustedRating = rating  // Assuming rating is already on 5-star scale

    if adjustedRating >= Double(index + 1) {
      return "star.fill"
    } else if adjustedRating >= Double(index) + 0.5 {
      return "star.leadinghalf.filled"
    } else {
      return "star"
    }
  }

  private func starColor(for rating: Double?) -> Color {
    guard let rating = rating else { return .blue }
    return rating == 5.0 ? .yellow : .blue
  }

  private func getDayFromWatchDate(_ dateString: String?) -> String {
    guard let dateString = dateString else { return "?" }
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    guard let date = formatter.date(from: dateString) else { return "?" }

    let dayFormatter = DateFormatter()
    dayFormatter.dateFormat = "d"
    return dayFormatter.string(from: date)
  }

  private func getDayOfWeekFromWatchDate(_ dateString: String?) -> String {
    guard let dateString = dateString else { return "?" }
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    guard let date = formatter.date(from: dateString) else { return "?" }

    let dayFormatter = DateFormatter()
    dayFormatter.dateFormat = "EEE"
    return dayFormatter.string(from: date)
  }

  private func tagIconsWithColors(for tagsString: String?) -> [(icon: String, color: Color)] {
    guard let tagsString = tagsString, !tagsString.isEmpty else { return [] }

    let tagIconColorMap: [String: (icon: String, color: Color)] = [
      "IMAX": ("film", .red),
      "theater": ("popcorn", .purple),
      "family": ("person.3.fill", .yellow),
      "theboys": ("person.2.fill", .green),
      "airplane": ("airplane", .orange),
      "train": ("train.side.front.car", .cyan),
      "short": ("movieclapper.fill", .pink),
    ]

    // Parse tags - assuming they're comma-separated or space-separated
    let tags = tagsString.components(separatedBy: CharacterSet(charactersIn: ", ")).compactMap {
      tag in
      tag.trimmingCharacters(in: .whitespaces).lowercased()
    }

    return tags.compactMap { tag in
      // Check both lowercase and original case for matching
      return tagIconColorMap[tag] ?? tagIconColorMap[tag.capitalized]
        ?? tagIconColorMap[tag.uppercased()]
    }
  }
}

struct MovieTileView: View {
  let movie: Movie
  let rewatchIconColor: Color

  var body: some View {
    VStack(spacing: 6) {
      // Movie poster (no overlay indicators)
      AsyncImage(url: movie.posterURL) { image in
        image
          .resizable()
          .aspectRatio(2 / 3, contentMode: .fill)
      } placeholder: {
        Rectangle()
          .fill(Color.gray.opacity(0.3))
          .aspectRatio(2 / 3, contentMode: .fill)
      }
      .clipped()
      .cornerRadius(12)

      // Star rating and rewatch icon centered below poster
      HStack(spacing: 6) {
        // Star rating
        if let rating = movie.rating {
          HStack(spacing: 1) {
            ForEach(0..<5, id: \.self) { index in
              Image(systemName: starType(for: index, rating: rating))
                .foregroundColor(starColor(for: rating))
                .font(.system(size: 10, weight: .bold))
            }
          }
        }

        // Rewatch indicator
        if movie.isRewatchMovie {
          Image(systemName: "arrow.clockwise")
            .foregroundColor(rewatchIconColor)
            .font(.system(size: 12, weight: .bold))
        }
      }
      .frame(maxWidth: .infinity)
      .frame(height: 16)
    }
  }

  private func starType(for index: Int, rating: Double?) -> String {
    guard let rating = rating else { return "star" }

    let adjustedRating = rating  // Assuming rating is already on 5-star scale

    if adjustedRating >= Double(index + 1) {
      return "star.fill"
    } else if adjustedRating >= Double(index) + 0.5 {
      return "star.leadinghalf.filled"
    } else {
      return "star"
    }
  }

  private func starColor(for rating: Double?) -> Color {
    guard let rating = rating else { return .blue }
    return rating == 5.0 ? .yellow : .blue
  }
}

// Placeholder views for sheets
struct FilterSortView: View {
  @Binding var sortBy: MovieSortField
    @ObservedObject var filterViewModel: FilterViewModel
    let movies: [Movie]
  @Environment(\.dismiss) private var dismiss
    @State private var selectedSection: FilterSection = .tags
    
    enum FilterSection: String, CaseIterable {
        case tags = "Tags"
        case ratings = "Ratings"
        case genres = "Genres"
        case dates = "Dates"
        case misc = "More"
        
        var icon: String {
            switch self {
            case .tags: return "tag.fill"
            case .ratings: return "star.fill"
            case .genres: return "theatermasks.fill"
            case .dates: return "calendar"
            case .misc: return "ellipsis.circle.fill"
            }
        }
    }

  var body: some View {
    NavigationView {
            VStack(spacing: 0) {
                // Filter section tabs
                filterSectionTabs
                
                // Filter content
                ScrollView {
                    LazyVStack(spacing: 20) {
                        // Clear All button (only show if there are active filters)
                        if filterViewModel.hasActiveFilters {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    filterViewModel.clearAllFilters()
                                }
                            }) {
                                HStack {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                    Text("Clear All Filters")
                                        .foregroundColor(.red)
                                        .fontWeight(.medium)
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal, 20)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.red.opacity(0.1))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.red.opacity(0.3), lineWidth: 1)
                                        )
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        switch selectedSection {
                        case .tags:
                            tagFilterSection
                        case .ratings:
                            ratingsFilterSection
                        case .genres:
                            genresFilterSection
                        case .dates:
                            datesFilterSection
                        case .misc:
                            miscFilterSection
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }
                .background(Color.black)
            }
            .background(Color.black)
            .navigationTitle("Filters")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", systemImage: "xmark") {
                        dismiss()
                    }
                    .foregroundColor(.red)
                }
                
        ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apply", systemImage: "checkmark") {
                        filterViewModel.applyStagingFilters()
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
            }
        }
    }
    
    @ViewBuilder
    private var filterSectionTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(FilterSection.allCases, id: \.self) { section in
                    filterSectionTab(section)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(Color.gray.opacity(0.1))
    }
    
    @ViewBuilder
    private func filterSectionTab(_ section: FilterSection) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedSection = section
            }
        }) {
            HStack(spacing: 6) {
                Image(systemName: section.icon)
                    .font(.system(size: 14, weight: .medium))
                Text(section.rawValue)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(selectedSection == section ? .black : .white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(selectedSection == section ? .white : Color.gray.opacity(0.2))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    @ViewBuilder
    private var tagFilterSection: some View {
        FilterSectionCard(title: "Tags", icon: "tag.fill") {
            let availableTags = filterViewModel.getAvailableTags(from: movies)
            
            if availableTags.isEmpty {
                Text("No tags found in your movies")
                    .foregroundColor(.gray)
                    .padding(.vertical, 20)
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                    ForEach(availableTags, id: \.self) { tag in
                        FilterChip(
                            text: tag,
                            isSelected: filterViewModel.stagingSelectedTags.contains(tag)
                        ) {
                            filterViewModel.toggleStagingTag(tag)
                        }
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var ratingsFilterSection: some View {
        VStack(spacing: 20) {
            // Star Rating Filter
            FilterSectionCard(title: "Star Rating", icon: "star.fill") {
                VStack(spacing: 16) {
                    let ratingRange = filterViewModel.getRatingRange(from: movies)
                    
                    HStack {
                        Text("Min:")
                            .foregroundColor(.gray)
                        Spacer()
                        RatingSlider(
                            value: Binding(
                                get: { filterViewModel.stagingMinStarRating ?? ratingRange.min },
                                set: { filterViewModel.stagingMinStarRating = $0 == ratingRange.min ? nil : $0 }
                            ),
                            range: ratingRange.min...ratingRange.max,
                            step: 0.5,
                            showStars: true
                        )
                    }
                    
                    HStack {
                        Text("Max:")
                            .foregroundColor(.gray)
                        Spacer()
                        RatingSlider(
                            value: Binding(
                                get: { filterViewModel.stagingMaxStarRating ?? ratingRange.max },
                                set: { filterViewModel.stagingMaxStarRating = $0 == ratingRange.max ? nil : $0 }
                            ),
                            range: ratingRange.min...ratingRange.max,
                            step: 0.5,
                            showStars: true
                        )
                    }
                }
            }
            
            // Detailed Rating Filter
            FilterSectionCard(title: "Detailed Rating", icon: "number") {
                VStack(spacing: 16) {
                    let detailedRange = filterViewModel.getDetailedRatingRange(from: movies)
                    
                    HStack {
                        Text("Min:")
                            .foregroundColor(.gray)
                        Spacer()
                        RatingSlider(
                            value: Binding(
                                get: { filterViewModel.stagingMinDetailedRating ?? detailedRange.min },
                                set: { filterViewModel.stagingMinDetailedRating = $0 == detailedRange.min ? nil : $0 }
                            ),
                            range: detailedRange.min...detailedRange.max,
                            step: 5,
                            showStars: false
                        )
                    }
                    
                    HStack {
                        Text("Max:")
                            .foregroundColor(.gray)
                        Spacer()
                        RatingSlider(
                            value: Binding(
                                get: { filterViewModel.stagingMaxDetailedRating ?? detailedRange.max },
                                set: { filterViewModel.stagingMaxDetailedRating = $0 == detailedRange.max ? nil : $0 }
                            ),
                            range: detailedRange.min...detailedRange.max,
                            step: 5,
                            showStars: false
                        )
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var genresFilterSection: some View {
        FilterSectionCard(title: "Genres", icon: "theatermasks.fill") {
            let availableGenres = filterViewModel.getAvailableGenres(from: movies)
            
            if availableGenres.isEmpty {
                Text("No genres found in your movies")
                    .foregroundColor(.gray)
                    .padding(.vertical, 20)
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                    ForEach(availableGenres, id: \.self) { genre in
                        FilterChip(
                            text: genre,
                            isSelected: filterViewModel.stagingSelectedGenres.contains(genre)
                        ) {
                            filterViewModel.toggleStagingGenre(genre)
                        }
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var datesFilterSection: some View {
        VStack(spacing: 20) {
            // Date Range Filter
            FilterSectionCard(title: "Watch Date Range", icon: "calendar") {
                VStack(spacing: 16) {
                    DatePicker(
                        "Start Date",
                        selection: Binding(
                            get: { 
                                let earliestDate = filterViewModel.getEarliestWatchDate(from: movies)
                                return filterViewModel.stagingStartDate ?? earliestDate 
                            },
                            set: { 
                                let earliestDate = filterViewModel.getEarliestWatchDate(from: movies)
                                filterViewModel.stagingStartDate = Calendar.current.isDate($0, inSameDayAs: earliestDate) ? nil : $0 
                            }
                        ),
                        displayedComponents: .date
                    )
                    .accentColor(.blue)
                    
                    DatePicker(
                        "End Date",
                        selection: Binding(
                            get: { filterViewModel.stagingEndDate ?? Date() },
                            set: { filterViewModel.stagingEndDate = Calendar.current.isDate($0, inSameDayAs: Date()) ? nil : $0 }
                        ),
                        displayedComponents: .date
                    )
                    .accentColor(.blue)
                }
            }
            
            // Decade Filter
            FilterSectionCard(title: "Release Decades", icon: "calendar.badge.clock") {
                let availableDecades = filterViewModel.getAvailableDecades(from: movies)
                
                if availableDecades.isEmpty {
                    Text("No release years found")
                        .foregroundColor(.gray)
                        .padding(.vertical, 20)
                } else {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                        ForEach(availableDecades, id: \.self) { decade in
                            FilterChip(
                                text: decade,
                                isSelected: filterViewModel.stagingSelectedDecades.contains(decade)
                            ) {
                                filterViewModel.toggleStagingDecade(decade)
                            }
                        }
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var miscFilterSection: some View {
        VStack(spacing: 20) {
            // Rewatch Filter
            FilterSectionCard(title: "Rewatch Status", icon: "arrow.clockwise") {
                VStack(spacing: 12) {
                    FilterToggle(
                        title: "Show only rewatches",
                        isOn: Binding(
                            get: { filterViewModel.stagingShowRewatchesOnly },
                            set: { filterViewModel.stagingShowRewatchesOnly = $0 }
                        )
                    )
                    
                    FilterToggle(
                        title: "Hide rewatches",
                        isOn: Binding(
                            get: { filterViewModel.stagingHideRewatches },
                            set: { filterViewModel.stagingHideRewatches = $0 }
                        )
                    )
                }
            }
            
            // Review Filter
            FilterSectionCard(title: "Reviews", icon: "text.quote") {
                VStack(spacing: 12) {
                    HStack {
                        Text("Has Review:")
                            .foregroundColor(.white)
                        Spacer()
                        
                        Button(action: {
                            filterViewModel.stagingHasReview = filterViewModel.stagingHasReview == true ? nil : true
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: filterViewModel.stagingHasReview == true ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(filterViewModel.stagingHasReview == true ? .green : .gray)
                                Text("Yes")
                                    .foregroundColor(filterViewModel.stagingHasReview == true ? .green : .gray)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Button(action: {
                            filterViewModel.stagingHasReview = filterViewModel.stagingHasReview == false ? nil : false
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: filterViewModel.stagingHasReview == false ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(filterViewModel.stagingHasReview == false ? .red : .gray)
                                Text("No")
                                    .foregroundColor(filterViewModel.stagingHasReview == false ? .red : .gray)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            
            // Runtime Filter
            FilterSectionCard(title: "Runtime", icon: "clock") {
                VStack(spacing: 16) {
                    let runtimeRange = filterViewModel.getRuntimeRange(from: movies)
                    
                    HStack {
                        Text("Min:")
                            .foregroundColor(.gray)
                        Spacer()
                        RuntimeSlider(
                            value: Binding(
                                get: { filterViewModel.stagingMinRuntime ?? runtimeRange.min },
                                set: { filterViewModel.stagingMinRuntime = $0 == runtimeRange.min ? nil : $0 }
                            ),
                            range: runtimeRange.min...runtimeRange.max
                        )
                    }
                    
                    HStack {
                        Text("Max:")
                            .foregroundColor(.gray)
                        Spacer()
                        RuntimeSlider(
                            value: Binding(
                                get: { filterViewModel.stagingMaxRuntime ?? runtimeRange.max },
                                set: { filterViewModel.stagingMaxRuntime = $0 == runtimeRange.max ? nil : $0 }
                            ),
                            range: runtimeRange.min...runtimeRange.max
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Filter UI Components

struct FilterSectionCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                    .font(.system(size: 16, weight: .semibold))
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                Spacer()
            }
            
            content
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.15))
        )
    }
}

struct FilterChip: View {
    let text: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(isSelected ? .black : .white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isSelected ? .white : Color.gray.opacity(0.3))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isSelected ? .clear : Color.gray.opacity(0.5), lineWidth: 1)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct FilterToggle: View {
    let title: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.white)
            Spacer()
            Toggle("", isOn: $isOn)
                .toggleStyle(SwitchToggleStyle(tint: .blue))
        }
    }
}

struct RatingSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let showStars: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            if showStars {
                HStack(spacing: 2) {
                    ForEach(0..<Int(value), id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.system(size: 12))
                    }
                    if value.truncatingRemainder(dividingBy: 1) >= 0.5 {
                        Image(systemName: "star.leadinghalf.filled")
                            .foregroundColor(.yellow)
                            .font(.system(size: 12))
                    }
                    ForEach(0..<(5 - Int(ceil(value))), id: \.self) { _ in
                        Image(systemName: "star")
                            .foregroundColor(.gray)
                            .font(.system(size: 12))
                    }
                }
                .frame(width: 80)
            } else {
                Text("\(Int(value))")
                    .foregroundColor(.white)
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 40, alignment: .trailing)
            }
            
            Slider(value: $value, in: range, step: step)
                .accentColor(.blue)
        }
    }
}

struct RuntimeSlider: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    
    var body: some View {
        HStack(spacing: 12) {
            Text(formatRuntime(value))
                .foregroundColor(.white)
                .font(.system(size: 14, weight: .medium))
                .frame(width: 60, alignment: .trailing)
            
            Slider(
                value: Binding(
                    get: { Double(value) },
                    set: { value = Int($0) }
                ),
                in: Double(range.lowerBound)...Double(range.upperBound),
                step: 5
            )
            .accentColor(.blue)
        }
    }
    
    private func formatRuntime(_ runtime: Int) -> String {
        let hours = runtime / 60
        let minutes = runtime % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Centennial Background Components

struct CentennialUniqueBackground: View {
  var body: some View {
    RoundedRectangle(cornerRadius: 24)
      .fill(
        LinearGradient(
          colors: [.yellow.opacity(0.15), .orange.opacity(0.1)],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      )
      .shadow(color: .orange.opacity(0.3), radius: 8, x: 0, y: 0)
      .shadow(color: .yellow.opacity(0.2), radius: 12, x: 0, y: 0)
  }
}

struct CentennialTotalBackground: View {
  var body: some View {
    RoundedRectangle(cornerRadius: 24)
      .fill(
        LinearGradient(
          colors: [.red.opacity(0.15), .pink.opacity(0.1)],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      )
      .shadow(color: .orange.opacity(0.3), radius: 8, x: 0, y: 0)
      .shadow(color: .red.opacity(0.2), radius: 12, x: 0, y: 0)
  }
}

struct CentennialTileUniqueBackground: View {
  var body: some View {
    RoundedRectangle(cornerRadius: 12)
      .fill(
        LinearGradient(
          colors: [.yellow.opacity(0.15), .orange.opacity(0.1)],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      )
      .shadow(color: .orange.opacity(0.3), radius: 6, x: 0, y: 0)
      .shadow(color: .yellow.opacity(0.2), radius: 8, x: 0, y: 0)
  }
}

struct CentennialTileTotalBackground: View {
  var body: some View {
    RoundedRectangle(cornerRadius: 12)
      .fill(
        LinearGradient(
          colors: [.red.opacity(0.15), .pink.opacity(0.1)],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      )
      .shadow(color: .orange.opacity(0.3), radius: 6, x: 0, y: 0)
      .shadow(color: .red.opacity(0.2), radius: 8, x: 0, y: 0)
  }
}

// MARK: - Animated Border Overlay Component

struct AnimatedBorderOverlay: View {
  let isVisible: Bool
  let colors: [Color]
  let cornerRadius: CGFloat
  
  @State private var rotationAngle: Double = 0
  
  var body: some View {
    if isVisible && !colors.isEmpty {
      RoundedRectangle(cornerRadius: cornerRadius)
        .strokeBorder(
          LinearGradient(
            colors: colors.count == 1 ? [colors[0], colors[0]] : colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          ),
          lineWidth: 4
        )
        .rotationEffect(.degrees(rotationAngle))
        .scaleEffect(isVisible ? 1.02 : 1.0)
        .opacity(isVisible ? 1.0 : 0.0)
        .animation(.easeInOut(duration: 0.2), value: isVisible)
        .onAppear {
          if isVisible {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
              rotationAngle = 360
            }
          }
        }
        .onChange(of: isVisible) { _, visible in
          if visible {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
              rotationAngle = 360
            }
          } else {
            rotationAngle = 0
          }
        }
    }
  }
}

// MARK: - Multiple Border Layers Overlay

struct MultipleBorderOverlay: View {
  let isVisible: Bool
  let colors: [Color]
  let cornerRadius: CGFloat
  
  @State private var rotationAngle: Double = 0
  
  var body: some View {
    if isVisible && !colors.isEmpty {
      ZStack {
        ForEach(Array(colors.enumerated()), id: \.offset) { index, color in
          RoundedRectangle(cornerRadius: cornerRadius)
            .strokeBorder(
              color.opacity(0.8),
              lineWidth: 2
            )
            .scaleEffect(1.0 + CGFloat(index) * 0.015)
            .rotationEffect(.degrees(rotationAngle + Double(index) * 30))
            .opacity(isVisible ? 1.0 : 0.0)
        }
      }
      .scaleEffect(isVisible ? 1.02 : 1.0)
      .animation(.easeInOut(duration: 0.3), value: isVisible)
      .onAppear {
        withAnimation(.linear(duration: 3.0).repeatForever(autoreverses: false)) {
          rotationAngle = 360
        }
      }
      .onDisappear {
        rotationAngle = 0
      }
    }
  }
}

// MARK: - Sort Options View

struct SortOptionsView: View {
  @Binding var sortBy: MovieSortField
  @Binding var sortAscending: Bool
  @Environment(\.dismiss) private var dismiss
  
  var body: some View {
    NavigationView {
      VStack(spacing: 24) {
        // Sort Field Selection
        VStack(alignment: .leading, spacing: 16) {
          HStack {
            Image(systemName: "arrow.up.arrow.down")
              .foregroundColor(.blue)
              .font(.system(size: 16, weight: .semibold))
            Text("Sort By")
              .font(.headline)
              .fontWeight(.semibold)
              .foregroundColor(.white)
            Spacer()
          }
          
          LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 1), spacing: 8) {
            ForEach(MovieSortField.allCases, id: \.self) { sortField in
              SortFieldRow(
                sortField: sortField,
                isSelected: sortBy == sortField,
                sortAscending: sortAscending
              ) {
                sortBy = sortField
              }
            }
          }
        }
        .padding(16)
        .background(
          RoundedRectangle(cornerRadius: 12)
            .fill(Color.gray.opacity(0.15))
        )
        
        // Sort Direction Selection
        VStack(alignment: .leading, spacing: 16) {
          HStack {
            Image(systemName: "arrow.up.arrow.down")
              .foregroundColor(.blue)
              .font(.system(size: 16, weight: .semibold))
            Text("Sort Direction")
              .font(.headline)
              .fontWeight(.semibold)
              .foregroundColor(.white)
            Spacer()
          }
          
          VStack(spacing: 8) {
            SortDirectionRow(
              title: getSortDirectionTitle(ascending: false),
              icon: "arrow.down",
              isSelected: !sortAscending
            ) {
              sortAscending = false
            }
            
            SortDirectionRow(
              title: getSortDirectionTitle(ascending: true),
              icon: "arrow.up",
              isSelected: sortAscending
            ) {
              sortAscending = true
            }
          }
        }
        .padding(16)
        .background(
          RoundedRectangle(cornerRadius: 12)
            .fill(Color.gray.opacity(0.15))
        )
        
        Spacer()
      }
      .padding(.horizontal, 20)
      .padding(.top, 16)
      .background(Color.black)
      .navigationTitle("Sort Options")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button("Cancel", systemImage: "xmark") {
            dismiss()
          }
          .foregroundColor(.red)
        }
        
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Done", systemImage: "checkmark") {
            dismiss()
          }
          .foregroundColor(.blue)
        }
      }
    }
  }
  
  private func getSortDirectionTitle(ascending: Bool) -> String {
    switch sortBy {
    case .title:
      return ascending ? "A to Z" : "Z to A"
    case .watchDate:
      return ascending ? "Oldest First" : "Newest First"
    case .releaseDate:
      return ascending ? "Oldest First" : "Newest First"
    case .rating:
      return ascending ? "Lowest First" : "Highest First"
    case .detailedRating:
      return ascending ? "Lowest First" : "Highest First"
    case .dateAdded:
      return ascending ? "Oldest First" : "Newest First"
    }
  }
}

struct SortFieldRow: View {
  let sortField: MovieSortField
  let isSelected: Bool
  let sortAscending: Bool
  let action: () -> Void
  
  var body: some View {
    Button(action: action) {
      HStack {
        Text(sortField.displayName)
          .font(.system(size: 16, weight: .medium))
          .foregroundColor(isSelected ? .black : .white)
        
        Spacer()
        
        if isSelected {
          Image(systemName: "checkmark")
            .foregroundColor(.black)
            .font(.system(size: 14, weight: .bold))
        }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
      .background(
        RoundedRectangle(cornerRadius: 8)
          .fill(isSelected ? .white : Color.gray.opacity(0.3))
      )
    }
    .buttonStyle(PlainButtonStyle())
  }
}

struct SortDirectionRow: View {
  let title: String
  let icon: String
  let isSelected: Bool
  let action: () -> Void
  
  var body: some View {
    Button(action: action) {
      HStack {
        Image(systemName: icon)
          .foregroundColor(isSelected ? .black : .white)
          .font(.system(size: 14, weight: .medium))
        
        Text(title)
          .font(.system(size: 16, weight: .medium))
          .foregroundColor(isSelected ? .black : .white)
        
        Spacer()
        
        if isSelected {
          Image(systemName: "checkmark")
            .foregroundColor(.black)
            .font(.system(size: 14, weight: .bold))
        }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
      .background(
        RoundedRectangle(cornerRadius: 8)
          .fill(isSelected ? .white : Color.gray.opacity(0.3))
      )
    }
    .buttonStyle(PlainButtonStyle())
  }
}

#Preview {
  MoviesView()
}

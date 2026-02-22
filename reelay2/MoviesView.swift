//
//  MoviesView.swift
//  reelay2
//
//  Created by Humza Khalil on 7/21/25.
//

import SDWebImageSwiftUI
import SwiftUI
import Combine

struct MoviesView: View {
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @ObservedObject private var movieService = SupabaseMovieService.shared
  @StateObject private var viewModel = MoviesViewModel()
  @State private var showingAddMovie = false
  @State private var showingAddTelevision = false
  @State private var showingAddAlbum = false
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
  private let listService = SupabaseListService.shared
  @StateObject private var filterViewModel = FilterViewModel()
  @State private var movieToAddToLists: Movie?
  @State private var movieToChangePoster: Movie?
  @State private var movieToChangeBackdrop: Movie?
  
  #if os(macOS)
  @EnvironmentObject private var navigationCoordinator: NavigationCoordinator
  #endif

  private var appBackground: Color {
    #if canImport(UIKit)
    colorScheme == .dark ? .black : Color(.systemGroupedBackground)
    #else
    colorScheme == .dark ? .black : Color(.windowBackgroundColor)
    #endif
  }

  enum ViewMode {
    case list, tile, calendar
  }

  private var movies: [Movie] { viewModel.allMovies }
  private var filteredMovies: [Movie] { viewModel.filteredMovies }

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
    return "Movies"
  }

  private func cycleViewMode() {
    switch viewMode {
    case .list:
      viewMode = .tile
    case .tile:
      viewMode = .calendar
    case .calendar:
      viewMode = .list
    }
  }

  private func syncViewModelInputs() {
    viewModel.configure(
      sortBy: sortBy,
      sortAscending: sortAscending,
      filters: filterViewModel.appliedFiltersState,
      selectedDate: selectedDate,
      currentCalendarMonth: currentCalendarMonth
    )
  }

  // MARK: - Local Sorting Logic

  private func sortMovies(_ movies: [Movie]) -> [Movie] {
    return movies.sorted { movie1, movie2 in
      switch sortBy {
      case .title:
        let title1 = movie1.title.lowercased()
        let title2 = movie2.title.lowercased()
        if title1 == title2 {
          let created1 = movie1.created_at ?? ""
          let created2 = movie2.created_at ?? ""
          return sortAscending ? created1 < created2 : created1 > created2
        }
        return sortAscending ? title1 < title2 : title1 > title2
        
      case .watchDate:
        let date1 = movie1.watch_date ?? ""
        let date2 = movie2.watch_date ?? ""
        if date1 == date2 {
          let created1 = movie1.created_at ?? ""
          let created2 = movie2.created_at ?? ""
          return sortAscending ? created1 < created2 : created1 > created2
        }
        return sortAscending ? date1 < date2 : date1 > date2
        
      case .releaseDate:
        let year1 = movie1.release_year ?? 0
        let year2 = movie2.release_year ?? 0
        if year1 == year2 {
          let created1 = movie1.created_at ?? ""
          let created2 = movie2.created_at ?? ""
          return sortAscending ? created1 < created2 : created1 > created2
        }
        return sortAscending ? year1 < year2 : year1 > year2
        
      case .rating:
        let rating1 = movie1.rating ?? 0
        let rating2 = movie2.rating ?? 0
        if rating1 == rating2 {
          let created1 = movie1.created_at ?? ""
          let created2 = movie2.created_at ?? ""
          return sortAscending ? created1 < created2 : created1 > created2
        }
        return sortAscending ? rating1 < rating2 : rating1 > rating2
        
      case .detailedRating:
        let detailed1 = movie1.detailed_rating ?? 0
        let detailed2 = movie2.detailed_rating ?? 0
        if detailed1 == detailed2 {
          let created1 = movie1.created_at ?? ""
          let created2 = movie2.created_at ?? ""
          return sortAscending ? created1 < created2 : created1 > created2
        }
        return sortAscending ? detailed1 < detailed2 : detailed1 > detailed2
        
      case .dateAdded:
        let created1 = movie1.created_at ?? ""
        let created2 = movie2.created_at ?? ""
        return sortAscending ? created1 < created2 : created1 > created2
      }
    }
  }

  var body: some View {
    presentedView
  }

  private var baseView: some View {
    VStack(spacing: 0) {
      if filterViewModel.hasActiveFilters {
        filterSummaryBar
      }
      contentView
    }
    .navigationTitle(navigationTitle)
    #if canImport(UIKit)
    .toolbarTitleDisplayMode(.inlineLarge)
    .background(Color(.systemGroupedBackground))
    #else
    .background(Color(.windowBackgroundColor))
    #endif
    .toolbar {
      moviesToolbar
    }
  }

  @ToolbarContentBuilder
  private var moviesToolbar: some ToolbarContent {
    ToolbarItemGroup {
      Button(action: {
        if reduceMotion {
          cycleViewMode()
        } else {
          withAnimation(.easeInOut(duration: 0.3)) {
            cycleViewMode()
          }
        }
      }) {
        Image(systemName: viewModeIcon)
          .font(.system(size: 16, weight: .medium))
      }
      .accessibilityIdentifier("movies.viewModeButton")

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
      .accessibilityIdentifier("movies.filterButton")

      Button(action: {
        showingSortOptions = true
      }) {
        Image(systemName: sortAscending ? "arrow.up" : "arrow.down")
          .font(.system(size: 16, weight: .medium))
      }
      .accessibilityIdentifier("movies.sortButton")
    }

    ToolbarSpacer(.fixed)

    ToolbarItem(placement: .confirmationAction) {
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
      } label: {
        Image(systemName: "plus")
      }
      .accessibilityIdentifier("movies.addMenuButton")
    }
  }

  private var lifecycleBoundView: some View {
    baseView
      .task {
        syncViewModelInputs()
        if movieService.isLoggedIn && !viewModel.hasLoadedInitially {
          await DataManager.shared.refreshListsOptimized()
          await viewModel.loadMoviesIfNeeded(force: true)
        }
      }
      .onChange(of: movieService.isLoggedIn) { _, isLoggedIn in
        if isLoggedIn {
          Task {
            syncViewModelInputs()
            await DataManager.shared.refreshListsOptimized()
            await viewModel.loadMoviesIfNeeded(force: true)
          }
        } else {
          viewModel.clearForLogout()
        }
      }
      .onAppear {
        syncViewModelInputs()
        if movieService.isLoggedIn && viewModel.shouldRefreshData() {
          Task {
            await viewModel.loadMoviesIfNeeded(force: false)
          }
        }
      }
      .onChange(of: showingAddMovie) { _, isShowing in
        if !isShowing && movieService.isLoggedIn {
          Task {
            await refreshMoviesKeepingPlace()
          }
        }
      }
      .onChange(of: showingAddTelevision) { _, isShowing in
        if !isShowing && movieService.isLoggedIn {
          Task {
            await DataManager.shared.refreshTelevision()
          }
        }
      }
      .onChange(of: showingAddAlbum) { _, isShowing in
        if !isShowing && movieService.isLoggedIn {
          Task {
            await DataManager.shared.refreshAlbums()
          }
        }
      }
      .onChange(of: showingLogAgain) { _, isShowing in
        if !isShowing && movieService.isLoggedIn {
          Task {
            await refreshMoviesKeepingPlace()
          }
        }
      }
      .onChange(of: sortBy) { _, _ in
        syncViewModelInputs()
      }
      .onChange(of: sortAscending) { _, _ in
        syncViewModelInputs()
      }
      .onChange(of: selectedDate) { _, _ in
        syncViewModelInputs()
      }
      .onChange(of: currentCalendarMonth) { _, _ in
        syncViewModelInputs()
      }
      .onChange(of: filterViewModel.appliedFiltersState) { _, _ in
        syncViewModelInputs()
      }
      .onReceive(movieService.$lastMovieMutationAt.dropFirst()) { mutationDate in
        guard mutationDate != nil, movieService.isLoggedIn else { return }
        Task {
          await refreshMoviesKeepingPlace()
        }
      }
  }

  private var presentedView: some View {
    lifecycleBoundView
      .sheet(isPresented: $showingAddMovie) {
        AddMoviesView()
      }
      .sheet(isPresented: $showingAddTelevision) {
        AddTelevisionView()
      }
      .sheet(isPresented: $showingAddAlbum) {
        AddAlbumsView()
      }
      .sheet(isPresented: $showingFilters) {
        FilterSortView(
          sortBy: $sortBy,
          filterViewModel: filterViewModel,
          movies: movies
        )
      }
      .confirmationDialog("Sort By", isPresented: $showingSortOptions) {
        ForEach(MovieSortField.allCases, id: \.rawValue) { field in
          Button(field.displayName) {
            if sortBy == field {
              sortAscending.toggle()
            } else {
              sortBy = field
              sortAscending = false
            }
          }
        }
      }
      #if os(iOS)
      .sheet(item: $selectedMovie) { movie in
        MovieDetailsView(movie: movie)
      }
      #else
      .onChange(of: selectedMovie) { _, newMovie in
        if let movie = newMovie {
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
          ) { _ in
            Task {
              await refreshMoviesKeepingPlace()
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
          ) { _ in
            Task {
              await refreshMoviesKeepingPlace()
            }
          }
        }
      }
      .alert("Delete Entry", isPresented: $showingDeleteMovieAlert) {
        Button("Cancel", role: .cancel) {}
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

      Text(
        "\(filterViewModel.activeFilterCount) filter\(filterViewModel.activeFilterCount == 1 ? "" : "s") active"
      )
      .font(.system(size: 14, weight: .medium))
      .foregroundColor(Color.adaptiveText(scheme: colorScheme))

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
    .background(Color.adaptiveCardBackground(scheme: colorScheme))
  }

  @ViewBuilder
  private var contentView: some View {
    Group {
      if !movieService.isLoggedIn {
        notLoggedInView
      } else if viewModel.isInitialLoad {
        SkeletonMoviesContent(viewMode: viewMode)
      } else if viewModel.isLoading && viewModel.allMovies.isEmpty {
        loadingView
      } else if filteredMovies.isEmpty {
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
        .foregroundColor(Color.adaptiveText(scheme: colorScheme))

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
    VStack(spacing: 16) {
      Spacer()
      ProgressView()
        .progressViewStyle(CircularProgressViewStyle(tint: .white))
        .scaleEffect(1.2)
      Text("Finishing a film...")
        .font(.system(size: 16, weight: .medium))
        .foregroundColor(Color.adaptiveText(scheme: colorScheme))
      Spacer()
    }
  }

  @ViewBuilder
  private var emptyStateView: some View {
    VStack(spacing: 16) {
      if let errorMessage = viewModel.errorMessage {
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
        .foregroundColor(Color.adaptiveText(scheme: colorScheme))
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
          .foregroundColor(Color.adaptiveText(scheme: colorScheme))
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
          .foregroundColor(Color.adaptiveText(scheme: colorScheme))
        Text(
          "Start logging your movie diary by adding your first film."
        )
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
        ForEach(viewModel.visibleSections) { section in
          movieMonthSection(section: section)
        }
      }
    }
    .scrollContentBackground(.hidden)
    .refreshable {
      await handleUserRefresh()
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
        ForEach(viewModel.visibleSections) { section in
          movieTileMonthSection(section: section)
        }
      }
    }
    .scrollContentBackground(.hidden)
    .refreshable {
      await handleUserRefresh()
    }
  }

  @ViewBuilder
  private func movieMonthSection(section: MovieSectionSnapshot)
    -> some View
  {
    VStack(spacing: 0) {
      MonthHeaderView(
        monthYearKey: section.monthYearKey,
        displayMonthYear: section.displayTitle
      ) {
        Task {
          await viewModel.reloadMonthDescriptors()
        }
      }

      // Movies for this month
      VStack(spacing: 12) {
        ForEach(section.movies) { movie in
          movieButton(for: movie)
        }
      }
      .padding(.bottom, 8)
    }
  }

  @ViewBuilder
  private func movieButton(for movie: Movie) -> some View {
    let metadata = viewModel.metadata(for: movie)

    Button(action: {
      selectedMovie = movie
    }) {
      movieRowCard(movie: movie, metadata: metadata)
    }
    .buttonStyle(PlainButtonStyle())
    .contextMenu {
      movieContextMenuItems(for: movie)
    }
    .accessibilityAction(named: Text("Log Again")) {
      handleLogAgain(movie)
    }
    .accessibilityAction(
      named: Text(movie.isFavorited ? "Remove Favorite" : "Add Favorite")
    ) {
      handleToggleFavorite(movie)
    }
    .accessibilityAction(named: Text("Add to List")) {
      handleAddToList(movie)
    }
    .accessibilityAction(named: Text("Edit Entry")) {
      handleEditMovie(movie)
    }
    .accessibilityAction(named: Text("Delete Entry")) {
      handleDeleteMovie(movie)
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
  private func movieRowCard(movie: Movie, metadata: MovieRowMetadata) -> some View {
    MovieRowView(
      movie: movie,
      rewatchIconColor: metadata.rewatchColorToken.color,
      shouldHighlightMustWatchTitle: metadata.shouldHighlightMustWatchTitle,
      shouldHighlightReleaseYearTitle: metadata.shouldHighlightReleaseYearTitle,
      shouldHighlightReleaseYearOnYear: metadata.shouldHighlightReleaseYearOnYear,
      watchDay: metadata.watchDay,
      watchDayOfWeek: metadata.watchDayOfWeek,
      tagIcons: metadata.tagIcons,
      accessibilityLabel: metadata.accessibilityLabel,
      accessibilityValue: metadata.accessibilityValue
    )
    .padding(.horizontal, 20)
    .background(
      RoundedRectangle(cornerRadius: 24)
        .fill(colorScheme == .dark ? Color.gray.opacity(0.15) : .white)
        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
    )
    .overlay {
      if metadata.isCentennialTotalLog {
        RoundedRectangle(cornerRadius: 24)
          .stroke(
            LinearGradient(
              colors: [.red, .pink, .purple],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            ),
            lineWidth: 3
          )
      } else if metadata.isCentennialUniqueFilm {
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
    .cornerRadius(24)
    .padding(.horizontal, 20)
  }

  @ViewBuilder
  private func movieContextMenuItems(for movie: Movie) -> some View {
    Button("Log Again", systemImage: "plus.circle") {
      handleLogAgain(movie)
    }
    Button(
      movie.isFavorited ? "Remove from Favorites" : "Add to Favorites",
      systemImage: movie.isFavorited ? "heart.fill" : "heart"
    ) {
      handleToggleFavorite(movie)
    }
    Button("Add to List", systemImage: "list.bullet") {
      handleAddToList(movie)
    }
    Button("Edit Entry", systemImage: "pencil") {
      handleEditMovie(movie)
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
      handleDeleteMovie(movie)
    }
  }

  private func handleLogAgain(_ movie: Movie) {
    movieToLogAgain = movie
    showingLogAgain = true
  }

  private func handleToggleFavorite(_ movie: Movie) {
    Task {
      await toggleMovieFavorite(movie)
    }
  }

  private func handleAddToList(_ movie: Movie) {
    movieToAddToLists = movie
  }

  private func handleEditMovie(_ movie: Movie) {
    movieToEdit = movie
  }

  private func handleDeleteMovie(_ movie: Movie) {
    movieToDelete = movie
    showingDeleteMovieAlert = true
  }

  @ViewBuilder
  private func movieTileMonthSection(section: MovieSectionSnapshot)
    -> some View
  {
    VStack(spacing: 0) {
      MonthHeaderView(
        monthYearKey: section.monthYearKey,
        displayMonthYear: section.displayTitle
      ) {
        Task {
          await viewModel.reloadMonthDescriptors()
        }
      }

      // Movies grid for this month
      let columns = Array(
        repeating: GridItem(.flexible(), spacing: 12),
        count: 3
      )
      LazyVGrid(columns: columns, spacing: 12) {
        ForEach(section.movies) { movie in
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
                    currentCalendarMonth =
                      Calendar.current.date(
                        byAdding: .month,
                        value: -1,
                        to: currentCalendarMonth
                      ) ?? currentCalendarMonth
                  }
                } else if value.translation.width < -threshold {
                  // Swipe left - next month
                  withAnimation(.easeInOut(duration: 0.3)) {
                    currentCalendarMonth =
                      Calendar.current.date(
                        byAdding: .month,
                        value: 1,
                        to: currentCalendarMonth
                      ) ?? currentCalendarMonth
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
      await handleUserRefresh()
    }
  }

  @ViewBuilder
  private var calendarHeader: some View {
    HStack(alignment: .center) {
      Button(action: {
        withAnimation(.easeInOut(duration: 0.2)) {
          currentCalendarMonth =
            Calendar.current.date(
              byAdding: .month,
              value: -1,
              to: currentCalendarMonth
            ) ?? currentCalendarMonth
        }
      }) {
        Image(systemName: "chevron.left")
          .foregroundColor(Color.adaptiveText(scheme: colorScheme))
          .font(.title2)
      }

      Spacer()

      VStack(spacing: 6) {
        Text(Self.monthYearFormatter.string(from: currentCalendarMonth))
          .font(.title2)
          .fontWeight(.semibold)
          .foregroundColor(Color.adaptiveText(scheme: colorScheme))
          .onTapGesture(count: 2) {
            returnToCurrentDate()
          }
        monthCountPill
      }

      Spacer()

      Button(action: {
        withAnimation(.easeInOut(duration: 0.2)) {
          currentCalendarMonth =
            Calendar.current.date(
              byAdding: .month,
              value: 1,
              to: currentCalendarMonth
            ) ?? currentCalendarMonth
        }
      }) {
        Image(systemName: "chevron.right")
          .foregroundColor(Color.adaptiveText(scheme: colorScheme))
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
        ForEach(
          ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"],
          id: \.self
        ) { day in
          Text(day)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(.gray)
            .frame(maxWidth: .infinity)
        }
      }

      // Calendar days
      LazyVGrid(
        columns: Array(repeating: GridItem(.flexible()), count: 7),
        spacing: 8
      ) {
        ForEach(calendarDays, id: \.self) { date in
          calendarDayView(for: date)
        }
      }
    }
    .padding(.vertical, 12)
    .background(colorScheme == .dark ? Color.gray.opacity(0.15) : .white)
    .cornerRadius(16)
  }

  private var calendarDays: [Date] {
    let calendar = Calendar.current
    let startOfMonth =
      calendar.dateInterval(of: .month, for: currentCalendarMonth)?.start
      ?? currentCalendarMonth
    let startOfCalendar =
      calendar.dateInterval(of: .weekOfYear, for: startOfMonth)?.start
      ?? startOfMonth

    var days: [Date] = []
    var currentDate = startOfCalendar

    // Generate 42 days (6 weeks) to fill the calendar grid
    for _ in 0..<42 {
      days.append(currentDate)
      currentDate =
        calendar.date(byAdding: .day, value: 1, to: currentDate)
        ?? currentDate
    }

    return days
  }

  @ViewBuilder
  private func calendarDayView(for date: Date) -> some View {
    let calendar = Calendar.current
    let isCurrentMonth = calendar.isDate(
      date,
      equalTo: currentCalendarMonth,
      toGranularity: .month
    )
    let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
    let isToday = calendar.isDateInToday(date)
    let movieCount = viewModel.movieCountForDate(date)

    Button(action: {
      withAnimation(.easeInOut(duration: 0.2)) {
        selectedDate = date
      }
    }) {
      VStack(spacing: 2) {
        // Day number
        Text("\(calendar.component(.day, from: date))")
          .font(
            .system(size: 14, weight: isSelected ? .bold : .medium)
          )
          .foregroundColor(
            dayTextColor(
              isCurrentMonth: isCurrentMonth,
              isSelected: isSelected,
              isToday: isToday
            )
          )

        // Movie dots (max 3)
        HStack(spacing: 2) {
          ForEach(0..<min(movieCount, 3), id: \.self) { _ in
            Circle()
              .fill(Color.adaptiveText(scheme: colorScheme).opacity(0.8))
              .frame(width: 3, height: 3)
          }
          if movieCount > 3 {
            Text("+")
              .font(.system(size: 6, weight: .bold))
              .foregroundColor(Color.adaptiveText(scheme: colorScheme).opacity(0.8))
          }
        }
        .frame(height: 6)
      }
      .frame(width: 36, height: 36)
      .background(
        RoundedRectangle(cornerRadius: 8)
          .fill(
            dayBackgroundColor(
              movieCount: movieCount,
              isSelected: isSelected,
              isToday: isToday
            )
          )
      )
    }
    .buttonStyle(PlainButtonStyle())
    .opacity(isCurrentMonth ? 1.0 : 0.3)
  }

  @ViewBuilder
  private var selectedDateMoviesList: some View {
    let moviesForSelectedDate = viewModel.selectedDateMovies

    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text(
          "Movies watched on \(Self.selectedDateFormatter.string(from: selectedDate))"
        )
        .font(.headline)
        .fontWeight(.semibold)
        .foregroundColor(Color.adaptiveText(scheme: colorScheme))
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
              let metadata = viewModel.metadata(for: movie)

              selectedDateMovieRow(
                movie: movie,
                rewatchIconColor: metadata.rewatchColorToken.color,
                shouldHighlightMustWatchTitle: metadata.shouldHighlightMustWatchTitle,
                shouldHighlightReleaseYearTitle: metadata.shouldHighlightReleaseYearTitle,
                shouldHighlightReleaseYearOnYear: metadata.shouldHighlightReleaseYearOnYear,
                isUniqueFilm: metadata.isCentennialUniqueFilm,
                isTotalLog: metadata.isCentennialTotalLog,
                tagIcons: metadata.tagIcons,
                accessibilityLabel: metadata.accessibilityLabel,
                accessibilityValue: metadata.accessibilityValue
              )
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
              Button(movie.isFavorited ? "Remove from Favorites" : "Add to Favorites", 
                     systemImage: movie.isFavorited ? "heart.fill" : "heart") {
                Task {
                  await toggleMovieFavorite(movie)
                }
              }
              Button("Add to List", systemImage: "list.bullet") {
                movieToAddToLists = movie
              }
              Button("Edit Entry", systemImage: "pencil") {
                movieToEdit = movie
              }
              Button(
                "Remove Entry",
                systemImage: "trash",
                role: .destructive
              ) {
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
  private func selectedDateMovieRow(
    movie: Movie,
    rewatchIconColor: Color,
    shouldHighlightMustWatchTitle: Bool,
    shouldHighlightReleaseYearTitle: Bool,
    shouldHighlightReleaseYearOnYear: Bool,
    isUniqueFilm: Bool,
    isTotalLog: Bool,
    tagIcons: [MovieTagIconSnapshot],
    accessibilityLabel: String,
    accessibilityValue: String
  ) -> some View {
    HStack(spacing: 12) {
      // Movie poster
      WebImage(
        url: movie.posterURL(for: .w92),
        options: [.scaleDownLargeImages, .continueInBackground, .retryFailed]
      ) { image in
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
        HStack(alignment: .top, spacing: 4) {
          Text(movie.title)
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundColor(
              shouldHighlightMustWatchTitle
                ? .purple
                : shouldHighlightReleaseYearTitle ? .cyan : Color.adaptiveText(scheme: colorScheme)
            )
            .shadow(
              color: shouldHighlightMustWatchTitle
                ? .purple.opacity(0.6)
                : shouldHighlightReleaseYearTitle
                  ? .cyan.opacity(0.6) : .clear,
              radius: 2,
              x: 0,
              y: 0
            )
            .lineLimit(2)
          
          if movie.isFavorited {
            Image(systemName: "heart.fill")
              .foregroundColor(.orange)
              .font(.system(size: 10, weight: .semibold))
              .baselineOffset(-12)  // Drop down by 12 points
          }
        }

        Text(movie.formattedReleaseYear)
          .font(.caption)
          .foregroundColor(
            shouldHighlightReleaseYearOnYear ? .cyan : .gray
          )
          .shadow(
            color: shouldHighlightReleaseYearOnYear
              ? .cyan.opacity(0.6) : .clear,
            radius: 2,
            x: 0,
            y: 0
          )

        // Star rating and detailed rating
        HStack(spacing: 6) {
          CompactStarRatingView(rating: movie.rating, fontSize: 10)

          if let detailedRating = movie.detailed_rating {
            Text(String(format: "%.0f", detailedRating))
              .font(
                .system(
                  size: 11,
                  weight: .medium,
                  design: .rounded
                )
              )
              .foregroundColor(.purple)
          }

          if movie.isRewatchMovie {
            Image(systemName: "arrow.clockwise")
              .foregroundColor(rewatchIconColor)
              .font(.system(size: 12, weight: .semibold))
          }
        }

        if !tagIcons.isEmpty {
          HStack(spacing: 3) {
            ForEach(tagIcons, id: \.icon) { iconData in
              Image(systemName: iconData.icon)
                .foregroundColor(iconData.colorToken.color)
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
        .fill(colorScheme == .dark ? Color.gray.opacity(0.15) : .white)
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
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(accessibilityLabel)
    .accessibilityValue(accessibilityValue)
    .accessibilityHint("Opens movie details")
  }

  // Helper computed properties and functions
  // Static formatters to avoid recreation on each view update
  private static let monthYearFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMMM yyyy"
    return formatter
  }()

  @ViewBuilder
  private var monthCountPill: some View {
    let filteredCount = viewModel.moviesCountInMonth(for: currentCalendarMonth, filtered: true)
    let totalCount = viewModel.moviesCountInMonth(for: currentCalendarMonth, filtered: false)

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

  private static let selectedDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "EEEE, MMMM d"
    return formatter
  }()

  /// Pre-sorts movies for section display to avoid inline sorting during ForEach rendering
  private func sortedMoviesForSection(_ movies: [Movie]) -> [Movie] {
    movies.sorted { movie1, movie2 in
      let date1 = movie1.watch_date ?? ""
      let date2 = movie2.watch_date ?? ""
      if date1 == date2 {
        // Secondary sort by created_at for same watch dates
        let created1 = movie1.created_at ?? ""
        let created2 = movie2.created_at ?? ""
        return created1 > created2  // Most recent created_at first
      }
      return date1 > date2  // Most recent watch_date first
    }
  }
  private func moviesCountInMonth(for monthDate: Date, in source: [Movie])
    -> Int
  {
    let calendar = Calendar.current
    var total = 0
    for movie in source {
      guard let dateString = movie.watch_date,
        let date = DateFormatter.movieDateFormatter.date(
          from: dateString
        )
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

  private func dayTextColor(
    isCurrentMonth: Bool,
    isSelected: Bool,
    isToday: Bool
  ) -> Color {
    if isSelected {
      return .black
    } else if isToday {
      return .white
    } else if isCurrentMonth {
      return Color.adaptiveText(scheme: colorScheme)
    } else {
      return .gray
    }
  }

  private func dayBackgroundColor(
    movieCount: Int,
    isSelected: Bool,
    isToday: Bool
  ) -> Color {
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

  private func tagIconsWithColors(
    for tagsString: String?,
    hasLocation: Bool = false
  ) -> [(
    icon: String, color: Color
  )] {
    return TagConfiguration.getTagIconsWithColors(
      for: tagsString,
      hasLocation: hasLocation
    )
  }

  @ViewBuilder
  private func movieTileButton(for movie: Movie) -> some View {
    Button(action: {
      if reduceMotion {
        tappedMovieId = movie.id
      } else {
        withAnimation(
          .spring(response: 0.3, dampingFraction: 0.6, blendDuration: 0)
        ) {
          tappedMovieId = movie.id
        }
      }

      // Show movie details after brief delay
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        selectedMovie = movie
        tappedMovieId = nil
      }
    }) {
      let metadata = viewModel.metadata(for: movie)

      MovieTileView(
        movie: movie,
        rewatchIconColor: metadata.rewatchColorToken.color,
        accessibilityLabel: metadata.accessibilityLabel,
        accessibilityValue: metadata.accessibilityValue
      )
      .overlay(
        Group {
          // Prioritize red (total log) over yellow (unique film) if both apply
          if metadata.isCentennialTotalLog {
            RoundedRectangle(cornerRadius: 12)
              .stroke(
                LinearGradient(
                  colors: [.red, .pink, .purple],
                  startPoint: .topLeading,
                  endPoint: .bottomTrailing
                ),
                lineWidth: 3
              )
          } else if metadata.isCentennialUniqueFilm {
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
        reduceMotion
          ? .linear(duration: 0.01)
          : .spring(response: 0.3, dampingFraction: 0.6, blendDuration: 0),
        value: tappedMovieId
      )
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
      Button(movie.isFavorited ? "Remove from Favorites" : "Add to Favorites", 
             systemImage: movie.isFavorited ? "heart.fill" : "heart") {
        Task {
          await toggleMovieFavorite(movie)
        }
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
    guard let date = DateFormatter.movieDateFormatter.date(from: dateString) else {
      return "Unknown Date"
    }
    return Self.monthYearFormatter.string(from: date)
  }

  private func getDateFromMonthYear(_ monthYearString: String) -> Date {
    return Self.monthYearFormatter.date(from: monthYearString) ?? Date.distantPast
  }

  // MARK: - Efficient Loading Functions

  private func shouldRefreshData() -> Bool {
    viewModel.shouldRefreshData()
  }

  private func loadMoviesIfNeeded(force: Bool) async {
    await viewModel.loadMoviesIfNeeded(force: force)
  }

  private func refreshMovies() async {
    await viewModel.refreshMovies()
  }

  private func refreshMoviesKeepingPlace() async {
    syncViewModelInputs()
    if viewModel.hasLoadedInitially && !movies.isEmpty {
      await viewModel.refreshMovies()
    } else {
      await viewModel.loadMoviesIfNeeded(force: true)
    }
  }

  private func handleUserRefresh() async {
    syncViewModelInputs()
    await viewModel.refreshMovies()
  }

  private func loadMovies() async {
    await viewModel.loadMoviesIfNeeded(force: true)
  }

  private func updateMovieInPlace(_ updated: Movie) {
    viewModel.updateMovieInPlace(updated)
  }

  private func deleteMovie(_ movie: Movie) async {
    do {
      try await movieService.deleteMovie(id: movie.id)
      await MainActor.run {
        viewModel.removeMovie(id: movie.id)
        movieToDelete = nil
        showingDeleteMovieAlert = false
      }
    } catch {
      await MainActor.run {
        // Error remains visible through existing empty/error states after next refresh.
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
    let entriesForMovie = movies.filter {
      $0.tmdb_id == movie.tmdb_id && $0.tmdb_id != nil
    }

    // Check if this is the first entry (by watch_date) and it's marked as rewatch
    guard
      let sortedEntries = entriesForMovie.sorted(by: {
        ($0.watch_date ?? "") < ($1.watch_date ?? "")
      }).first
    else {
      return false
    }

    return sortedEntries.id == movie.id && movie.isRewatchMovie
  }

  private func wasFirstWatchedInSameYear(_ movie: Movie) -> Bool {
    guard let watchDate = movie.watch_date,
      let movieWatchDate = DateFormatter.movieDateFormatter.date(
        from: watchDate
      ),
      let tmdbId = movie.tmdb_id
    else { return false }

    let calendar = Calendar.current
    let movieYear = calendar.component(.year, from: movieWatchDate)

    // Find all entries for this movie
    let entriesForMovie = movies.filter { $0.tmdb_id == tmdbId }
      .compactMap { movie -> (Movie, Date)? in
        guard let dateString = movie.watch_date,
          let date = DateFormatter.movieDateFormatter.date(
            from: dateString
          )
        else { return nil }
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
      return !firstEntry.isRewatchMovie && movie.isRewatchMovie
        && movie.id != firstEntry.id
    }

    return false
  }

  private func isOnMustWatchesList(_ movie: Movie, for year: Int) -> Bool {
    guard let tmdbId = movie.tmdb_id else { return false }
    
    // Try to use cached must watches mapping for better performance
    if !MustWatchesCache.shared.needsRefresh {
      return MustWatchesCache.shared.isOnMustWatches(tmdbId: tmdbId, year: year)
    }

    // Fallback to legacy lookup if cache is stale
    let mustWatchesListName = "Must Watches for \(year)"
    guard
      let mustWatchesList = listService.movieLists.first(where: {
        $0.name == mustWatchesListName
      })
    else {
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

    // Try to use cached first watch date for better performance
    if let tmdbId = movie.tmdb_id,
       let cachedFirstWatch = FirstWatchDateCache.shared.getFirstWatch(for: tmdbId) {
      return getRewatchColorFromCache(movie: movie, firstWatch: cachedFirstWatch)
    }
    
    // Fallback to legacy computation if cache miss
    return getRewatchColorLegacy(for: movie)
  }
  
  /// Compute rewatch color using cached first watch date
  private func getRewatchColorFromCache(movie: Movie, firstWatch: (date: Date?, year: Int?)) -> Color {
    guard let watchDateString = movie.watch_date,
          let movieWatchDate = DateFormatter.movieDateFormatter.date(from: watchDateString) else {
      return .orange
    }
    
    let calendar = Calendar.current
    let movieYear = calendar.component(.year, from: movieWatchDate)
    
    // Grey: No first watch found (first entry but marked as rewatch)
    guard let firstWatchYear = firstWatch.year else {
      return .gray
    }
    
    // Yellow: First watched and rewatched in same calendar year
    if movieYear == firstWatchYear {
      return .yellow
    }
    
    // Orange: Movie was logged in a previous year
    return .orange
  }
  
  /// Legacy rewatch color computation (fallback when cache is not available)
  private func getRewatchColorLegacy(for movie: Movie) -> Color {
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
      let movieWatchDate = DateFormatter.movieDateFormatter.date(
        from: watchDate
      ),
      let tmdbId = movie.tmdb_id
    else { return false }

    let calendar = Calendar.current
    let movieYear = calendar.component(.year, from: movieWatchDate)

    // Find all entries for this movie
    let entriesForMovie = movies.filter { $0.tmdb_id == tmdbId }
      .compactMap { movie -> (Movie, Date)? in
        guard let dateString = movie.watch_date,
          let date = DateFormatter.movieDateFormatter.date(
            from: dateString
          )
        else { return nil }
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
      return !firstEntry.isRewatchMovie && movie.isRewatchMovie
        && movie.id != firstEntry.id
    }

    return false
  }

  private func wasLoggedInPreviousYear(_ movie: Movie) -> Bool {
    guard let watchDate = movie.watch_date,
      let movieWatchDate = DateFormatter.movieDateFormatter.date(
        from: watchDate
      ),
      let tmdbId = movie.tmdb_id
    else { return false }

    let calendar = Calendar.current
    let movieYear = calendar.component(.year, from: movieWatchDate)

    // Find all entries for this movie
    let entriesForMovie = movies.filter { $0.tmdb_id == tmdbId }
      .compactMap { movie -> Date? in
        guard let dateString = movie.watch_date,
          let date = DateFormatter.movieDateFormatter.date(
            from: dateString
          )
        else { return nil }
        return date
      }

    // Check if any entry was in a previous year
    return entriesForMovie.contains { date in
      calendar.component(.year, from: date) < movieYear
    }
  }

  private func wasWatchedInReleaseYear(_ movie: Movie) -> Bool {
    guard let watchDate = movie.watch_date,
      let movieWatchDate = DateFormatter.movieDateFormatter.date(
        from: watchDate
      ),
      let releaseYear = movie.release_year
    else { return false }

    let calendar = Calendar.current
    let watchYear = calendar.component(.year, from: movieWatchDate)

    return watchYear == releaseYear
  }

  private func shouldHighlightMustWatchTitle(_ movie: Movie) -> Bool {
    guard let watchDate = movie.watch_date,
      let movieWatchDate = DateFormatter.movieDateFormatter.date(
        from: watchDate
      )
    else { return false }

    let calendar = Calendar.current
    let watchYear = calendar.component(.year, from: movieWatchDate)

    let isOnMustWatches = isOnMustWatchesList(movie, for: watchYear)
    let isWatchedInReleaseYear = wasWatchedInReleaseYear(movie)

    // Highlight title for must watches when there's no overlap with release year highlighting
    // OR when there is overlap (both conditions true), prioritize must watch on title
    return isOnMustWatches
      && (!isWatchedInReleaseYear || isWatchedInReleaseYear)
  }

  private func shouldHighlightReleaseYearTitle(_ movie: Movie) -> Bool {
    guard let watchDate = movie.watch_date,
      let movieWatchDate = DateFormatter.movieDateFormatter.date(
        from: watchDate
      )
    else { return false }

    let calendar = Calendar.current
    let watchYear = calendar.component(.year, from: movieWatchDate)

    let isOnMustWatches = isOnMustWatchesList(movie, for: watchYear)
    let isWatchedInReleaseYear = wasWatchedInReleaseYear(movie)

    // Highlight title for release year only when there's no must watch overlap
    return isWatchedInReleaseYear && !isOnMustWatches
  }

  private func shouldHighlightReleaseYearOnYear(_ movie: Movie) -> Bool {
    guard let watchDate = movie.watch_date,
      let movieWatchDate = DateFormatter.movieDateFormatter.date(
        from: watchDate
      )
    else { return false }

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
      guard let date1 = movie1.watch_date, let date2 = movie2.watch_date
      else { return false }
      return date1 < date2
    }

    // Track unique titles encountered
    var uniqueTitles: Set<String> = []
    var centennialPositions: Set<Int> = []

    for (index, sortedMovie) in sortedMovies.enumerated() {
      let title = sortedMovie.title.lowercased().trimmingCharacters(
        in: .whitespaces
      )
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
    if let movieIndex = sortedMovies.firstIndex(where: { $0.id == movie.id }
    ) {
      return centennialPositions.contains(movieIndex)
    }

    return false
  }

  private func isCentennialTotalLog(_ movie: Movie) -> Bool {
    // Sort movies by watch date to get chronological order
    let sortedMovies = movies.sorted { movie1, movie2 in
      guard let date1 = movie1.watch_date, let date2 = movie2.watch_date
      else { return false }
      return date1 < date2
    }

    // Find the position of this movie in the sorted list
    if let movieIndex = sortedMovies.firstIndex(where: { $0.id == movie.id }
    ) {
      let position = movieIndex + 1  // 1-based indexing
      return position % 100 == 0
    }

    return false
  }

  // MARK: - Favorite Functions
  
  private func toggleMovieFavorite(_ movie: Movie) async {
    do {
      let updatedMovie = try await movieService.toggleMovieFavorite(movieId: movie.id)
      await MainActor.run {
        viewModel.replaceMovie(updatedMovie)
      }
    } catch {
      await MainActor.run {
        viewModel.setErrorMessage("Failed to update favorite status: \(error.localizedDescription)")
      }
    }
  }
}

struct MovieRowView: View {
  @Environment(\.colorScheme) private var colorScheme
  let movie: Movie
  let rewatchIconColor: Color
  let shouldHighlightMustWatchTitle: Bool
  let shouldHighlightReleaseYearTitle: Bool
  let shouldHighlightReleaseYearOnYear: Bool
  let watchDay: String
  let watchDayOfWeek: String
  let tagIcons: [MovieTagIconSnapshot]
  let accessibilityLabel: String
  let accessibilityValue: String

  var body: some View {
    HStack(spacing: 16) {
      // Movie poster
      WebImage(
        url: movie.posterURL(for: .w185),
        options: [.scaleDownLargeImages, .continueInBackground, .retryFailed]
      ) { image in
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
          .foregroundColor(
            shouldHighlightMustWatchTitle
              ? .purple
              : shouldHighlightReleaseYearTitle ? .cyan : Color.adaptiveText(scheme: colorScheme)
          )
          .shadow(
            color: shouldHighlightMustWatchTitle
              ? .purple.opacity(0.6)
              : shouldHighlightReleaseYearTitle
                ? .cyan.opacity(0.6) : .clear,
            radius: 3,
            x: 0,
            y: 0
          )
          .lineLimit(3)
          .frame(maxWidth: .infinity, alignment: .leading)

        Text(movie.formattedReleaseYear)
          .font(.subheadline)
          .foregroundColor(
            shouldHighlightReleaseYearOnYear ? .cyan : .gray
          )
          .shadow(
            color: shouldHighlightReleaseYearOnYear
              ? .cyan.opacity(0.6) : .clear,
            radius: 3,
            x: 0,
            y: 0
          )

        // Star rating and score in same row
        HStack(alignment: .firstTextBaseline, spacing: 8) {
          // Stars container with fixed alignment
          CompactStarRatingView(rating: movie.rating, fontSize: 12)

          // Numerical rating with baseline alignment
          if let detailedRating = movie.detailed_rating {
            Text(String(format: "%.0f", detailedRating))
              .font(
                .system(
                  size: 13,
                  weight: .medium,
                  design: .rounded
                )
              )
              .foregroundColor(.purple)
              .frame(minWidth: 30, alignment: .leading)
              .baselineOffset(-1)  // Slight downward adjustment
          }
          
          // Favorites heart next to detailed rating
          if movie.isFavorited {
            Image(systemName: "heart.fill")
              .foregroundColor(.orange)
              .font(.system(size: 12, weight: .semibold))
              .baselineOffset(-1)  // Match detailed rating alignment
              .padding(.leading, -13)  // Pull closer to rating number
          }

        }

        if !tagIcons.isEmpty {
          HStack(spacing: 4) {
            ForEach(tagIcons, id: \.icon) { iconData in
              Image(systemName: iconData.icon)
                .foregroundColor(iconData.colorToken.color)
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
            Text(watchDay)
              .font(.title)
              .fontWeight(.bold)
              .foregroundColor(Color.adaptiveText(scheme: colorScheme))

            Text(watchDayOfWeek)
              .font(.caption)
              .foregroundColor(Color.adaptiveText(scheme: colorScheme))
              .textCase(.uppercase)
          }
        }
      }
      .frame(width: 80, alignment: .trailing)
    }
    .padding(.vertical, 12)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(accessibilityLabel)
    .accessibilityValue(accessibilityValue)
    .accessibilityHint("Opens movie details")
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

  private func tagIconsWithColors(
    for tagsString: String?,
    hasLocation: Bool = false
  ) -> [(
    icon: String, color: Color
  )] {
    return TagConfiguration.getTagIconsWithColors(
      for: tagsString,
      hasLocation: hasLocation
    )
  }
}

struct MovieTileView: View {
  let movie: Movie
  let rewatchIconColor: Color
  let accessibilityLabel: String
  let accessibilityValue: String

  var body: some View {
    VStack(spacing: 6) {
      // Movie poster (no overlay indicators)
      WebImage(
        url: movie.posterURL(for: .w342),
        options: [.scaleDownLargeImages, .continueInBackground, .retryFailed]
      ) { image in
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

      // Star rating, favorites, and rewatch icon centered below poster
      HStack(spacing: 6) {
        // Star rating
        CompactStarRatingView(rating: movie.rating, fontSize: 10)
        
        // Favorites heart
        if movie.isFavorited {
          Image(systemName: "heart.fill")
            .foregroundColor(.orange)
            .font(.system(size: 10, weight: .bold))
            .baselineOffset(-16)  // Drop down by 12 points
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
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(accessibilityLabel)
    .accessibilityValue(accessibilityValue)
    .accessibilityHint("Opens movie details")
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
// MARK - Filter and Sorting View - FilterSortView
struct FilterSortView: View {
  @Environment(\.colorScheme) private var colorScheme
  @Binding var sortBy: MovieSortField
  @ObservedObject var filterViewModel: FilterViewModel
  let movies: [Movie]
  @Environment(\.dismiss) private var dismiss
  @State private var selectedSection: FilterSection = .tags
  @State private var draftFilters = FilterDraftState()

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
            if draftFilters.toAppliedFilters().hasActiveFilters {
              Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                  draftFilters.clearAll()
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
                        .stroke(
                          Color.red.opacity(0.3),
                          lineWidth: 1
                        )
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
        .background(Color.adaptiveBackground(scheme: colorScheme))
      }
      .background(Color.adaptiveBackground(scheme: colorScheme))
      .navigationTitle("Filters")
      #if canImport(UIKit)
      .navigationBarTitleDisplayMode(.inline)
      #endif
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel", systemImage: "xmark") {
            dismiss()
          }
          .foregroundColor(.red)
        }

        ToolbarItem(placement: .confirmationAction) {
          Button("Apply", systemImage: "checkmark") {
            filterViewModel.apply(filters: draftFilters.toAppliedFilters())
            dismiss()
          }
          .foregroundColor(.blue)
        }
      }
    }
    .onAppear {
      draftFilters = FilterDraftState(from: filterViewModel.appliedFiltersState)
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
      .foregroundColor(selectedSection == section ? (colorScheme == .dark ? .black : .white) : Color.adaptiveText(scheme: colorScheme))
      .padding(.horizontal, 16)
      .padding(.vertical, 8)
      .background(
        RoundedRectangle(cornerRadius: 20)
          .fill(
            selectedSection == section
              ? (colorScheme == .dark ? .white : .black) : Color.gray.opacity(0.2)
          )
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
        LazyVGrid(
          columns: Array(repeating: GridItem(.flexible()), count: 2),
          spacing: 8
        ) {
          ForEach(availableTags, id: \.self) { tag in
            FilterChip(
              text: tag,
              isSelected: draftFilters.selectedTags.contains(tag)
            ) {
              if draftFilters.selectedTags.contains(tag) {
                draftFilters.selectedTags.remove(tag)
              } else {
                draftFilters.selectedTags.insert(tag)
              }
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
          HStack {
            Text("Min:")
              .foregroundColor(.gray)
              .frame(width: 40, alignment: .leading)

            StarRatingView(
              rating: Binding(
                get: { draftFilters.minStarRating ?? 0.0 },
                set: {
                  draftFilters.minStarRating = $0 == 0.0 ? nil : $0
                }
              ),
              size: 24
            )

            Spacer()
          }

          HStack {
            Text("Max:")
              .foregroundColor(.gray)
              .frame(width: 40, alignment: .leading)

            StarRatingView(
              rating: Binding(
                get: { draftFilters.maxStarRating ?? 5.0 },
                set: {
                  draftFilters.maxStarRating = $0 == 5.0 ? nil : $0
                }
              ),
              size: 24
            )

            Spacer()
          }
        }
      }

      // Detailed Rating Filter
      FilterSectionCard(title: "Detailed Rating (0-100)", icon: "number") {
        VStack(spacing: 16) {
          HStack {
            Text("Min:")
              .foregroundColor(.gray)
              .frame(width: 40, alignment: .leading)

            TextField(
              "0",
              text: Binding(
                get: {
                  if let minRating = draftFilters.minDetailedRating {
                    return String(Int(minRating))
                  }
                  return "0"
                },
                set: { newValue in
                  let filtered = newValue.filter { $0.isNumber }
                  if let value = Double(filtered), value >= 0, value <= 100 {
                    draftFilters.minDetailedRating = value == 0 ? nil : value
                  } else if filtered.isEmpty {
                    draftFilters.minDetailedRating = nil
                  }
                }
              )
            )
            .textFieldStyle(RoundedBorderTextFieldStyle())
            #if canImport(UIKit)
            .keyboardType(.numberPad)
            #endif
            .frame(width: 80)
          }

          HStack {
            Text("Max:")
              .foregroundColor(.gray)
              .frame(width: 40, alignment: .leading)

            TextField(
              "100",
              text: Binding(
                get: {
                  if let maxRating = draftFilters.maxDetailedRating {
                    return String(Int(maxRating))
                  }
                  return "100"
                },
                set: { newValue in
                  let filtered = newValue.filter { $0.isNumber }
                  if let value = Double(filtered), value >= 0, value <= 100 {
                    draftFilters.maxDetailedRating = value == 100 ? nil : value
                  } else if filtered.isEmpty {
                    draftFilters.maxDetailedRating = nil
                  }
                }
              )
            )
            .textFieldStyle(RoundedBorderTextFieldStyle())
            #if canImport(UIKit)
            .keyboardType(.numberPad)
            #endif
            .frame(width: 80)
          }
        }
      }
    }
  }

  @ViewBuilder
  private var genresFilterSection: some View {
    FilterSectionCard(title: "Genres", icon: "theatermasks.fill") {
      let availableGenres = filterViewModel.getAvailableGenres(
        from: movies
      )

      if availableGenres.isEmpty {
        Text("No genres found in your movies")
          .foregroundColor(.gray)
          .padding(.vertical, 20)
      } else {
        LazyVGrid(
          columns: Array(repeating: GridItem(.flexible()), count: 2),
          spacing: 8
        ) {
          ForEach(availableGenres, id: \.self) { genre in
            FilterChip(
              text: genre,
              isSelected: draftFilters.selectedGenres.contains(genre)
            ) {
              if draftFilters.selectedGenres.contains(genre) {
                draftFilters.selectedGenres.remove(genre)
              } else {
                draftFilters.selectedGenres.insert(genre)
              }
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
                let earliestDate =
                  filterViewModel.getEarliestWatchDate(
                    from: movies
                  )
                return draftFilters.startDate
                  ?? earliestDate
              },
              set: {
                let earliestDate =
                  filterViewModel.getEarliestWatchDate(
                    from: movies
                  )
                draftFilters.startDate =
                  Calendar.current.isDate(
                    $0,
                    inSameDayAs: earliestDate
                  ) ? nil : $0
              }
            ),
            displayedComponents: .date
          )
          .accentColor(.blue)

          DatePicker(
            "End Date",
            selection: Binding(
              get: { draftFilters.endDate ?? Date() },
              set: {
                draftFilters.endDate =
                  Calendar.current.isDate(
                    $0,
                    inSameDayAs: Date()
                  ) ? nil : $0
              }
            ),
            displayedComponents: .date
          )
          .accentColor(.blue)
        }
      }

      // Decade Filter
      FilterSectionCard(
        title: "Release Decades",
        icon: "calendar.badge.clock"
      ) {
        let availableDecades = filterViewModel.getAvailableDecades(
          from: movies
        )

        if availableDecades.isEmpty {
          Text("No release years found")
            .foregroundColor(.gray)
            .padding(.vertical, 20)
        } else {
          LazyVGrid(
            columns: Array(
              repeating: GridItem(.flexible()),
              count: 3
            ),
            spacing: 8
          ) {
            ForEach(availableDecades, id: \.self) { decade in
              FilterChip(
                text: decade,
                isSelected: draftFilters.selectedDecades.contains(decade)
              ) {
                if draftFilters.selectedDecades.contains(decade) {
                  draftFilters.selectedDecades.remove(decade)
                } else {
                  draftFilters.selectedDecades.insert(decade)
                }
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
              get: { draftFilters.showRewatchesOnly },
              set: {
                draftFilters.showRewatchesOnly = $0
              }
            )
          )

          FilterToggle(
            title: "Hide rewatches",
            isOn: Binding(
              get: { draftFilters.hideRewatches },
              set: { draftFilters.hideRewatches = $0 }
            )
          )
        }
      }

      // Review Filter
      FilterSectionCard(title: "Reviews", icon: "text.quote") {
        VStack(spacing: 12) {
          HStack {
            Text("Has Review:")
              .foregroundColor(Color.adaptiveText(scheme: colorScheme))
            Spacer()

            Button(action: {
              draftFilters.hasReview =
                draftFilters.hasReview == true
                ? nil : true
            }) {
              HStack(spacing: 4) {
                Image(
                  systemName: draftFilters.hasReview
                    == true
                    ? "checkmark.circle.fill" : "circle"
                )
                .foregroundColor(
                  draftFilters.hasReview == true
                    ? .green : .gray
                )
                Text("Yes")
                  .foregroundColor(
                    draftFilters.hasReview == true
                      ? .green : .gray
                  )
              }
            }
            .buttonStyle(PlainButtonStyle())

            Button(action: {
              draftFilters.hasReview =
                draftFilters.hasReview == false
                ? nil : false
            }) {
              HStack(spacing: 4) {
                Image(
                  systemName: draftFilters.hasReview
                    == false
                    ? "checkmark.circle.fill" : "circle"
                )
                .foregroundColor(
                  draftFilters.hasReview == false
                    ? .red : .gray
                )
                Text("No")
                  .foregroundColor(
                    draftFilters.hasReview
                      == false ? .red : .gray
                  )
              }
            }
            .buttonStyle(PlainButtonStyle())
          }
        }
      }

      // Runtime Filter
      FilterSectionCard(title: "Runtime", icon: "clock") {
        VStack(spacing: 16) {
          let runtimeRange = filterViewModel.getRuntimeRange(
            from: movies
          )

          HStack {
            Text("Min:")
              .foregroundColor(.gray)
            Spacer()
            RuntimeSlider(
              value: Binding(
                get: {
                  draftFilters.minRuntime
                    ?? runtimeRange.min
                },
                set: {
                  draftFilters.minRuntime =
                    $0 == runtimeRange.min ? nil : $0
                }
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
                get: {
                  draftFilters.maxRuntime
                    ?? runtimeRange.max
                },
                set: {
                  draftFilters.maxRuntime =
                    $0 == runtimeRange.max ? nil : $0
                }
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
  @Environment(\.colorScheme) private var colorScheme
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
          .foregroundColor(Color.adaptiveText(scheme: colorScheme))
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
            .stroke(
              isSelected ? .clear : Color.gray.opacity(0.5),
              lineWidth: 1
            )
        )
    }
    .buttonStyle(PlainButtonStyle())
  }
}

struct FilterToggle: View {
  @Environment(\.colorScheme) private var colorScheme
  let title: String
  @Binding var isOn: Bool

  var body: some View {
    HStack {
      Text(title)
        .foregroundColor(Color.adaptiveText(scheme: colorScheme))
      Spacer()
      Toggle("", isOn: $isOn)
        .toggleStyle(SwitchToggleStyle(tint: .blue))
    }
  }
}

struct RuntimeSlider: View {
  @Environment(\.colorScheme) private var colorScheme
  @Binding var value: Int
  let range: ClosedRange<Int>

  var body: some View {
    HStack(spacing: 12) {
      Text(formatRuntime(value))
        .foregroundColor(Color.adaptiveText(scheme: colorScheme))
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
            colors: colors.count == 1
              ? [colors[0], colors[0]] : colors,
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
            withAnimation(
              .linear(duration: 1.5).repeatForever(
                autoreverses: false
              )
            ) {
              rotationAngle = 360
            }
          }
        }
        .onChange(of: isVisible) { _, visible in
          if visible {
            withAnimation(
              .linear(duration: 1.5).repeatForever(
                autoreverses: false
              )
            ) {
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
        ForEach(Array(colors.enumerated()), id: \.offset) {
          index,
          color in
          RoundedRectangle(cornerRadius: cornerRadius)
            .strokeBorder(
              color.opacity(0.8),
              lineWidth: 2
            )
            .scaleEffect(1.0 + CGFloat(index) * 0.015)
            .rotationEffect(
              .degrees(rotationAngle + Double(index) * 30)
            )
            .opacity(isVisible ? 1.0 : 0.0)
        }
      }
      .scaleEffect(isVisible ? 1.02 : 1.0)
      .animation(.easeInOut(duration: 0.3), value: isVisible)
      .onAppear {
        withAnimation(
          .linear(duration: 3.0).repeatForever(autoreverses: false)
        ) {
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
  @Environment(\.colorScheme) private var colorScheme
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
              .foregroundColor(Color.adaptiveText(scheme: colorScheme))
            Spacer()
          }

          LazyVGrid(
            columns: Array(
              repeating: GridItem(.flexible()),
              count: 1
            ),
            spacing: 8
          ) {
            ForEach(MovieSortField.allCases, id: \.self) {
              sortField in
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
              .foregroundColor(Color.adaptiveText(scheme: colorScheme))
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
      #if canImport(UIKit)
      .navigationBarTitleDisplayMode(.inline)
      #endif
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel", systemImage: "xmark") {
            dismiss()
          }
          .foregroundColor(.red)
        }

        ToolbarItem(placement: .confirmationAction) {
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

// MARK: - Compact Star Rating View
struct CompactStarRatingView: View {
  let rating: Double?
  let fontSize: CGFloat
  
  var body: some View {
    HStack(spacing: 2) {
      if let rating = rating, rating > 0 {
        let wholeStars = Int(rating)
        let hasHalfStar = rating.truncatingRemainder(dividingBy: 1) >= 0.5
        
        // Show whole stars
        if wholeStars > 0 {
          ForEach(0..<wholeStars, id: \.self) { _ in
            Image(systemName: "star.fill")
              .foregroundColor(rating == 5.0 ? .yellow : .blue)
              .font(.system(size: fontSize, weight: .regular))
          }
        }
        
        // Show half star icon
        if hasHalfStar {
          Image(systemName: "star.leadinghalf.filled")
            .foregroundColor(rating == 5.0 ? .yellow : .blue)
            .font(.system(size: fontSize, weight: .regular))
        }
      }
    }
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

#Preview {
  MoviesView()
}

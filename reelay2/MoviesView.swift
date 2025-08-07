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
  @State private var searchText = ""
  @State private var selectedMovie: Movie?
  @State private var tappedMovieId: Int?
  @State private var viewMode: ViewMode = .list
  @State private var selectedDate: Date = Date()
  @State private var currentCalendarMonth: Date = Date()
  @State private var longPressedMovieId: Int?
  @StateObject private var listService = SupabaseListService.shared

  enum ViewMode {
    case list, tile, calendar
  }

  private var groupedMovies: [(String, [Movie])] {
    let grouped = Dictionary(grouping: movies) { movie in
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

  var body: some View {
    contentView
      .navigationTitle(navigationTitle)
      .navigationBarTitleDisplayMode(.large)
      .background(Color.black)
      .preferredColorScheme(.dark)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          HStack(spacing: 16) {
            Button(action: {
              showingFilters = true
            }) {
              Image(systemName: "line.3.horizontal.decrease")
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
        if movieService.isLoggedIn {
          await loadMovies()
        }
      }
      .onChange(of: movieService.isLoggedIn) { _, isLoggedIn in
        if isLoggedIn {
          Task {
            await loadMovies()
          }
        } else {
          movies = []
          errorMessage = nil
        }
      }
      .sheet(isPresented: $showingAddMovie) {
        AddMoviesView()
      }
      .onChange(of: showingAddMovie) { _, isShowing in
        if !isShowing && movieService.isLoggedIn {
          // Refresh movies list when add movie sheet is dismissed
          Task {
            await loadMovies()
          }
        }
      }
      .sheet(isPresented: $showingFilters) {
        FilterSortView(sortBy: $sortBy)
      }
      .sheet(item: $selectedMovie) { movie in
        MovieDetailsView(movie: movie)
      }
  }

  @ViewBuilder
  private var contentView: some View {
    Group {
      if !movieService.isLoggedIn {
        notLoggedInView
      } else if isLoading {
        loadingView
      } else if movies.isEmpty && !isLoading {
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
      await loadMovies()
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
      await loadMovies()
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
      .padding(.top, 20)
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
      .padding(.bottom, 24)
    }
  }

  @ViewBuilder
  private func movieButton(for movie: Movie) -> some View {
    Button(action: {
      selectedMovie = movie
    }) {
      MovieRowView(movie: movie)
        .padding(.horizontal, 20)
        .background(Color.gray.opacity(0.15))
        .cornerRadius(24)
        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
        .padding(.horizontal, 20)
    }
    .buttonStyle(PlainButtonStyle())
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
      .padding(.top, 20)
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
      .padding(.bottom, 24)
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
      await loadMovies()
    }
  }
  
  @ViewBuilder
  private var calendarHeader: some View {
    HStack {
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
      
      Text(monthYearFormatter.string(from: currentCalendarMonth))
        .font(.title2)
        .fontWeight(.semibold)
        .foregroundColor(.white)
        .onTapGesture(count: 2) {
          returnToCurrentDate()
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
    .background(Color.gray.opacity(0.1))
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
              selectedDateMovieRow(movie: movie)
            }
            .buttonStyle(PlainButtonStyle())
          }
        }
      }
    }
    .padding(.top, 8)
  }
  
  @ViewBuilder
  private func selectedDateMovieRow(movie: Movie) -> some View {
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
          .foregroundColor(.white)
          .lineLimit(1)
        
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
              .foregroundColor(.orange)
              .font(.system(size: 9, weight: .regular))
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
    .background(Color.gray.opacity(0.15))
    .cornerRadius(12)
  }
  
  // Helper computed properties and functions
  private var monthYearFormatter: DateFormatter {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMMM yyyy"
    return formatter
  }
  
  private var selectedDateFormatter: DateFormatter {
    let formatter = DateFormatter()
    formatter.dateFormat = "EEEE, MMMM d"
    return formatter
  }
  
  private func moviesForDate(_ date: Date) -> [Movie] {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    let dateString = formatter.string(from: date)
    
    return movies.filter { movie in
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
      MovieTileView(movie: movie)
        .scaleEffect(tappedMovieId == movie.id ? 1.05 : 1.0)
        .animation(
          .spring(response: 0.3, dampingFraction: 0.6, blendDuration: 0), value: tappedMovieId)
    }
    .buttonStyle(PlainButtonStyle())
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

  private func loadMovies() async {
    isLoading = true
    errorMessage = nil
    do {
      movies = try await movieService.getMovies(sortBy: sortBy, ascending: false, limit: 10000)
    } catch {
      errorMessage = error.localizedDescription
    }
    isLoading = false
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
}

struct MovieRowView: View {
  let movie: Movie

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

      // Movie details
      VStack(alignment: .leading, spacing: 4) {
        Text(movie.title)
          .font(.headline)
          .fontWeight(.semibold)
          .foregroundColor(.white)
          .lineLimit(2)

        Text(movie.formattedReleaseYear)
          .font(.subheadline)
          .foregroundColor(.gray)

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
              .frame(minWidth: 20, alignment: .leading)
              .baselineOffset(-1)  // Slight downward adjustment
          }

          // Rewatch indicator aligned with ratings
          if movie.isRewatchMovie {
            Image(systemName: "arrow.clockwise")
              .foregroundColor(.orange)
              .font(.system(size: 11, weight: .regular))
              .baselineOffset(-1)  // Same baseline adjustment as the number
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

      Spacer()

      // Watch date
      VStack {
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
              Image(systemName: index < Int(rating) ? "star.fill" : "star")
                .foregroundColor(rating == 5.0 ? .yellow : .blue)
                .font(.system(size: 10, weight: .bold))
            }
          }
        }

        // Rewatch indicator
        if movie.isRewatchMovie {
          Image(systemName: "arrow.clockwise")
            .foregroundColor(.orange)
            .font(.system(size: 10, weight: .bold))
        }
      }
      .frame(maxWidth: .infinity)
      .frame(height: 16)
    }
  }
}

// Placeholder views for sheets
struct FilterSortView: View {
  @Binding var sortBy: MovieSortField
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationView {
      VStack {
        Text("Filter & Sort")
          .font(.title)
        Spacer()
        Text("Filter and sort options coming soon...")
          .foregroundColor(.gray)
        Spacer()
      }
      .padding()
      .navigationTitle("Filter & Sort")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Done") {
            dismiss()
          }
        }
      }
    }
  }
}

#Preview {
  MoviesView()
}

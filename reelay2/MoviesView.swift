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

  enum ViewMode {
    case list, tile
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

  var body: some View {
    contentView
      .navigationTitle("Movies")
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
                viewMode = viewMode == .list ? .tile : .list
              }
            }) {
              Image(systemName: viewMode == .list ? "square.grid.3x3" : "list.bullet")
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
        if viewMode == .list {
          moviesListView
        } else {
          moviesTileView
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

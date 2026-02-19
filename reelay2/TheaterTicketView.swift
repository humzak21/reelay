//
//  TheaterTicketView.swift
//  reelay2
//
//  Created by Humza Khalil on 8/7/25.
//

import SwiftUI

struct TheaterTicketView: View {
    let item: ListItem
    let list: MovieList
    let rank: Int?
    let showSpecialLayout: Bool
    @ObservedObject private var dataManager = DataManager.shared
    #if os(macOS)
    @EnvironmentObject private var navigationCoordinator: NavigationCoordinator
    #endif
    @State private var selectedMovie: Movie?
    @State private var showingMovieDetails = false
    @State private var isLoadingMovie = false
    @State private var movieDetails: Movie?
    
    private var ticketDate: String {
        if let movie = movieDetails, let watchDate = movie.watch_date {
            return formatTicketDate(watchDate)
        }
        return formatTicketDate(item.addedAt.ISO8601Format())
    }
    
    private var director: String {
        movieDetails?.director ?? ""
    }
    
    private var rating: Double {
        movieDetails?.rating ?? 0.0
    }
    
    private var detailedRating: String? {
        guard let rating = movieDetails?.detailed_rating else { return nil }
        return String(format: "%.0f", rating)
    }
    
    private func wrappedTitle(_ title: String) -> String {
        let uppercaseTitle = title.uppercased()
        let words = uppercaseTitle.components(separatedBy: " ")
        var lines: [String] = []
        var currentLine = ""
        
        for word in words {
            let testLine = currentLine.isEmpty ? word : "\(currentLine) \(word)"
            if testLine.count <= 12 {
                currentLine = testLine
            } else {
                if !currentLine.isEmpty {
                    lines.append(currentLine)
                }
                currentLine = word
            }
        }
        
        if !currentLine.isEmpty {
            lines.append(currentLine)
        }
        
        return lines.joined(separator: "\n")
    }

    private func loadTicketImage() -> Image? {
        #if os(iOS)
        guard let uiImage = UIImage(named: "ticket_blue_image") else { return nil }
        return Image(uiImage: uiImage)
        #elseif os(macOS)
        guard let nsImage = NSImage(named: "ticket_blue_image") else { return nil }
        return Image(nsImage: nsImage)
        #endif
    }

    var body: some View {
        Button(action: {
            Task {
                await loadLatestMovieEntry()
            }
        }) {
            ZStack {
                // Use the actual ticket image as background
                if let ticketImage = loadTicketImage() {
                    ticketImage
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 240) // Increased by 50% (160 * 1.5 = 240)
                } else {
                    // Fallback: recreate the ticket design if image not found
                    HStack(spacing: 0) {
                        // Blue section
                        Rectangle()
                            .fill(Color(red: 0.15, green: 0.5, blue: 0.95))
                            .frame(width: 360) // Increased by 50%
                        
                        // White section
                        Rectangle()
                            .fill(Color(white: 0.96))
                            .frame(width: 150) // Increased by 50%
                    }
                    .frame(height: 240) // Increased by 50%
                    .cornerRadius(8)
                }
                
                // Overlay content on the ticket image
                HStack(spacing: 0) {
                    // Blue section content
                    VStack(spacing: 8) {
                        // Title section (positioned where the clapperboard is in the image)
                        VStack {
                            Text(wrappedTitle(item.movieTitle))
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                                .lineLimit(3)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 10)
                        }
                        .padding(.top, 35)
                        
                        // Star rating section (centered on blue section)
                        VStack {
                            StarRatingDisplayView(rating: rating, maxRating: 5, size: 18)
                        }
                        .padding(.top, 2)
                        
                        // Details section (under the white line)
                        VStack(alignment: .center, spacing: 2) {
                            if let detailedRating = detailedRating {
                                Text(detailedRating)
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundColor(.white.opacity(0.95))
                            }
                            
                            if !director.isEmpty {
                                Text("Dir: \(director)")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundColor(.white.opacity(0.95))
                                    .lineLimit(1)
                            }
                            
                            if let year = item.movieYear {
                                Text("\(String(year)) • \(ticketDate)")
                                    .font(.system(size: 8, weight: .medium))
                                    .foregroundColor(.white.opacity(0.9))
                            } else {
                                Text(ticketDate)
                                    .font(.system(size: 8, weight: .medium))
                                    .foregroundColor(.white.opacity(0.9))
                            }
                        }
                        .padding(.horizontal, 10)
                        
                        Spacer()
                    }
                    .frame(width: 360) // Increased by 50%
                    
                    // Right section for rank if applicable
                    VStack {
                        if let rank = rank {
                            Text("#\(rank)")
                                .font(.system(size: 20, weight: .bold, design: .monospaced))
                                .foregroundColor(.black.opacity(0.7))
                                .rotationEffect(.degrees(90))
                        }
                    }
                    .frame(width: 100)
                    .padding(.trailing, 20)
                }
                
                // Loading overlay
                if isLoadingMovie {
                    Color.black.opacity(0.3)
                        .overlay(
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        )
                        .cornerRadius(8)
                }
            }
            .frame(height: 160)
            .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 3)
        }
        .buttonStyle(PlainButtonStyle())
        #if os(iOS)
        .sheet(isPresented: $showingMovieDetails) {
            if let selectedMovie = selectedMovie {
                MovieDetailsView(movie: selectedMovie)
            }
        }
        #else
        .onChange(of: showingMovieDetails) { _, showing in
            if showing, let movie = selectedMovie {
                navigationCoordinator.showMovieDetails(movie)
                showingMovieDetails = false
            }
        }
        #endif
        .task {
            await loadMovieDetails()
        }
    }
    
    private func formatTicketDate(_ dateString: String) -> String {
        let dateFormatter = ISO8601DateFormatter()
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "MMM dd, yyyy"
        
        if let date = dateFormatter.date(from: dateString) {
            return displayFormatter.string(from: date).uppercased()
        } else if let date = Date.parseFromString(dateString) {
            return displayFormatter.string(from: date).uppercased()
        }
        
        // Fallback to show something
        return "DATE UNKNOWN"
    }
    
    private func loadMovieDetails() async {
        do {
            let movies = try await dataManager.getMoviesByTmdbId(tmdbId: item.tmdbId)
            
            if let latestMovie = movies.max(by: { movie1, movie2 in
                let date1 = movie1.watch_date ?? movie1.created_at ?? ""
                let date2 = movie2.watch_date ?? movie2.created_at ?? ""
                return date1 < date2
            }) {
                await MainActor.run {
                    movieDetails = latestMovie
                }
            }
        } catch {
            // Silently handle error
        }
    }
    
    private func loadLatestMovieEntry() async {
        isLoadingMovie = true
        
        do {
            let movies = try await dataManager.getMoviesByTmdbId(tmdbId: item.tmdbId)
            
            if movies.isEmpty {
                // Create placeholder movie for unlogged state
                let placeholderMovie = Movie(
                    id: -1,
                    title: item.movieTitle,
                    release_year: item.movieYear,
                    release_date: nil,
                    rating: nil,
                    detailed_rating: nil,
                    review: nil,
                    tags: nil,
                    watch_date: nil,
                    is_rewatch: nil,
                    tmdb_id: item.tmdbId,
                    overview: nil,
                    poster_url: item.moviePosterUrl,
                    backdrop_path: item.movieBackdropPath,
                    director: movieDetails?.director,
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
                
                await MainActor.run {
                    selectedMovie = placeholderMovie
                    showingMovieDetails = true
                    isLoadingMovie = false
                }
            } else {
                // Find the latest entry
                let latestMovie = movies.max { movie1, movie2 in
                    let date1 = movie1.watch_date ?? movie1.created_at ?? ""
                    let date2 = movie2.watch_date ?? movie2.created_at ?? ""
                    return date1 < date2
                }
                
                await MainActor.run {
                    selectedMovie = latestMovie
                    if latestMovie != nil {
                        showingMovieDetails = true
                    }
                    isLoadingMovie = false
                }
            }
        } catch {
            await MainActor.run {
                isLoadingMovie = false
            }
        }
    }
}

// MARK: - StarRatingDisplayView
struct StarRatingDisplayView: View {
    let rating: Double
    let maxRating: Int
    let size: CGFloat
    
    init(rating: Double, maxRating: Int = 5, size: CGFloat = 20) {
        self.rating = rating
        self.maxRating = maxRating
        self.size = size
    }
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...maxRating, id: \.self) { starIndex in
                star(for: starIndex)
                    .foregroundColor(starColor(for: starIndex))
                    .font(.system(size: size))
            }
        }
    }
    
    private func star(for index: Int) -> some View {
        let starValue = Double(index)
        let difference = rating - starValue + 1.0
        
        if difference >= 1.0 {
            // Full star
            return Image(systemName: "star.fill")
        } else if difference >= 0.5 {
            // Half star
            return Image(systemName: "star.leadinghalf.filled")
        } else {
            // Empty star
            return Image(systemName: "star")
        }
    }
    
    private func starColor(for index: Int) -> Color {
        let starValue = Double(index)
        
        if rating > 0 && rating >= starValue - 0.25 {
            // Yellow for rated films
            return .yellow
        } else {
            // Grey for unrated films or empty stars
            return Color.white.opacity(0.4)
        }
    }
}

// Extension to help parse date strings
extension Date {
    static func parseFromString(_ dateString: String) -> Date? {
        let formatters = [
            "yyyy-MM-dd'T'HH:mm:ss.SSSSSSXXXXX",
            "yyyy-MM-dd'T'HH:mm:ssXXXXX",
            "yyyy-MM-dd HH:mm:ss.SSSSSSXXXXX",
            "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'",
            "yyyy-MM-dd'T'HH:mm:ss'Z'",
            "yyyy-MM-dd"
        ]
        
        for format in formatters {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            if let date = formatter.date(from: dateString) {
                return date
            }
        }
        
        return nil
    }
}

#Preview {
    TheaterTicketView(
        item: ListItem(
            id: 1,
            listId: UUID(),
            tmdbId: 550,
            movieTitle: "Fight Club",
            moviePosterUrl: "https://image.tmdb.org/t/p/w500/pB8BM7pdSp6B6Ih7QZ4DrQ3PmJK.jpg",
            movieBackdropPath: "/87hTDiay2N2qWyX4Ds7ybXi9h8I.jpg",
            movieYear: 1999,
            addedAt: Date(),
            sortOrder: 0
        ),
        list: MovieList(
            id: UUID(),
            userId: UUID(),
            name: "Films Watched in Theaters",
            description: "Movies I've seen on the big screen"
        ),
        rank: 1,
        showSpecialLayout: true
    )
    .padding()
    .background(Color.gray.opacity(0.2))
}
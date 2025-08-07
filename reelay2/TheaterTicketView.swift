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
    @StateObject private var dataManager = DataManager.shared
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
        movieDetails?.director ?? "Unknown Director"
    }
    
    var body: some View {
        Button(action: {
            Task {
                await loadLatestMovieEntry()
            }
        }) {
            VStack(spacing: 0) {
                ticketStub
                ticketBody
            }
        }
        .buttonStyle(PlainButtonStyle())
        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        .sheet(isPresented: $showingMovieDetails) {
            if let selectedMovie = selectedMovie {
                MovieDetailsView(movie: selectedMovie)
            }
        }
        .task {
            await loadMovieDetails()
        }
    }
    
    private var ticketStub: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("ADMIT ONE")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .tracking(1)
                
                Text(ticketDate)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.8))
                
                // Rank number for ranked lists
                if let rank = rank {
                    Text("#\(rank)")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.yellow)
                        .tracking(1)
                }
            }
            
            Spacer()
            
            // Ticket stub number
            Text(String(format: "%06d", item.tmdbId % 1000000))
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.7))
                .rotationEffect(.degrees(90))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(height: 60)
        .background(
            LinearGradient(
                colors: [Color.blue.opacity(0.9), Color.blue.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            // Perforation line
            VStack {
                Spacer()
                Rectangle()
                    .fill(Color.white.opacity(0.3))
                    .frame(height: 1)
                    .mask(
                        HStack(spacing: 4) {
                            ForEach(0..<50, id: \.self) { _ in
                                Circle()
                                    .frame(width: 3, height: 3)
                            }
                        }
                    )
            }
        )
    }
    
    private var ticketBody: some View {
        HStack(spacing: 16) {
            // Movie poster
            AsyncImage(url: URL(string: item.moviePosterUrl ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(2/3, contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Group {
                            if isLoadingMovie {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .gray))
                                    .scaleEffect(0.6)
                            } else {
                                Image(systemName: "photo")
                                    .foregroundColor(.gray)
                                    .font(.system(size: 16))
                            }
                        }
                    )
            }
            .frame(width: 80, height: 120)
            .cornerRadius(8)
            .clipped()
            
            // Movie details
            VStack(alignment: .leading, spacing: 8) {
                Text(item.movieTitle.uppercased())
                    .font(.system(size: 18, weight: .bold, design: .default))
                    .foregroundColor(.black)
                    .lineLimit(3)
                    .tracking(0.5)
                
                if let year = item.movieYear {
                    Text(String(year))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.black.opacity(0.7))
                }
                
                Text("DIRECTED BY")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.black.opacity(0.5))
                    .tracking(1)
                
                Text(director.uppercased())
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.black.opacity(0.8))
                    .lineLimit(2)
                    .tracking(0.3)
                
                Spacer()
                
                // Theater branding
                HStack {
                    Image(systemName: "film.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.blue.opacity(0.7))
                    
                    Text("REELAY THEATERS")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.blue.opacity(0.7))
                        .tracking(1)
                }
            }
            
            Spacer(minLength: 0)
            
            // Ticket validation area
            VStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.blue.opacity(0.6))
                
                Text("VALID")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(.blue.opacity(0.6))
                    .tracking(1)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
        .frame(height: 140)
        .background(
            LinearGradient(
                colors: [Color.white, Color.gray.opacity(0.1)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .overlay(
            // Loading overlay
            Group {
                if isLoadingMovie {
                    Color.black.opacity(0.3)
                        .overlay(
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        )
                }
            }
        )
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
            print("Failed to load movie details for ticket: \(error)")
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
                    updated_at: nil
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
            print("Error loading latest movie entry: \(error)")
            await MainActor.run {
                isLoadingMovie = false
            }
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
        rank: 1
    )
    .padding()
    .background(Color.black)
}
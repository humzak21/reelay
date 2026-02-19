//
//  OnThisDayView.swift
//  reelay2
//
//  Memory section showing movies watched on this day in previous years
//

import SwiftUI

struct OnThisDayView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingAllMovies = false
    @State private var randomBackdropMovie: OnThisDayMovie?

    let movies: [OnThisDayMovie]
    let onMovieTapped: (Movie) -> Void
    
    private let cardHeight: CGFloat = 280

    // Get a random movie for the hero backdrop
    private var heroMovie: OnThisDayMovie? {
        randomBackdropMovie ?? movies.first
    }

    var body: some View {
        VStack(spacing: 0) {
            // Section Header
            sectionHeader
            
            // Memory Card
            memoryCardContent
        }
        .padding(.bottom, 20)
        .sheet(isPresented: $showingAllMovies) {
            OnThisDayFullListView(movies: movies, onMovieTapped: onMovieTapped)
        }
        .onAppear {
            // Randomly select a backdrop from all movies
            if !movies.isEmpty {
                randomBackdropMovie = movies.randomElement()
            }
        }
    }

    // MARK: - Section Header

    @ViewBuilder
    private var sectionHeader: some View {
        HStack {
            Image(systemName: "clock.arrow.circlepath")
                .font(.title3)
                .foregroundColor(.orange)

            Text("On This Day")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(Color.adaptiveText(scheme: colorScheme))

            Spacer()

            Text(formattedDate)
                .font(.subheadline)
                .foregroundColor(Color.adaptiveSecondaryText(scheme: colorScheme))
        }
        .padding(.top, 12)
        .padding(.bottom, 16)
    }

    // MARK: - Memory Card Content

    @ViewBuilder
    private var memoryCardContent: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // Hero Backdrop Background - constrained to geometry
                heroBackdropView(width: geometry.size.width)

                // Content Overlay
                VStack(spacing: 16) {
                    Spacer()

                    // Horizontally scrollable posters with year badges
                    posterScrollView

                    // Caption with "See All" button
                    captionRow
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
            .frame(width: geometry.size.width, height: cardHeight)
            .background(Color.black.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .frame(height: cardHeight)
    }

    // MARK: - Hero Backdrop with explicit width constraint

    @ViewBuilder
    private func heroBackdropView(width: CGFloat) -> some View {
        if let hero = heroMovie {
            AsyncImage(url: hero.backdropURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: width, height: cardHeight)
                        .clipped()
                case .failure:
                    AsyncImage(url: hero.posterURL) { posterPhase in
                        switch posterPhase {
                        case .success(let posterImage):
                            posterImage
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: width, height: cardHeight)
                                .clipped()
                        default:
                            fallbackGradient
                        }
                    }
                case .empty:
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: width, height: cardHeight)
                @unknown default:
                    fallbackGradient
                }
            }
            .overlay(
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.0),
                        Color.black.opacity(0.3),
                        Color.black.opacity(0.7),
                        Color.black.opacity(0.95)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        } else {
            fallbackGradient
        }
    }

    private var fallbackGradient: some View {
        LinearGradient(
            colors: [Color.orange.opacity(0.4), Color.purple.opacity(0.6)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Poster Scroll View

    @ViewBuilder
    private var posterScrollView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(movies) { movie in
                    posterCard(movie: movie)
                }
            }
            .padding(.horizontal, 4)
        }
    }

    @ViewBuilder
    private func posterCard(movie: OnThisDayMovie) -> some View {
        Button(action: {
            onMovieTapped(movie.toMovie())
        }) {
            VStack(spacing: 0) {
                // Poster with year badge
                ZStack(alignment: .bottom) {
                    AsyncImage(url: movie.posterURL) { image in
                        image
                            .resizable()
                            .aspectRatio(2/3, contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .aspectRatio(2/3, contentMode: .fill)
                    }
                    .frame(width: 85, height: 128)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    // Year badge at bottom - positioned to overlap poster edge
                    Text(String(movie.resolvedWatchedYear))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.orange, Color.orange.opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                        )
                        .offset(y: 12)
                }
                .padding(.bottom, 14) // Space for the badge overflow
            }
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Caption Row

    @ViewBuilder
    private var captionRow: some View {
        HStack {
            Text(captionText)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white.opacity(0.9))

            Spacer()

            if movies.count > 3 {
                Button(action: {
                    showingAllMovies = true
                }) {
                    HStack(spacing: 4) {
                        Text("See All")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                    }
                    .foregroundColor(.orange)
                }
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Helpers

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d"
        return formatter.string(from: Date())
    }

    private var captionText: String {
        let count = movies.count
        let years = Set(movies.map { $0.resolvedWatchedYear }).count

        if count == 1 {
            return "1 film watched on this day"
        } else {
            return "\(count) films across \(years) \(years == 1 ? "year" : "years")"
        }
    }
}

// MARK: - Full List View (Sheet)

struct OnThisDayFullListView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    let movies: [OnThisDayMovie]
    let onMovieTapped: (Movie) -> Void

    // Group movies by year
    private var moviesByYear: [(year: Int, movies: [OnThisDayMovie])] {
        let grouped = Dictionary(grouping: movies) { $0.resolvedWatchedYear }
        return grouped.map { (year: $0.key, movies: $0.value) }
            .sorted { $0.year > $1.year }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 24) {
                    ForEach(moviesByYear, id: \.year) { yearGroup in
                        yearSection(year: yearGroup.year, movies: yearGroup.movies)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .background(Color.adaptiveBackground(scheme: colorScheme))
            .navigationTitle("On This Day")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", systemImage: "checkmark") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    @ViewBuilder
    private func yearSection(year: Int, movies: [OnThisDayMovie]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Year header
            HStack {
                Text(String(year))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(Color.adaptiveText(scheme: colorScheme))

                Text("•")
                    .foregroundColor(.orange)

                Text("\(movies.count) \(movies.count == 1 ? "film" : "films")")
                    .font(.subheadline)
                    .foregroundColor(Color.adaptiveSecondaryText(scheme: colorScheme))

                Spacer()
            }

            // Movies grid
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 16) {
                ForEach(movies) { movie in
                    movieGridItem(movie: movie)
                }
            }
        }
    }

    @ViewBuilder
    private func movieGridItem(movie: OnThisDayMovie) -> some View {
        Button(action: {
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                onMovieTapped(movie.toMovie())
            }
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
                .clipShape(RoundedRectangle(cornerRadius: 12))

                Text(movie.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(Color.adaptiveText(scheme: colorScheme))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(height: 32)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    OnThisDayView(movies: [], onMovieTapped: { _ in })
}

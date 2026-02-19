//
//  MoviesSkeletonViews.swift
//  reelay2
//
//  Skeleton loading components for MoviesView
//

import SwiftUI

// MARK: - Skeleton Movie Row

struct SkeletonMovieRow: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var animationPhase: CGFloat = 0

    var body: some View {
        HStack(spacing: 12) {
            // Poster skeleton
            SkeletonBox(width: 60, height: 90, cornerRadius: 8)

            // Content skeleton
            VStack(alignment: .leading, spacing: 8) {
                SkeletonBox(width: 200, height: 16, cornerRadius: 4)
                SkeletonBox(width: 80, height: 12, cornerRadius: 4)
                HStack(spacing: 8) {
                    SkeletonBox(width: 100, height: 12, cornerRadius: 4)
                    SkeletonBox(width: 40, height: 12, cornerRadius: 4)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(colorScheme == .dark ? Color.gray.opacity(0.15) : .white)
        .cornerRadius(24)
        .padding(.horizontal, 20)
    }
}

// MARK: - Skeleton Movie Tile

struct SkeletonMovieTile: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 4) {
            SkeletonBox(height: 180, cornerRadius: 12)
            SkeletonBox(width: 60, height: 12, cornerRadius: 4)
        }
    }
}

// MARK: - Skeleton Month Header

struct SkeletonMonthHeader: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack {
            SkeletonBox(width: 150, height: 24, cornerRadius: 6)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 16)
    }
}

// MARK: - Skeleton List View

struct SkeletonMoviesListView: View {
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                Color.clear.frame(height: 1)

                ForEach(0..<3, id: \.self) { _ in
                    VStack(spacing: 0) {
                        SkeletonMonthHeader()

                        LazyVStack(spacing: 12) {
                            ForEach(0..<4, id: \.self) { _ in
                                SkeletonMovieRow()
                            }
                        }
                        .padding(.bottom, 8)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
    }
}

// MARK: - Skeleton Tile View

struct SkeletonMoviesTileView: View {
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                Color.clear.frame(height: 1)

                ForEach(0..<3, id: \.self) { _ in
                    VStack(spacing: 0) {
                        SkeletonMonthHeader()

                        let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(0..<9, id: \.self) { _ in
                                SkeletonMovieTile()
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
    }
}

// MARK: - Skeleton Calendar View

struct SkeletonMoviesCalendarView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                // Calendar header skeleton
                HStack {
                    SkeletonBox(width: 30, height: 30, cornerRadius: 8)
                    Spacer()
                    SkeletonBox(width: 150, height: 24, cornerRadius: 6)
                    Spacer()
                    SkeletonBox(width: 30, height: 30, cornerRadius: 8)
                }
                .padding(.horizontal, 28)

                // Calendar grid skeleton
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

                    // Calendar days skeleton
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                        ForEach(0..<35, id: \.self) { _ in
                            SkeletonBox(width: 36, height: 36, cornerRadius: 8)
                        }
                    }
                }
                .padding(.vertical, 12)
                .background(colorScheme == .dark ? Color.gray.opacity(0.15) : .white)
                .cornerRadius(16)
                .padding(.horizontal, 20)

                // Selected date movies skeleton
                VStack(alignment: .leading, spacing: 12) {
                    SkeletonBox(width: 250, height: 18, cornerRadius: 4)
                        .padding(.horizontal, 20)

                    LazyVStack(spacing: 8) {
                        ForEach(0..<3, id: \.self) { _ in
                            HStack(spacing: 12) {
                                SkeletonBox(width: 40, height: 60, cornerRadius: 6)

                                VStack(alignment: .leading, spacing: 6) {
                                    SkeletonBox(width: 150, height: 14, cornerRadius: 4)
                                    SkeletonBox(width: 80, height: 10, cornerRadius: 4)
                                    SkeletonBox(width: 100, height: 10, cornerRadius: 4)
                                }

                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(colorScheme == .dark ? Color.gray.opacity(0.15) : .white)
                            .cornerRadius(12)
                            .padding(.horizontal, 20)
                        }
                    }
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 0)
        }
        .scrollContentBackground(.hidden)
    }
}

// MARK: - Combined Skeleton Content (respects view mode)

struct SkeletonMoviesContent: View {
    let viewMode: MoviesView.ViewMode

    var body: some View {
        switch viewMode {
        case .list:
            SkeletonMoviesListView()
        case .tile:
            SkeletonMoviesTileView()
        case .calendar:
            SkeletonMoviesCalendarView()
        }
    }
}

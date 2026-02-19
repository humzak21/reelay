//
//  HomeSkeletonViews.swift
//  reelay2
//
//  Skeleton loading components for HomeView
//

import SwiftUI

// MARK: - Skeleton Components

struct SkeletonBox: View {
    let width: CGFloat?
    let height: CGFloat
    let cornerRadius: CGFloat

    @Environment(\.colorScheme) private var colorScheme
    @State private var animationPhase: CGFloat = 0

    init(width: CGFloat? = nil, height: CGFloat, cornerRadius: CGFloat = 8) {
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        colorScheme == .dark ? Color.gray.opacity(0.15) : .white,
                        (colorScheme == .dark ? Color.gray.opacity(0.15) : .white).opacity(0.7),
                        colorScheme == .dark ? Color.gray.opacity(0.15) : .white
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: width, height: height)
            .cornerRadius(cornerRadius)
            .overlay(
                LinearGradient(
                    colors: [
                        Color.clear,
                        Color.white.opacity(colorScheme == .dark ? 0.1 : 0.3),
                        Color.clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: width ?? 200)
                .offset(x: animationPhase)
                .mask(
                    Rectangle()
                        .frame(width: width, height: height)
                        .cornerRadius(cornerRadius)
                )
            )
            .onAppear {
                withAnimation(
                    .linear(duration: 1.5)
                    .repeatForever(autoreverses: false)
                ) {
                    animationPhase = (width ?? 200) + 100
                }
            }
    }
}

// MARK: - Skeleton Poster View

struct SkeletonPosterView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 8) {
            SkeletonBox(width: 100, height: 150, cornerRadius: 12)
            SkeletonBox(width: 80, height: 12, cornerRadius: 4)
        }
        .frame(width: 100)
    }
}

// MARK: - Skeleton Unified Stat Tile

struct SkeletonUnifiedStatTile: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 4) {
            SkeletonBox(width: 24, height: 24, cornerRadius: 12)
            SkeletonBox(width: 40, height: 20, cornerRadius: 4)
            SkeletonBox(width: 60, height: 10, cornerRadius: 4)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 90)
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color.gray.opacity(0.15) : .white)
        )
    }
}

// MARK: - Skeleton Goal Card

struct SkeletonGoalCard: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            SkeletonBox(width: 24, height: 24, cornerRadius: 12)

            VStack(alignment: .leading, spacing: 6) {
                SkeletonBox(width: 200, height: 16, cornerRadius: 4)
                SkeletonBox(width: 100, height: 12, cornerRadius: 4)
                SkeletonBox(height: 4, cornerRadius: 2)
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

// MARK: - Section Skeleton Views

struct SkeletonGoalsSection: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            // Section header
            HStack {
                Text("Goals")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(Color.adaptiveText(scheme: colorScheme))
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 16)

            VStack(spacing: 12) {
                SkeletonGoalCard()
                SkeletonGoalCard()
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 20)
    }
}

struct SkeletonRecentlyLoggedSection: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            // Section header
            HStack {
                Text("Recently Logged")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(Color.adaptiveText(scheme: colorScheme))
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 16)

            // Horizontal scrollable movie posters row
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(0..<5, id: \.self) { _ in
                        SkeletonPosterView()
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 20)
        }
    }
}

struct SkeletonCurrentlyWatchingSection: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            // Section header
            HStack {
                Text("Currently Watching")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(Color.adaptiveText(scheme: colorScheme))
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 16)

            // Horizontal scrollable TV show posters row
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(0..<5, id: \.self) { _ in
                        SkeletonPosterView()
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 20)
        }
    }
}

struct SkeletonUpcomingFilmsSection: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            // Section header
            HStack {
                Text("Upcoming Films")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(Color.adaptiveText(scheme: colorScheme))
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 16)

            // Horizontal scrollable movie posters row
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(0..<5, id: \.self) { _ in
                        SkeletonPosterView()
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 20)
        }
    }
}

struct SkeletonYearStatsSection: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            // Section header
            HStack {
                SkeletonBox(width: 120, height: 24, cornerRadius: 4)
                Spacer()
            }
            .padding(.top, 12)
            .padding(.bottom, 16)

            // Stats grid - 3x2 uniform layout
            VStack(spacing: 12) {
                // First row
                HStack(spacing: 12) {
                    SkeletonUnifiedStatTile()
                    SkeletonUnifiedStatTile()
                    SkeletonUnifiedStatTile()
                }
                
                // Second row
                HStack(spacing: 12) {
                    SkeletonUnifiedStatTile()
                    SkeletonUnifiedStatTile()
                    SkeletonUnifiedStatTile()
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }
}

// MARK: - Full Skeleton Home View

struct SkeletonHomeContent: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                SkeletonYearStatsSection()
                SkeletonGoalsSection()
                SkeletonRecentlyLoggedSection()
                SkeletonCurrentlyWatchingSection()
                SkeletonUpcomingFilmsSection()
                Spacer()
            }
            .padding(.top, 20)
        }
    }
}

//
//  ProfileSkeletonViews.swift
//  reelay2
//
//  Skeleton loading components for ProfileView
//

import SwiftUI

// MARK: - Skeleton Backdrop Section

struct SkeletonBackdropSection: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        Color.adaptiveCardBackground(scheme: colorScheme),
                        Color.adaptiveCardBackground(scheme: colorScheme).opacity(0.7)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(height: 400)
            .overlay(
                LinearGradient.adaptiveBackdropOverlay(scheme: colorScheme)
            )
    }
}

// MARK: - Skeleton Profile Info Section

struct SkeletonProfileInfoSection: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 12) {
            // Profile picture skeleton
            Circle()
                .fill(Color.adaptiveCardBackground(scheme: colorScheme))
                .frame(width: 120, height: 120)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 4)
                )
                .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 8)

            VStack(spacing: 6) {
                SkeletonBox(width: 150, height: 28, cornerRadius: 6)
                    .shadow(color: .black, radius: 4, x: 0, y: 2)

                SkeletonBox(width: 200, height: 16, cornerRadius: 4)
                    .shadow(color: .black, radius: 2, x: 0, y: 1)
            }
        }
        .padding(.bottom, 30)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Skeleton Navigation Option

struct SkeletonNavigationOption: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 16) {
            SkeletonBox(width: 30, height: 30, cornerRadius: 15)

            VStack(alignment: .leading, spacing: 2) {
                SkeletonBox(width: 100, height: 16, cornerRadius: 4)
                SkeletonBox(width: 150, height: 12, cornerRadius: 4)
            }

            Spacer()

            SkeletonBox(width: 12, height: 12, cornerRadius: 4)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
}

// MARK: - Full Skeleton Profile Content

struct SkeletonProfileContent: View {
    @Environment(\.colorScheme) private var colorScheme

    private var appBackground: Color {
        #if canImport(UIKit)
        colorScheme == .dark ? .black : Color(.systemGroupedBackground)
        #else
        colorScheme == .dark ? .black : Color(.windowBackgroundColor)
        #endif
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // Backdrop Section with overlaid profile info
                ZStack(alignment: .bottom) {
                    SkeletonBackdropSection()
                    SkeletonProfileInfoSection()
                }

                // Content Section
                VStack(spacing: 16) {
                    // Navigation Options
                    VStack(spacing: 0) {
                        ForEach(0..<5, id: \.self) { _ in
                            SkeletonNavigationOption()
                        }
                    }
                    .background(Color.adaptiveCardBackground(scheme: colorScheme))
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 4)
                .background(appBackground)

                Spacer(minLength: 100)
            }
        }
        .background(appBackground.ignoresSafeArea())
        .ignoresSafeArea(edges: .top)
    }
}

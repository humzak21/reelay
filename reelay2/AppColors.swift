//
//  AppColors.swift
//  reelay2
//
//  Created by Claude Code on 1/12/26.
//

import SwiftUI

extension Color {
    // MARK: - Text Colors

    /// Primary text color that adapts to light/dark mode
    /// Dark mode: white, Light mode: black
    static func adaptiveText(scheme: ColorScheme) -> Color {
        scheme == .dark ? .white : .black
    }

    /// Secondary text color with reduced opacity
    /// Dark mode: white 70%, Light mode: black 60%
    static func adaptiveSecondaryText(scheme: ColorScheme) -> Color {
        scheme == .dark ? .white.opacity(0.7) : .black.opacity(0.6)
    }

    /// Tertiary text color using system gray
    /// Same in both modes for consistency
    static func adaptiveTertiaryText(scheme: ColorScheme) -> Color {
        .gray
    }

    // MARK: - Background Colors

    /// Primary background color (page/screen backgrounds)
    /// Dark mode: pure black, Light mode: light grey (systemGroupedBackground)
    static func adaptiveBackground(scheme: ColorScheme) -> Color {
        #if canImport(UIKit)
        scheme == .dark ? .black : Color(.systemGroupedBackground)
        #else
        scheme == .dark ? .black : Color(.windowBackgroundColor)
        #endif
    }

    /// Card/container background color (cells, cards, interactive elements)
    /// Dark mode: subtle fill, Light mode: white
    static func adaptiveCardBackground(scheme: ColorScheme) -> Color {
        #if canImport(UIKit)
        scheme == .dark ? Color(.secondarySystemFill) : .white
        #else
        scheme == .dark ? Color(.controlBackgroundColor) : .white
        #endif
    }

    /// Interactive element background (buttons, pickers, form fields)
    /// Dark mode: tertiary fill, Light mode: white
    static func adaptiveInteractiveBackground(scheme: ColorScheme) -> Color {
        #if canImport(UIKit)
        scheme == .dark ? Color(.tertiarySystemFill) : .white
        #else
        scheme == .dark ? Color(.controlBackgroundColor) : .white
        #endif
    }

    // MARK: - Overlay & Effects

    /// Adaptive overlay with adjustable intensity
    /// Dark mode: black overlay, Light mode: white overlay with reduced intensity
    /// - Parameters:
    ///   - scheme: Current color scheme
    ///   - intensity: Opacity level (0.0 - 1.0)
    static func adaptiveOverlay(scheme: ColorScheme, intensity: Double) -> Color {
        scheme == .dark ? Color.black.opacity(intensity) : Color.white.opacity(intensity * 0.5)
    }

    /// Adaptive shadow color
    /// Dark mode: black 50%, Light mode: black 20%
    static func adaptiveShadow(scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.black.opacity(0.5) : Color.black.opacity(0.2)
    }
}

extension LinearGradient {
    // MARK: - Gradient Overlays

    /// Backdrop overlay gradient for images
    /// Creates a 4-stop gradient from transparent to opaque
    /// - Parameter scheme: Current color scheme
    /// - Returns: Adaptive gradient suitable for overlaying on backdrops
    static func adaptiveBackdropOverlay(scheme: ColorScheme) -> LinearGradient {
        if scheme == .dark {
            return LinearGradient(
                colors: [
                    Color.black.opacity(0.1),
                    Color.black.opacity(0.3),
                    Color.black.opacity(0.6),
                    Color.black.opacity(0.9)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            return LinearGradient(
                colors: [
                    Color.white.opacity(0.1),
                    Color.white.opacity(0.3),
                    Color.white.opacity(0.5),
                    Color.white.opacity(0.7)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    /// Section background gradient
    /// Creates a subtle 2-stop gradient for section backgrounds
    /// - Parameter scheme: Current color scheme
    /// - Returns: Adaptive gradient for section backgrounds
    static func adaptiveSectionBackground(scheme: ColorScheme) -> LinearGradient {
        if scheme == .dark {
            return LinearGradient(
                colors: [Color.black.opacity(0.8), Color.black],
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            #if canImport(UIKit)
            let lightColors = [Color(.systemGroupedBackground).opacity(0.9), Color(.systemGroupedBackground)]
            #else
            let lightColors = [Color(.windowBackgroundColor).opacity(0.9), Color(.windowBackgroundColor)]
            #endif
            return LinearGradient(
                colors: lightColors,
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

// MARK: - App-Specific Color Helpers

struct AppColorHelpers {
    /// Returns yellow for 5-star ratings, blue otherwise
    /// - Parameter rating: Movie rating (0.0 - 5.0)
    /// - Returns: Yellow for perfect ratings, blue for all others
    static func starColor(for rating: Double?) -> Color {
        guard let rating = rating else { return .blue }
        return rating == 5.0 ? .yellow : .blue
    }

    /// Returns yellow for 100-point detailed ratings, purple otherwise
    /// - Parameter detailedRating: Detailed rating (0 - 100)
    /// - Returns: Yellow for perfect ratings, purple for all others
    static func detailedRatingColor(for detailedRating: Double?) -> Color {
        guard let rating = detailedRating else { return .purple }
        return rating == 100.0 ? .yellow : .purple
    }

    /// Generates consistent tag colors based on tag name hash
    /// Uses a predefined palette of 10 colors with 80% opacity
    /// - Parameter tag: Tag name string
    /// - Returns: Consistent color for the given tag
    static func tagColor(for tag: String) -> Color {
        let tagHash = tag.lowercased().hash
        let colors: [Color] = [
            .blue.opacity(0.8),
            .green.opacity(0.8),
            .orange.opacity(0.8),
            .purple.opacity(0.8),
            .red.opacity(0.8),
            .yellow.opacity(0.8),
            .pink.opacity(0.8),
            .cyan.opacity(0.8),
            .indigo.opacity(0.8),
            .mint.opacity(0.8)
        ]
        return colors[abs(tagHash) % colors.count]
    }
}

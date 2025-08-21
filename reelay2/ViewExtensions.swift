//
//  ViewExtensions.swift
//  reelay2
//
//  Created by Humza Khalil on 8/1/25.
//

import SwiftUI

extension View {
    func glassEffect(in shape: some InsettableShape) -> some View {
        self
            .background {
                shape
                    .fill(.ultraThinMaterial, style: FillStyle())
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
            }
    }

    // Adds a subtle dark glass background suitable for dashboard sections
    func sectionGlassBackground(cornerRadius: CGFloat = 20) -> some View {
        background(
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.45),
                            Color.black.opacity(0.60)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }

    // Adds a multi-color gradient stroke around a rounded rect with soft glow
    func gradientSectionStroke(
        cornerRadius: CGFloat = 20,
        lineWidth: CGFloat = 0.8,
        colors: [Color] = [
            .purple.opacity(0.9),
            .blue.opacity(0.9),
            .green.opacity(0.9),
            .pink.opacity(0.9),
            .purple.opacity(0.9)
        ]
    ) -> some View {
        overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: colors),
                        center: .center
                    ),
                    lineWidth: lineWidth
                )
                .opacity(0.25)
        )
        .shadow(color: .purple.opacity(0.06), radius: 5, x: 0, y: 2)
        .shadow(color: .blue.opacity(0.05), radius: 3, x: 0, y: 1)
    }

    // Dark card background for inner stat tiles
    func darkCardBackground(cornerRadius: CGFloat = 14) -> some View {
        background(
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.13, green: 0.13, blue: 0.15),
                                 Color(red: 0.10, green: 0.10, blue: 0.12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(Color.white.opacity(0.04), lineWidth: 0.6)
        )
    }

    // Neon gradient border plus soft glow; ideal for stat tiles
    func neonBorder(
        cornerRadius: CGFloat = 14,
        colors: [Color],
        lineWidth: CGFloat = 1.1,
        glowRadius: CGFloat = 8
    ) -> some View {
        overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: colors),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: lineWidth
                )
                .opacity(0.55)
        )
        // revert glow to the version you liked previously
        .shadow(color: (colors.first ?? .clear).opacity(0.12), radius: glowRadius, x: 0, y: 0)
        .shadow(color: (colors.last ?? .clear).opacity(0.08), radius: glowRadius - 1, x: 0, y: 0)
    }

    // Gradient foreground for text
    func gradientForeground(_ colors: [Color], start: UnitPoint = .leading, end: UnitPoint = .trailing) -> some View {
        overlay(
            LinearGradient(gradient: Gradient(colors: colors), startPoint: start, endPoint: end)
        )
        .mask(self)
    }
}
//
//  ListsSkeletonViews.swift
//  reelay2
//
//  Skeleton loading components for ListsView
//

import SwiftUI

// MARK: - Skeleton List Card

struct SkeletonListCard: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header section
            HStack {
                // Left header section
                VStack(alignment: .leading, spacing: 4) {
                    SkeletonBox(width: 180, height: 24, cornerRadius: 6)
                    SkeletonBox(width: 140, height: 14, cornerRadius: 4)
                }

                Spacer()

                // Right header section (count)
                VStack(alignment: .trailing, spacing: 4) {
                    SkeletonBox(width: 40, height: 24, cornerRadius: 6)
                    SkeletonBox(width: 50, height: 10, cornerRadius: 4)
                }
            }

            // Poster preview section
            HStack(spacing: 6) {
                ForEach(0..<6, id: \.self) { _ in
                    SkeletonBox(width: 50, height: 75, cornerRadius: 8)
                }
            }
        }
        .padding(16)
        .background(colorScheme == .dark ? Color.gray.opacity(0.15) : .white)
        .cornerRadius(16)
    }
}

// MARK: - Skeleton Lists Grid View

struct SkeletonListsGridView: View {
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                Color.clear.frame(height: 1)

                LazyVStack(spacing: 16) {
                    ForEach(0..<5, id: \.self) { _ in
                        SkeletonListCard()
                            .padding(.horizontal, 20)
                    }
                }
                .padding(.vertical, 16)
            }
        }
        .scrollContentBackground(.hidden)
    }
}

// MARK: - Full Skeleton Lists Content

struct SkeletonListsContent: View {
    var body: some View {
        SkeletonListsGridView()
    }
}

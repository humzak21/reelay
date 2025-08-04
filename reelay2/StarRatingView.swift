//
//  StarRatingView.swift
//  reelay2
//
//  Created by Claude on 8/1/25.
//

import SwiftUI

struct StarRatingView: View {
    @Binding var rating: Double
    let maxRating: Int
    let size: CGFloat
    let interactive: Bool
    
    init(rating: Binding<Double>, maxRating: Int = 5, size: CGFloat = 20, interactive: Bool = true) {
        self._rating = rating
        self.maxRating = maxRating
        self.size = size
        self.interactive = interactive
    }
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...maxRating, id: \.self) { starIndex in
                star(for: starIndex)
                    .foregroundColor(starColor(for: starIndex))
                    .font(.system(size: size))
                    .onTapGesture {
                        if interactive {
                            updateRating(for: starIndex)
                        }
                    }
                    .contentShape(Rectangle())
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
        
        if rating >= starValue - 0.25 {
            // Gold color for 5-star ratings, blue for others
            return rating >= 4.75 ? .yellow : .blue
        } else {
            return .gray
        }
    }
    
    private func updateRating(for starIndex: Int) {
        let starValue = Double(starIndex)
        
        if rating == starValue {
            // If tapping the same star, toggle between full and half
            rating = starValue - 0.5
        } else if rating == starValue - 0.5 {
            // If tapping on a half star, make it empty
            rating = starValue - 1.0
        } else {
            // Otherwise, set to full star
            rating = starValue
        }
        
        // Ensure rating doesn't go below 0
        if rating < 0 {
            rating = 0
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        StarRatingView(rating: .constant(4.5))
        StarRatingView(rating: .constant(3.0))
        StarRatingView(rating: .constant(5.0))
        StarRatingView(rating: .constant(2.5))
    }
    .padding()
}
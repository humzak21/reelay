//
//  StarRatingView.swift
//  reelay
//
//  Created by Humza Khalil on 6/11/25.
//

import SwiftUI

struct StarRatingView: View {
    let rating: Double
    let maxRating: Int
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...maxRating, id: \.self) { index in
                Image(systemName: starType(for: index))
                    .foregroundColor(.yellow)
                    .font(.caption)
            }
        }
    }
    
    private func starType(for index: Int) -> String {
        if Double(index) <= rating {
            return "star.fill"
        } else if Double(index) - 0.5 <= rating {
            return "star.leadinghalf.filled"
        } else {
            return "star"
        }
    }
}

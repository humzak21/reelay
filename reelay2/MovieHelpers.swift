//
//  MovieHelpers.swift
//  reelay2
//
//  Created by Humza Khalil
//

import SwiftUI

// MARK: - Helper Structs
struct MovieRatingHelper {
    static func starType(for index: Int, rating: Double?) -> String {
        guard let rating = rating else { return "star" }
        
        let adjustedRating = rating  // Assuming rating is already on 5-star scale
        
        if adjustedRating >= Double(index + 1) {
            return "star.fill"
        } else if adjustedRating >= Double(index) + 0.5 {
            return "star.leadinghalf.filled"
        } else {
            return "star"
        }
    }
    
    static func starColor(for rating: Double?) -> Color {
        guard let rating = rating else { return .blue }
        return rating == 5.0 ? .yellow : .blue
    }
}

struct MovieTagHelper {
    static func tagIconsWithColors(for tagsString: String?) -> [(icon: String, color: Color)] {
        guard let tagsString = tagsString, !tagsString.isEmpty else { return [] }
        
        let tagIconColorMap: [String: (icon: String, color: Color)] = [
            "IMAX": ("film", .red),
            "theater": ("popcorn", .purple),
            "family": ("person.3.fill", .yellow),
            "theboys": ("person.2.fill", .green),
            "airplane": ("airplane", .orange),
            "train": ("train.side.front.car", .cyan),
            "short": ("movieclapper.fill", .pink),
        ]
        
        // Parse tags - assuming they're comma-separated or space-separated
        let tags = tagsString.components(separatedBy: CharacterSet(charactersIn: ", ")).compactMap { tag in
            tag.trimmingCharacters(in: .whitespaces).lowercased()
        }
        
        return tags.compactMap { tag in
            // Check both lowercase and original case for matching
            return tagIconColorMap[tag] ?? tagIconColorMap[tag.capitalized] ?? tagIconColorMap[tag.uppercased()]
        }
    }
}
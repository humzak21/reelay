//
//  TagConfiguration.swift
//  reelay2
//
//  Created by Humza Khalil on 9/2/25.
//

import SwiftUI

/// Centralized configuration for movie tags including icons and colors
struct TagConfiguration {
    
    /// Tag data structure containing icon and color information
    struct TagData {
        let icon: String
        let color: Color
    }
    
    /// Master tag configuration mapping
    static let tagMap: [String: TagData] = [
        "IMAX": TagData(icon: "film", color: .red),
        "theater": TagData(icon: "popcorn.fill", color: .purple),
        "family": TagData(icon: "figure.2.and.child.holdinghands", color: .yellow),
        "theboys": TagData(icon: "person.3.fill", color: .green),
        "airplane": TagData(icon: "airplane", color: .orange),
        "train": TagData(icon: "train.side.front.car", color: .cyan),
        "short": TagData(icon: "movieclapper.fill", color: .mint),
        "bookclub": TagData(icon: "book.fill", color: .pink),
        "scavenger hunt": TagData(icon: "magnifyingglass", color: .white),
    ]
    
    /// Get icon and color data for tags from a tag string
    /// - Parameter tagsString: Comma or space separated string of tags
    /// - Returns: Array of tuples containing icon name and color for each recognized tag
    static func getTagIconsWithColors(for tagsString: String?) -> [(icon: String, color: Color)] {
        guard let tagsString = tagsString, !tagsString.isEmpty else {
            return []
        }
        
        // Parse tags - assuming they're comma-separated
        let tags = tagsString.components(separatedBy: ",")
            .compactMap { tag in
                tag.trimmingCharacters(in: .whitespaces).lowercased()
            }
        
        return tags.compactMap { tag in
            // Check lowercase, capitalized, and uppercase versions for matching
            if let tagData = tagMap[tag] {
                return (icon: tagData.icon, color: tagData.color)
            } else if let tagData = tagMap[tag.capitalized] {
                return (icon: tagData.icon, color: tagData.color)
            } else if let tagData = tagMap[tag.uppercased()] {
                return (icon: tagData.icon, color: tagData.color)
            }
            return nil
        }
    }
    
    /// Get icon for a specific tag
    /// - Parameter tag: The tag name
    /// - Returns: SF Symbol name for the tag, or "tag.fill" as default
    static func getIcon(for tag: String) -> String {
        let lowercaseTag = tag.lowercased()
        return tagMap[lowercaseTag]?.icon ?? 
               tagMap[tag.capitalized]?.icon ?? 
               tagMap[tag.uppercased()]?.icon ?? 
               "tag.fill"
    }
    
    /// Get color for a specific tag
    /// - Parameter tag: The tag name
    /// - Returns: Color for the tag, or .blue as default
    static func getColor(for tag: String) -> Color {
        let lowercaseTag = tag.lowercased()
        return tagMap[lowercaseTag]?.color ?? 
               tagMap[tag.capitalized]?.color ?? 
               tagMap[tag.uppercased()]?.color ?? 
               .blue
    }
    
    /// Get all available tag names
    /// - Returns: Array of all configured tag names
    static var allTagNames: [String] {
        return Array(tagMap.keys)
    }
}
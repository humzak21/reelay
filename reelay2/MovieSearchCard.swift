//
//  MovieSearchCard.swift
//  reelay2
//
//  Created by Assistant on 8/10/25.
//

import SwiftUI
import SDWebImageSwiftUI

struct MovieSearchCard: View {
    let movie: Movie
    let searchQuery: String
    let rewatchIconColor: Color
    @State private var isPressed = false
    @State private var showingDetails = false
    
    var body: some View {
        Button(action: {
            showingDetails = true
        }) {
            HStack(spacing: 16) {
                // Movie Poster with shadow and animation
                ZStack {
                    AsyncImage(url: movie.posterURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                Image(systemName: "film")
                                    .font(.system(size: 24))
                                    .foregroundColor(.gray.opacity(0.5))
                            )
                    }
                    .frame(width: 80, height: 120)
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 3)
                    
                }
                .scaleEffect(isPressed ? 0.95 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
                
                // Movie Details
                VStack(alignment: .leading, spacing: 6) {
                    // Title with search highlighting
                    HighlightedText(
                        text: movie.title,
                        highlight: searchQuery,
                        font: .system(size: 16, weight: .semibold),
                        textColor: .white,
                        highlightColor: .yellow.opacity(0.8)
                    )
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    
                    // Year
                    if let year = movie.release_year {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.system(size: 10))
                            Text(String(year))
                                .font(.caption)
                        }
                        .foregroundColor(.gray)
                    }
                    
                    // Watch date - separate row for more space
                    if let watchDate = movie.watch_date {
                        HStack(spacing: 4) {
                            Image(systemName: "eye.fill")
                                .font(.system(size: 10))
                            Text(formatWatchDate(watchDate))
                                .font(.caption)
                        }
                        .foregroundColor(.blue)
                    }
                    
                    // Star rating and detailed rating together
                    HStack(spacing: 8) {
                        // Star rating
                        if let rating = movie.rating {
                            HStack(spacing: 1) {
                                ForEach(0..<5) { index in
                                    Image(systemName: starType(for: index, rating: rating))
                                        .font(.system(size: 10))
                                        .foregroundColor(starColor(for: rating))
                                }
                            }
                        }
                        
                        // Detailed rating next to stars
                        if let detailedRating = movie.detailed_rating {
                            HStack(spacing: 2) {
                                Text("\(Int(detailedRating))")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background(
                                        Capsule()
                                            .fill(ratingColor(for: detailedRating))
                                    )
                            }
                        }
                    }
                    
                    // Rewatch indicator - separate row
                    if movie.isRewatchMovie {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Rewatch")
                                .font(.caption2)
                        }
                        .foregroundColor(rewatchIconColor)
                    }
                    
                    // Tags
                    if let tags = movie.tags, !tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(parseTags(tags), id: \.self) { tag in
                                    TagChip(tag: tag)
                                }
                            }
                        }
                    }
                    
                }
                
                Spacer(minLength: 0)
                
                // Chevron indicator
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray.opacity(0.5))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.gray.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.1),
                                        Color.white.opacity(0.05)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0.1, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
        .sheet(isPresented: $showingDetails) {
            MovieDetailsView(movie: movie)
        }
    }
    
    private func formatWatchDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        
        guard let date = formatter.date(from: dateString) else {
            // If parsing fails, try to return a cleaned version
            return dateString.replacingOccurrences(of: "-", with: "/")
        }
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "MMM dd, yyyy"
        displayFormatter.locale = Locale(identifier: "en_US_POSIX")
        return displayFormatter.string(from: date)
    }
    
    private func parseTags(_ tags: String) -> [String] {
        return tags.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .prefix(3) // Show max 3 tags
            .map { String($0) }
    }
    
    private func starType(for index: Int, rating: Double?) -> String {
        guard let rating = rating else { return "star" }
        
        if rating >= Double(index + 1) {
            return "star.fill"
        } else if rating >= Double(index) + 0.5 {
            return "star.leadinghalf.filled"
        } else {
            return "star"
        }
    }
    
    private func starColor(for rating: Double?) -> Color {
        guard let rating = rating else { return .blue }
        return rating == 5.0 ? .yellow : .blue
    }
    
    private func ratingColor(for rating: Double) -> Color {
        switch rating {
        case 90...100:
            return .yellow
        case 80..<90:
            return .purple
        case 70..<80:
            return .blue
        case 60..<70:
            return .green
        default:
            return .gray
        }
    }
}

// MARK: - Tag Chip Component
struct TagChip: View {
    let tag: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: iconForTag(tag))
                .font(.system(size: 9, weight: .medium))
            Text(tag.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.5)
        }
        .foregroundColor(colorForTag(tag))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(colorForTag(tag).opacity(0.15))
                .overlay(
                    Capsule()
                        .stroke(colorForTag(tag).opacity(0.3), lineWidth: 0.5)
                )
        )
    }
    
    private func iconForTag(_ tag: String) -> String {
        switch tag.lowercased() {
        case "imax": return "film"
        case "theater": return "popcorn"
        case "family": return "person.3.fill"
        case "theboys": return "person.2.fill"
        case "airplane": return "airplane"
        case "train": return "train.side.front.car"
        case "short": return "movieclapper.fill"
        default: return "tag.fill"
        }
    }
    
    private func colorForTag(_ tag: String) -> Color {
        switch tag.lowercased() {
        case "imax": return .red
        case "theater": return .purple
        case "family": return .yellow
        case "theboys": return .green
        case "airplane": return .orange
        case "train": return .cyan
        case "short": return .pink
        default: return .blue
        }
    }
}

// MARK: - Highlighted Text Component
struct HighlightedText: View {
    let text: String
    let highlight: String
    let font: Font
    let textColor: Color
    let highlightColor: Color
    
    var body: some View {
        if highlight.isEmpty {
            Text(text)
                .font(font)
                .foregroundColor(textColor)
        } else {
            let attributed = NSMutableAttributedString(string: text)
            let range = NSString(string: text.lowercased()).range(of: highlight.lowercased())
            
            if range.location != NSNotFound {
                Text(text)
                    .font(font)
                    .foregroundColor(textColor)
                    .overlay(
                        GeometryReader { geometry in
                            let attributedString = AttributedString(attributed)
                            Text(attributedString)
                                .font(font)
                                .foregroundColor(textColor)
                        }
                    )
            } else {
                Text(text)
                    .font(font)
                    .foregroundColor(textColor)
            }
        }
    }
}

// MARK: - Compact Search Card (Alternative View)
struct MovieSearchCardCompact: View {
    let movie: Movie
    @State private var showingDetails = false
    
    var body: some View {
        Button(action: {
            showingDetails = true
        }) {
            VStack(spacing: 8) {
                // Poster
                AsyncImage(url: movie.posterURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: "film")
                                .foregroundColor(.gray.opacity(0.5))
                        )
                }
                .frame(width: 110, height: 165)
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                
                // Title
                Text(movie.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(width: 110)
                
                // Rating
                if let rating = movie.rating {
                    HStack(spacing: 1) {
                        ForEach(0..<5) { index in
                            Image(systemName: starType(for: index, rating: rating))
                                .font(.system(size: 10))
                                .foregroundColor(starColor(for: rating))
                        }
                    }
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingDetails) {
            MovieDetailsView(movie: movie)
        }
    }
    
    private func starType(for index: Int, rating: Double?) -> String {
        guard let rating = rating else { return "star" }
        
        if rating >= Double(index + 1) {
            return "star.fill"
        } else if rating >= Double(index) + 0.5 {
            return "star.leadinghalf.filled"
        } else {
            return "star"
        }
    }
    
    private func starColor(for rating: Double?) -> Color {
        guard let rating = rating else { return .blue }
        return rating == 5.0 ? .yellow : .blue
    }
}
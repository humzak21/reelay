//
//  DraftsBottomSheet.swift
//  reelay2
//
//  Created for the Drafts feature
//

import SwiftUI
import SDWebImageSwiftUI

/// Bottom sheet displaying all saved drafts
struct DraftsBottomSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    let drafts: [MovieDraft]
    let onSelectDraft: (MovieDraft) -> Void
    let onDeleteDraft: (MovieDraft) -> Void
    
    var body: some View {
        NavigationView {
            Group {
                if drafts.isEmpty {
                    emptyState
                } else {
                    draftsList
                }
            }
            .navigationTitle("Your Drafts")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("No Drafts")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(Color.adaptiveText(scheme: colorScheme))
            
            Text("Drafts are automatically saved when you start adding a movie.")
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Drafts List
    
    private var draftsList: some View {
        List {
            ForEach(drafts, id: \.tmdbId) { draft in
                DraftRow(draft: draft)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onSelectDraft(draft)
                        dismiss()
                    }
            }
            .onDelete { indexSet in
                for index in indexSet {
                    onDeleteDraft(drafts[index])
                }
            }
        }
        #if os(macOS)
        .listStyle(.inset)
        #else
        .listStyle(.insetGrouped)
        #endif
    }
}

// MARK: - Draft Row

struct DraftRow: View {
    let draft: MovieDraft
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack(spacing: 12) {
            // Poster
            if let posterUrl = draft.posterUrl, let url = URL(string: posterUrl) {
                WebImage(url: url)
                    .resizable()
                    .indicator(.activity)
                    .transition(.fade(duration: 0.3))
                    .aspectRatio(2/3, contentMode: .fill)
                    .frame(width: 50, height: 75)
                    .cornerRadius(6)
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 50, height: 75)
                    .overlay(
                        Image(systemName: "film")
                            .foregroundColor(.gray)
                    )
            }
            
            // Details
            VStack(alignment: .leading, spacing: 4) {
                Text(draft.title)
                    .font(.headline)
                    .foregroundColor(Color.adaptiveText(scheme: colorScheme))
                    .lineLimit(1)
                
                if let year = draft.releaseYear {
                    Text(String(year))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Draft status
                HStack(spacing: 8) {
                    if let rating = draft.starRating, rating > 0 {
                        Label("\(rating, specifier: "%.1f")★", systemImage: "star.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    
                    if let detailed = draft.detailedRating, !detailed.isEmpty {
                        Text("\(detailed)/100")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    
                    if let review = draft.review, !review.isEmpty {
                        Image(systemName: "text.quote")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
                
                Text(draft.editedAgo)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    DraftsBottomSheet(
        drafts: [],
        onSelectDraft: { _ in },
        onDeleteDraft: { _ in }
    )
}

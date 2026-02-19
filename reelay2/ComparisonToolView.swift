//
//  ComparisonToolView.swift
//  reelay2
//
//  Created by Humza Khalil on 1/11/26.
//

import SwiftUI
import SDWebImageSwiftUI

/// Interactive comparison tool view that helps users determine a detailed rating
/// by comparing their film against existing rated films.
struct ComparisonToolView: View {
    
    // MARK: - Properties
    
    /// The movie the user is trying to rate
    let movieToRate: TMDBMovie
    
    /// The star rating the user has already set (nil for sentiment mode)
    let starRating: Double?
    
    /// Movies in the appropriate rating range for comparison
    let moviesInRange: [Movie]
    
    /// Callback when comparison is complete with the final rating
    let onComplete: (Int) -> Void
    
    /// Callback when user dismisses without completing
    let onDismiss: () -> Void
    
    // MARK: - State
    
    @StateObject private var viewModel: ComparisonToolViewModel
    @Environment(\.colorScheme) private var colorScheme
    
    // MARK: - Initialization
    
    init(
        movieToRate: TMDBMovie,
        starRating: Double?,
        moviesInRange: [Movie],
        onComplete: @escaping (Int) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.movieToRate = movieToRate
        self.starRating = starRating
        self.moviesInRange = moviesInRange
        self.onComplete = onComplete
        self.onDismiss = onDismiss
        
        // Initialize ViewModel based on mode
        if let starRating = starRating, starRating > 0 {
            // Standard mode: use star rating to determine range
            _viewModel = StateObject(wrappedValue: ComparisonToolViewModel(
                starRating: starRating,
                moviesInRange: moviesInRange
            ))
        } else {
            // Sentiment mode: show sentiment selection first
            _viewModel = StateObject(wrappedValue: ComparisonToolViewModel(
                moviesPool: moviesInRange
            ))
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                backgroundColor
                    .ignoresSafeArea()
                
                // Content based on current state
                if viewModel.showSentimentSelection {
                    sentimentSelectionView
                } else if viewModel.earlyExitTriggered {
                    earlyExitView
                } else if !viewModel.hasEnoughMovies {
                    noMoviesView
                } else if viewModel.isComplete {
                    completionView
                } else {
                    comparisonContent
                }
            }
            .navigationTitle(navigationTitle)
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                    }
                }

                // Only show progress when in comparison mode
                if !viewModel.showSentimentSelection && !viewModel.earlyExitTriggered && !viewModel.isComplete && viewModel.hasEnoughMovies {
                    ToolbarItem(placement: .automatic) {
                        Text(viewModel.progressText)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var navigationTitle: String {
        if viewModel.showSentimentSelection {
            return "How do you feel?"
        } else {
            return "Compare"
        }
    }
    
    // MARK: - Subviews
    
    private var backgroundColor: Color {
        #if os(macOS)
        colorScheme == .dark ? Color.black : Color(NSColor.windowBackgroundColor)
        #else
        colorScheme == .dark ? Color.black : Color(.systemGroupedBackground)
        #endif
    }
    
    // MARK: - Sentiment Selection View
    
    private var sentimentSelectionView: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Title
            VStack(spacing: 8) {
                Text("How do you feel about")
                    .font(.title3)
                    .foregroundColor(.secondary)
                
                Text(movieToRate.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 24)
            }
            
            Spacer()
            
            // Sentiment buttons
            VStack(spacing: 16) {
                ForEach(Sentiment.allCases, id: \.self) { sentiment in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            viewModel.selectSentiment(sentiment)
                        }
                    }) {
                        Text(sentiment.displayName)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 72)
                            .background(sentiment.color)
                            .cornerRadius(16)
                    }
                }
            }
            .padding(.horizontal, 24)
            
            Spacer()
        }
    }
    
    // MARK: - Early Exit View
    
    private var earlyExitView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Info icon
            Image(systemName: "info.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            // Message
            Text(viewModel.earlyExitMessage ?? "")
                .font(.title2)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Spacer()
            
            // Buttons
            VStack(spacing: 16) {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        viewModel.returnToSentimentSelection()
                    }
                }) {
                    Text("Try a different feeling")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.purple)
                        .cornerRadius(16)
                }
                
                Button(action: onDismiss) {
                    Text("Cancel")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }
    
    // MARK: - Comparison Content
    
    private var comparisonContent: some View {
        VStack(spacing: 0) {
            // Progress bar
            progressBar
                .padding(.horizontal)
                .padding(.top, 8)
            
            Spacer()
            
            // Question prompt
            Text("Which do you prefer?")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .padding(.bottom, 24)
            
            // Film comparison cards
            HStack(spacing: 16) {
                // User's film (left side)
                userFilmCard
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.userSelectedTheirFilm()
                        }
                    }
                
                // Prompted film (right side)
                if let promptedMovie = viewModel.currentPromptedMovie {
                    promptedFilmCard(movie: promptedMovie)
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                viewModel.userSelectedPromptedFilm()
                            }
                        }
                } else {
                    loadingCard
                }
            }
            .padding(.horizontal)
            
            Spacer()
            
            // Bottom controls
            bottomControls
                .padding(.horizontal)
                .padding(.bottom, 32)
        }
    }
    
    private var progressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 4)
                
                // Progress fill
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.purple)
                    .frame(width: geometry.size.width * viewModel.progress, height: 4)
                    .animation(.easeInOut(duration: 0.3), value: viewModel.progress)
            }
        }
        .frame(height: 4)
    }
    
    private var userFilmCard: some View {
        VStack(spacing: 12) {
            // Poster
            WebImage(url: movieToRate.posterURL)
                .resizable()
                .indicator(.activity)
                .transition(.fade(duration: 0.3))
                .aspectRatio(2/3, contentMode: .fill)
                .frame(width: 140, height: 210)
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
            
            // Title
            Text(movieToRate.title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 140)
        }
        .padding(16)
        .background(cardBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.purple.opacity(0.3), lineWidth: 2)
        )
    }
    
    private func promptedFilmCard(movie: Movie) -> some View {
        VStack(spacing: 12) {
            // Poster
            WebImage(url: movie.posterURL)
                .resizable()
                .indicator(.activity)
                .transition(.fade(duration: 0.3))
                .aspectRatio(2/3, contentMode: .fill)
                .frame(width: 140, height: 210)
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
            
            // Title
            Text(movie.title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 140)
        }
        .padding(16)
        .background(cardBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.blue.opacity(0.3), lineWidth: 2)
        )
    }
    
    private var loadingCard: some View {
        VStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.2))
                .frame(width: 140, height: 210)
                .overlay(
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                )
            
            Text("Loading...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(cardBackground)
        .cornerRadius(16)
    }
    
    private var cardBackground: Color {
        colorScheme == .dark ? Color.gray.opacity(0.15) : Color.gray.opacity(0.08)
    }
    
    private var bottomControls: some View {
        HStack {
            // Undo button
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.undo()
                }
            }) {
                VStack(spacing: 4) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 20, weight: .medium))
                    Text("Undo")
                        .font(.caption2)
                }
                .foregroundColor(viewModel.canUndo ? .primary : .gray.opacity(0.5))
                .frame(width: 60, height: 50)
            }
            .disabled(!viewModel.canUndo)
            
            Spacer()
            
            // Equal button
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.userSelectedEqual()
                }
            }) {
                Text("Equal")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(
                        colorScheme == .dark 
                            ? Color.gray.opacity(0.3) 
                            : Color.gray.opacity(0.15)
                    )
                    .cornerRadius(25)
            }
            
            Spacer()
            
            // Skip button
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.skip()
                }
            }) {
                VStack(spacing: 4) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 20, weight: .medium))
                    Text("Skip")
                        .font(.caption2)
                }
                .foregroundColor(.primary)
                .frame(width: 60, height: 50)
            }
        }
    }
    
    private var noMoviesView: some View {
        VStack(spacing: 20) {
            Image(systemName: "film.stack")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("Not Enough Films")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text(viewModel.isSentimentMode 
                 ? "You need to rate more films in this feeling range before using the comparison tool."
                 : "You need to rate more films in this star range before using the comparison tool.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            if viewModel.isSentimentMode {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        viewModel.returnToSentimentSelection()
                    }
                }) {
                    Text("Try a different feeling")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 12)
                        .background(Color.purple)
                        .cornerRadius(25)
                }
                .padding(.top, 12)
            }
            
            Button(action: onDismiss) {
                Text(viewModel.isSentimentMode ? "Cancel" : "Got it")
                    .font(.headline)
                    .foregroundColor(viewModel.isSentimentMode ? .secondary : .white)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 12)
                    .background(viewModel.isSentimentMode ? Color.clear : Color.purple)
                    .cornerRadius(25)
            }
            .padding(.top, viewModel.isSentimentMode ? 0 : 12)
        }
    }
    
    private var completionView: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
            
            Text("Comparison Complete!")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            if let rating = viewModel.finalRating {
                VStack(spacing: 8) {
                    Text("Your Detailed Rating")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("\(rating)")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundColor(.purple)
                }
            }
            
            Button(action: {
                if let rating = viewModel.finalRating {
                    onComplete(rating)
                }
            }) {
                Text("Apply Rating")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 48)
                    .padding(.vertical, 14)
                    .background(Color.purple)
                    .cornerRadius(25)
            }
            .padding(.top, 12)
        }
    }
}

// MARK: - Preview

#Preview {
    ComparisonToolView(
        movieToRate: TMDBMovie(
            id: 1,
            title: "Interstellar",
            originalTitle: nil,
            overview: nil,
            releaseDate: "2014-11-05",
            posterPath: nil,
            backdropPath: nil,
            voteAverage: 8.6,
            voteCount: 1000,
            popularity: 100,
            originalLanguage: "en",
            genreIds: nil,
            adult: nil,
            video: nil
        ),
        starRating: nil, // Sentiment mode
        moviesInRange: [],
        onComplete: { _ in },
        onDismiss: { }
    )
}

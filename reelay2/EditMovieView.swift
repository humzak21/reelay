//
//  EditMovieView.swift
//  reelay2
//
//  Created by Humza Khalil on 8/1/25.
//

import SwiftUI
import SDWebImageSwiftUI
import MapKit
import Contacts

struct EditMovieView: View {
    @Environment(\.dismiss) private var dismiss
    private let supabaseService = SupabaseMovieService.shared
    private let locationService = SupabaseLocationService.shared

    let movie: Movie
    let onSave: (Movie) -> Void
    
    // User input state
    @State private var starRating: Double = 0.0
    @State private var detailedRating: String = ""
    @State private var review: String = ""
    @State private var tags: String = ""
    @State private var watchDate = Date()
    @State private var isRewatch = false
    @StateObject private var locationHelper = LocationHelper()

    // Location state
    @State private var locationSearchText = ""
    @State private var selectedLocationId: Int?
    @State private var selectedLocationName: String?
    @State private var selectedLocationAddress: String?
    @State private var selectedLocationLatitude: Double?
    @State private var selectedLocationLongitude: Double?
    @State private var selectedLocationNormalizedKey: String?
    @State private var selectedLocationCity: String?
    @State private var selectedLocationAdminArea: String?
    @State private var selectedLocationCountry: String?
    @State private var selectedLocationPostalCode: String?
    @State private var selectedLocationGroupId: Int?
    @State private var selectedLocationGroupName: String?
    @State private var locationGroups: [LocationGroup] = []
    @State private var isCreatingNewLocationGroup = false
    @State private var newLocationGroupName = ""
    @State private var isResolvingLocation = false
    @State private var initialLocationId: Int?
    
    // UI state
    @State private var isUpdatingMovie = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    movieHeader
                    
                    watchDateSection
                    
                    ratingSection
                    
                    detailedRatingSection
                    
                    rewatchSection
                    
                    reviewSection
                    
                    tagsSection

                    locationSection
                    
                    Spacer(minLength: 100)
                }
                .padding()
            }
            .navigationTitle("Edit Movie")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", systemImage: "checkmark") {
                        Task {
                            await updateMovie()
                        }
                    }
                    .disabled(isUpdatingMovie)
                }
            }
            .alert("Error", isPresented: $showingAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
        }
        .onAppear {
            setupInitialValues()
            locationHelper.requestLocationPermission()
            Task {
                await loadLocationGroups()
                await loadInitialLocationIfNeeded()
            }
        }
    }
    
    // MARK: - Movie Header
    private var movieHeader: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .top, spacing: 15) {
                WebImage(url: movie.posterURL)
                    .resizable()
                    .indicator(.activity)
                    .transition(.fade(duration: 0.5))
                    .aspectRatio(2/3, contentMode: .fill)
                    .frame(width: 120)
                    .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(movie.title)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if let year = movie.release_year {
                        Text(String(year))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    if let director = movie.director {
                        Text("Directed by \(director)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    if let overview = movie.overview {
                        Text(overview)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(4)
                    }
                }
                
                Spacer()
            }
        }
    }
    
    // MARK: - Rating Section
    private var ratingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Star Rating")
                .font(.headline)
            
            StarRatingView(rating: $starRating, size: 30)
            
            Text("Tap stars to rate (tap twice for half stars)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Detailed Rating Section
    private var detailedRatingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Detailed Rating (out of 100)")
                .font(.headline)
            
            TextField("Enter rating 0-100", text: $detailedRating)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .cornerRadius(24)
                #if !os(macOS)
                .keyboardType(.numberPad)
                #endif
                .onChange(of: detailedRating) { oldValue, newValue in
                    // Validate input
                    let filtered = newValue.filter { $0.isNumber }
                    if filtered != newValue {
                        detailedRating = filtered
                    }
                }
        }
    }
    
    // MARK: - Review Section
    private var reviewSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Review")
                .font(.headline)
            
            TextField("Write your review...", text: $review, axis: .vertical)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .cornerRadius(24)
                .lineLimit(5...10)
        }
    }
    
    // MARK: - Tags Section
    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Tags")
                .font(.headline)
            
            TextField("e.g., theater, family, IMAX", text: $tags)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .cornerRadius(24)
                #if !os(macOS)
                .autocapitalization(.none)
                #endif
            
            Text("Separate tags with commas (e.g., theater, family, IMAX)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var locationSection: some View {
        MovieLocationSelectionSection(
            title: "Location",
            searchText: $locationSearchText,
            isSearching: locationHelper.isSearching,
            isResolvingSelection: isResolvingLocation,
            searchResults: locationHelper.searchResults,
            selectedLocationName: selectedLocationName,
            selectedLocationAddress: selectedLocationAddress,
            selectedLatitude: selectedLocationLatitude,
            selectedLongitude: selectedLocationLongitude,
            groups: locationGroups,
            selectedGroupId: $selectedLocationGroupId,
            isCreatingNewGroup: $isCreatingNewLocationGroup,
            newGroupName: $newLocationGroupName,
            onSearchTextChanged: { newText in
                locationHelper.searchLocations(query: newText)
            },
            onSelectSearchResult: { completion in
                selectLocation(completion)
            },
            onClearSearch: {
                locationHelper.clearSearch()
            },
            onClearLocation: {
                clearLocationSelection()
            }
        )
        .onChange(of: selectedLocationGroupId) { _, newValue in
            if let group = locationGroups.first(where: { $0.id == newValue }) {
                selectedLocationGroupName = group.name
            } else {
                selectedLocationGroupName = nil
            }
        }
        .onChange(of: isCreatingNewLocationGroup) { _, newValue in
            if !newValue {
                newLocationGroupName = ""
            }
        }
    }
    
    // MARK: - Watch Date Section
    private var watchDateSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Watch Date")
                .font(.headline)
            
            DatePicker("When did you watch this?", selection: $watchDate, displayedComponents: .date)
                .datePickerStyle(CompactDatePickerStyle())
        }
    }
    
    // MARK: - Rewatch Section
    private var rewatchSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Rewatch")
                .font(.headline)
            
            Toggle("This was a rewatch", isOn: $isRewatch)
        }
    }
    
    // MARK: - Helper Methods
    private func setupInitialValues() {
        // Set initial values from the movie
        starRating = movie.rating ?? 0.0
        detailedRating = movie.detailed_rating != nil ? String(Int(movie.detailed_rating!)) : ""
        review = movie.review ?? ""
        tags = movie.tags ?? ""
        isRewatch = movie.is_rewatch ?? false
        initialLocationId = movie.location_id
        selectedLocationId = movie.location_id
        
        // Set watch date
        if let watchDateString = movie.watch_date {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            watchDate = formatter.date(from: watchDateString) ?? Date()
        }
    }

    private func loadLocationGroups() async {
        do {
            let groups = try await locationService.getLocationGroups()
            await MainActor.run {
                locationGroups = groups
            }
        } catch {
            // Location grouping is optional.
        }
    }

    private func loadInitialLocationIfNeeded() async {
        guard let locationId = movie.location_id else { return }
        do {
            if let location = try await locationService.getLocation(id: locationId) {
                await MainActor.run {
                    selectedLocationId = location.id
                    selectedLocationName = location.display_name
                    selectedLocationAddress = location.formatted_address
                    selectedLocationLatitude = location.latitude
                    selectedLocationLongitude = location.longitude
                    selectedLocationNormalizedKey = location.normalized_key
                    selectedLocationCity = location.city
                    selectedLocationAdminArea = location.admin_area
                    selectedLocationCountry = location.country
                    selectedLocationPostalCode = location.postal_code
                    selectedLocationGroupId = location.location_group_id
                    selectedLocationGroupName = location.location_group_name
                }
            }
        } catch {
            // Keep existing location_id even if details fail to load.
        }
    }

    private func selectLocation(_ completion: MKLocalSearchCompletion) {
        Task {
            await MainActor.run {
                isResolvingLocation = true
            }

            guard let mapItem = await locationHelper.resolveLocation(completion) else {
                await MainActor.run {
                    isResolvingLocation = false
                }
                return
            }

            let address = completion.subtitle.isEmpty ? mapItem.placemark.title : completion.subtitle
            let displayName = completion.title.isEmpty
                ? (mapItem.name ?? mapItem.placemark.name ?? "Saved Location")
                : completion.title
            let coordinate = mapItem.placemark.coordinate
            let normalizedKey = SupabaseLocationService.normalizedKey(
                displayName: displayName,
                formattedAddress: address,
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            )

            let postal = mapItem.placemark.postalAddress
            let existing = (try? await locationService.findLocation(byNormalizedKey: normalizedKey)) ?? nil

            await MainActor.run {
                selectedLocationName = displayName
                selectedLocationAddress = address
                selectedLocationLatitude = coordinate.latitude
                selectedLocationLongitude = coordinate.longitude
                selectedLocationNormalizedKey = normalizedKey
                selectedLocationCity = postal?.city
                selectedLocationAdminArea = postal?.state
                selectedLocationCountry = postal?.country
                selectedLocationPostalCode = postal?.postalCode

                if let existing {
                    selectedLocationId = existing.id
                    selectedLocationGroupId = existing.location_group_id
                    selectedLocationGroupName = existing.location_group_name
                    isCreatingNewLocationGroup = false
                    newLocationGroupName = ""
                } else {
                    selectedLocationId = nil
                    selectedLocationGroupId = nil
                    selectedLocationGroupName = nil
                }

                locationSearchText = ""
                locationHelper.clearSearch()
                isResolvingLocation = false
            }
        }
    }

    private func clearLocationSelection() {
        selectedLocationId = nil
        selectedLocationName = nil
        selectedLocationAddress = nil
        selectedLocationLatitude = nil
        selectedLocationLongitude = nil
        selectedLocationNormalizedKey = nil
        selectedLocationCity = nil
        selectedLocationAdminArea = nil
        selectedLocationCountry = nil
        selectedLocationPostalCode = nil
        selectedLocationGroupId = nil
        selectedLocationGroupName = nil
        isCreatingNewLocationGroup = false
        newLocationGroupName = ""
        locationSearchText = ""
        locationHelper.clearSearch()
    }

    private func resolveLocationIdForSave() async throws -> Int? {
        var resolvedGroupId = selectedLocationGroupId
        if isCreatingNewLocationGroup {
            let trimmed = newLocationGroupName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                let group = try await locationService.getOrCreateLocationGroup(named: trimmed)
                resolvedGroupId = group.id
                await MainActor.run {
                    selectedLocationGroupId = group.id
                    selectedLocationGroupName = group.name
                    isCreatingNewLocationGroup = false
                    newLocationGroupName = ""
                    if !locationGroups.contains(where: { $0.id == group.id }) {
                        locationGroups.append(group)
                        locationGroups.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                    }
                }
            }
        }

        if let existingId = selectedLocationId {
            let updatedLocation = try await locationService.updateLocationGroup(locationId: existingId, groupId: resolvedGroupId)
            await MainActor.run {
                selectedLocationGroupId = updatedLocation.location_group_id
                selectedLocationGroupName = updatedLocation.location_group_name
            }
            return existingId
        }

        guard let selectedLocationName,
              let selectedLocationNormalizedKey,
              let selectedLocationLatitude,
              let selectedLocationLongitude else {
            return nil
        }

        let request = AddLocationRequest(
            display_name: selectedLocationName,
            formatted_address: selectedLocationAddress,
            normalized_key: selectedLocationNormalizedKey,
            latitude: selectedLocationLatitude,
            longitude: selectedLocationLongitude,
            city: selectedLocationCity,
            admin_area: selectedLocationAdminArea,
            country: selectedLocationCountry,
            postal_code: selectedLocationPostalCode,
            location_group_id: resolvedGroupId
        )

        let location = try await locationService.createLocation(request)
        await MainActor.run {
            selectedLocationId = location.id
            selectedLocationGroupId = location.location_group_id
            selectedLocationGroupName = location.location_group_name
        }
        return location.id
    }
    
    private func updateMovie() async {
        isUpdatingMovie = true
        
        do {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            
            let updateRequest = UpdateMovieRequest(
                title: nil, // Don't update title
                release_year: nil, // Don't update release year
                release_date: nil, // Don't update release date
                rating: starRating > 0 ? starRating : nil,
                ratings100: Double(detailedRating),
                reviews: review.isEmpty ? nil : review,
                tags: tags.isEmpty ? nil : tags,
                watched_date: formatter.string(from: watchDate),
                rewatch: isRewatch ? "yes" : "no",
                tmdb_id: nil, // Don't update TMDB ID
                overview: nil, // Don't update overview
                poster_url: nil, // Don't update poster
                backdrop_path: nil, // Don't update backdrop
                director: nil, // Don't update director
                runtime: nil, // Don't update runtime
                vote_average: nil, // Don't update vote average
                vote_count: nil, // Don't update vote count
                popularity: nil, // Don't update popularity
                original_language: nil, // Don't update original language
                original_title: nil, // Don't update original title
                tagline: nil, // Don't update tagline
                status: nil, // Don't update status
                budget: nil, // Don't update budget
                revenue: nil, // Don't update revenue
                imdb_id: nil, // Don't update IMDB ID
                homepage: nil, // Don't update homepage
                genres: nil, // Don't update genres
                location_id: nil // Updated explicitly below for null-safe behavior
            )
            
            var updatedMovie = try await supabaseService.updateMovie(id: movie.id, with: updateRequest)
            let resolvedLocationId = try await resolveLocationIdForSave()

            if resolvedLocationId != initialLocationId {
                updatedMovie = try await supabaseService.setMovieLocation(movieId: movie.id, locationId: resolvedLocationId)
                initialLocationId = resolvedLocationId
            }
            
            await MainActor.run {
                isUpdatingMovie = false
                onSave(updatedMovie)
                dismiss()
            }
            
        } catch {
            await MainActor.run {
                isUpdatingMovie = false
                alertMessage = "Failed to update movie: \(error.localizedDescription)"
                showingAlert = true
            }
        }
    }
}

#Preview {
    EditMovieView(movie: Movie(
        id: 1,
        title: "Harry Potter and the Deathly Hallows: Part 1",
        release_year: 2010,
        release_date: "2010-11-17",
        rating: 4.5,
        detailed_rating: 82,
        review: "Great movie!",
        tags: "family, theater",
        watch_date: "2025-07-18",
        is_rewatch: false,
        tmdb_id: 12444,
        overview: "The final adventure begins...",
        poster_url: nil,
        backdrop_path: nil,
        director: "David Yates",
        runtime: 146,
        vote_average: nil,
        vote_count: nil,
        popularity: nil,
        original_language: nil,
        original_title: nil,
        tagline: nil,
        status: nil,
        budget: nil,
        revenue: nil,
        imdb_id: nil,
        homepage: nil,
        genres: nil,
        created_at: nil,
        updated_at: nil,
        favorited: false
    )) { _ in }
}

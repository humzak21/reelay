//
//  AddTheaterVisitView.swift
//  reelay2
//
//  Form for adding/editing a theater visit
//

import SwiftUI
import SDWebImageSwiftUI
import MapKit

struct AddTheaterVisitView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var dataManager = DataManager.shared
    @ObservedObject private var tmdbService = TMDBService.shared
    
    // Edit mode
    var editingVisit: TheaterVisit?
    var preselectedDate: Date?
    
    // Form state
    @State private var title: String = ""
    @State private var tmdbId: Int?
    @State private var posterUrl: String?
    @State private var releaseYear: Int?
    @State private var visitDate: Date = Date()
    @State private var showtime: Date = Date()
    @State private var hasShowtime: Bool = true
    @State private var locationName: String?
    @State private var locationLatitude: Double?
    @State private var locationLongitude: Double?
    @State private var notes: String = ""
    
    // Film search state
    @State private var filmSearchText: String = ""
    @State private var filmSearchResults: [TMDBMovie] = []
    @State private var isSearchingFilm: Bool = false
    @State private var filmSearchTask: Task<Void, Never>?
    @State private var hasSelectedFilm: Bool = false
    
    // Location search state
    @State private var locationSearchText: String = ""
    @State private var hasSelectedLocation: Bool = false
    @StateObject private var locationHelper = LocationHelper()
    
    // UI state
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var isEditing: Bool { editingVisit != nil }
    
    init(preselectedDate: Date? = nil) {
        self.preselectedDate = preselectedDate
        self.editingVisit = nil
    }
    
    init(editingVisit: TheaterVisit) {
        self.editingVisit = editingVisit
        self.preselectedDate = nil
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Film selection section
                    filmSection
                    
                    Divider()
                    
                    // Date & Time section
                    dateTimeSection
                    
                    Divider()
                    
                    // Location section
                    locationSection
                    
                    Divider()
                    
                    // Notes section
                    notesSection
                }
                .padding()
            }
            #if canImport(UIKit)
            .background(Color(.systemGroupedBackground))
            #else
            .background(Color(.windowBackgroundColor))
            #endif
            .navigationTitle(isEditing ? "Edit Visit" : "Plan a Visit")
            #if canImport(UIKit)
            .toolbarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: { saveVisit() }) {
                        if isSaving {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "checkmark")
                        }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
        }
        .onAppear {
            setupInitialValues()
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Film Section
    
    @ViewBuilder
    private var filmSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Film", systemImage: "film")
                .font(.headline)
                .foregroundColor(Color.adaptiveText(scheme: colorScheme))
            
            if hasSelectedFilm {
                // Selected film display
                HStack(spacing: 12) {
                    if let url = posterUrl, !url.isEmpty {
                        let fullURL: URL? = {
                            if url.hasPrefix("http") { return URL(string: url) }
                            if url.hasPrefix("/") { return URL(string: "https://image.tmdb.org/t/p/w200\(url)") }
                            return URL(string: url)
                        }()
                        
                        if let fullURL = fullURL {
                            WebImage(url: fullURL)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 50, height: 75)
                                .cornerRadius(8)
                                .clipped()
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.headline)
                            .foregroundColor(Color.adaptiveText(scheme: colorScheme))
                        
                        if let year = releaseYear {
                            Text("(\(String(year)))")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        clearFilmSelection()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                            .font(.title3)
                    }
                }
                .padding(12)
                .background(colorScheme == .dark ? Color.gray.opacity(0.2) : Color.white)
                .cornerRadius(10)
            } else {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    
                    TextField("Search films...", text: $filmSearchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .foregroundColor(Color.adaptiveText(scheme: colorScheme))
                        .onChange(of: filmSearchText) { _, newValue in
                            filmSearchTask?.cancel()
                            if !newValue.isEmpty {
                                filmSearchTask = Task {
                                    try? await Task.sleep(nanoseconds: 500_000_000)
                                    if !Task.isCancelled {
                                        await performFilmSearch()
                                    }
                                }
                            } else {
                                filmSearchResults = []
                            }
                        }
                    
                    if !filmSearchText.isEmpty {
                        Button(action: {
                            filmSearchText = ""
                            filmSearchResults = []
                            filmSearchTask?.cancel()
                        }) {
                            Image(systemName: "xmark")
                                .foregroundColor(.gray)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    if isSearchingFilm {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(10)
                
                // Search results
                if !filmSearchResults.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(filmSearchResults.prefix(5)) { movie in
                            Button(action: {
                                selectFilm(movie)
                            }) {
                                HStack(spacing: 10) {
                                    if let posterPath = movie.posterPath {
                                        WebImage(url: URL(string: "https://image.tmdb.org/t/p/w92\(posterPath)"))
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 35, height: 52)
                                            .cornerRadius(6)
                                            .clipped()
                                    } else {
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color.gray.opacity(0.3))
                                            .frame(width: 35, height: 52)
                                            .overlay(
                                                Image(systemName: "film")
                                                    .font(.caption2)
                                                    .foregroundColor(.gray)
                                            )
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(movie.title)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(Color.adaptiveText(scheme: colorScheme))
                                            .lineLimit(1)
                                        
                                        if let releaseDate = movie.releaseDate, !releaseDate.isEmpty {
                                            Text(String(releaseDate.prefix(4)))
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "plus.circle")
                                        .foregroundColor(.purple)
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            if movie.id != filmSearchResults.prefix(5).last?.id {
                                Divider().padding(.leading, 57)
                            }
                        }
                    }
                    .background(colorScheme == .dark ? Color.gray.opacity(0.2) : Color.white)
                    .cornerRadius(10)
                }
                
                // Manual entry hint
                if filmSearchText.isEmpty && !hasSelectedFilm {
                    Text("Search TMDB or type a title manually below")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Image(systemName: "pencil")
                            .foregroundColor(.gray)
                        
                        TextField("Or enter title manually...", text: $title)
                            .textFieldStyle(PlainTextFieldStyle())
                            .foregroundColor(Color.adaptiveText(scheme: colorScheme))
                    }
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(10)
                }
            }
        }
    }
    
    // MARK: - Date & Time Section
    
    @ViewBuilder
    private var dateTimeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Date & Time", systemImage: "calendar.badge.clock")
                .font(.headline)
                .foregroundColor(Color.adaptiveText(scheme: colorScheme))
            
            DatePicker(
                "Visit Date",
                selection: $visitDate,
                displayedComponents: .date
            )
            .datePickerStyle(.compact)
            
            Toggle(isOn: $hasShowtime) {
                Label("Set Showtime", systemImage: "clock")
                    .font(.subheadline)
            }
            
            if hasShowtime {
                DatePicker(
                    "Showtime",
                    selection: $showtime,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.compact)
            }
        }
    }
    
    // MARK: - Location Section
    
    @ViewBuilder
    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Location", systemImage: "location")
                .font(.headline)
                .foregroundColor(Color.adaptiveText(scheme: colorScheme))
            
            if hasSelectedLocation, let name = locationName {
                // Selected location display
                HStack(spacing: 8) {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title3)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(Color.adaptiveText(scheme: colorScheme))
                            .lineLimit(2)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        clearLocationSelection()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                            .font(.title3)
                    }
                }
                .padding(12)
                .background(colorScheme == .dark ? Color.gray.opacity(0.2) : Color.white)
                .cornerRadius(10)
                
                // Mini map preview
                if let lat = locationLatitude, let lon = locationLongitude {
                    Map(initialPosition: .region(MKCoordinateRegion(
                        center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    ))) {
                        Marker(name, coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon))
                            .tint(.purple)
                    }
                    .frame(height: 150)
                    .cornerRadius(10)
                    .allowsHitTesting(false)
                }
            } else {
                // Location search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    
                    TextField("Search theaters or locations...", text: $locationSearchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .foregroundColor(Color.adaptiveText(scheme: colorScheme))
                        .onChange(of: locationSearchText) { _, newValue in
                            locationHelper.searchLocations(query: newValue)
                        }
                    
                    if !locationSearchText.isEmpty {
                        Button(action: {
                            locationSearchText = ""
                            locationHelper.clearSearch()
                        }) {
                            Image(systemName: "xmark")
                                .foregroundColor(.gray)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    if locationHelper.isSearching {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(10)
                
                // Location search results
                if !locationHelper.searchResults.isEmpty {
                    let results = Array(locationHelper.searchResults.prefix(5))
                    VStack(spacing: 0) {
                        ForEach(Array(results.enumerated()), id: \.offset) { index, completion in
                            Button(action: {
                                selectLocation(completion)
                            }) {
                                HStack(spacing: 10) {
                                    Image(systemName: "mappin.circle")
                                        .foregroundColor(.blue)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(completion.title)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(Color.adaptiveText(scheme: colorScheme))
                                            .lineLimit(1)
                                        
                                        if !completion.subtitle.isEmpty {
                                            Text(completion.subtitle)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                        }
                                    }
                                    
                                    Spacer()
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            if index < results.count - 1 {
                                Divider().padding(.leading, 42)
                            }
                        }
                    }
                    .background(colorScheme == .dark ? Color.gray.opacity(0.2) : Color.white)
                    .cornerRadius(10)
                }
            }
        }
        .onAppear {
            locationHelper.requestLocationPermission()
        }
    }
    
    // MARK: - Notes Section
    
    @ViewBuilder
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Notes", systemImage: "note.text")
                .font(.headline)
                .foregroundColor(Color.adaptiveText(scheme: colorScheme))
            
            TextEditor(text: $notes)
                .frame(minHeight: 80, maxHeight: 150)
                .padding(8)
                .background(colorScheme == .dark ? Color.gray.opacity(0.2) : Color.white)
                .cornerRadius(10)
                .overlay(
                    Group {
                        if notes.isEmpty {
                            Text("Any notes about this visit...")
                                .foregroundColor(.gray.opacity(0.5))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 16)
                                .allowsHitTesting(false)
                        }
                    },
                    alignment: .topLeading
                )
        }
    }
    
    // MARK: - Actions
    
    private func setupInitialValues() {
        if let visit = editingVisit {
            title = visit.title
            tmdbId = visit.tmdb_id
            posterUrl = visit.poster_url
            releaseYear = visit.release_year
            notes = visit.notes ?? ""
            hasSelectedFilm = true
            
            if let date = visit.visitDate {
                visitDate = date
            }
            
            if let showtimeDate = visit.showtimeDate {
                showtime = showtimeDate
                hasShowtime = true
            }
            
            if let locName = visit.location_name {
                locationName = locName
                locationLatitude = visit.location_latitude
                locationLongitude = visit.location_longitude
                hasSelectedLocation = true
            }
        } else if let date = preselectedDate {
            visitDate = date
        }
    }
    
    private func performFilmSearch() async {
        guard !filmSearchText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        await MainActor.run { isSearchingFilm = true }
        
        do {
            let response = try await tmdbService.searchMovies(query: filmSearchText)
            await MainActor.run {
                filmSearchResults = response.results
                isSearchingFilm = false
            }
        } catch {
            await MainActor.run {
                isSearchingFilm = false
            }
        }
    }
    
    private func selectFilm(_ movie: TMDBMovie) {
        title = movie.title
        tmdbId = movie.id
        posterUrl = movie.posterPath
        
        if let releaseDate = movie.releaseDate, releaseDate.count >= 4 {
            releaseYear = Int(String(releaseDate.prefix(4)))
        }
        
        hasSelectedFilm = true
        filmSearchText = ""
        filmSearchResults = []
        filmSearchTask?.cancel()
    }
    
    private func clearFilmSelection() {
        title = ""
        tmdbId = nil
        posterUrl = nil
        releaseYear = nil
        hasSelectedFilm = false
        filmSearchText = ""
        filmSearchResults = []
    }
    
    private func selectLocation(_ completion: MKLocalSearchCompletion) {
        Task {
            if let mapItem = await locationHelper.resolveLocation(completion) {
                await MainActor.run {
                    locationName = [completion.title, completion.subtitle]
                        .filter { !$0.isEmpty }
                        .joined(separator: ", ")
                    locationLatitude = mapItem.placemark.coordinate.latitude
                    locationLongitude = mapItem.placemark.coordinate.longitude
                    hasSelectedLocation = true
                    locationSearchText = ""
                    locationHelper.clearSearch()
                }
            }
        }
    }
    
    private func clearLocationSelection() {
        locationName = nil
        locationLatitude = nil
        locationLongitude = nil
        hasSelectedLocation = false
        locationSearchText = ""
    }
    
    private func saveVisit() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else { return }
        
        isSaving = true
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        let dateString = dateFormatter.string(from: visitDate)
        
        var showtimeString: String?
        if hasShowtime {
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm:ss"
            timeFormatter.locale = Locale(identifier: "en_US_POSIX")
            showtimeString = timeFormatter.string(from: showtime)
        }
        
        Task {
            do {
                if let existing = editingVisit {
                    // Update existing
                    let updateData = UpdateTheaterVisitRequest(
                        tmdb_id: tmdbId,
                        title: trimmedTitle,
                        poster_url: posterUrl,
                        release_year: releaseYear,
                        visit_date: dateString,
                        showtime: showtimeString,
                        location_name: locationName,
                        location_latitude: locationLatitude,
                        location_longitude: locationLongitude,
                        notes: notes.isEmpty ? nil : notes,
                        is_completed: existing.is_completed
                    )
                    _ = try await dataManager.updateTheaterVisit(id: existing.id, with: updateData)
                } else {
                    // Add new
                    let addData = AddTheaterVisitRequest(
                        tmdb_id: tmdbId,
                        title: trimmedTitle,
                        poster_url: posterUrl,
                        release_year: releaseYear,
                        visit_date: dateString,
                        showtime: showtimeString,
                        location_name: locationName,
                        location_latitude: locationLatitude,
                        location_longitude: locationLongitude,
                        notes: notes.isEmpty ? nil : notes,
                        is_completed: false
                    )
                    _ = try await dataManager.addTheaterVisit(addData)
                }
                
                await MainActor.run {
                    isSaving = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}


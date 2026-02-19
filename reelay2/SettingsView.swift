//
//  SettingsView.swift
//  reelay2
//
//  Created by Humza Khalil on 8/9/25.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("appearanceMode") private var appearanceModeRawValue: String = AppearanceMode.automatic.rawValue
    @ObservedObject private var profileService = SupabaseProfileService.shared
    @ObservedObject private var authService = SupabaseMovieService.shared
    @State private var showingBackdropPicker = false
    @State private var availableMovies: [Movie] = []
    @State private var selectedBackdropMovie: Movie?
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var showingSignOutAlert = false
    @ObservedObject private var plexService = PlexService.shared
    @State private var isRefreshingPlexLibrary = false
    @State private var plexStatusMessage: String?
    @State private var plexStatusIsError = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Appearance") {
                    VStack(spacing: 20) {
                        HStack(spacing: 0) {
                            ForEach(AppearanceMode.allCases, id: \.rawValue) { mode in
                                AppearanceOptionView(
                                    mode: mode,
                                    isSelected: appearanceModeRawValue == mode.rawValue,
                                    action: {
                                        appearanceModeRawValue = mode.rawValue
                                    }
                                )
                                .frame(maxWidth: .infinity)
                            }
                        }
                        Text("Choose how reelay looks. Automatic adapts to your device's system setting.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, 12)
                }
                Section("Profile") {
                    HStack {
                        // Display Google profile picture (unchangeable)
                        Group {
                            if let profilePictureUrl = profileService.currentUserProfile?.picture,
                               let url = URL(string: profilePictureUrl) {
                                AsyncImage(url: url) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Image(systemName: "person.circle.fill")
                                        .font(.system(size: 80))
                                        .foregroundColor(.gray)
                                }
                                .frame(width: 80, height: 80)
                                .clipShape(Circle())
                            } else {
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 80))
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(profileService.currentUserProfile?.name ?? "Unknown User")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text(profileService.currentUserProfile?.email ?? "")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Text("Profile picture from Google account")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section("Profile Backdrop") {
                    Button(action: {
                        showingBackdropPicker = true
                        errorMessage = nil
                        successMessage = nil
                        Task {
                            await loadAvailableMovies()
                        }
                    }) {
                        HStack {
                            Image(systemName: "photo.on.rectangle")
                                .foregroundColor(.blue)
                            
                            VStack(alignment: .leading) {
                                Text("Select Backdrop")
                                    .foregroundColor(.primary)
                                
                                if let selectedMovie = selectedBackdropMovie {
                                    Text(selectedMovie.title)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("Choose from your logged movies")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    if selectedBackdropMovie != nil {
                        Button("Remove Backdrop") {
                            selectedBackdropMovie = nil
                            errorMessage = nil
                            successMessage = nil
                            Task {
                                await saveSettings()
                            }
                        }
                        .foregroundColor(.red)
                    }
                }
                
                Section("Plex") {
                    if plexService.isConfigured {
                        // Connected state
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Connected")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                if let username = plexService.connectedUsername {
                                    Text(username)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                        }
                        
                        // Server picker (inline dropdown)
                        if plexService.availableServers.count > 1 {
                            Picker("Server", selection: Binding(
                                get: { plexService.selectedServerName ?? "" },
                                set: { name in
                                    if let server = plexService.availableServers.first(where: { $0.name == name }) {
                                        plexService.selectServer(server)
                                        Task { await fetchLibrarySections() }
                                    }
                                }
                            )) {
                                ForEach(plexService.availableServers) { server in
                                    Text(server.name).tag(server.name)
                                }
                            }
                            .pickerStyle(.menu)
                        } else if let serverName = plexService.selectedServerName {
                            HStack {
                                Text("Server")
                                Spacer()
                                Text(serverName)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Library picker (inline dropdown)
                        if !plexService.availableLibrarySections.isEmpty {
                            Picker("Library", selection: Binding(
                                get: { plexService.selectedLibrarySectionId ?? "" },
                                set: { sectionId in
                                    if let section = plexService.availableLibrarySections.first(where: { $0.id == sectionId }) {
                                        plexService.selectLibrarySection(section)
                                        Task { await refreshPlexLibrary() }
                                    }
                                }
                            )) {
                                Text("Select a library").tag("")
                                ForEach(plexService.availableLibrarySections) { section in
                                    Text(section.title).tag(section.id)
                                }
                            }
                            .pickerStyle(.menu)
                        } else if plexService.isConfigured {
                            Button("Load Libraries") {
                                Task { await fetchLibrarySections() }
                            }
                        }
                        
                        // Refresh Library (only if section selected)
                        if plexService.selectedLibrarySectionId != nil {
                            Button(action: {
                                Task { await refreshPlexLibrary() }
                            }) {
                                HStack {
                                    Image(systemName: "arrow.clockwise")
                                        .foregroundColor(.blue)
                                    Text("Refresh Library")
                                        .foregroundColor(.primary)
                                    Spacer()
                                    if isRefreshingPlexLibrary {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    } else if plexService.libraryMovieCount > 0 {
                                        Text("\(plexService.libraryMovieCount) movies")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .disabled(isRefreshingPlexLibrary)
                        }
                        
                        // Sign out
                        Button("Sign out of Plex") {
                            plexService.signOut()
                            plexStatusMessage = nil
                        }
                        .foregroundColor(.red)
                        .font(.caption)
                    } else if plexService.isAuthenticating {
                        // Authenticating state
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Waiting for authorization...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        // Not connected — sign in button
                        Button(action: {
                            Task { await signInWithPlex() }
                        }) {
                            HStack {
                                Image(systemName: "play.rectangle.fill")
                                    .foregroundColor(.orange)
                                Text("Sign in with Plex")
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    // Status messages
                    if let msg = plexStatusMessage {
                        HStack(spacing: 6) {
                            Image(systemName: plexStatusIsError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                                .foregroundColor(plexStatusIsError ? .red : .green)
                                .font(.caption)
                            Text(msg)
                                .font(.caption)
                                .foregroundColor(plexStatusIsError ? .red : .green)
                        }
                    }
                }
                
                Section("Account") {
                    Button(action: {
                        showingSignOutAlert = true
                    }) {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .foregroundColor(.red)
                            
                            Text("Sign Out")
                                .foregroundColor(.red)
                            
                            Spacer()
                        }
                    }
                }
                
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                
                if let successMessage = successMessage {
                    Section {
                        Text(successMessage)
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Settings")
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
                            await saveSettings()
                        }
                    }
                }
            }
            .sheet(isPresented: $showingBackdropPicker) {
                BackdropPickerView(
                    movies: availableMovies,
                    selectedMovie: $selectedBackdropMovie
                )
            }
            .task {
                await loadCurrentProfile()
            }
            .alert("Sign Out", isPresented: $showingSignOutAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Sign Out", role: .destructive) {
                    Task {
                        try await authService.signOut()
                        dismiss()
                    }
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
        }
    }
    
    // MARK: - Plex Helpers
    
    private func signInWithPlex() async {
        plexStatusMessage = nil
        
        do {
            let (pinId, code) = try await plexService.requestPIN()
            
            guard let authURL = plexService.authURL(code: code) else {
                throw PlexServiceError.invalidURL
            }
            
            await MainActor.run {
                #if os(iOS)
                UIApplication.shared.open(authURL)
                #elseif os(macOS)
                NSWorkspace.shared.open(authURL)
                #endif
            }
            
            _ = try await plexService.pollForToken(pinId: pinId)
            try? await plexService.fetchUsername()
            
            let servers = try await plexService.fetchServers()
            
            if servers.isEmpty {
                await MainActor.run {
                    plexStatusMessage = "No servers found on your Plex account"
                    plexStatusIsError = true
                }
            } else if servers.count == 1 {
                plexService.selectServer(servers[0])
                await MainActor.run {
                    plexStatusMessage = "Connected to \(servers[0].name)"
                    plexStatusIsError = false
                }
                await fetchLibrarySections()
            } else {
                // Multiple servers — picker will appear automatically
                await MainActor.run {
                    plexStatusMessage = "Select a server"
                    plexStatusIsError = false
                }
            }
        } catch {
            await MainActor.run {
                plexStatusMessage = error.localizedDescription
                plexStatusIsError = true
            }
        }
    }
    
    private func fetchLibrarySections() async {
        do {
            let sections = try await plexService.fetchMovieLibrarySections()
            await MainActor.run {
                plexService.availableLibrarySections = sections
            }
            if sections.count == 1 {
                plexService.selectLibrarySection(sections[0])
                await refreshPlexLibrary()
            } else if sections.isEmpty {
                await MainActor.run {
                    plexStatusMessage = "No movie libraries found"
                    plexStatusIsError = true
                }
            }
        } catch {
            await MainActor.run {
                plexStatusMessage = error.localizedDescription
                plexStatusIsError = true
            }
        }
    }
    
    private func refreshPlexLibrary() async {
        await MainActor.run {
            isRefreshingPlexLibrary = true
            plexStatusMessage = nil
        }
        
        do {
            let count = try await plexService.refreshLibrary()
            await MainActor.run {
                plexStatusMessage = "Found \(count) movies in your library"
                plexStatusIsError = false
                isRefreshingPlexLibrary = false
            }
        } catch {
            await MainActor.run {
                plexStatusMessage = error.localizedDescription
                plexStatusIsError = true
                isRefreshingPlexLibrary = false
            }
        }
    }
    
    private func loadCurrentProfile() async {
        do {
            let profile = try await profileService.getCurrentUserProfile()
            
            await MainActor.run {
                if profile?.selected_backdrop_movie_id != nil {
                    Task {
                        selectedBackdropMovie = try await profileService.getSelectedBackdropMovie()
                    }
                } else {
                    selectedBackdropMovie = nil
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to load profile: \(error.localizedDescription)"
            }
        }
    }
    
    private func loadAvailableMovies() async {
        do {
            let movies = try await profileService.getMoviesForBackdropSelection()
            await MainActor.run {
                availableMovies = movies
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to load movies: \(error.localizedDescription)"
            }
        }
    }
    
    private func saveSettings() async {
        do {
            let updateRequest = UpdateUserProfileRequest(
                selected_backdrop_movie_id: selectedBackdropMovie?.id
            )
            
            _ = try await profileService.updateUserProfile(updateRequest)
            
            // Refresh the profile data to ensure consistency
            _ = try await profileService.getCurrentUserProfile()
            
            await MainActor.run {
                successMessage = "Settings saved successfully!"
                errorMessage = nil
            }
            
            // Dismiss after a short delay
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            await MainActor.run {
                dismiss()
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to save settings: \(error.localizedDescription)"
                successMessage = nil
            }
        }
    }
}

struct BackdropPickerView: View {
    let movies: [Movie]
    @Binding var selectedMovie: Movie?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List(movies) { movie in
                Button(action: {
                    selectedMovie = movie
                    dismiss()
                }) {
                    HStack {
                        AsyncImage(url: movie.posterURL) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                        }
                        .frame(width: 40, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(movie.title)
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            if let year = movie.release_year {
                                Text(String(year))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        if selectedMovie?.id == movie.id {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
            .navigationTitle("Select Backdrop")
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
}

#Preview {
    SettingsView()
}
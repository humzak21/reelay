//
//  SettingsView.swift
//  reelay2
//
//  Created by Humza Khalil on 8/9/25.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("appearanceMode") private var appearanceModeRawValue: String = AppearanceMode.automatic.rawValue
    @StateObject private var profileService = SupabaseProfileService.shared
    @State private var showingBackdropPicker = false
    @State private var availableMovies: [Movie] = []
    @State private var selectedBackdropMovie: Movie?
    @State private var errorMessage: String?
    @State private var successMessage: String?
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
                            Task {
                                await saveSettings()
                            }
                        }
                        .foregroundColor(.red)
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
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
        }
    }
    
    private func loadCurrentProfile() async {
        do {
            let profile = try await profileService.getCurrentUserProfile()
            
            if profile?.selected_backdrop_movie_id != nil {
                selectedBackdropMovie = try await profileService.getSelectedBackdropMovie()
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
            
            await MainActor.run {
                successMessage = "Settings saved successfully!"
            }
            
            // Dismiss after a short delay
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            await MainActor.run {
                dismiss()
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to save settings: \(error.localizedDescription)"
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
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
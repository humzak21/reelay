//
//  ProfileView.swift
//  reelay2
//
//  Created by Humza Khalil on 7/21/25.
//

import SwiftUI
import Auth

struct ProfileView: View {
    @StateObject private var authService = SupabaseMovieService.shared
    
    var body: some View {
        NavigationStack {
            if authService.isLoggedIn {
                LoggedInProfileView()
            } else {
                LoginView()
            }
        }
        .background(Color(.systemBackground))
    }
}

struct LoginView: View {
    @StateObject private var authService = SupabaseMovieService.shared
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // App Icon/Title
            VStack(spacing: 16) {
                Image(systemName: "film.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                
                Text("reelay")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("Your personal movie diary")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Login Form
            VStack(spacing: 16) {
                TextField("Email", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                
                SecureField("Password", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }
                
                Button(action: handleAuth) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text(isSignUp ? "Sign Up" : "Sign In")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                .disabled(isLoading || email.isEmpty || password.isEmpty)
                
                Button(action: {
                    isSignUp.toggle()
                    errorMessage = nil
                }) {
                    Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal, 40)
            
            Spacer()
        }
        .navigationTitle("Welcome")
        .navigationBarHidden(true)
    }
    
    private func handleAuth() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                if isSignUp {
                    try await authService.signUp(email: email, password: password)
                } else {
                    try await authService.signIn(email: email, password: password)
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
            
            await MainActor.run {
                isLoading = false
            }
        }
    }
}

struct LoggedInProfileView: View {
    @StateObject private var authService = SupabaseMovieService.shared
    @StateObject private var profileService = SupabaseProfileService.shared
    @State private var showingSignOutAlert = false
    @State private var showingSettings = false
    @State private var backdropMovie: Movie?
    @State private var showingAddMovie = false
    @State private var showingAddTelevision = false
    @State private var showingAddAlbum = false
    @State private var showingRandomizer = false
    @Environment(\.colorScheme) private var colorScheme
    
    private var appBackground: Color {
        colorScheme == .dark ? .black : Color(.systemBackground)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0) {
                    // Backdrop Section with overlaid profile info
                    ZStack(alignment: .bottom) {
                        backdropSection
                        profileInfoSection
                    }
                    
                    // Content Section
                    VStack(spacing: 16) {
                        // Navigation Options
                        VStack(spacing: 0) {
                            NavigationLink(destination: MoviesView()) {
                                HStack(spacing: 16) {
                                    Image(systemName: "film")
                                        .font(.title2)
                                        .foregroundColor(.blue)
                                        .frame(width: 30)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Diary")
                                            .font(.headline)
                                            .foregroundColor(.white)
                                        
                                        Text("View your movie diary")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 16)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            NavigationLink(destination: ListsView()) {
                                HStack(spacing: 16) {
                                    Image(systemName: "list.bullet")
                                        .font(.title2)
                                        .foregroundColor(.blue)
                                        .frame(width: 30)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Lists")
                                            .font(.headline)
                                            .foregroundColor(.white)
                                        
                                        Text("Manage your movie lists")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 16)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            NavigationLink(destination: StatisticsView()) {
                                HStack(spacing: 16) {
                                    Image(systemName: "chart.bar")
                                        .font(.title2)
                                        .foregroundColor(.blue)
                                        .frame(width: 30)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Statistics")
                                            .font(.headline)
                                            .foregroundColor(.white)
                                        
                                        Text("Your viewing stats")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 16)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            NavigationLink(destination: AlbumsView()) {
                                HStack(spacing: 16) {
                                    Image(systemName: "music.note")
                                        .font(.title2)
                                        .foregroundColor(.blue)
                                        .frame(width: 30)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Albums")
                                            .font(.headline)
                                            .foregroundColor(.white)
                                        
                                        Text("Manage your music collection")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 16)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .background(Color(.secondarySystemBackground).opacity(0.8))
                        .cornerRadius(12)
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        
                        // Sign Out Button
                        Button(action: {
                            showingSignOutAlert = true
                        }) {
                            Text("Sign Out")
                                .fontWeight(.semibold)
                                .foregroundColor(.red)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color(.secondarySystemBackground).opacity(0.8))
                        .cornerRadius(10)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(appBackground)
                    
                    Spacer(minLength: 100)
                }
            }
            .background(appBackground.ignoresSafeArea())
            .ignoresSafeArea(edges: .top)
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                HStack {
                    Button(action: {
                        showingSettings = true
                    }) {
                        Image(systemName: "gear")
                            .foregroundColor(.white)
                            .fontWeight(.medium)
                    }
                    
                    Button(action: {
                        showingRandomizer = true
                    }) {
                        Image(systemName: "dice")
                            .foregroundColor(.white)
                            .fontWeight(.medium)
                    }
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: {
                        showingAddMovie = true
                    }) {
                        Label("Add Movie", systemImage: "film")
                    }
                    
                    Button(action: {
                        showingAddTelevision = true
                    }) {
                        Label("Add TV Show", systemImage: "tv")
                    }
                    
                    Button(action: {
                        showingAddAlbum = true
                    }) {
                        Label("Add Album", systemImage: "music.note.list")
                    }
                } label: {
                    Image(systemName: "plus")
                        .foregroundColor(.white)
                        .fontWeight(.medium)
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showingAddMovie) {
            AddMoviesView()
        }
        .sheet(isPresented: $showingAddTelevision) {
            AddTelevisionView()
        }
        .sheet(isPresented: $showingAddAlbum) {
            AddAlbumsView()
        }
        .sheet(isPresented: $showingRandomizer) {
            WatchlistRandomizerView()
        }
        .alert("Sign Out", isPresented: $showingSignOutAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Sign Out", role: .destructive) {
                Task {
                    try await authService.signOut()
                }
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
        .task {
            await loadProfileData()
        }
    }
    
    private var backdropSection: some View {
        Group {
            // Backdrop image
            if let backdropMovie = backdropMovie,
               let backdropURL = backdropMovie.backdropURL {
                AsyncImage(url: backdropURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure(_):
                        // Fallback to default gradient when backdrop fails
                        LinearGradient(
                            colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    case .empty:
                        // Loading state
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                    @unknown default:
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                    }
                }
                .frame(height: 400)
                .clipped()
                .overlay(
                    // Enhanced gradient overlay for readability
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.1), 
                            Color.black.opacity(0.3),
                            Color.black.opacity(0.6),
                            Color.black.opacity(0.8)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            } else {
                // Fallback gradient when no backdrop
                LinearGradient(
                    colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: 400)
                .overlay(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.1), 
                            Color.black.opacity(0.3),
                            Color.black.opacity(0.6),
                            Color.black.opacity(0.8)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
    }
    
    private var profileInfoSection: some View {
        VStack(spacing: 12) {
            // Profile Picture (tappable to open Letterboxd)
            Group {
                if let profilePictureUrl = profileService.currentUserProfile?.picture,
                   let url = URL(string: profilePictureUrl) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 120))
                            .foregroundColor(.blue)
                    }
                    .frame(width: 120, height: 120)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 4)
                    )
                    .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 8)
                } else {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 120))
                        .foregroundColor(.blue)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 4)
                        )
                        .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 8)
                }
            }
            .onTapGesture {
                openLetterboxd()
            }
            
            VStack(spacing: 6) {
                Text(profileService.currentUserProfile?.name ?? "Loading...")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .shadow(color: .black, radius: 4, x: 0, y: 2)
                
                Text("I have no idea what I'm talking about.")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
                    .shadow(color: .black, radius: 2, x: 0, y: 1)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .padding(.horizontal, 20)
            }
        }
        .padding(.bottom, 30)
        .frame(maxWidth: .infinity)
    }
    
    private func loadProfileData() async {
        do {
            _ = try await profileService.getCurrentUserProfile()
            
            await MainActor.run {
                Task {
                    let backdropStart = Date()
                    do {
                        backdropMovie = try await profileService.getSelectedBackdropMovie()
                        let backdropDuration = Date().timeIntervalSince(backdropStart)
                        print("🎬 [PROFILEVIEW] Backdrop movie loaded in \(String(format: "%.3f", backdropDuration))s")
                    } catch {
                        backdropMovie = nil
                        print("⚠️ [PROFILEVIEW] Failed to load backdrop movie: \(error)")
                    }
                    
                }
            }
        } catch {
            print("❌ [PROFILEVIEW] Profile load failed: \(error)")
        }
    }
    
    private func openLetterboxd() {
        if let url = URL(string: "letterboxd://") {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            } else {
                // Fallback to App Store if Letterboxd isn't installed
                if let appStoreURL = URL(string: "https://apps.apple.com/app/letterboxd/id1054271011") {
                    UIApplication.shared.open(appStoreURL)
                }
            }
        }
    }
    
}

struct ProfileOptionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.blue)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    ProfileView()
}

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
    
    var body: some View {
        ZStack {
            // Background with movie backdrop
            if let backdropMovie = backdropMovie,
               let backdropURL = backdropMovie.backdropURL {
                AsyncImage(url: backdropURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .ignoresSafeArea()
                 } placeholder: {
                    Color(.systemBackground)
                        .ignoresSafeArea()
                }
                .overlay(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.black.opacity(0.7),
                            Color.black.opacity(0.3),
                            Color.black.opacity(0.7)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                )
            } else {
                Color(.systemBackground)
                    .ignoresSafeArea()
            }
            
            ScrollView {
                VStack(spacing: 24) {
                    // User Info with Profile Picture
                    VStack(spacing: 16) {
                        // Profile Picture (from Google, non-interactive)
                        Group {
                            if let profilePictureUrl = profileService.currentUserProfile?.picture,
                               let url = URL(string: profilePictureUrl) {
                                AsyncImage(url: url) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Image(systemName: "person.circle.fill")
                                        .font(.system(size: 100))
                                        .foregroundColor(.blue)
                                }
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: 3)
                                )
                                .shadow(radius: 10)
                            } else {
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 100))
                                    .foregroundColor(.blue)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white, lineWidth: 3)
                                    )
                                    .shadow(radius: 10)
                            }
                        }
                        
                        Text(profileService.currentUserProfile?.name ?? "Unknown User")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .shadow(radius: 2)
                        
                        Text("Movie enthusiast")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .shadow(radius: 2)
                    }
                    .padding(.top, 40)
                    
                    // Profile Options
                    VStack(spacing: 0) {
                        ProfileOptionRow(
                            icon: "film",
                            title: "Movies Watched",
                            subtitle: "View your diary",
                            action: {}
                        )
                        
                        ProfileOptionRow(
                            icon: "star",
                            title: "Ratings & Reviews",
                            subtitle: "Manage your reviews",
                            action: {}
                        )
                        
                        ProfileOptionRow(
                            icon: "chart.bar",
                            title: "Statistics",
                            subtitle: "Your viewing stats",
                            action: {}
                        )
                    }
                    .background(Color(.secondarySystemBackground).opacity(0.6))
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                    
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
                    .background(Color(.secondarySystemBackground).opacity(0.6))
                    .cornerRadius(10)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showingSettings = true
                }) {
                        Image(systemName: "gear")
                            .foregroundColor(.primary)
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
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
    
    private func loadProfileData() async {
        do {
            _ = try await profileService.getCurrentUserProfile()
            backdropMovie = try await profileService.getSelectedBackdropMovie()
        } catch {
            // Silently handle error
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
//
//  SupabaseProfileService.swift
//  reelay2
//
//  Created by Humza Khalil on 8/9/25.
//

import Foundation
import Supabase
import Combine

class SupabaseProfileService: ObservableObject {
    static let shared = SupabaseProfileService()
    
    private let supabase: SupabaseClient
    @Published var currentUserProfile: UserProfile?
    
    private init() {
        guard let supabaseURL = URL(string: Config.supabaseURL) else {
            fatalError("Missing Supabase URL configuration")
        }
        
        let supabaseKey = Config.supabaseAnonKey
        
        self.supabase = SupabaseClient(
            supabaseURL: supabaseURL,
            supabaseKey: supabaseKey
        )
    }
    
    // MARK: - Profile Operations
    
    /// Get the current user's profile from the users table
    @MainActor
    func getCurrentUserProfile() async throws -> UserProfile? {
        let session = try await supabase.auth.session
        let userEmail = session.user.email ?? ""
        
        let response = try await supabase
            .from("users")
            .select()
            .eq("email", value: userEmail)
            .limit(1)
            .execute()
        
        let profiles: [UserProfile] = try JSONDecoder().decode([UserProfile].self, from: response.data)
        let profile = profiles.first
        
        currentUserProfile = profile
        return profile
    }
    
    /// Update the current user's backdrop selection
    @MainActor
    func updateUserProfile(_ profileData: UpdateUserProfileRequest) async throws -> UserProfile {
        let session = try await supabase.auth.session
        let userEmail = session.user.email ?? ""
        
        let response = try await supabase
            .from("users")
            .update(profileData)
            .eq("email", value: userEmail)
            .select()
            .execute()
        
        let profiles: [UserProfile] = try JSONDecoder().decode([UserProfile].self, from: response.data)
        guard let profile = profiles.first else {
            throw UserProfileError.updateFailed(NSError(domain: "ProfileService", code: 0, userInfo: [NSLocalizedDescriptionKey: "No profile returned"]))
        }
        
        currentUserProfile = profile
        return profile
    }
    
    /// Get movies for backdrop selection (user's logged movies with backdrop images)
    nonisolated func getMoviesForBackdropSelection() async throws -> [Movie] {
        let response = try await supabase
            .from("diary")
            .select()
            .not("backdrop_path", operator: .is, value: AnyJSON.null)
            .order("watched_date", ascending: false)
            .limit(3000)
            .execute()
        
        let movies: [Movie] = try JSONDecoder().decode([Movie].self, from: response.data)
        return movies
    }
    
    /// Get the selected backdrop movie for the current user
    @MainActor
    func getSelectedBackdropMovie() async throws -> Movie? {
        let profile: UserProfile?
        if let currentProfile = currentUserProfile {
            profile = currentProfile
        } else {
            profile = try await getCurrentUserProfile()
        }
        
        guard let validProfile = profile,
              let movieId = validProfile.selected_backdrop_movie_id else {
            return nil
        }
        
        let response = try await supabase
            .from("diary")
            .select()
            .eq("id", value: movieId)
            .limit(1)
            .execute()
        
        let movies: [Movie] = try JSONDecoder().decode([Movie].self, from: response.data)
        return movies.first
    }
}
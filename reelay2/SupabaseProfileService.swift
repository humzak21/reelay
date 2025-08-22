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
        
        print("Fetching profile for email: \(userEmail)")
        print("User ID from auth: \(session.user.id)")
        print("Auth user role: \(session.user.role ?? "nil")")
        print("Auth user aud: \(session.user.aud)")
        print("Full auth user: \(session.user)")
        
        // Test basic query to see if RLS allows anything
        let testResponse = try await supabase
            .from("users")
            .select("*")
            .execute()
        
        print("Basic users query: \(String(data: testResponse.data, encoding: .utf8) ?? "nil")")
        
        // First try querying by email
        let response = try await supabase
            .from("users")
            .select()
            .eq("email", value: userEmail)
            .limit(1)
            .execute()
        
        print("Raw response data (by email): \(String(data: response.data, encoding: .utf8) ?? "nil")")
        
        var profiles: [UserProfile] = try JSONDecoder().decode([UserProfile].self, from: response.data)
        var profile = profiles.first
        
        // If not found by email, try by auth user ID
        if profile == nil {
            print("No profile found by email, trying by auth user ID: \(session.user.id)")
            let idResponse = try await supabase
                .from("users")
                .select()
                .eq("id", value: session.user.id.uuidString)
                .limit(1)
                .execute()
            
            print("Raw response data (by ID): \(String(data: idResponse.data, encoding: .utf8) ?? "nil")")
            
            let idProfiles: [UserProfile] = try JSONDecoder().decode([UserProfile].self, from: idResponse.data)
            profile = idProfiles.first
        }
        
        print("Decoded profile: \(profile?.name ?? "nil")")
        
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
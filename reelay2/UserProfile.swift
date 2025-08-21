//
//  UserProfile.swift
//  reelay2
//
//  Created by Humza Khalil on 8/9/25.
//

import Foundation

struct UserProfile: Codable, Identifiable, @unchecked Sendable {
    let id: String // UUID from users table
    let google_id: String
    let email: String
    let name: String
    let picture: String? // Profile picture from Google OAuth (unchangeable)
    let selected_backdrop_movie_id: Int? // References a movie ID from the diary table
    let created_at: String?
    let last_login: String?
    let updated_at: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case google_id
        case email
        case name
        case picture
        case selected_backdrop_movie_id
        case created_at
        case last_login
        case updated_at
    }
}

struct UpdateUserProfileRequest: Codable, @unchecked Sendable {
    let selected_backdrop_movie_id: Int?
}

enum UserProfileError: LocalizedError {
    case profileNotFound
    case updateFailed(Error)
    case fetchFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .profileNotFound:
            return "User profile not found"
        case .updateFailed(let error):
            return "Failed to update profile: \(error.localizedDescription)"
        case .fetchFailed(let error):
            return "Failed to fetch profile: \(error.localizedDescription)"
        }
    }
}
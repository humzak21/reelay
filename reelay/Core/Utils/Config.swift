//
//  Config.swift
//  reelay
//
//  Created by Humza Khalil on 6/11/25.
//

import Foundation

struct Config {
    // Use proper environment variable keys, with fallback to hardcoded values for development
    static let supabaseURL = Bundle.main.infoDictionary?["SUPABASE_URL"] as? String ?? "https://urwrwlkxmrwbdfpyccya.supabase.co"
    static let supabaseAnonKey = Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as? String ?? "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVyd3J3bGt4bXJ3YmRmcHljY3lhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDg0ODE5NjksImV4cCI6MjA2NDA1Nzk2OX0.GVvawbn8fDbvcuBqTvGLWsbQx2pdQba_iiAHT8sSSWg"
    static let tmdbAPIKey = Bundle.main.infoDictionary?["TMDB_API_KEY"] as? String ?? "bfc678838a493cb4b5a00ffddaed0eef"
    static let backendBaseURL = Bundle.main.infoDictionary?["BACKEND_BASE_URL"] as? String ?? "https://movietracker-production-87d4.up.railway.app"
    
    static var apiBaseURL: String {
        return "\(backendBaseURL)/api"
    }
}

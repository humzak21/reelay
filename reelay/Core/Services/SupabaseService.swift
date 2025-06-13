//
//  SupabaseService.swift
//  reelay
//
//  Created by Humza Khalil on 6/11/25.
//
import Supabase
import Foundation

class SupabaseService: ObservableObject {
    static let shared = SupabaseService()
    
    private let client: SupabaseClient  
    
    private init() {
        guard let supabaseURL = URL(string: Config.supabaseURL),
              !Config.supabaseAnonKey.isEmpty else {
            fatalError("Supabase configuration missing")
        }
        
        self.client = SupabaseClient(
            supabaseURL: supabaseURL,
            supabaseKey: Config.supabaseAnonKey
        )
    }
    
    var database: SupabaseClient {
        return client
    }
}


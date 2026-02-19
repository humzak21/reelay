//
//  SupabaseTheaterVisitService.swift
//  reelay2
//
//  Service for theater visit planning CRUD operations
//

import Foundation
import Supabase
import Combine

class SupabaseTheaterVisitService: ObservableObject {
    static let shared = SupabaseTheaterVisitService()
    
    // Use the shared authenticated client from SupabaseMovieService
    private var supabase: SupabaseClient {
        return SupabaseMovieService.shared.client
    }
    
    @Published var isLoggedIn = false
    @Published var currentUser: User?
    
    private init() {
        Task {
            await checkAuthState()
        }
    }
    
    // MARK: - Authentication
    
    @MainActor
    private func checkAuthState() async {
        do {
            let session = try await supabase.auth.session
            currentUser = session.user
            isLoggedIn = true
        } catch {
            currentUser = nil
            isLoggedIn = false
        }
    }
    
    // MARK: - CRUD Operations
    
    /// Get all visits within a date range
    nonisolated func getVisits(from startDate: Date, to endDate: Date) async throws -> [TheaterVisit] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        
        let startString = formatter.string(from: startDate)
        let endString = formatter.string(from: endDate)
        
        let response = try await supabase
            .from("theater_visits")
            .select()
            .gte("visit_date", value: startString)
            .lte("visit_date", value: endString)
            .order("visit_date", ascending: true)
            .order("showtime", ascending: true)
            .execute()
        
        if response.data.isEmpty {
            return []
        }
        
        let visits: [TheaterVisit] = try JSONDecoder().decode([TheaterVisit].self, from: response.data)
        return visits
    }
    
    /// Get visits for a specific date
    nonisolated func getVisitsForDate(_ date: Date) async throws -> [TheaterVisit] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let dateString = formatter.string(from: date)
        
        let response = try await supabase
            .from("theater_visits")
            .select()
            .eq("visit_date", value: dateString)
            .order("showtime", ascending: true)
            .execute()
        
        if response.data.isEmpty {
            return []
        }
        
        let visits: [TheaterVisit] = try JSONDecoder().decode([TheaterVisit].self, from: response.data)
        return visits
    }
    
    /// Get all visits (for loading into DataManager)
    nonisolated func getAllVisits() async throws -> [TheaterVisit] {
        let response = try await supabase
            .from("theater_visits")
            .select()
            .order("visit_date", ascending: true)
            .order("showtime", ascending: true)
            .execute()
        
        if response.data.isEmpty {
            return []
        }
        
        let visits: [TheaterVisit] = try JSONDecoder().decode([TheaterVisit].self, from: response.data)
        return visits
    }
    
    /// Get upcoming (future) visits only
    nonisolated func getUpcomingVisits() async throws -> [TheaterVisit] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let todayString = formatter.string(from: Date())
        
        let response = try await supabase
            .from("theater_visits")
            .select()
            .gte("visit_date", value: todayString)
            .eq("is_completed", value: false)
            .order("visit_date", ascending: true)
            .order("showtime", ascending: true)
            .execute()
        
        if response.data.isEmpty {
            return []
        }
        
        let visits: [TheaterVisit] = try JSONDecoder().decode([TheaterVisit].self, from: response.data)
        return visits
    }
    
    /// Add a new theater visit
    nonisolated func addVisit(_ visitData: AddTheaterVisitRequest) async throws -> TheaterVisit {
        let response = try await supabase
            .from("theater_visits")
            .insert(visitData)
            .select()
            .execute()
        
        let visits: [TheaterVisit] = try JSONDecoder().decode([TheaterVisit].self, from: response.data)
        guard let visit = visits.first else {
            throw TheaterVisitError.noVisitReturned
        }
        return visit
    }
    
    /// Update an existing theater visit
    nonisolated func updateVisit(id: Int, with data: UpdateTheaterVisitRequest) async throws -> TheaterVisit {
        let response = try await supabase
            .from("theater_visits")
            .update(data)
            .eq("id", value: id)
            .select()
            .execute()
        
        let visits: [TheaterVisit] = try JSONDecoder().decode([TheaterVisit].self, from: response.data)
        guard let visit = visits.first else {
            throw TheaterVisitError.noVisitReturned
        }
        return visit
    }
    
    /// Delete a theater visit
    nonisolated func deleteVisit(id: Int) async throws {
        try await supabase
            .from("theater_visits")
            .delete()
            .eq("id", value: id)
            .execute()
    }
    
    /// Toggle visit completion status
    nonisolated func toggleCompleted(id: Int, completed: Bool) async throws -> TheaterVisit {
        let data = UpdateTheaterVisitRequest(
            tmdb_id: nil, title: nil, poster_url: nil, release_year: nil,
            visit_date: nil, showtime: nil, location_name: nil,
            location_latitude: nil, location_longitude: nil,
            notes: nil, is_completed: completed
        )
        return try await updateVisit(id: id, with: data)
    }
}

// MARK: - Errors

enum TheaterVisitError: LocalizedError {
    case noVisitReturned
    case visitNotFound
    case invalidData
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .noVisitReturned:
            return "No visit data returned from server"
        case .visitNotFound:
            return "Theater visit not found"
        case .invalidData:
            return "Invalid visit data"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

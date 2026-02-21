//
//  SupabaseLocationService.swift
//  reelay2
//

import Foundation
import Supabase

class SupabaseLocationService {
    static let shared = SupabaseLocationService()

    private var supabase: SupabaseClient {
        SupabaseMovieService.shared.client
    }

    private let locationSelectColumns = "id,user_id,display_name,formatted_address,normalized_key,latitude,longitude,city,admin_area,country,postal_code,location_group_id,location_groups(name),created_at,updated_at"

    private init() {}

    nonisolated func getLocationGroups() async throws -> [LocationGroup] {
        let response = try await supabase
            .from("location_groups")
            .select()
            .order("name", ascending: true)
            .execute()

        if response.data.isEmpty {
            return []
        }

        return try JSONDecoder().decode([LocationGroup].self, from: response.data)
    }

    nonisolated func getOrCreateLocationGroup(named name: String) async throws -> LocationGroup {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw LocationServiceError.invalidGroupName
        }

        let existing = try await getLocationGroups()
        if let match = existing.first(where: { $0.name.lowercased() == trimmed.lowercased() }) {
            return match
        }

        do {
            let response = try await supabase
                .from("location_groups")
                .insert(["name": trimmed])
                .select()
                .single()
                .execute()

            return try JSONDecoder().decode(LocationGroup.self, from: response.data)
        } catch {
            let refreshed = try await getLocationGroups()
            if let match = refreshed.first(where: { $0.name.lowercased() == trimmed.lowercased() }) {
                return match
            }
            throw error
        }
    }

    nonisolated func getLocation(id: Int) async throws -> MovieLocation? {
        let response = try await supabase
            .from("locations")
            .select(locationSelectColumns)
            .eq("id", value: id)
            .limit(1)
            .execute()

        if response.data.isEmpty {
            return nil
        }

        let locations = try JSONDecoder().decode([MovieLocation].self, from: response.data)
        return locations.first
    }

    nonisolated func findLocation(byNormalizedKey key: String) async throws -> MovieLocation? {
        let response = try await supabase
            .from("locations")
            .select(locationSelectColumns)
            .eq("normalized_key", value: key)
            .limit(1)
            .execute()

        if response.data.isEmpty {
            return nil
        }

        let locations = try JSONDecoder().decode([MovieLocation].self, from: response.data)
        return locations.first
    }

    nonisolated func createLocation(_ request: AddLocationRequest) async throws -> MovieLocation {
        let response = try await supabase
            .from("locations")
            .insert(request)
            .select(locationSelectColumns)
            .single()
            .execute()

        return try JSONDecoder().decode(MovieLocation.self, from: response.data)
    }

    nonisolated func updateLocationGroup(locationId: Int, groupId: Int?) async throws -> MovieLocation {
        let payload: [String: Int?] = ["location_group_id": groupId]
        let response = try await supabase
            .from("locations")
            .update(payload)
            .eq("id", value: locationId)
            .select(locationSelectColumns)
            .single()
            .execute()

        return try JSONDecoder().decode(MovieLocation.self, from: response.data)
    }

    static func normalizedKey(
        displayName: String,
        formattedAddress: String?,
        latitude: Double?,
        longitude: Double?
    ) -> String {
        let sanitizedName = sanitize(displayName)
        let sanitizedAddress = sanitize(formattedAddress ?? "")
        let latKey = latitude.map { String(format: "%.5f", $0) } ?? "na"
        let lonKey = longitude.map { String(format: "%.5f", $0) } ?? "na"
        return "\(sanitizedName)|\(sanitizedAddress)|\(latKey)|\(lonKey)"
    }

    private static func sanitize(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }
}

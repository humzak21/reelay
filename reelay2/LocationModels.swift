//
//  LocationModels.swift
//  reelay2
//

import Foundation

struct LocationGroup: Codable, Identifiable, Sendable {
    let id: Int
    let user_id: String?
    let name: String
    let created_at: String?
    let updated_at: String?
}

struct MovieLocation: Decodable, Identifiable, Sendable {
    let id: Int
    let user_id: String?
    let display_name: String
    let formatted_address: String?
    let normalized_key: String
    let latitude: Double?
    let longitude: Double?
    let city: String?
    let admin_area: String?
    let country: String?
    let postal_code: String?
    let location_group_id: Int?
    let location_group_name: String?
    let created_at: String?
    let updated_at: String?

    enum CodingKeys: String, CodingKey {
        case id
        case user_id
        case display_name
        case formatted_address
        case normalized_key
        case latitude
        case longitude
        case city
        case admin_area
        case country
        case postal_code
        case location_group_id
        case location_group_name
        case created_at
        case updated_at
        case location_groups
    }

    enum GroupCodingKeys: String, CodingKey {
        case name
    }

    struct GroupNameWrapper: Decodable {
        let name: String?
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        user_id = try container.decodeIfPresent(String.self, forKey: .user_id)
        display_name = try container.decode(String.self, forKey: .display_name)
        formatted_address = try container.decodeIfPresent(String.self, forKey: .formatted_address)
        normalized_key = try container.decode(String.self, forKey: .normalized_key)
        latitude = try container.decodeIfPresent(Double.self, forKey: .latitude)
        longitude = try container.decodeIfPresent(Double.self, forKey: .longitude)
        city = try container.decodeIfPresent(String.self, forKey: .city)
        admin_area = try container.decodeIfPresent(String.self, forKey: .admin_area)
        country = try container.decodeIfPresent(String.self, forKey: .country)
        postal_code = try container.decodeIfPresent(String.self, forKey: .postal_code)
        location_group_id = try container.decodeIfPresent(Int.self, forKey: .location_group_id)
        created_at = try container.decodeIfPresent(String.self, forKey: .created_at)
        updated_at = try container.decodeIfPresent(String.self, forKey: .updated_at)

        if let explicit = try container.decodeIfPresent(String.self, forKey: .location_group_name) {
            location_group_name = explicit
        } else if let nested = try? container.nestedContainer(keyedBy: GroupCodingKeys.self, forKey: .location_groups) {
            location_group_name = try nested.decodeIfPresent(String.self, forKey: .name)
        } else if let nestedArray = try? container.decodeIfPresent([GroupNameWrapper].self, forKey: .location_groups) {
            location_group_name = nestedArray.first?.name
        } else {
            location_group_name = nil
        }
    }
}

struct AddLocationRequest: Codable, Sendable {
    let display_name: String
    let formatted_address: String?
    let normalized_key: String
    let latitude: Double?
    let longitude: Double?
    let city: String?
    let admin_area: String?
    let country: String?
    let postal_code: String?
    let location_group_id: Int?
}

enum LocationServiceError: LocalizedError {
    case invalidGroupName
    case invalidLocation

    var errorDescription: String? {
        switch self {
        case .invalidGroupName:
            return "Location group name cannot be empty."
        case .invalidLocation:
            return "Selected location is incomplete."
        }
    }
}

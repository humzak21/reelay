//
//  ListSortingModels.swift
//  reelay2
//
//  Created by Humza Khalil on 8/14/25.
//

import Foundation

extension String {
    func titleForSorting() -> String {
        let trimmed = self.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased().hasPrefix("the ") && trimmed.count > 4 {
            return String(trimmed.dropFirst(4))
        }
        return trimmed
    }
}

enum ListSortOption: String, CaseIterable, Identifiable {
    case sortOrder = "sortOrder"
    case name = "name"
    case nameDesc = "nameDesc"
    case releaseDate = "releaseDate"
    case releaseDateDesc = "releaseDateDesc"
    case releaseYear = "releaseYear"
    case releaseYearDesc = "releaseYearDesc"
    case addedDate = "addedDate"
    case addedDateDesc = "addedDateDesc"
    case watchedStatus = "watchedStatus"
    case unwatchedStatus = "unwatchedStatus"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .sortOrder:
            return "List Order"
        case .name:
            return "Name (A-Z)"
        case .nameDesc:
            return "Name (Z-A)"
        case .releaseDate:
            return "Release Date (Newest)"
        case .releaseDateDesc:
            return "Release Date (Oldest)"
        case .releaseYear:
            return "Release Year (Newest)"
        case .releaseYearDesc:
            return "Release Year (Oldest)"
        case .addedDate:
            return "Date Added (Newest)"
        case .addedDateDesc:
            return "Date Added (Oldest)"
        case .watchedStatus:
            return "Watched First"
        case .unwatchedStatus:
            return "Unwatched First"
        }
    }
    
    var systemImage: String {
        switch self {
        case .sortOrder:
            return "list.number"
        case .name, .nameDesc:
            return "textformat"
        case .releaseDate, .releaseDateDesc:
            return "calendar"
        case .releaseYear, .releaseYearDesc:
            return "calendar.badge.clock"
        case .addedDate, .addedDateDesc:
            return "clock"
        case .watchedStatus, .unwatchedStatus:
            return "eye"
        }
    }
}

extension Array where Element == ListItem {
    func sorted(by option: ListSortOption, watchedTmdbIds: Set<Int> = []) -> [ListItem] {
        switch option {
        case .sortOrder:
            return self.sorted { $0.sortOrder < $1.sortOrder }
        case .name:
            return self.sorted { $0.movieTitle.titleForSorting().localizedCaseInsensitiveCompare($1.movieTitle.titleForSorting()) == .orderedAscending }
        case .nameDesc:
            return self.sorted { $0.movieTitle.titleForSorting().localizedCaseInsensitiveCompare($1.movieTitle.titleForSorting()) == .orderedDescending }
        case .releaseDate:
            return self.sorted { item1, item2 in
                guard let date1 = item1.movieReleaseDate, let date2 = item2.movieReleaseDate else {
                    return item1.movieReleaseDate != nil
                }
                return date1 > date2
            }
        case .releaseDateDesc:
            return self.sorted { item1, item2 in
                guard let date1 = item1.movieReleaseDate, let date2 = item2.movieReleaseDate else {
                    return item1.movieReleaseDate != nil
                }
                return date1 < date2
            }
        case .releaseYear:
            return self.sorted { item1, item2 in
                guard let year1 = item1.movieYear, let year2 = item2.movieYear else {
                    return item1.movieYear != nil
                }
                return year1 > year2
            }
        case .releaseYearDesc:
            return self.sorted { item1, item2 in
                guard let year1 = item1.movieYear, let year2 = item2.movieYear else {
                    return item1.movieYear != nil
                }
                return year1 < year2
            }
        case .addedDate:
            return self.sorted { $0.addedAt > $1.addedAt }
        case .addedDateDesc:
            return self.sorted { $0.addedAt < $1.addedAt }
        case .watchedStatus:
            return self.sorted { item1, item2 in
                let watched1 = watchedTmdbIds.contains(item1.tmdbId)
                let watched2 = watchedTmdbIds.contains(item2.tmdbId)
                if watched1 && !watched2 { return true }
                if !watched1 && watched2 { return false }
                return item1.movieTitle.titleForSorting().localizedCaseInsensitiveCompare(item2.movieTitle.titleForSorting()) == .orderedAscending
            }
        case .unwatchedStatus:
            return self.sorted { item1, item2 in
                let watched1 = watchedTmdbIds.contains(item1.tmdbId)
                let watched2 = watchedTmdbIds.contains(item2.tmdbId)
                if !watched1 && watched2 { return true }
                if watched1 && !watched2 { return false }
                return item1.movieTitle.titleForSorting().localizedCaseInsensitiveCompare(item2.movieTitle.titleForSorting()) == .orderedAscending
            }
        }
    }
}
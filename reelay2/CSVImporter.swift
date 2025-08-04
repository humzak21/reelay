//
//  CSVImporter.swift
//  reelay
//
//  Created by Humza Khalil on 6/11/25.
//

import Foundation

// MARK: - Models for CSV Import

struct ListEntry: Identifiable {
    let id = UUID()
    let position: Int
    let name: String
    let year: Int?
    let url: String?
    let description: String?
    let tags: [String]?
    let dateAdded: Date?
}

class CSVImporter {
    static let shared = CSVImporter()
    
    private init() {}
    
    // MARK: - CSV Import Methods
    
    func importCSVFile(from url: URL) throws -> String {
        guard url.startAccessingSecurityScopedResource() else {
            throw CSVImportError.accessDenied
        }
        
        defer {
            url.stopAccessingSecurityScopedResource()
        }
        
        let csvData = try String(contentsOf: url, encoding: .utf8)
        return csvData
    }
    
    func parseCSVString(_ csvString: String) throws -> [CSVRow] {
        let lines = csvString.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        
        guard lines.count > 1 else {
            throw CSVImportError.emptyFile
        }
        
        // Check if this is a Letterboxd export format
        if lines.first?.contains("Letterboxd list export") == true {
            return try parseLetterboxdFormat(lines)
        } else {
            return try parseStandardCSVFormat(lines)
        }
    }
    
    private func parseLetterboxdFormat(_ lines: [String]) throws -> [CSVRow] {
        var movieSectionStartIndex = -1
        var movieHeaders: [String] = []
        
        // Find the movie section (starts with "Position,Name,Year,URL,Description")
        for (index, line) in lines.enumerated() {
            if line.lowercased().starts(with: "position,") {
                movieSectionStartIndex = index
                movieHeaders = parseCSVLine(line)
                break
            }
        }
        
        guard movieSectionStartIndex != -1 else {
            throw CSVImportError.invalidFormat
        }
        
        var rows: [CSVRow] = []
        let movieDataLines = Array(lines.dropFirst(movieSectionStartIndex + 1)).filter { !$0.isEmpty }
        
        // Parse movie data rows
        for (index, line) in movieDataLines.enumerated() {
            let values = parseCSVLine(line)
            
            // Create dictionary mapping headers to values
            var rowData: [String: String] = [:]
            for (i, header) in movieHeaders.enumerated() {
                let cleanHeader = header.trimmingCharacters(in: .whitespacesAndNewlines)
                if i < values.count {
                    rowData[cleanHeader] = values[i].trimmingCharacters(in: .whitespacesAndNewlines)
                } else {
                    rowData[cleanHeader] = ""
                }
            }
            
            let csvRow = CSVRow(
                rowNumber: movieSectionStartIndex + index + 2,
                data: rowData
            )
            
            rows.append(csvRow)
        }
        
        return rows
    }
    
    private func parseStandardCSVFormat(_ lines: [String]) throws -> [CSVRow] {
        let filteredLines = lines.filter { !$0.isEmpty }
        
        guard filteredLines.count > 1 else {
            throw CSVImportError.emptyFile
        }
        
        // Parse header
        let headerLine = filteredLines[0]
        let headers = parseCSVLine(headerLine)
        
        var rows: [CSVRow] = []
        
        // Parse data rows
        for (index, line) in filteredLines.dropFirst().enumerated() {
            let values = parseCSVLine(line)
            
            // Create dictionary mapping headers to values
            var rowData: [String: String] = [:]
            for (i, header) in headers.enumerated() {
                let cleanHeader = header.trimmingCharacters(in: .whitespacesAndNewlines)
                if i < values.count {
                    rowData[cleanHeader] = values[i].trimmingCharacters(in: .whitespacesAndNewlines)
                } else {
                    rowData[cleanHeader] = ""
                }
            }
            
            let csvRow = CSVRow(
                rowNumber: index + 2, // +2 because we skip header and arrays are 0-indexed
                data: rowData
            )
            
            rows.append(csvRow)
        }
        
        return rows
    }
    
    private func parseCSVLine(_ line: String) -> [String] {
        var values: [String] = []
        var currentValue = ""
        var insideQuotes = false
        var i = line.startIndex
        
        while i < line.endIndex {
            let char = line[i]
            
            if char == "\"" {
                if insideQuotes {
                    // Check if this is an escaped quote
                    let nextIndex = line.index(after: i)
                    if nextIndex < line.endIndex && line[nextIndex] == "\"" {
                        currentValue.append("\"")
                        i = line.index(after: nextIndex)
                        continue
                    } else {
                        insideQuotes = false
                    }
                } else {
                    insideQuotes = true
                }
            } else if char == "," && !insideQuotes {
                values.append(currentValue)
                currentValue = ""
            } else {
                currentValue.append(char)
            }
            
            i = line.index(after: i)
        }
        
        // Add the last value
        values.append(currentValue)
        
        return values
    }
    
    func convertToListEntries(_ csvRows: [CSVRow]) -> [ListEntry] {
        return csvRows.compactMap { row in
            convertRowToListEntry(row)
        }
    }
    
    private func convertRowToListEntry(_ row: CSVRow) -> ListEntry? {
        // Try to extract required fields from the row
        guard let name = extractMovieName(from: row) else {
            print("⚠️ Skipping row \(row.rowNumber): No movie name found")
            return nil
        }
        
        let position = extractPosition(from: row) ?? row.rowNumber - 1
        let year = extractYear(from: row)
        let url = extractURL(from: row)
        let description = extractDescription(from: row)
        let tags = extractTags(from: row)
        let dateAdded = extractDate(from: row)
        
        return ListEntry(
            position: position,
            name: name,
            year: year,
            url: url,
            description: description,
            tags: tags,
            dateAdded: dateAdded
        )
    }
    
    // MARK: - Field Extraction Methods
    
    private func extractMovieName(from row: CSVRow) -> String? {
        // Try various common column names for movie titles
        let possibleKeys = ["name", "title", "movie", "film", "movie_name", "movie_title"]
        
        for key in possibleKeys {
            if let value = findValueForKey(key, in: row.data), !value.isEmpty {
                return value
            }
        }
        
        return nil
    }
    
    private func extractPosition(from row: CSVRow) -> Int? {
        let possibleKeys = ["position", "pos", "rank", "order", "#"]
        
        for key in possibleKeys {
            if let value = findValueForKey(key, in: row.data),
               let intValue = Int(value) {
                return intValue
            }
        }
        
        return nil
    }
    
    private func extractYear(from row: CSVRow) -> Int? {
        let possibleKeys = ["year", "release_year", "date", "release_date"]
        
        for key in possibleKeys {
            if let value = findValueForKey(key, in: row.data) {
                // Try to extract year from various formats
                if let year = Int(value) {
                    return year
                } else if value.count >= 4 {
                    // Try to extract year from date string (e.g., "2023-05-15" -> 2023)
                    let yearString = String(value.prefix(4))
                    if let year = Int(yearString) {
                        return year
                    }
                }
            }
        }
        
        return nil
    }
    
    private func extractURL(from row: CSVRow) -> String? {
        let possibleKeys = ["url", "link", "imdb", "tmdb", "letterboxd", "web_url"]
        
        for key in possibleKeys {
            if let value = findValueForKey(key, in: row.data), !value.isEmpty {
                return value
            }
        }
        
        return nil
    }
    
    private func extractDescription(from row: CSVRow) -> String? {
        let possibleKeys = ["description", "desc", "notes", "comment", "review"]
        
        for key in possibleKeys {
            if let value = findValueForKey(key, in: row.data), !value.isEmpty {
                return value
            }
        }
        
        return nil
    }
    
    private func extractTags(from row: CSVRow) -> [String]? {
        let possibleKeys = ["tags", "genres", "categories", "labels"]
        
        for key in possibleKeys {
            if let value = findValueForKey(key, in: row.data), !value.isEmpty {
                let tags = value.split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                
                return tags.isEmpty ? nil : tags
            }
        }
        
        return nil
    }
    
    private func extractDate(from row: CSVRow) -> Date? {
        let possibleKeys = ["date", "date_added", "watch_date", "created_at", "added_on"]
        
        let formatters = [
            DateFormatter.iso8601,
            DateFormatter.yyyyMMdd,
            DateFormatter.ddMMMyyyy,
            DateFormatter.MMddyyyy
        ]
        
        for key in possibleKeys {
            if let value = findValueForKey(key, in: row.data), !value.isEmpty {
                for formatter in formatters {
                    if let date = formatter.date(from: value) {
                        return date
                    }
                }
            }
        }
        
        return nil
    }
    
    private func findValueForKey(_ key: String, in data: [String: String]) -> String? {
        let lowercaseKey = key.lowercased()
        
        // First try exact match
        if let value = data[lowercaseKey] {
            return value
        }
        
        // Then try case-insensitive search
        for (dataKey, dataValue) in data {
            if dataKey.lowercased() == lowercaseKey {
                return dataValue
            }
        }
        
        // Finally try partial matches
        for (dataKey, dataValue) in data {
            if dataKey.lowercased().contains(lowercaseKey) || lowercaseKey.contains(dataKey.lowercased()) {
                return dataValue
            }
        }
        
        return nil
    }
}

// MARK: - Supporting Types

struct CSVRow {
    let rowNumber: Int
    let data: [String: String]
}

enum CSVImportError: LocalizedError {
    case accessDenied
    case emptyFile
    case invalidFormat
    case encodingError
    
    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Access to file was denied"
        case .emptyFile:
            return "The CSV file is empty or contains no data"
        case .invalidFormat:
            return "The CSV file format is invalid"
        case .encodingError:
            return "Unable to read the file encoding"
        }
    }
}

// MARK: - DateFormatter Extensions

extension DateFormatter {
    static let iso8601: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    
    static let yyyyMMdd: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    
    static let ddMMMyyyy: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd-MMM-yyyy"
        return formatter
    }()
    
    static let MMddyyyy: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yyyy"
        return formatter
    }()
} 
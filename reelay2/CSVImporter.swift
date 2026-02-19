//
//  CSVImporter.swift
//  reelay
//
//  Created by Humza Khalil on 6/11/25.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers
import Auth

// MARK: - Models for CSV Import

struct SearchStrategy {
    let query: String
    let type: SearchType
    let priority: Int
    
    enum SearchType {
        case exactWithYear
        case exact
        case normalizedWithYear
        case normalized
        case keywordsWithYear
        case keywords
    }
}

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
                // Return movie title as-is from CSV, no cleaning
                return value.trimmingCharacters(in: .whitespacesAndNewlines)
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

// MARK: - CSV Import View

struct CSVImportView: View {
    @Environment(\.dismiss) private var dismiss
    private let dataManager = DataManager.shared
    private let tmdbService = TMDBService.shared
    
    @State private var showingFilePicker = false
    @State private var selectedFileURL: URL?
    @State private var importedEntries: [ListEntry] = []
    @State private var listName = ""
    @State private var listDescription = ""
    @State private var isProcessing = false
    @State private var isImporting = false
    @State private var errorMessage: String?
    @State private var importProgress = 0.0
    @State private var currentlyProcessing = ""
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                if importedEntries.isEmpty {
                    initialView
                } else {
                    importPreviewView
                }
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            #if os(macOS)
            .background(Color(NSColor.windowBackgroundColor))
            #else
            .background(Color(.systemGroupedBackground))
            #endif
            .navigationTitle("Import CSV")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") {
                        dismiss()
                    }
                }

                if !importedEntries.isEmpty {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Import", systemImage: "checkmark") {
                            Task {
                                await importList()
                            }
                        }
                        .disabled(listName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isImporting)
                    }
                }
            }
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: [UTType.commaSeparatedText, UTType.plainText],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
        }
        #if os(macOS)
        .background(Color(NSColor.windowBackgroundColor))
        #else
        .background(Color(.systemGroupedBackground))
        .toolbarBackground(Color(.systemGroupedBackground), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        #endif
    }

    @ViewBuilder
    private var initialView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "doc.text")
                .font(.system(size: 64))
                .foregroundColor(.gray)
            
            Text("Import Movie List from CSV")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            Text("Select a CSV file containing movie information to import as a new list.")
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            
            if isProcessing {
                VStack(spacing: 8) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    
                    Text("Processing CSV file...")
                        .foregroundColor(.gray)
                        .font(.caption)
                    
                    if !currentlyProcessing.isEmpty {
                        Text(currentlyProcessing)
                            .foregroundColor(.blue)
                            .font(.caption2)
                    }
                }
            } else {
                Button(action: {
                    showingFilePicker = true
                }) {
                    HStack {
                        Image(systemName: "folder")
                        Text("Choose CSV File")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
            }
            
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Spacer()
        }
    }
    
    @ViewBuilder
    private var importPreviewView: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("List Name")
                    .font(.headline)
                    .foregroundColor(.white)
                
                TextField("Enter list name", text: $listName)
                    .textFieldStyle(.roundedBorder)
                    .colorScheme(.dark)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Description (Optional)")
                    .font(.headline)
                    .foregroundColor(.white)
                
                TextField("Enter description", text: $listDescription, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .colorScheme(.dark)
                    .lineLimit(3, reservesSpace: true)
            }
            
            HStack {
                Text("Found \(importedEntries.count) movies")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("Ready to import")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            
            if isImporting {
                VStack(spacing: 8) {
                    ProgressView(value: importProgress, total: Double(importedEntries.count))
                        .progressViewStyle(LinearProgressViewStyle())
                    
                    Text("Importing movies... (\(Int(importProgress))/\(importedEntries.count))")
                        .foregroundColor(.gray)
                        .font(.caption)
                    
                    if !currentlyProcessing.isEmpty {
                        Text("Adding: \(currentlyProcessing)")
                            .foregroundColor(.blue)
                            .font(.caption2)
                    }
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(Array(importedEntries.enumerated()), id: \.offset) { index, entry in
                            moviePreviewRow(entry: entry, index: index)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .frame(maxHeight: 400)
                .background(Color.black)
            }
            
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
            }
        }
    }
    
    @ViewBuilder
    private func moviePreviewRow(entry: ListEntry, index: Int) -> some View {
        HStack {
            Text("\(entry.position)")
                .font(.caption)
                .foregroundColor(.gray)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                    .font(.body)
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                if let year = entry.year {
                    Text("(\(String(year)))")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
    }
    
    private func cleanListTitle(_ filename: String) -> String {
        // Clean the CSV filename to create a nice list title
        let cleanTitle = filename
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Split into words and capitalize each word
        let words = cleanTitle.split(separator: " ")
        let capitalizedWords = words.map { word in
            let lowercased = word.lowercased()
            
            // Don't capitalize common articles, prepositions, and conjunctions unless they're the first word
            let skipWords = ["the", "a", "an", "and", "but", "or", "for", "nor", "on", "at", "to", "from", "by", "of", "in", "with", "as"]
            
            if words.first == word || !skipWords.contains(lowercased) {
                return word.capitalized
            } else {
                return String(word)
            }
        }
        
        return capitalizedWords.joined(separator: " ")
    }
    
    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            selectedFileURL = url
            Task {
                await processCSVFile(url)
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }
    
    private func processCSVFile(_ url: URL) async {
        isProcessing = true
        errorMessage = nil
        currentlyProcessing = "Reading CSV file..."
        
        do {
            let csvContent = try CSVImporter.shared.importCSVFile(from: url)
            let csvRows = try CSVImporter.shared.parseCSVString(csvContent)
            let entries = CSVImporter.shared.convertToListEntries(csvRows)
            
            await MainActor.run {
                self.importedEntries = entries
                self.listName = cleanListTitle(url.deletingPathExtension().lastPathComponent)
                self.isProcessing = false
                self.currentlyProcessing = ""
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isProcessing = false
                self.currentlyProcessing = ""
            }
        }
    }
    
    
    private func searchForMovie(entry: ListEntry) async -> TMDBMovie? {
        // Try multiple search strategies in order of preference
        let searchStrategies = buildSearchStrategies(for: entry)
        print("   🔍 Built \(searchStrategies.count) search strategies for '\(entry.name)'")
        
        for (index, strategy) in searchStrategies.enumerated() {
            do {
                print("   🌐 Trying strategy \(index + 1): '\(strategy.query)'")
                let searchResponse = try await tmdbService.searchMovies(query: strategy.query)
                print("   📊 TMDB returned \(searchResponse.results.count) results")
                
                if let match = findBestMatchInResults(entry: entry, results: searchResponse.results, strategy: strategy) {
                    print("   ✅ Found match: \(match.title)")
                    return match
                } else {
                    print("   ❌ No suitable match in results")
                }
                
            } catch {
                print("   ⚠️ Search failed for '\(strategy.query)': \(error)")
            }
        }
        
        print("   ❌ All strategies failed for '\(entry.name)'")
        return nil
    }
    
    private func buildSearchStrategies(for entry: ListEntry) -> [SearchStrategy] {
        var strategies: [SearchStrategy] = []
        
        // Strategy 1: Exact title with year
        if let year = entry.year {
            strategies.append(SearchStrategy(
                query: "\(entry.name) \(year)",
                type: .exactWithYear,
                priority: 1
            ))
        }
        
        // Strategy 2: Exact title without year
        strategies.append(SearchStrategy(
            query: entry.name,
            type: .exact,
            priority: 2
        ))
        
        // Strategy 3: Normalized title with year (remove punctuation, extra spaces)
        let normalizedTitle = normalizeTitle(entry.name)
        if let year = entry.year, normalizedTitle != entry.name {
            strategies.append(SearchStrategy(
                query: "\(normalizedTitle) \(year)",
                type: .normalizedWithYear,
                priority: 3
            ))
        }
        
        // Strategy 4: Normalized title without year
        if normalizedTitle != entry.name {
            strategies.append(SearchStrategy(
                query: normalizedTitle,
                type: .normalized,
                priority: 4
            ))
        }
        
        // Strategy 5: Keywords only (remove articles, common words)
        let keywordsTitle = extractKeywords(entry.name)
        if keywordsTitle != entry.name && keywordsTitle != normalizedTitle {
            if let year = entry.year {
                strategies.append(SearchStrategy(
                    query: "\(keywordsTitle) \(year)",
                    type: .keywordsWithYear,
                    priority: 5
                ))
            }
            strategies.append(SearchStrategy(
                query: keywordsTitle,
                type: .keywords,
                priority: 6
            ))
        }
        
        return strategies
    }
    
    private func normalizeTitle(_ title: String) -> String {
        return title
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "[()]", with: "", options: .regularExpression)
            .replacingOccurrences(of: "  +", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func extractKeywords(_ title: String) -> String {
        let normalized = normalizeTitle(title)
        let stopWords = ["the", "a", "an", "and", "or", "but", "in", "on", "at", "to", "for", "of", "with", "by"]
        
        let words = normalized.split(separator: " ")
            .map { $0.lowercased() }
            .filter { !stopWords.contains($0) && $0.count > 2 }
        
        return words.joined(separator: " ")
    }
    
    private func findBestMatchInResults(entry: ListEntry, results: [TMDBMovie], strategy: SearchStrategy) -> TMDBMovie? {
        guard !results.isEmpty else { return nil }
        
        let entryTitle = entry.name.lowercased()
        let normalizedEntryTitle = normalizeTitle(entry.name).lowercased()
        
        // For exact matches, check title similarity and year
        for movie in results {
            let movieTitle = movie.title.lowercased()
            let normalizedMovieTitle = normalizeTitle(movie.title).lowercased()
            
            // Check for exact title matches first
            if movieTitle == entryTitle || normalizedMovieTitle == normalizedEntryTitle {
                if let entryYear = entry.year, let movieYear = extractYearFromDate(movie.releaseDate) {
                    if abs(movieYear - entryYear) <= 1 {
                        return movie
                    }
                } else if entry.year == nil {
                    return movie
                }
            }
        }
        
        // For normalized searches, allow partial matches
        if strategy.type == .normalized || strategy.type == .normalizedWithYear {
            for movie in results {
                let movieTitle = normalizeTitle(movie.title).lowercased()
                
                if movieTitle.contains(normalizedEntryTitle) || normalizedEntryTitle.contains(movieTitle) {
                    if let entryYear = entry.year, let movieYear = extractYearFromDate(movie.releaseDate) {
                        if abs(movieYear - entryYear) <= 2 {
                            return movie
                        }
                    } else {
                        return movie
                    }
                }
            }
        }
        
        // For keyword searches, return the most popular result if any
        if strategy.type == .keywords || strategy.type == .keywordsWithYear {
            return results.max(by: { $0.popularity ?? 0 < $1.popularity ?? 0 })
        }
        
        // For exact searches with year mismatch, return first result if year is close
        if strategy.type == .exactWithYear {
            for movie in results {
                if let entryYear = entry.year, let movieYear = extractYearFromDate(movie.releaseDate) {
                    if abs(movieYear - entryYear) <= 3 {
                        return movie
                    }
                }
            }
        }
        
        // Default: return the most popular result for exact matches
        if strategy.type == .exact {
            return results.max(by: { $0.popularity ?? 0 < $1.popularity ?? 0 })
        }
        
        return nil
    }
    
    private func extractYearFromDate(_ dateString: String?) -> Int? {
        guard let dateString = dateString, dateString.count >= 4 else { return nil }
        return Int(String(dateString.prefix(4)))
    }
    
    
    
    private func importList() async {
        isImporting = true
        errorMessage = nil
        importProgress = 0
        
        do {
            let trimmedName = listName.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedDescription = listDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            
            print("🚀 Creating new list: '\(trimmedName)'")
            let newList = try await dataManager.createList(
                name: trimmedName,
                description: trimmedDescription.isEmpty ? nil : trimmedDescription
            )
            print("✅ Created list with ID: \(newList.id)")
            print("📊 Starting to search and import \(importedEntries.count) movies to list")
            
            var successfullyAdded = 0
            var searchFailures = 0
            
            for (index, entry) in importedEntries.enumerated() {
                await MainActor.run {
                    currentlyProcessing = "Searching: \(entry.name)"
                    importProgress = Double(index)
                }
                
                print("🔍 [Movie \(index + 1)/\(importedEntries.count)] Searching for: '\(entry.name)' (Year: \(entry.year?.description ?? "nil"))")
                
                // Search for movie on TMDB
                if let tmdbMovie = await searchForMovie(entry: entry) {
                    print("✅ Found TMDB match: \(tmdbMovie.title) (ID: \(tmdbMovie.id))")
                    
                    await MainActor.run {
                        currentlyProcessing = "Adding: \(tmdbMovie.title)"
                    }
                    
                    // Immediately add to list
                    do {
                        let posterUrl = tmdbMovie.posterPath.map { "https://image.tmdb.org/t/p/w500\($0)" }
                        let backdropPath = tmdbMovie.backdropPath
                        let year = tmdbMovie.releaseDate.flatMap { String($0.prefix(4)) }.flatMap(Int.init)
                        
                        try await dataManager.addMovieToList(
                            tmdbId: tmdbMovie.id,
                            title: tmdbMovie.title,
                            posterUrl: posterUrl,
                            backdropPath: backdropPath,
                            year: year,
                            listId: newList.id
                        )
                        
                        successfullyAdded += 1
                        print("✅ Successfully added \(tmdbMovie.title) to list! (\(successfullyAdded) total)")
                        
                    } catch {
                        print("❌ Failed to add \(tmdbMovie.title) to list: \(error)")
                        print("❌ Error details: \(error.localizedDescription)")
                    }
                } else {
                    searchFailures += 1
                    print("❌ No TMDB match found for: '\(entry.name)' (\(searchFailures) total failures)")
                }
                
                try await Task.sleep(nanoseconds: 200_000_000)
            }
            
            print("🎯 List import completed!")
            print("📊 Processed \(importedEntries.count) entries: \(successfullyAdded) added, \(searchFailures) not found")
            
            await MainActor.run {
                importProgress = Double(importedEntries.count)
                currentlyProcessing = "Complete!"
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    dismiss()
                }
            }
            
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isImporting = false
            }
        }
    }
}

// MARK: - Watchlist Import

struct WatchlistEntry: Identifiable {
    let id = UUID()
    let date: Date?
    let name: String
    let year: Int?
    let letterboxdURI: String?
}

struct WatchlistImportView: View {
    @Environment(\.dismiss) private var dismiss
    private let dataManager = DataManager.shared
    private let tmdbService = TMDBService.shared

    @State private var showingFilePicker = false
    @State private var selectedFileURL: URL?
    @State private var importedEntries: [WatchlistEntry] = []
    @State private var listName = ""
    @State private var listDescription = ""
    @State private var isProcessing = false
    @State private var isImporting = false
    @State private var errorMessage: String?
    @State private var importProgress = 0.0
    @State private var currentlyProcessing = ""
    @State private var matchedMovies: [UUID: TMDBMovie] = [:]

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                if importedEntries.isEmpty {
                    initialView
                } else {
                    importPreviewView
                }
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            #if os(macOS)
            .background(Color(NSColor.windowBackgroundColor))
            #else
            .background(Color(.systemGroupedBackground))
            #endif
            .navigationTitle("Import Watchlist")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") { dismiss() }
                }
                if !importedEntries.isEmpty {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Import", systemImage: "checkmark") {
                            Task { await importWatchlist() }
                        }
                        .disabled(importedEntries.isEmpty || isImporting)
                    }
                }
            }
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: [UTType.commaSeparatedText, UTType.plainText],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
        }
        #if os(macOS)
        .background(Color(NSColor.windowBackgroundColor))
        #else
        .background(Color(.systemGroupedBackground))
        .toolbarBackground(Color(.systemGroupedBackground), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        #endif
    }

    @ViewBuilder
    private var initialView: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 64))
                .foregroundColor(.gray)
            Text("Import Watchlist CSV")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            Text("Select a watchlist CSV (Date, Name, Year, Letterboxd URI). We'll match titles to TMDB and add them to your Watchlist.")
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            if isProcessing {
                VStack(spacing: 8) {
                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                    Text("Processing CSV file...").foregroundColor(.gray).font(.caption)
                    if !currentlyProcessing.isEmpty {
                        Text(currentlyProcessing).foregroundColor(.blue).font(.caption2)
                    }
                }
            } else {
                Button(action: { showingFilePicker = true }) {
                    HStack { Image(systemName: "folder"); Text("Choose CSV File") }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
            if let errorMessage = errorMessage {
                Text(errorMessage).foregroundColor(.red).font(.caption).multilineTextAlignment(.center).padding(.horizontal)
            }
            Spacer()
        }
    }

    @ViewBuilder
    private var importPreviewView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Watchlist Entries").font(.headline).foregroundColor(.white)
            HStack {
                Text("Found \(importedEntries.count) movies").font(.headline).foregroundColor(.white)
                Spacer()
                if isImporting {
                    ProgressView(value: importProgress, total: Double(importedEntries.count)).progressViewStyle(LinearProgressViewStyle())
                }
            }
            if isImporting {
                VStack(spacing: 8) {
                    Text("Importing movies... (\(Int(importProgress))/\(importedEntries.count))").foregroundColor(.gray).font(.caption)
                    if !currentlyProcessing.isEmpty { Text("Adding: \(currentlyProcessing)").foregroundColor(.blue).font(.caption2) }
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(Array(importedEntries.enumerated()), id: \.offset) { index, entry in
                            watchlistPreviewRow(entry: entry, index: index)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .frame(maxHeight: 400)
                .background(Color.black)
            }
            if let errorMessage = errorMessage { Text(errorMessage).foregroundColor(.red).font(.caption) }
        }
    }

    @ViewBuilder
    private func watchlistPreviewRow(entry: WatchlistEntry, index: Int) -> some View {
        HStack {
            Text("\(index + 1)").font(.caption).foregroundColor(.gray).frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name).font(.body).foregroundColor(.white).lineLimit(1)
                if let year = entry.year { Text("(\(year))").font(.caption).foregroundColor(.gray) }
            }
            Spacer()
            if matchedMovies[entry.id] != nil {
                Image(systemName: "checkmark.circle.fill").foregroundColor(.green).font(.caption)
            } else {
                Image(systemName: "questionmark.circle").foregroundColor(.orange).font(.caption)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            selectedFileURL = url
            Task { await processCSVFile(url) }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    private func processCSVFile(_ url: URL) async {
        isProcessing = true
        errorMessage = nil
        currentlyProcessing = "Reading CSV file..."
        do {
            let csvContent = try CSVImporter.shared.importCSVFile(from: url)
            let entries = parseWatchlistCSV(csvContent)
            await MainActor.run {
                self.importedEntries = entries
                self.listName = defaultListName(from: url)
                self.isProcessing = false
                self.currentlyProcessing = ""
            }
            await searchMoviesForEntries(entries)
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isProcessing = false
                self.currentlyProcessing = ""
            }
        }
    }

    private func parseWatchlistCSV(_ csv: String) -> [WatchlistEntry] {
        let lines = csv.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !lines.isEmpty else {
            print("❌ CSV is empty")
            return []
        }
        
        let header = parseCSVLineWatchlist(lines[0]).map { $0.lowercased() }
        print("📋 CSV Headers found: \(header)")
        
        let dataLines = Array(lines.dropFirst())
        print("📊 CSV has \(dataLines.count) data rows")
        
        var entries: [WatchlistEntry] = []
        for (lineIndex, line) in dataLines.enumerated() {
            let cols = parseCSVLineWatchlist(line)
            if cols.isEmpty { continue }
            
            func val(_ key: String) -> String? {
                if let idx = header.firstIndex(of: key), idx < cols.count {
                    let v = cols[idx].trimmingCharacters(in: .whitespacesAndNewlines)
                    return v.isEmpty ? nil : v
                }
                return nil
            }
            
            let name = val("name") ?? val("title")
            guard let title = name else {
                print("⚠️ Row \(lineIndex + 1): No title found")
                continue
            }
            
            let yearStr = val("year")
            let year = yearStr.flatMap { Int($0) }
            let dateStr = val("date")
            let date = dateStr.flatMap { DateFormatter.yyyyMMdd.date(from: $0) }
            let uri = val("letterboxd uri") ?? val("letterboxd") ?? val("url")
            
            // Log first few entries to verify parsing
            if lineIndex < 5 {
                print("📝 Row \(lineIndex + 1): Title='\(title)', Year=\(year?.description ?? "nil"), Date=\(dateStr ?? "nil")")
            }
            
            entries.append(WatchlistEntry(date: date, name: title, year: year, letterboxdURI: uri))
        }
        
        print("✅ Parsed \(entries.count) watchlist entries from CSV")
        return entries
    }

    private func parseCSVLineWatchlist(_ line: String) -> [String] {
        var values: [String] = []
        var currentValue = ""
        var insideQuotes = false
        var i = line.startIndex
        while i < line.endIndex {
            let char = line[i]
            if char == "\"" {
                if insideQuotes {
                    let nextIndex = line.index(after: i)
                    if nextIndex < line.endIndex && line[nextIndex] == "\"" {
                        currentValue.append("\"")
                        i = line.index(after: nextIndex)
                        continue
                    } else { insideQuotes = false }
                } else { insideQuotes = true }
            } else if char == "," && !insideQuotes {
                values.append(currentValue)
                currentValue = ""
            } else {
                currentValue.append(char)
            }
            i = line.index(after: i)
        }
        values.append(currentValue)
        return values
    }

    private func defaultListName(from url: URL) -> String {
        let base = url.deletingPathExtension().lastPathComponent
        return base.isEmpty ? "Imported Watchlist" : base.replacingOccurrences(of: "_", with: " ").replacingOccurrences(of: "-", with: " ")
    }

    private func searchMoviesForEntries(_ entries: [WatchlistEntry]) async {
        await MainActor.run { currentlyProcessing = "Searching for movies..." }
        var matched: [UUID: TMDBMovie] = [:]
        var successfullyWritten = 0
        
        print("🔍 Starting TMDB search and immediate database writing for \(entries.count) entries")
        
        for (index, entry) in entries.enumerated() {
            await MainActor.run {
                currentlyProcessing = "Processing: \(entry.name)"
                importProgress = Double(index)
            }
            print("🔍 [\(index + 1)/\(entries.count)] Searching TMDB for: '\(entry.name)' (Year: \(entry.year?.description ?? "nil"))")
            
            if let bestMatch = await searchForMovie(entry: entry) {
                print("✅ Found TMDB match: \(bestMatch.title) (ID: \(bestMatch.id))")
                matched[entry.id] = bestMatch
                
                // Write to database immediately
                await MainActor.run { currentlyProcessing = "Saving: \(entry.name)" }
                
                do {
                    print("💾 Writing \(bestMatch.title) to database...")
                    let posterUrl = bestMatch.posterPath.map { "https://image.tmdb.org/t/p/w500\($0)" }
                    let backdropPath = bestMatch.backdropPath
                    let year = bestMatch.releaseDate.flatMap { String($0.prefix(4)) }.flatMap(Int.init)
                    let releaseDate = bestMatch.releaseDate
                    let addedAt = entry.date ?? Date()
                    
                    try await SupabaseWatchlistService.shared.upsertItem(
                        tmdbId: bestMatch.id,
                        title: bestMatch.title,
                        posterUrl: posterUrl,
                        backdropPath: backdropPath,
                        year: year,
                        releaseDate: releaseDate,
                        addedAt: addedAt
                    )
                    
                    successfullyWritten += 1
                    print("✅ Successfully wrote \(bestMatch.title) to database! (\(successfullyWritten) total)")
                    
                } catch {
                    print("❌ Failed to write \(bestMatch.title) to database: \(error)")
                    print("❌ Error details: \(error.localizedDescription)")
                }
                
            } else {
                print("❌ No TMDB match found for: '\(entry.name)'")
            }
            
            try? await Task.sleep(nanoseconds: 120_000_000) // Slightly longer delay for database writes
        }
        
        await MainActor.run {
            self.matchedMovies = matched
            self.currentlyProcessing = ""
            self.importProgress = Double(entries.count)
        }
        
        print("🎯 TMDB search and database writing completed!")
        print("📊 Found \(matched.count) TMDB matches out of \(entries.count) entries")
        print("💾 Successfully wrote \(successfullyWritten) movies to database")
        
        if successfullyWritten != matched.count {
            print("⚠️ Database write mismatch: \(matched.count) found vs \(successfullyWritten) written")
        }
    }

    private func searchForMovie(entry: WatchlistEntry) async -> TMDBMovie? {
        let strategies = buildSearchStrategies(for: entry)
        print("🔍 Built \(strategies.count) search strategies for '\(entry.name)':")
        for (index, strategy) in strategies.enumerated() {
            print("   \(index + 1). \(strategy.type) - '\(strategy.query)'")
        }
        
        for (strategyIndex, strategy) in strategies.enumerated() {
            do {
                print("🌐 Trying TMDB search [\(strategyIndex + 1)/\(strategies.count)]: '\(strategy.query)'")
                let searchResponse = try await tmdbService.searchMovies(query: strategy.query)
                print("📊 TMDB returned \(searchResponse.results.count) results for '\(strategy.query)'")
                
                if !searchResponse.results.isEmpty {
                    print("🎬 First few results:")
                    for (i, movie) in searchResponse.results.prefix(3).enumerated() {
                        let year = movie.releaseDate?.prefix(4) ?? "Unknown"
                        print("   \(i + 1). \(movie.title) (\(year)) - ID: \(movie.id)")
                    }
                }
                
                if let match = findBestMatchInResults(entry: entry, results: searchResponse.results, strategy: strategy) {
                    print("✅ Found best match: \(match.title) (ID: \(match.id))")
                    return match
                } else {
                    print("❌ No suitable match found in results for strategy '\(strategy.query)'")
                }
            } catch {
                print("⚠️ TMDB search failed for '\(strategy.query)': \(error)")
            }
        }
        print("❌ All search strategies failed for '\(entry.name)'")
        return nil
    }

    private func buildSearchStrategies(for entry: WatchlistEntry) -> [SearchStrategy] {
        var strategies: [SearchStrategy] = []
        if let year = entry.year { strategies.append(SearchStrategy(query: "\(entry.name) \(year)", type: .exactWithYear, priority: 1)) }
        strategies.append(SearchStrategy(query: entry.name, type: .exact, priority: 2))
        let normalized = normalizeTitle(entry.name)
        if let year = entry.year, normalized != entry.name { strategies.append(SearchStrategy(query: "\(normalized) \(year)", type: .normalizedWithYear, priority: 3)) }
        if normalized != entry.name { strategies.append(SearchStrategy(query: normalized, type: .normalized, priority: 4)) }
        let keywords = extractKeywords(entry.name)
        if keywords != entry.name && keywords != normalized {
            if let year = entry.year { strategies.append(SearchStrategy(query: "\(keywords) \(year)", type: .keywordsWithYear, priority: 5)) }
            strategies.append(SearchStrategy(query: keywords, type: .keywords, priority: 6))
        }
        return strategies
    }

    private func normalizeTitle(_ title: String) -> String {
        title.replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "[()]", with: "", options: .regularExpression)
            .replacingOccurrences(of: "  +", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractKeywords(_ title: String) -> String {
        let normalized = normalizeTitle(title)
        let stopWords = ["the","a","an","and","or","but","in","on","at","to","for","of","with","by"]
        let words = normalized.split(separator: " ").map { $0.lowercased() }.filter { !stopWords.contains($0) && $0.count > 2 }
        return words.joined(separator: " ")
    }

    private func findBestMatchInResults(entry: WatchlistEntry, results: [TMDBMovie], strategy: SearchStrategy) -> TMDBMovie? {
        guard !results.isEmpty else {
            print("   ❌ No results to match against")
            return nil
        }
        
        let entryTitle = entry.name.lowercased()
        let normalizedEntryTitle = normalizeTitle(entry.name).lowercased()
        
        print("   🔍 Matching '\(entry.name)' (Year: \(entry.year?.description ?? "nil")) against \(results.count) results:")
        print("   📝 Entry title normalized: '\(normalizedEntryTitle)'")
        
        // Exact title matching with year check
        for movie in results {
            let movieTitle = movie.title.lowercased()
            let normalizedMovieTitle = normalizeTitle(movie.title).lowercased()
            let movieYear = movie.releaseDate.flatMap({ Int(String($0.prefix(4))) })
            
            print("   🎬 Checking: '\(movie.title)' (\(movieYear?.description ?? "No year")) - ID: \(movie.id)")
            
            if movieTitle == entryTitle || normalizedMovieTitle == normalizedEntryTitle {
                print("   ✅ Title match found!")
                if let entryYear = entry.year, let movieYear = movieYear {
                    let yearDiff = abs(movieYear - entryYear)
                    print("   📅 Year check: Entry(\(entryYear)) vs Movie(\(movieYear)) = diff \(yearDiff)")
                    if yearDiff <= 1 {
                        print("   ✅ Year match within tolerance!")
                        return movie
                    } else {
                        print("   ❌ Year difference too large (\(yearDiff))")
                    }
                } else if entry.year == nil {
                    print("   ✅ No year constraint, accepting match!")
                    return movie
                } else {
                    print("   ❌ Movie has no release date")
                }
            }
        }
        
        // Normalized partial matching
        if strategy.type == .normalized || strategy.type == .normalizedWithYear {
            print("   🔍 Trying normalized partial matching...")
            for movie in results {
                let movieTitle = normalizeTitle(movie.title).lowercased()
                let movieYear = movie.releaseDate.flatMap({ Int(String($0.prefix(4))) })
                
                if movieTitle.contains(normalizedEntryTitle) || normalizedEntryTitle.contains(movieTitle) {
                    print("   ✅ Partial match found: '\(movie.title)'")
                    if let entryYear = entry.year, let movieYear = movieYear {
                        let yearDiff = abs(movieYear - entryYear)
                        if yearDiff <= 2 {
                            print("   ✅ Year within extended tolerance (\(yearDiff))")
                            return movie
                        } else {
                            print("   ❌ Year difference still too large (\(yearDiff))")
                        }
                    } else {
                        print("   ✅ No year constraint for partial match")
                        return movie
                    }
                }
            }
        }
        
        // Popularity fallback for keyword/exact searches
        if strategy.type == .keywords || strategy.type == .keywordsWithYear || strategy.type == .exact {
            let bestMovie = results.max(by: { $0.popularity ?? 0 < $1.popularity ?? 0 })
            if let movie = bestMovie {
                print("   📈 Using most popular result: '\(movie.title)' (popularity: \(movie.popularity ?? 0))")
                return movie
            }
        }
        
        print("   ❌ No suitable match found using current strategy")
        return nil
    }

    private func importWatchlist() async {
        print("🚀 Starting watchlist import...")
        isImporting = true
        errorMessage = nil
        importProgress = 0
        
        // Ensure user is authenticated
        guard let currentUser = SupabaseMovieService.shared.currentUser else {
            print("❌ Watchlist import failed: No authenticated user")
            await MainActor.run { errorMessage = "You must be logged in to import a watchlist."; isImporting = false }
            return
        }
        
        print("✅ User authenticated: \(currentUser.id)")
        print("📝 Starting search and immediate database writing for \(importedEntries.count) entries")
        
        // Search for movies and write them immediately to database
        await searchMoviesForEntries(importedEntries)
        
        print("🔄 Refreshing local watchlist cache...")
        // Refresh local cache to show the newly imported movies
        await dataManager.refreshWatchlist()
        
        print("✅ Watchlist import completed successfully!")
        await MainActor.run {
            currentlyProcessing = "Complete!"
            isImporting = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { dismiss() }
        }
    }
}

// MARK: - Tabbed Importer

struct CSVImportTabbedView: View {
    var body: some View {
        TabView {
            CSVImportView()
                .tabItem { Label("Lists", systemImage: "list.bullet") }
            WatchlistImportView()
                .tabItem { Label("Watchlists", systemImage: "text.badge.plus") }
        }
         
    }
}

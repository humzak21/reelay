//
//  CSVImporter.swift
//  reelay
//
//  Created by Humza Khalil on 6/11/25.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers

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
    @StateObject private var dataManager = DataManager.shared
    @StateObject private var tmdbService = TMDBService.shared
    
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
    @State private var matchedMovies: [UUID: TMDBMovie] = [:]
    @State private var unmatchedEntries: [ListEntry] = []
    @State private var existingInDiary: [UUID: Bool] = [:]
    
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
            .background(Color.black)
            .preferredColorScheme(.dark)
            .navigationTitle("Import CSV")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", systemImage: "xmark") {
                        dismiss()
                    }
                }
                
                if !importedEntries.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
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
        .background(Color.black)
        .toolbarBackground(Color.black, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
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
                
                VStack(alignment: .trailing, spacing: 2) {
                    if !unmatchedEntries.isEmpty {
                        Text("\(unmatchedEntries.count) not matched")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    
                    let diaryCount = existingInDiary.values.filter { $0 }.count
                    if diaryCount > 0 {
                        Text("\(diaryCount) in diary")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
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
            
            HStack(spacing: 4) {
                // TMDB match status
                if matchedMovies[entry.id] != nil {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                } else {
                    Image(systemName: "questionmark.circle")
                        .foregroundColor(.orange)
                        .font(.caption)
                }
                
                // Diary status
                if existingInDiary[entry.id] == true {
                    Image(systemName: "book.circle.fill")
                        .foregroundColor(.blue)
                        .font(.caption)
                        .help("Already in diary")
                }
            }
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
            
            await searchMoviesForEntries(entries)
            await checkExistingInDiary(entries)
            
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isProcessing = false
                self.currentlyProcessing = ""
            }
        }
    }
    
    private func searchMoviesForEntries(_ entries: [ListEntry]) async {
        await MainActor.run {
            currentlyProcessing = "Searching for movies..."
        }
        
        var matched: [UUID: TMDBMovie] = [:]
        var unmatched: [ListEntry] = []
        
        for (_, entry) in entries.enumerated() {
            await MainActor.run {
                currentlyProcessing = "Searching: \(entry.name)"
            }
            
            if let bestMatch = await searchForMovie(entry: entry) {
                matched[entry.id] = bestMatch
            } else {
                unmatched.append(entry)
            }
            
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        
        await MainActor.run {
            self.matchedMovies = matched
            self.unmatchedEntries = unmatched
            self.currentlyProcessing = ""
        }
    }
    
    private func searchForMovie(entry: ListEntry) async -> TMDBMovie? {
        // Try multiple search strategies in order of preference
        let searchStrategies = buildSearchStrategies(for: entry)
        print("🎯 Searching '\(entry.name)' with \(searchStrategies.count) strategies")
        
        for strategy in searchStrategies {
            do {
                let searchResponse = try await tmdbService.searchMovies(query: strategy.query)
                print("🔍 Searching '\(entry.name)' with query: '\(strategy.query)' - Found \(searchResponse.results.count) results")
                
                if let match = findBestMatchInResults(entry: entry, results: searchResponse.results, strategy: strategy) {
                    print("✅ Matched '\(entry.name)' -> '\(match.title)' (TMDB ID: \(match.id))")
                    return match
                }
                
            } catch {
                print("❌ Search failed for query '\(strategy.query)': \(error)")
            }
        }
        
        print("❌ No match found for '\(entry.name)' after trying \(searchStrategies.count) strategies")
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
    
    private func checkExistingInDiary(_ entries: [ListEntry]) async {
        await MainActor.run {
            currentlyProcessing = "Checking diary entries..."
        }
        
        var diaryStatus: [UUID: Bool] = [:]
        
        for entry in entries {
            if let tmdbMovie = matchedMovies[entry.id] {
                do {
                    let existingMovies = try await dataManager.getMoviesByTmdbId(tmdbId: tmdbMovie.id)
                    let isInDiary = !existingMovies.isEmpty
                    diaryStatus[entry.id] = isInDiary
                    
                    if isInDiary {
                        print("📖 '\(entry.name)' found in diary (TMDB ID: \(tmdbMovie.id)) - \(existingMovies.count) entries")
                    }
                    
                    try await Task.sleep(nanoseconds: 50_000_000)
                } catch {
                    print("❌ Failed to check diary for movie: \(entry.name) - \(error)")
                    diaryStatus[entry.id] = false
                }
            }
        }
        
        await MainActor.run {
            self.existingInDiary = diaryStatus
            self.currentlyProcessing = ""
        }
    }
    
    
    private func importList() async {
        isImporting = true
        errorMessage = nil
        importProgress = 0
        
        do {
            let trimmedName = listName.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedDescription = listDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            
            let newList = try await dataManager.createList(
                name: trimmedName,
                description: trimmedDescription.isEmpty ? nil : trimmedDescription
            )
            
            for (index, entry) in importedEntries.enumerated() {
                await MainActor.run {
                    currentlyProcessing = entry.name
                    importProgress = Double(index)
                }
                
                // Add all TMDB-matched movies to the list, regardless of diary status
                // This ensures we can add movies even if they haven't been logged yet
                if let tmdbMovie = matchedMovies[entry.id] {
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
                        
                        try await Task.sleep(nanoseconds: 200_000_000)
                        
                    } catch {
                        print("Failed to add movie \(entry.name): \(error)")
                    }
                }
            }
            
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
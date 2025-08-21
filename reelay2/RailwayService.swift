import Foundation

class RailwayService {
    private let baseURL = "https://reelay2apiserver-production.up.railway.app/api"
    
    func fetchMovies() async throws -> [Movie] {
        guard let url = URL(string: "\(baseURL)/movies") else {
            throw URLError(.badURL)
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        // Check HTTP status code
        if let httpResponse = response as? HTTPURLResponse {
            guard httpResponse.statusCode == 200 else {
                let responseString = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw RailwayCacheError.serverError(httpResponse.statusCode, responseString)
            }
        }
        
        // Validate JSON structure
        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw RailwayCacheError.invalidData("Unable to decode response as UTF-8")
        }
        
        // Check if response contains HTML (error page)
        if jsonString.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("<") {
            throw RailwayCacheError.htmlError(jsonString)
        }
        
        // Try to decode as array first
        do {
            return try JSONDecoder().decode([Movie].self, from: data)
        } catch {
            // If array decoding fails, try to decode as object with data array
            do {
                let wrapper = try JSONDecoder().decode(MovieWrapper.self, from: data)
                return wrapper.data ?? wrapper.movies ?? []
            } catch {
                throw RailwayCacheError.decodingError(error.localizedDescription)
            }
        }
    }
    
    func fetchStatistics(userId: String) async throws -> DashboardStats {
        guard let url = URL(string: "\(baseURL)/statistics/\(userId)") else {
            throw URLError(.badURL)
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        // Check HTTP status code
        if let httpResponse = response as? HTTPURLResponse {
            guard httpResponse.statusCode == 200 else {
                let responseString = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw RailwayCacheError.serverError(httpResponse.statusCode, responseString)
            }
        }
        
        // Validate JSON structure
        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw RailwayCacheError.invalidData("Unable to decode response as UTF-8")
        }
        
        // Check if response contains HTML (error page)
        if jsonString.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("<") {
            throw RailwayCacheError.htmlError(jsonString)
        }
        
        return try JSONDecoder().decode(DashboardStats.self, from: data)
    }
    
    func fetchMovieLists(userId: String) async throws -> [MovieList] {
        guard let url = URL(string: "\(baseURL)/lists/\(userId)") else {
            throw URLError(.badURL)
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        // Check HTTP status code
        if let httpResponse = response as? HTTPURLResponse {
            guard httpResponse.statusCode == 200 else {
                let responseString = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw RailwayCacheError.serverError(httpResponse.statusCode, responseString)
            }
        }
        
        // Validate JSON structure
        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw RailwayCacheError.invalidData("Unable to decode response as UTF-8")
        }
        
        // Check if response contains HTML (error page)
        if jsonString.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("<") {
            throw RailwayCacheError.htmlError(jsonString)
        }
        
        // Try to decode as array first
        do {
            return try JSONDecoder().decode([MovieList].self, from: data)
        } catch {
            // If array decoding fails, try to decode as object with data array
            do {
                let wrapper = try JSONDecoder().decode(MovieListWrapper.self, from: data)
                return wrapper.data ?? wrapper.lists ?? []
            } catch {
                throw RailwayCacheError.decodingError(error.localizedDescription)
            }
        }
    }
    
    func fetchListItems(listId: String) async throws -> [ListItem] {
        guard let url = URL(string: "\(baseURL)/lists/\(listId)/items") else {
            throw URLError(.badURL)
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        // Check HTTP status code
        if let httpResponse = response as? HTTPURLResponse {
            guard httpResponse.statusCode == 200 else {
                let responseString = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw RailwayCacheError.serverError(httpResponse.statusCode, responseString)
            }
        }
        
        // Validate JSON structure
        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw RailwayCacheError.invalidData("Unable to decode response as UTF-8")
        }
        
        // Check if response contains HTML (error page)
        if jsonString.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("<") {
            throw RailwayCacheError.htmlError(jsonString)
        }
        
        // Try to decode as array first
        do {
            return try JSONDecoder().decode([ListItem].self, from: data)
        } catch {
            // If array decoding fails, try to decode as object with data array
            do {
                let wrapper = try JSONDecoder().decode(ListItemWrapper.self, from: data)
                return wrapper.data ?? wrapper.items ?? []
            } catch {
                throw RailwayCacheError.decodingError(error.localizedDescription)
            }
        }
    }
    
    func fetchUserProfile(userId: String) async throws -> UserProfile {
        guard let url = URL(string: "\(baseURL)/profile/\(userId)") else {
            throw URLError(.badURL)
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        // Check HTTP status code
        if let httpResponse = response as? HTTPURLResponse {
            guard httpResponse.statusCode == 200 else {
                let responseString = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw RailwayCacheError.serverError(httpResponse.statusCode, responseString)
            }
        }
        
        // Validate JSON structure
        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw RailwayCacheError.invalidData("Unable to decode response as UTF-8")
        }
        
        // Check if response contains HTML (error page)
        if jsonString.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("<") {
            throw RailwayCacheError.htmlError(jsonString)
        }
        
        return try JSONDecoder().decode(UserProfile.self, from: data)
    }
    
    // MARK: - Cache Management
    
    func clearMovieCache() async {
        guard let url = URL(string: "\(baseURL)/cache/*/movies*") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        let _ = try? await URLSession.shared.data(for: request)
    }
    
    func clearStatisticsCache(userId: String) async {
        guard let url = URL(string: "\(baseURL)/cache/*/statistics/\(userId)*") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        let _ = try? await URLSession.shared.data(for: request)
    }
    
    func clearListsCache(userId: String) async {
        guard let url = URL(string: "\(baseURL)/cache/*/lists/\(userId)*") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        let _ = try? await URLSession.shared.data(for: request)
    }
    
    func clearProfileCache(userId: String) async {
        guard let url = URL(string: "\(baseURL)/cache/*/profile/\(userId)*") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        let _ = try? await URLSession.shared.data(for: request)
    }
    
    func clearAllUserCache(userId: String) async {
        await clearStatisticsCache(userId: userId)
        await clearListsCache(userId: userId)
        await clearProfileCache(userId: userId)
    }
    
    // MARK: - Cache Monitoring & Verification
    
    func checkCacheHealth() async -> CacheHealthStatus {
        let startTime = Date()
        var status = CacheHealthStatus()
        
        // Test basic connectivity
        do {
            guard let url = URL(string: "\(baseURL)/health") else {
                status.isConnected = false
                status.message = "Invalid health check URL"
                return status
            }
            
            let (_, response) = try await URLSession.shared.data(from: url)
            if let httpResponse = response as? HTTPURLResponse {
                status.isConnected = httpResponse.statusCode == 200
                status.responseTime = Date().timeIntervalSince(startTime)
                status.message = "Railway API \(status.isConnected ? "connected" : "disconnected") - Status: \(httpResponse.statusCode)"
            }
        } catch {
            status.isConnected = false
            status.responseTime = Date().timeIntervalSince(startTime)
            status.message = "Connection failed: \(error.localizedDescription)"
        }
        
        return status
    }
    
    func fetchWithCacheHeaders(endpoint: String) async -> CacheResponse {
        let startTime = Date()
        var cacheResponse = CacheResponse(endpoint: endpoint, startTime: startTime)
        
        guard let url = URL(string: "\(baseURL)/\(endpoint)") else {
            cacheResponse.error = "Invalid URL"
            cacheResponse.responseTime = Date().timeIntervalSince(startTime)
            return cacheResponse
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            cacheResponse.responseTime = Date().timeIntervalSince(startTime)
            
            if let httpResponse = response as? HTTPURLResponse {
                cacheResponse.statusCode = httpResponse.statusCode
                cacheResponse.isCacheHit = httpResponse.allHeaderFields["X-Cache"] as? String == "HIT"
                cacheResponse.cacheAge = httpResponse.allHeaderFields["Age"] as? String
                cacheResponse.dataSize = data.count
                
                print("🔍 Cache Check - \(endpoint):")
                print("   Status: \(httpResponse.statusCode)")
                print("   Cache Hit: \(cacheResponse.isCacheHit ? "✅ YES" : "❌ NO")")
                print("   Response Time: \(String(format: "%.3f", cacheResponse.responseTime))s")
                print("   Data Size: \(cacheResponse.dataSize) bytes")
                if let age = cacheResponse.cacheAge {
                    print("   Cache Age: \(age)s")
                }
            }
        } catch {
            cacheResponse.error = error.localizedDescription
            cacheResponse.responseTime = Date().timeIntervalSince(startTime)
            print("❌ Cache Check Failed - \(endpoint): \(error.localizedDescription)")
        }
        
        return cacheResponse
    }
    
    func testCachePerformance(userId: String) async -> CachePerformanceReport {
        var report = CachePerformanceReport()
        
        print("🚀 Starting Cache Performance Test...")
        
        // Test multiple endpoints
        let endpoints = [
            "movies",
            "statistics/\(userId)",
            "lists/\(userId)",
            "profile/\(userId)"
        ]
        
        for endpoint in endpoints {
            let response = await fetchWithCacheHeaders(endpoint: endpoint)
            report.responses.append(response)
        }
        
        // Calculate averages
        report.averageResponseTime = report.responses.map { $0.responseTime }.reduce(0, +) / Double(report.responses.count)
        report.cacheHitRate = Double(report.responses.filter { $0.isCacheHit }.count) / Double(report.responses.count)
        report.totalDataTransferred = report.responses.map { $0.dataSize }.reduce(0, +)
        
        print("📊 Cache Performance Summary:")
        print("   Average Response Time: \(String(format: "%.3f", report.averageResponseTime))s")
        print("   Cache Hit Rate: \(String(format: "%.1f", report.cacheHitRate * 100))%")
        print("   Total Data: \(report.totalDataTransferred) bytes")
        
        return report
    }
    
    func logCacheOperation(_ operation: String, endpoint: String, startTime: Date, success: Bool, cacheHit: Bool? = nil) {
        let duration = Date().timeIntervalSince(startTime)
        let hitStatus = cacheHit == true ? " [CACHE HIT]" : cacheHit == false ? " [CACHE MISS]" : ""
        let successIcon = success ? "✅" : "❌"
        
        print("\(successIcon) Railway \(operation) - \(endpoint)\(hitStatus) (\(String(format: "%.3f", duration))s)")
    }
}

// MARK: - Cache Monitoring Models

struct CacheHealthStatus {
    var isConnected: Bool = false
    var responseTime: TimeInterval = 0
    var message: String = ""
}

struct CacheResponse {
    let endpoint: String
    let startTime: Date
    var responseTime: TimeInterval = 0
    var statusCode: Int = 0
    var isCacheHit: Bool = false
    var cacheAge: String?
    var dataSize: Int = 0
    var error: String?
}

struct CachePerformanceReport {
    var responses: [CacheResponse] = []
    var averageResponseTime: TimeInterval = 0
    var cacheHitRate: Double = 0
    var totalDataTransferred: Int = 0
}

// MARK: - Error Types

enum RailwayCacheError: LocalizedError {
    case serverError(Int, String)
    case invalidData(String)
    case htmlError(String)
    case decodingError(String)
    
    var errorDescription: String? {
        switch self {
        case .serverError(let code, let message):
            return "Railway server error (\(code)): \(message)"
        case .invalidData(let message):
            return "Invalid data format: \(message)"
        case .htmlError(let html):
            let preview = String(html.prefix(200))
            return "Received HTML instead of JSON: \(preview)..."
        case .decodingError(let message):
            return "JSON decoding failed: \(message)"
        }
    }
}

// MARK: - Wrapper Types for Flexible JSON Responses

struct MovieWrapper: Codable {
    let data: [Movie]?
    let movies: [Movie]?
}

struct MovieListWrapper: Codable {
    let data: [MovieList]?
    let lists: [MovieList]?
}

struct ListItemWrapper: Codable {
    let data: [ListItem]?
    let items: [ListItem]?
}
//
//  StreamingServiceTest.swift
//  reelay2
//
//  Created by Cascade AI on 9/9/25.
//

import Foundation

/// Test utility for validating streaming API integration
class StreamingServiceTest {
    private let streamingService = StreamingService.shared
    
    /// Test the streaming API with a known movie (The Godfather - TMDB ID: 238)
    func testKnownMovie() async {
        print("🧪 [StreamingTest] Testing with The Godfather (TMDB: 238)")
        
        do {
            let result = try await streamingService.getMovieStreamingAvailability(tmdbId: 238, country: "us")
            
            print("✅ [StreamingTest] Success! Movie: \(result.title ?? "Unknown")")
            print("📊 [StreamingTest] Show Type: \(result.showType ?? "Unknown")")
            print("📅 [StreamingTest] Release Year: \(result.releaseYear ?? 0)")
            
            if let streamingOptions = result.streamingOptions?["us"] {
                print("📺 [StreamingTest] Found \(streamingOptions.count) streaming options:")
                for option in streamingOptions.prefix(5) {
                    print("   - \(option.service.name): \(option.type) (\(option.quality ?? "Unknown quality"))")
                }
            } else {
                print("📺 [StreamingTest] No streaming options found for US")
            }
            
            if let error = result.error ?? result.message {
                print("⚠️ [StreamingTest] API returned error: \(error)")
            }
            
        } catch {
            print("❌ [StreamingTest] Test failed: \(error)")
            
            if let streamingError = error as? StreamingServiceError {
                switch streamingError {
                case .httpError(let code):
                    print("💡 [StreamingTest] HTTP \(code) - Check your RapidAPI key and subscription")
                case .authenticationRequired:
                    print("💡 [StreamingTest] Add your RapidAPI key to Config.swift")
                case .decodingError:
                    print("💡 [StreamingTest] Response format issue - API may have changed")
                default:
                    print("💡 [StreamingTest] Other error: \(streamingError.localizedDescription)")
                }
            }
        }
    }
    
    /// Test with multiple popular movies
    func testMultipleMovies() async {
        let testMovies = [
            (238, "The Godfather"),
            (550, "Fight Club"),
            (13, "Forrest Gump"),
            (680, "Pulp Fiction")
        ]
        
        print("🧪 [StreamingTest] Testing multiple movies...")
        
        for (tmdbId, title) in testMovies {
            print("\n🎬 [StreamingTest] Testing: \(title) (TMDB: \(tmdbId))")
            
            do {
                let result = try await streamingService.getMovieStreamingAvailability(tmdbId: tmdbId, country: "us")
                
                if let resultTitle = result.title {
                    print("✅ [StreamingTest] Found: \(resultTitle)")
                    let optionCount = result.streamingOptions?["us"]?.count ?? 0
                    print("📺 [StreamingTest] Streaming options: \(optionCount)")
                } else {
                    print("⚠️ [StreamingTest] No title returned")
                }
                
            } catch {
                print("❌ [StreamingTest] Failed for \(title): \(error.localizedDescription)")
            }
            
            // Small delay to avoid rate limiting
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        }
    }
    
    /// Test supported services endpoint
    func testSupportedServices() async {
        print("🧪 [StreamingTest] Testing supported services...")
        
        do {
            let result = try await streamingService.getSupportedServices(country: "us")
            print("✅ [StreamingTest] Found \(result.services.count) supported services in \(result.country)")
            print("📋 [StreamingTest] Services: \(result.services.prefix(10).joined(separator: ", "))")
            
        } catch {
            print("❌ [StreamingTest] Failed to get supported services: \(error)")
        }
    }
    
    /// Run all tests
    func runAllTests() async {
        print("\n🚀 [StreamingTest] Starting comprehensive streaming API tests...\n")
        
        await testKnownMovie()
        print("\n" + String(repeating: "=", count: 50) + "\n")
        
        await testSupportedServices()
        print("\n" + String(repeating: "=", count: 50) + "\n")
        
        await testMultipleMovies()
        
        print("\n🏁 [StreamingTest] All tests completed!")
    }
}

// MARK: - Usage Example
/*
 To test the streaming API integration, add this to your view or app delegate:
 
 Task {
     let tester = StreamingServiceTest()
     await tester.runAllTests()
 }
 
 Or test individual components:
 
 Task {
     let tester = StreamingServiceTest()
     await tester.testKnownMovie()
 }
*/

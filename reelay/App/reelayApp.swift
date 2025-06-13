//
//  reelayApp.swift
//  reelay
//
//  Created by Humza Khalil on 6/2/25.
//
// App/MovieTrackerApp.swift
import SwiftUI
import SDWebImage

@main
struct reelayApp: App {
    
    init() {
        configureImageCache()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(SupabaseService.shared)
        }
    }
    
    private func configureImageCache() {
        // Configure SDWebImage for better performance
        SDImageCache.shared.config.maxMemoryCost = 100 * 1024 * 1024 // 100MB memory cache
        SDImageCache.shared.config.maxDiskSize = 200 * 1024 * 1024 // 200MB disk cache
        SDImageCache.shared.config.maxDiskAge = 7 * 24 * 60 * 60 // 7 days
        
        // Enable disk cache cleanup
        SDImageCache.shared.config.shouldCacheImagesInMemory = true
        SDImageCache.shared.config.shouldUseWeakMemoryCache = true
    }
}

//
//  reelay2App.swift
//  reelay2
//
//  Created by Humza Khalil on 7/19/25.
//

import SwiftUI
import SwiftData
import Combine
import SDWebImage

@main
struct reelay2App: App {
    @AppStorage("appearanceMode") private var appearanceModeRawValue: String = AppearanceMode.automatic.rawValue
    private var selectedAppearanceMode: AppearanceMode {
        AppearanceMode(rawValue: appearanceModeRawValue) ?? .automatic
    }

    init() {
        let cacheConfig = SDImageCache.shared.config
        cacheConfig.maxMemoryCost = 120 * 1024 * 1024
        cacheConfig.maxMemoryCount = 400
        cacheConfig.maxDiskSize = 750 * 1024 * 1024
        cacheConfig.shouldUseWeakMemoryCache = true

        SDWebImageDownloader.shared.config.maxConcurrentDownloads = 6
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(selectedAppearanceMode.colorScheme)
        }
        .modelContainer(ModelContainerManager.shared.modelContainer)
        #if os(macOS)
        .defaultSize(width: 1200, height: 800)
        #endif
    }
}

//
//  ModelContainerManager.swift
//  reelay2
//
//  Created by Claude on 8/4/25.
//

import Foundation
import SwiftData

class ModelContainerManager {
    static let shared = ModelContainerManager()
    
    let modelContainer: ModelContainer
    
    private init() {
        let schema = Schema([
            Item.self,
            PersistentMovieList.self,
            PersistentListItem.self
        ])
        
        let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let storeURL = appSupportURL.appendingPathComponent("reelay2.sqlite")
        
        do {
            try FileManager.default.createDirectory(at: appSupportURL, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print("Failed to create directory: \(error)")
        }
        
        let modelConfiguration = ModelConfiguration(schema: schema, url: storeURL)

        do {
            self.modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }
}
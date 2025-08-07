//
//  ModelContainerManager.swift
//  reelay2
//
//  Created by Humza Khalil on 8/4/25.
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
            print("ModelContainer creation failed: \(error)")
            
            // Try to delete the existing database and recreate
            do {
                if FileManager.default.fileExists(atPath: storeURL.path) {
                    try FileManager.default.removeItem(at: storeURL)
                    print("Deleted existing database file")
                }
                
                // Try creating the container again
                self.modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
                print("Successfully recreated ModelContainer")
            } catch {
                fatalError("Could not create ModelContainer even after reset: \(error)")
            }
        }
    }
}
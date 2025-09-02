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
            // Silently handle directory creation error
        }
        
        let modelConfiguration = ModelConfiguration(schema: schema, url: storeURL)

        do {
            self.modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            print("SwiftData migration failed: \(error)")
            
            // Check if this is specifically the tags attribute migration error
            let errorDescription = error.localizedDescription
            if errorDescription.contains("tags") && errorDescription.contains("PersistentMovieList") {
                print("Detected missing tags attribute on PersistentMovieList - removing database for clean migration")
            } else {
                print("General SwiftData migration error - removing database for clean migration")
            }
            
            // Try to delete the existing database and related files
            do {
                let fileManager = FileManager.default
                let parentURL = storeURL.deletingLastPathComponent()
                let fileName = storeURL.deletingPathExtension().lastPathComponent
                
                // Remove all database-related files
                let filesToRemove = [
                    storeURL.path,
                    storeURL.path + "-shm",
                    storeURL.path + "-wal"
                ]
                
                for filePath in filesToRemove {
                    if fileManager.fileExists(atPath: filePath) {
                        try fileManager.removeItem(atPath: filePath)
                        print("Removed: \(filePath)")
                    }
                }
                
                // Try creating the container again with fresh database
                self.modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
                print("Successfully created fresh ModelContainer after database reset")
            } catch {
                fatalError("Could not create ModelContainer even after complete database reset: \(error)")
            }
        }
    }
}
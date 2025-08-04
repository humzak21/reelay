//
//  reelay2App.swift
//  reelay2
//
//  Created by Humza Khalil on 7/19/25.
//

import SwiftUI
import SwiftData

@main
struct reelay2App: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(ModelContainerManager.shared.modelContainer)
    }
}

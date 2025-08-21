//
//  reelay2App.swift
//  reelay2
//
//  Created by Humza Khalil on 7/19/25.
//

import SwiftUI
import SwiftData
import Combine

@main
struct reelay2App: App {
    @AppStorage("appearanceMode") private var appearanceModeRawValue: String = AppearanceMode.automatic.rawValue
    private var selectedAppearanceMode: AppearanceMode {
        AppearanceMode(rawValue: appearanceModeRawValue) ?? .automatic
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(selectedAppearanceMode.colorScheme)
        }
        .modelContainer(ModelContainerManager.shared.modelContainer)
    }
}

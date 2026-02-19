//
//  reelay2macOSApp.swift
//  reelay2macOS
//
//  Created by Humza Khalil on 2/7/26.
//

import SwiftUI
import SwiftData

@main
struct reelay2macOSApp: App {
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
        .defaultSize(width: 1200, height: 800)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Movie Entry") {
                    NotificationCenter.default.post(name: .openAddMovie, object: nil)
                }
                .keyboardShortcut("n")

                Button("Import CSV...") {
                    NotificationCenter.default.post(name: .openCSVImport, object: nil)
                }
                .keyboardShortcut("i")
            }

            CommandGroup(after: .sidebar) {
                Button("Home") {
                    NotificationCenter.default.post(name: .switchSidebar, object: SidebarItem.home)
                }
                .keyboardShortcut("1")

                Button("Movies") {
                    NotificationCenter.default.post(name: .switchSidebar, object: SidebarItem.movies)
                }
                .keyboardShortcut("2")

                Button("Lists") {
                    NotificationCenter.default.post(name: .switchSidebar, object: SidebarItem.lists)
                }
                .keyboardShortcut("3")

                Button("Statistics") {
                    NotificationCenter.default.post(name: .switchSidebar, object: SidebarItem.statistics)
                }
                .keyboardShortcut("4")

                Button("Search") {
                    NotificationCenter.default.post(name: .switchSidebar, object: SidebarItem.search)
                }
                .keyboardShortcut("5")

                Button("Profile") {
                    NotificationCenter.default.post(name: .switchSidebar, object: SidebarItem.profile)
                }
                .keyboardShortcut("6")
            }

            CommandGroup(replacing: .textEditing) {
                Button("Find...") {
                    NotificationCenter.default.post(name: .switchSidebar, object: SidebarItem.search)
                }
                .keyboardShortcut("f")
            }
        }
    }
}

// MARK: - Notification Names for Menu Commands
extension Notification.Name {
    static let openAddMovie = Notification.Name("openAddMovie")
    static let openCSVImport = Notification.Name("openCSVImport")
    static let switchSidebar = Notification.Name("switchSidebar")
}

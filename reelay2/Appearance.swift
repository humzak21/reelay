import SwiftUI

enum AppearanceMode: String, CaseIterable {
    case automatic = "Automatic"
    case light = "Light"
    case dark = "Dark"

    var colorScheme: ColorScheme? {
        switch self {
        case .automatic:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}



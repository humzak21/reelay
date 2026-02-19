import SwiftUI

struct AppearanceOptionView: View {
    let mode: AppearanceMode
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(previewBackgroundColor)
                        .frame(width: 60, height: 100)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(previewBorderColor, lineWidth: 2)
                        )
                    
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(previewTextColor)
                            .frame(width: 40, height: 2)
                        
                        VStack(spacing: 2) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(previewAccentColor)
                                .frame(width: 45, height: 8)
                            
                            RoundedRectangle(cornerRadius: 2)
                                .fill(previewTextColor.opacity(0.6))
                                .frame(width: 35, height: 4)
                            
                            RoundedRectangle(cornerRadius: 2)
                                .fill(previewTextColor.opacity(0.6))
                                .frame(width: 40, height: 4)
                        }
                        .padding(.top, 8)
                        
                        Spacer()
                    }
                    .padding(.top, 8)
                }
                
                Text(mode.rawValue)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .medium)
                    .foregroundColor(isSelected ? .primary : .secondary)
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.caption)
                    .foregroundColor(isSelected ? .blue : .secondary)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
    
    private var previewBackgroundColor: Color {
        switch mode {
        case .automatic:
            #if os(macOS)
            return Color(NSColor.windowBackgroundColor)
            #else
            return Color(.systemGroupedBackground)
            #endif
        case .light:
            #if os(macOS)
            return Color(NSColor.windowBackgroundColor)
            #else
            return Color(.systemGroupedBackground)
            #endif
        case .dark:
            return Color(.black)
        }
    }

    private var previewBorderColor: Color {
        switch mode {
        case .automatic:
            #if os(macOS)
            return Color(NSColor.separatorColor)
            #else
            return Color(.systemGray3)
            #endif
        case .light:
            #if os(macOS)
            return Color(NSColor.gridColor)
            #else
            return Color(.systemGray4)
            #endif
        case .dark:
            #if os(macOS)
            return Color(NSColor.quaternaryLabelColor)
            #else
            return Color(.systemGray2)
            #endif
        }
    }

    private var previewTextColor: Color {
        switch mode {
        case .automatic:
            #if os(macOS)
            return Color(NSColor.labelColor)
            #else
            return Color(.label)
            #endif
        case .light:
            return .black
        case .dark:
            return .white
        }
    }
    
    private var previewAccentColor: Color { .blue }
}



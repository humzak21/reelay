import SwiftUI

struct MonthHeaderView: View {
    @Environment(\.colorScheme) private var colorScheme
    let monthYear: String
    @ObservedObject private var monthDescriptorService = MonthDescriptorService.shared
    @State private var showingEditDescriptor = false
    
    private var displayMonthYear: String {
        monthDescriptorService.formatMonthYearForDisplay(
            convertToMonthYearFormat(monthYear),
            with: monthDescriptorService.getDescriptor(for: convertToMonthYearFormat(monthYear))
        )
    }
    
    private var monthYearKey: String {
        convertToMonthYearFormat(monthYear)
    }
    
    var body: some View {
        HStack {
            Button(action: {
                showingEditDescriptor = true
            }) {
                Text(displayMonthYear)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(Color.adaptiveText(scheme: colorScheme))
                    .multilineTextAlignment(.leading)
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .sheet(isPresented: $showingEditDescriptor) {
            EditMonthDescriptorView(
                monthYear: monthYearKey,
                displayMonthYear: getBaseDisplayMonthYear(),
                isPresented: $showingEditDescriptor
            )
        }
    }
    
    private func convertToMonthYearFormat(_ displayDate: String) -> String {
        // Convert "August 2025" or similar format to "2025-08"
        let baseDate = displayDate.components(separatedBy: " - ").first ?? displayDate
        let components = baseDate.components(separatedBy: " ")
        
        guard components.count == 2,
              let year = components.last,
              let month = components.first else {
            return displayDate
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM"
        guard let date = dateFormatter.date(from: month) else {
            return displayDate
        }
        
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MM"
        let monthNum = monthFormatter.string(from: date)
        
        return "\(year)-\(monthNum)"
    }
    
    private func getBaseDisplayMonthYear() -> String {
        // Get just the "August 2025" part without any descriptor
        let components = monthYear.components(separatedBy: " - ")
        return components.first ?? monthYear
    }
}

#Preview {
    VStack {
        MonthHeaderView(monthYear: "August 2025")
        MonthHeaderView(monthYear: "July 2025")
        MonthHeaderView(monthYear: "December 2024")
    }
    .background(Color.black)
}
import SwiftUI

struct MonthHeaderView: View {
    @Environment(\.colorScheme) private var colorScheme

    let monthYearKey: String
    let displayMonthYear: String
    var onDescriptorChanged: (() -> Void)? = nil

    @State private var showingEditDescriptor = false

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
                displayMonthYear: baseDisplayMonthYear(),
                isPresented: $showingEditDescriptor
            )
        }
        .onChange(of: showingEditDescriptor) { _, isShowing in
            if !isShowing {
                onDescriptorChanged?()
            }
        }
    }

    private func baseDisplayMonthYear() -> String {
        let components = monthYearKey.split(separator: "-")
        guard components.count == 2,
              let year = Int(components[0]),
              let month = Int(components[1]),
              (1...12).contains(month) else {
            return displayMonthYear
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")

        var dateComponents = DateComponents()
        dateComponents.year = year
        dateComponents.month = month
        dateComponents.day = 1

        guard let date = calendar.date(from: dateComponents) else {
            return displayMonthYear
        }

        return Self.displayFormatter.string(from: date)
    }

    private static let displayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()
}

#Preview {
    VStack {
        MonthHeaderView(monthYearKey: "2025-08", displayMonthYear: "August 2025")
        MonthHeaderView(monthYearKey: "2025-07", displayMonthYear: "July 2025")
        MonthHeaderView(monthYearKey: "2024-12", displayMonthYear: "December 2024")
    }
    .background(Color.black)
}

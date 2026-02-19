//
//  ChartInteractionModifier.swift
//  reelay2
//
//  Created for modular chart interaction functionality
//

import SwiftUI
import Charts
import Combine

// MARK: - Chart Value Tooltip View
struct ChartValueTooltip: View {
    let title: String
    let value: String
    let color: Color
    let xPosition: Double
    let yPosition: Double

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(
                            LinearGradient(
                                colors: [color.opacity(0.6), color.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
        )
        .shadow(color: color.opacity(0.4), radius: 12, x: 0, y: 6)
    }
}

// MARK: - Chart Data Protocol
protocol ChartDataItem {
    var displayLabel: String { get }
    var displayValue: String { get }
    var xValue: Double { get }
    var yValue: Int { get }
}

// MARK: - Accurate Chart Selection Modifier
struct AccurateChartSelectionModifier<DataItem: ChartDataItem>: ViewModifier {
    let data: [DataItem]
    let color: Color
    @Binding var selectedValue: Double?

    func body(content: Content) -> some View {
        content
            .chartXSelection(value: $selectedValue)
            .chartAngleSelection(value: $selectedValue)
            .sensoryFeedback(.selection, trigger: selectedValue)
    }
}

extension View {
    func accurateChartSelection<DataItem: ChartDataItem>(
        data: [DataItem],
        color: Color,
        selectedValue: Binding<Double?>
    ) -> some View {
        self.modifier(AccurateChartSelectionModifier(data: data, color: color, selectedValue: selectedValue))
    }
}

// MARK: - Conformance Extensions for Existing Data Types

extension RatingDistribution: ChartDataItem {
    var displayLabel: String {
        "\(String(format: "%.1f", ratingValue))★"
    }

    var displayValue: String {
        "\(count) films (\(String(format: "%.1f", percentage))%)"
    }

    var xValue: Double {
        ratingValue
    }

    var yValue: Int {
        count
    }
}

extension FilmsByReleaseYear: ChartDataItem {
    var displayLabel: String {
        String(year)
    }

    var displayValue: String {
        "\(count) films (\(String(format: "%.1f", percentage))%)"
    }

    var xValue: Double {
        Double(year)
    }

    var yValue: Int {
        count
    }
}

extension FilmsByDecade: ChartDataItem {
    var displayLabel: String {
        "\(decade)s"
    }

    var displayValue: String {
        "\(count) films (\(String(format: "%.1f", percentage))%)"
    }

    var xValue: Double {
        Double(decade)
    }

    var yValue: Int {
        count
    }
}

extension DayOfWeekPattern: ChartDataItem {
    var displayLabel: String {
        dayOfWeek
    }

    var displayValue: String {
        "\(count) films (\(String(format: "%.1f", percentage))%)"
    }

    var xValue: Double {
        Double(dayNumber)
    }

    var yValue: Int {
        count
    }
}

extension FilmsPerYear: ChartDataItem {
    var displayLabel: String {
        "\(year)"
    }

    var displayValue: String {
        "\(count) films"
    }

    var xValue: Double {
        Double(year)
    }

    var yValue: Int {
        count
    }
}

extension FilmsPerMonth: ChartDataItem {
    var displayLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        return formatter.shortMonthSymbols[month - 1]
    }

    var displayValue: String {
        "\(count) films"
    }

    var xValue: Double {
        Double(month)
    }

    var yValue: Int {
        count
    }
}

extension WeeklyFilmsData: ChartDataItem {
    var displayLabel: String {
        weekLabel
    }

    var displayValue: String {
        "\(count) films"
    }

    var xValue: Double {
        Double(weekNumber)
    }

    var yValue: Int {
        count
    }
}

extension AverageStarRatingPerYear: ChartDataItem {
    var displayLabel: String {
        String(year)
    }

    var displayValue: String {
        String(format: "%.2f★ (%d films)", averageStarRating, filmCount)
    }

    var xValue: Double {
        Double(year)
    }

    var yValue: Int {
        filmCount
    }
}

extension AverageDetailedRatingPerYear: ChartDataItem {
    var displayLabel: String {
        String(year)
    }

    var displayValue: String {
        String(format: "%.1f/100 (%d films)", averageDetailedRating, filmCount)
    }

    var xValue: Double {
        Double(year)
    }

    var yValue: Int {
        filmCount
    }
}
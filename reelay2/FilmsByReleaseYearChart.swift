//
//  FilmsByReleaseYearChart.swift
//  reelay2
//
//  Bar chart showing logged films grouped by their release year.
//

import SwiftUI
import Charts

struct FilmsByReleaseYearChart: View {
    @Environment(\.colorScheme) private var colorScheme
    let filmsByReleaseYear: [FilmsByReleaseYear]
    var filteredYear: Int? = nil  // nil = all-time, non-nil = year-filtered
    @State private var selectedYear: Double?

    // MARK: - Computed Properties

    private var totalFilms: Int {
        filmsByReleaseYear.reduce(0) { $0 + $1.count }
    }

    private var maxCount: Int {
        filmsByReleaseYear.map { $0.count }.max() ?? 0
    }

    private var yearRange: (min: Int, max: Int) {
        guard !filmsByReleaseYear.isEmpty else { return (1990, 2025) }
        let years = filmsByReleaseYear.map { $0.year }
        return (years.min() ?? 1990, years.max() ?? 2025)
    }

    /// Dynamically compute axis tick values based on year span
    private var yearAxisValues: [Int] {
        let range = yearRange
        let span = range.max - range.min

        let interval: Int
        if span <= 5 {
            interval = 1
        } else if span <= 12 {
            interval = 2
        } else if span <= 25 {
            interval = 5
        } else if span <= 60 {
            interval = 10
        } else {
            interval = 20
        }

        // Round the start down to the nearest interval multiple for clean labels
        let alignedStart = (range.min / interval) * interval
        var values: [Int] = []
        var current = alignedStart
        while current <= range.max {
            if current >= range.min {
                values.append(current)
            }
            current += interval
        }

        // Always include the max year if it's not already there
        if let last = values.last, last < range.max {
            values.append(range.max)
        }

        return values
    }

    private var selectedItem: FilmsByReleaseYear? {
        guard let year = selectedYear else { return nil }
        // Snap to nearest data point
        let roundedYear = Int(year.rounded())
        return filmsByReleaseYear.first { $0.year == roundedYear }
    }

    private var highestYear: FilmsByReleaseYear? {
        filmsByReleaseYear.max(by: { $0.count < $1.count })
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            headerSection

            // Chart
            chartSection

            // Tooltip / Selection info
            if let item = selectedItem {
                selectionTooltip(for: item)
            }

            // Highest-year pill
            if selectedItem == nil, let top = highestYear {
                highestYearPill(for: top)
            }
        }
        .padding(12)
        .background(cardBackground)
        .overlay(cardBorder)
    }

    // MARK: - Subviews

    private var chartTitle: String {
        if let year = filteredYear {
            return "Release Years (\(String(year)))"
        }
        return "Films by Release Year"
    }

    private var headerSection: some View {
        HStack {
            Image(systemName: "film.stack")
                .foregroundColor(.cyan)
            Text(chartTitle)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(Color.adaptiveText(scheme: colorScheme))
            Spacer()
            Text("\(totalFilms) films")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
    }

    /// Points per year on the X axis – ~3.3pt fits the full 1908–2025 span on screen
    private let pointsPerYear: CGFloat = 3.3

    /// Minimum chart width so small data sets still look good
    private let minimumChartWidth: CGFloat = 300

    /// Computed scroll content width based on the full year span
    private var scrollContentWidth: CGFloat {
        let span = CGFloat(yearRange.max - yearRange.min + 2)
        return max(span * pointsPerYear, minimumChartWidth)
    }

    /// Whether the chart needs scrolling
    private var needsScroll: Bool {
        let span = yearRange.max - yearRange.min
        return span > 40
    }

    private var chartSection: some View {
        HStack(alignment: .top, spacing: 0) {
            // Pinned Y-axis column
            yAxisLabels
                .frame(width: 32)

            // Scrollable (or static) chart area
            if needsScroll {
                ScrollView(.horizontal, showsIndicators: true) {
                    chartContent
                        .frame(width: scrollContentWidth, height: 200)
                }
                .defaultScrollAnchor(.trailing)
            } else {
                chartContent
                    .frame(height: 200)
            }
        }
        .padding(.horizontal, 12)
    }

    /// The actual Swift Charts view, used inside or outside a ScrollView
    private var chartContent: some View {
        Chart(filmsByReleaseYear, id: \.year) { item in
            BarMark(
                x: .value("Release Year", item.year),
                y: .value("Count", item.count),
                width: .fixed(2)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [.cyan, .blue],
                    startPoint: .bottom,
                    endPoint: .top
                )
            )
            .cornerRadius(1)
            .opacity(barOpacity(for: item))

            // Visual indicator on selected bar
            if let sel = selectedYear, Int(sel.rounded()) == item.year {
                RuleMark(x: .value("Selected", item.year))
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .foregroundStyle(.cyan.opacity(0.5))
                    .annotation(position: .top, spacing: 1) {
                        Text("\(item.count)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.cyan)
                    }
            }
        }
        .chartXAxis {
            AxisMarks(values: scrollableAxisValues) { value in
                AxisValueLabel {
                    if let yr = value.as(Int.self) {
                        Text("'\(String(yr).suffix(2))")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundColor(.primary)
                    }
                }
            }
        }
        .chartXScale(domain: (yearRange.min - 1)...(yearRange.max + 1))
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                    .foregroundStyle(.gray.opacity(0.2))
                // Hide labels inside chart – the pinned column shows them
                AxisValueLabel {
                    Text("")
                }
            }
        }
        .chartYScale(domain: 0...(maxCount + max(maxCount / 5, 2)))
        .chartXSelection(value: $selectedYear)
        .sensoryFeedback(.selection, trigger: selectedYear)
    }

    /// Axis tick values tuned for the scrollable width
    private var scrollableAxisValues: [Int] {
        if needsScroll {
            // Label every 10 years for a compact, readable axis
            let range = yearRange
            let alignedStart = (range.min / 10) * 10
            var values: [Int] = []
            var current = alignedStart
            while current <= range.max {
                if current >= range.min {
                    values.append(current)
                }
                current += 10
            }
            if let last = values.last, last < range.max {
                values.append(range.max)
            }
            return values
        }
        return yearAxisValues
    }

    /// Pinned Y-axis labels that sit outside the scroll area
    private var yAxisLabels: some View {
        VStack {
            Text("\(maxCount + max(maxCount / 5, 2))")
                .font(.system(size: 10, design: .rounded))
                .foregroundColor(.secondary)
            Spacer()
            Text("0")
                .font(.system(size: 10, design: .rounded))
                .foregroundColor(.secondary)
        }
        .frame(height: 200)
        .padding(.top, 4)
    }

    private func selectionTooltip(for item: FilmsByReleaseYear) -> some View {
        HStack {
            Spacer()
            VStack(spacing: 2) {
                Text(String(item.year))
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                Text("\(item.count) film\(item.count == 1 ? "" : "s") (\(String(format: "%.1f", item.percentage))%)")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
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
                                    colors: [.cyan.opacity(0.6), .blue.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
            )
            .shadow(color: .cyan.opacity(0.4), radius: 12, x: 0, y: 6)
            Spacer()
        }
        .padding(.horizontal, 12)
    }

    private func highestYearPill(for top: FilmsByReleaseYear) -> some View {
        HStack {
            Spacer()
            Text("\(String(top.year)) - \(top.count) films")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [.cyan.opacity(0.8), .blue.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
            Spacer()
        }
        .padding(.horizontal, 12)
    }

    // MARK: - Helpers

    private func barOpacity(for item: FilmsByReleaseYear) -> Double {
        guard let sel = selectedYear else { return 1.0 }
        return Int(sel.rounded()) == item.year ? 0.7 : 1.0
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 22)
            .fill(
                LinearGradient(
                    colors: [
                        Color.blue.opacity(0.05),
                        Color.cyan.opacity(0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 22)
            .stroke(
                LinearGradient(
                    colors: [
                        Color.blue.opacity(0.5),
                        Color.cyan.opacity(0.5)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 0.5
            )
    }
}

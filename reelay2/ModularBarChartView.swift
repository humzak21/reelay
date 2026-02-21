import SwiftUI
import Charts

enum ModularChartType: String, CaseIterable {
    case ratingDistribution = "Ratings Distribution"
    case detailedRatingDistribution = "Detailed Rating Distribution"
    case filmsPerYear = "Films Per Year"
    case dayOfWeek = "Films by Day of the Week"
    case filmsPerWeek = "Films Per Week"
    case avgStarRating = "Avg Star Rating / Year"
    case avgDetailedRating = "Avg Detailed Rating / Year"
    case filmsByReleaseYear = "Films by Release Year"
    case filmsByDecade = "Films by Decade"
    case filmsPerMonth = "Films Per Month"
}

struct ModularBarChartView: View {
    @Environment(\.colorScheme) private var colorScheme
    
    let ratingDistribution: [RatingDistribution]
    let detailedRatingDistribution: [DetailedRatingDistribution]
    let filmsPerYear: [FilmsPerYear]
    let dayOfWeekPatterns: [DayOfWeekPattern]
    let weeklyFilmsData: [WeeklyFilmsData]
    let averageStarRatingsPerYear: [AverageStarRatingPerYear]
    let averageDetailedRatingsPerYear: [AverageDetailedRatingPerYear]
    let filmsByReleaseYear: [FilmsByReleaseYear]
    let filmsByDecade: [FilmsByDecade]
    let filmsPerMonth: [FilmsPerMonth]
    
    let selectedYear: Int?
    
    @State private var selectedChartType: ModularChartType = .ratingDistribution
    
    var availableCharts: [ModularChartType] {
        var charts: [ModularChartType] = [.ratingDistribution, .detailedRatingDistribution]
        if selectedYear == nil {
            charts.append(.filmsPerYear)
        }
        charts.append(.dayOfWeek)
        if selectedYear != nil {
            charts.append(.filmsPerWeek)
        }
        if selectedYear == nil {
            charts.append(.avgStarRating)
            charts.append(.avgDetailedRating)
        }
        charts.append(.filmsByReleaseYear)
        charts.append(.filmsByDecade)
        charts.append(.filmsPerMonth)
        return charts
    }
    
    private var canNavigateBetweenCharts: Bool {
        availableCharts.count > 1
    }
    
    private func clampSelectedChartToAvailableSet() {
        let validCharts = availableCharts
        if !validCharts.contains(selectedChartType) {
            selectedChartType = validCharts.first ?? .ratingDistribution
        }
    }
    
    private func moveSelection(by delta: Int) {
        let charts = availableCharts
        guard !charts.isEmpty else { return }
        guard let currentIndex = charts.firstIndex(of: selectedChartType) else {
            selectedChartType = charts.first ?? .ratingDistribution
            return
        }
        
        let chartCount = charts.count
        let normalizedDelta = ((delta % chartCount) + chartCount) % chartCount
        let targetIndex = (currentIndex + normalizedDelta) % chartCount
        guard targetIndex != currentIndex else { return }
        selectedChartType = charts[targetIndex]
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Button {
                    moveSelection(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.headline.weight(.semibold))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .foregroundColor(canNavigateBetweenCharts ? .teal : .secondary.opacity(0.6))
                .disabled(!canNavigateBetweenCharts)
                
                Menu {
                    ForEach(availableCharts, id: \.self) { type in
                        Button {
                            selectedChartType = type
                        } label: {
                            if type == selectedChartType {
                                Label(type.rawValue, systemImage: "checkmark")
                            } else {
                                Text(type.rawValue)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(selectedChartType.rawValue)
                            .font(.headline)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .tint(.primary)
                
                Button {
                    moveSelection(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.headline.weight(.semibold))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .foregroundColor(canNavigateBetweenCharts ? .teal : .secondary.opacity(0.6))
                .disabled(!canNavigateBetweenCharts)
            }
            .frame(maxWidth: .infinity)
            
            // Render specific chart based on selection
            Group {
                switch selectedChartType {
                case .ratingDistribution:
                    if ratingDistribution.isEmpty {
                        Text("No data available")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 40)
                    } else {
                        RatingDistributionChart(distribution: ratingDistribution)
                    }
                case .detailedRatingDistribution:
                    if detailedRatingDistribution.contains(where: { $0.count > 0 }) {
                        DetailedRatingDistributionChart(distribution: detailedRatingDistribution)
                    } else {
                        Text("No data available")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 40)
                    }
                case .filmsPerYear:
                    if filmsPerYear.isEmpty {
                        Text("No data available")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 40)
                    } else {
                        FilmsPerYearChart(filmsPerYear: filmsPerYear)
                    }
                case .dayOfWeek:
                    if dayOfWeekPatterns.isEmpty {
                        Text("No data available")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 40)
                    } else {
                        DayOfWeekChart(dayOfWeekPatterns: dayOfWeekPatterns)
                    }
                case .filmsPerWeek:
                    if let year = selectedYear, !weeklyFilmsData.isEmpty {
                        WeeklyFilmsChart(weeklyData: weeklyFilmsData, selectedYear: year)
                    } else {
                        Text("No data available")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 40)
                    }
                case .avgStarRating:
                    if averageStarRatingsPerYear.isEmpty {
                        Text("No data available")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 40)
                    } else {
                        AverageStarRatingPerYearChart(averageStarRatings: averageStarRatingsPerYear)
                    }
                case .avgDetailedRating:
                    if averageDetailedRatingsPerYear.isEmpty {
                        Text("No data available")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 40)
                    } else {
                        AverageDetailedRatingPerYearChart(averageDetailedRatings: averageDetailedRatingsPerYear)
                    }
                case .filmsByReleaseYear:
                    if filmsByReleaseYear.isEmpty {
                        Text("No data available")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 40)
                    } else {
                        if let year = selectedYear {
                            FilmsByReleaseYearChart(filmsByReleaseYear: filmsByReleaseYear, filteredYear: year)
                        } else {
                            FilmsByReleaseYearChart(filmsByReleaseYear: filmsByReleaseYear)
                        }
                    }
                case .filmsByDecade:
                    if filmsByDecade.isEmpty {
                        Text("No data available")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 40)
                    } else {
                        FilmsByDecadeChart(filmsByDecade: filmsByDecade)
                    }
                case .filmsPerMonth:
                    if filmsPerMonth.isEmpty {
                        Text("No data available")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 40)
                    } else {
                        FilmsPerMonthChart(filmsPerMonth: filmsPerMonth)
                    }
                }
            }
            .transition(.opacity)
            .animation(.easeInOut, value: selectedChartType)
        }
        .onAppear {
            clampSelectedChartToAvailableSet()
        }
        .onChange(of: selectedYear) { _, _ in
            clampSelectedChartToAvailableSet()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.teal.opacity(0.05))
        )
    }
}

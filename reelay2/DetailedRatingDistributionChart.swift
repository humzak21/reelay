import SwiftUI
import Charts

private enum DetailedRatingDistributionMode: String, CaseIterable, Identifiable {
    case expanded
    case condensed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .expanded:
            return "0-100"
        case .condensed:
            return "By 10s"
        }
    }
}

private struct DetailedRatingChartBucket: Identifiable {
    let lowerBound: Int
    let upperBound: Int
    let count: Int

    var id: Int { lowerBound }

    var condensedLabel: String {
        if lowerBound == 100 { return "100" }
        return "\(lowerBound)s"
    }
}

struct DetailedRatingDistributionChart: View {
    @Environment(\.colorScheme) private var colorScheme

    let distribution: [DetailedRatingDistribution]

    @State private var mode: DetailedRatingDistributionMode = .expanded
    @State private var selectedBucketStart: Int?

    private var normalizedDistribution: [DetailedRatingDistribution] {
        var countsByRating: [Int: Int] = [:]
        for item in distribution {
            countsByRating[item.ratingValue, default: 0] += item.count
        }

        return (0...100).map { rating in
            DetailedRatingDistribution(
                ratingValue: rating,
                countFilms: countsByRating[rating, default: 0]
            )
        }
    }

    private var expandedBuckets: [DetailedRatingChartBucket] {
        normalizedDistribution.map {
            DetailedRatingChartBucket(lowerBound: $0.ratingValue, upperBound: $0.ratingValue, count: $0.count)
        }
    }

    private var condensedBuckets: [DetailedRatingChartBucket] {
        stride(from: 0, through: 100, by: 10).map { start in
            let end = min(start + 9, 100)
            let count = normalizedDistribution
                .filter { $0.ratingValue >= start && $0.ratingValue <= end }
                .reduce(0) { $0 + $1.count }

            return DetailedRatingChartBucket(lowerBound: start, upperBound: end, count: count)
        }
    }

    private var activeBuckets: [DetailedRatingChartBucket] {
        mode == .expanded ? expandedBuckets : condensedBuckets
    }

    private var totalRatedFilms: Int {
        normalizedDistribution.reduce(0) { $0 + $1.count }
    }

    private var hasAnyData: Bool {
        totalRatedFilms > 0
    }

    private var maxCount: Int {
        activeBuckets.map(\.count).max() ?? 0
    }

    private var mostCommonBucket: DetailedRatingChartBucket? {
        activeBuckets.max { lhs, rhs in
            if lhs.count == rhs.count {
                return lhs.lowerBound > rhs.lowerBound
            }
            return lhs.count < rhs.count
        }
    }

    private var selectedBucket: DetailedRatingChartBucket? {
        guard let selectedBucketStart else { return nil }

        if mode == .expanded {
            return activeBuckets.first { $0.lowerBound == max(0, min(100, selectedBucketStart)) }
        }

        let snapped = min(100, max(0, (selectedBucketStart / 10) * 10))
        return activeBuckets.first { $0.lowerBound == snapped }
    }

    private var xAxisValues: [Int] {
        if mode == .expanded {
            return Array(stride(from: 0, through: 100, by: 10))
        }

        return activeBuckets.map(\.lowerBound)
    }

    private var xDomain: ClosedRange<Int> {
        mode == .expanded ? (-1...101) : (-5...105)
    }

    private var yDomain: ClosedRange<Int> {
        let padding = max(5, Int(Double(maxCount) * 0.12))
        return 0...(maxCount + padding)
    }

    private func bucketLabel(_ bucket: DetailedRatingChartBucket) -> String {
        if mode == .expanded {
            return "\(bucket.lowerBound)"
        }

        return bucket.condensedLabel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                HStack(spacing: 8) {
                    Image(systemName: "chart.bar.xaxis")
                        .foregroundColor(.orange)
                    Text("Detailed Ratings")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(Color.adaptiveText(scheme: colorScheme))
                }

                Spacer()

                Picker("Distribution Mode", selection: $mode) {
                    ForEach(DetailedRatingDistributionMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 180)
            }
            .padding(.horizontal, 12)

            if hasAnyData {
                Chart(activeBuckets, id: \.id) { item in
                    BarMark(
                        x: .value("Detailed Rating", item.lowerBound),
                        y: .value("Count", item.count),
                        width: .fixed(2)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.yellow, .orange],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .cornerRadius(1)
                    .opacity(selectedBucket?.id == item.id ? 0.7 : 1.0)

                    if let selectedBucket, selectedBucket.id == item.id {
                        RuleMark(x: .value("Selected", item.lowerBound))
                            .lineStyle(StrokeStyle(lineWidth: 2))
                            .foregroundStyle(.orange.opacity(0.5))
                            .annotation(position: .top, spacing: 1) {
                                Text("\(bucketLabel(item)) - \(item.count)")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.orange)
                            }
                    }
                }
                .frame(height: 210)
                .chartXAxis {
                    AxisMarks(values: xAxisValues) { value in
                        AxisValueLabel {
                            if let rating = value.as(Int.self) {
                                if mode == .expanded {
                                    Text("\(rating)")
                                        .font(.system(size: 10, weight: .medium, design: .rounded))
                                        .foregroundColor(.primary)
                                } else {
                                    Text(rating == 100 ? "100" : "\(rating)s")
                                        .font(.system(size: 10, weight: .medium, design: .rounded))
                                        .foregroundColor(.primary)
                                }
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                            .foregroundStyle(.gray.opacity(0.2))
                        AxisValueLabel()
                            .font(.system(size: 10, design: .rounded))
                    }
                }
                .chartXScale(domain: xDomain)
                .chartYScale(domain: yDomain)
                .chartXSelection(value: $selectedBucketStart)
                .padding(.horizontal, 12)

                if let selectedBucket {
                    HStack {
                        Spacer()
                        Text("\(bucketLabel(selectedBucket)) - \(selectedBucket.count)")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.orange)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                }
            } else {
                Text("No detailed ratings available")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 48)
            }

            if let mostCommonBucket, hasAnyData {
                HStack {
                    Spacer()
                    Text("Most common rating: \(bucketLabel(mostCommonBucket)) - \(mostCommonBucket.count)")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(
                                    LinearGradient(
                                        colors: [.yellow.opacity(0.85), .orange.opacity(0.85)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                    Spacer()
                }
                .padding(.horizontal, 12)
            }

            HStack {
                Spacer()
                Text("\(totalRatedFilms) unique film\(totalRatedFilms == 1 ? "" : "s") with detailed ratings")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 12)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.orange.opacity(0.06),
                            Color.yellow.opacity(0.06)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .onChange(of: mode) { _, _ in
            selectedBucketStart = nil
        }
    }
}

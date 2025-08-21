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
    let position: CGPoint
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.9))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(color.opacity(0.5), lineWidth: 1)
                )
        )
        .shadow(color: color.opacity(0.3), radius: 8, x: 0, y: 4)
        .position(x: position.x, y: max(40, position.y - 60)) // Position above the touch point
    }
}

// MARK: - Chart Data Protocol
protocol ChartDataItem {
    var displayLabel: String { get }
    var displayValue: String { get }
    var xValue: Double { get }
}

// MARK: - Chart Long Press State
class ChartLongPressState: ObservableObject {
    @Published var isPressed = false
    @Published var pressLocation: CGPoint = .zero
    @Published var selectedItem: (label: String, value: String)?
    
    func reset() {
        isPressed = false
        selectedItem = nil
    }
}

// MARK: - Chart Long Press Modifier
struct ChartLongPressModifier<DataItem: ChartDataItem>: ViewModifier {
    let data: [DataItem]
    let color: Color
    let chartProxy: ChartProxy?
    @StateObject private var longPressState = ChartLongPressState()
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(
                            LongPressGesture(minimumDuration: 0.3)
                                .sequenced(before: DragGesture(minimumDistance: 0))
                                .onChanged { value in
                                    switch value {
                                    case .first(true):
                                        // Long press started
                                        handleLongPressStart(in: geometry)
                                    case .second(true, let drag):
                                        // Dragging after long press
                                        if let drag = drag {
                                            handleLongPressDrag(location: drag.location, in: geometry)
                                        }
                                    default:
                                        break
                                    }
                                }
                                .onEnded { _ in
                                    handleLongPressEnd()
                                }
                        )
                        .simultaneousGesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    if longPressState.isPressed {
                                        handleLongPressDrag(location: value.location, in: geometry)
                                    }
                                }
                                .onEnded { _ in
                                    if longPressState.isPressed {
                                        handleLongPressEnd()
                                    }
                                }
                        )
                }
            )
            .overlay(
                Group {
                    if longPressState.isPressed,
                       let item = longPressState.selectedItem {
                        ChartValueTooltip(
                            title: item.label,
                            value: item.value,
                            color: color,
                            position: longPressState.pressLocation
                        )
                        .allowsHitTesting(false)
                        .animation(.easeInOut(duration: 0.2), value: longPressState.pressLocation)
                    }
                }
            )
            .sensoryFeedback(.impact(flexibility: .soft), trigger: longPressState.isPressed)
    }
    
    private func handleLongPressStart(in geometry: GeometryProxy) {
        longPressState.isPressed = true
    }
    
    private func handleLongPressDrag(location: CGPoint, in geometry: GeometryProxy) {
        guard let chartProxy = chartProxy,
              let plotFrame = chartProxy.plotFrame else { return }
        
        let frame = geometry[plotFrame]
        let relativeX = location.x - frame.origin.x
        
        guard relativeX >= 0, relativeX <= frame.width, !data.isEmpty else { return }
        
        // Find the closest data point
        let step = frame.width / CGFloat(data.count)
        let index = Int(round(relativeX / max(step, 1)))
        
        guard index >= 0, index < data.count else { return }
        
        let item = data[index]
        longPressState.selectedItem = (label: item.displayLabel, value: item.displayValue)
        longPressState.pressLocation = CGPoint(x: location.x, y: location.y)
    }
    
    private func handleLongPressEnd() {
        // Add a slight delay before hiding to make the interaction feel smoother
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            longPressState.reset()
        }
    }
}

// MARK: - View Extension for Easy Application
extension View {
    func chartLongPress<DataItem: ChartDataItem>(
        data: [DataItem],
        color: Color,
        chartProxy: ChartProxy?
    ) -> some View {
        self.modifier(ChartLongPressModifier(data: data, color: color, chartProxy: chartProxy))
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
}

// MARK: - Alternative Simpler Tooltip for Basic Use Cases
struct SimpleChartTooltip: ViewModifier {
    @Binding var showTooltip: Bool
    let text: String
    let color: Color
    
    func body(content: Content) -> some View {
        content
            .overlay(
                Group {
                    if showTooltip {
                        VStack {
                            Text(text)
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(color.opacity(0.9))
                                )
                                .shadow(radius: 4)
                            Spacer()
                        }
                        .padding(.top, -40)
                        .allowsHitTesting(false)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
            )
    }
}

extension View {
    func simpleTooltip(show: Binding<Bool>, text: String, color: Color) -> some View {
        self.modifier(SimpleChartTooltip(showTooltip: show, text: text, color: color))
    }
}
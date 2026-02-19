//
//  TheaterPlannerView.swift
//  reelay2
//
//  Theater visit planner with two-state layout:
//  - Compact: purple date box + "X films planned next 7 days"
//  - Full: calendar + selected date visit list
//

import SwiftUI
import SDWebImageSwiftUI
import MapKit
import CoreLocation

// MARK: - Planner Detent

enum PlannerDetent: Equatable {
    case compact
    case full
}

// MARK: - Theater Planner View

struct TheaterPlannerView: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var dataManager = DataManager.shared
    
    @Binding var selectedDate: Date
    @Binding var currentCalendarMonth: Date
    var plannerDetent: PlannerDetent
    
    @State private var showingAddVisit = false
    @State private var visitToEdit: TheaterVisit?
    @State private var visitToDelete: TheaterVisit?
    @State private var showingDeleteAlert = false
    
    // Complete & Log Film state
    @State private var showingLogFilm = false
    @State private var visitToLog: TheaterVisit?
    
    // Location manager for driving time estimates
    @StateObject private var locationHelper = LocationHelper()
    
    // Static formatters
    private static let monthYearFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f
    }()
    
    private static let selectedDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f
    }()
    
    private static let dateStringFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
    
    private static let dayNumberFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d"
        return f
    }()
    
    private static let monthAbbrevFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM"
        return f
    }()
    
    var body: some View {
        VStack(spacing: 0) {
            // 1. Compact bar (always visible)
            compactBar
            
            // 2. Full content (calendar + visit list, visible when expanded)
            if plannerDetent == .full {
                VStack(spacing: 12) {
                    calendarHeader
                    
                    calendarGrid
                        .gesture(
                            DragGesture(minimumDistance: 50)
                                .onEnded { value in
                                    let threshold: CGFloat = 50
                                    if value.translation.width > threshold {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            currentCalendarMonth = Calendar.current.date(
                                                byAdding: .month, value: -1,
                                                to: currentCalendarMonth
                                            ) ?? currentCalendarMonth
                                        }
                                    } else if value.translation.width < -threshold {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            currentCalendarMonth = Calendar.current.date(
                                                byAdding: .month, value: 1,
                                                to: currentCalendarMonth
                                            ) ?? currentCalendarMonth
                                        }
                                    }
                                }
                        )
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
                
                selectedDateVisitsHeader
                    .padding(.horizontal, 20)
                
                selectedDateVisitsList
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .sheet(isPresented: $showingAddVisit) {
            AddTheaterVisitView(preselectedDate: selectedDate)
        }
        .sheet(item: $visitToEdit) { visit in
            AddTheaterVisitView(editingVisit: visit)
        }
        .sheet(isPresented: $showingLogFilm) {
            if let visit = visitToLog {
                AddMoviesView(
                    preSelectedMovie: visit.toTMDBMovie(),
                    presetWatchDate: visit.visitDate,
                    presetTags: "Theater"
                )
            }
        }
        .alert("Delete Visit", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let visit = visitToDelete {
                    Task {
                        try? await dataManager.deleteTheaterVisit(id: visit.id)
                    }
                }
            }
        } message: {
            if let visit = visitToDelete {
                Text("Remove '\(visit.title)' visit from your planner?")
            } else {
                Text("")
            }
        }
    }
    
    // MARK: - Compact Bar
    
    @ViewBuilder
    private var compactBar: some View {
        HStack(spacing: 12) {
            // Purple date box
            VStack(spacing: 1) {
                Text(Self.monthAbbrevFormatter.string(from: Date()).uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.85))
                Text(Self.dayNumberFormatter.string(from: Date()))
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(width: 44, height: 44)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.purple)
            )
            
            // Upcoming count text
            VStack(alignment: .leading, spacing: 2) {
                let upcomingCount = visitsInNext7Days()
                if upcomingCount == 0 {
                    Text("No films planned")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(Color.adaptiveText(scheme: colorScheme))
                    Text("next 7 days")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("\(upcomingCount) film\(upcomingCount == 1 ? "" : "s") planned")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(Color.adaptiveText(scheme: colorScheme))
                    Text("next 7 days")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Add button (always accessible)
            Button(action: {
                Task {
                    await dataManager.refreshTheaterVisits()
                    showingAddVisit = true
                }
            }) {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundColor(.purple)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }
    
    // MARK: - Calendar Header
    
    @ViewBuilder
    private var calendarHeader: some View {
        HStack(alignment: .center) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    currentCalendarMonth = Calendar.current.date(
                        byAdding: .month, value: -1,
                        to: currentCalendarMonth
                    ) ?? currentCalendarMonth
                }
            }) {
                Image(systemName: "chevron.left")
                    .foregroundColor(Color.adaptiveText(scheme: colorScheme))
                    .font(.title3)
            }
            
            Spacer()
            
            VStack(spacing: 4) {
                Text(Self.monthYearFormatter.string(from: currentCalendarMonth))
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(Color.adaptiveText(scheme: colorScheme))
                    .onTapGesture(count: 2) {
                        returnToCurrentDate()
                    }
                
                visitCountPill
            }
            
            Spacer()
            
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    currentCalendarMonth = Calendar.current.date(
                        byAdding: .month, value: 1,
                        to: currentCalendarMonth
                    ) ?? currentCalendarMonth
                }
            }) {
                Image(systemName: "chevron.right")
                    .foregroundColor(Color.adaptiveText(scheme: colorScheme))
                    .font(.title3)
            }
        }
        .padding(.horizontal, 8)
    }
    
    // MARK: - Visit Count Pill
    
    @ViewBuilder
    private var visitCountPill: some View {
        let count = visitsInMonth(currentCalendarMonth)
        HStack(spacing: 4) {
            Image(systemName: "ticket.fill")
                .font(.system(size: 9))
            Text("\(count) planned")
                .font(.caption2)
                .fontWeight(.medium)
        }
        .foregroundColor(Color.adaptiveText(scheme: colorScheme).opacity(0.7))
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(colorScheme == .dark ? Color.gray.opacity(0.3) : Color.white)
                .shadow(color: .black.opacity(0.08), radius: 2, x: 0, y: 1)
        )
    }
    
    // MARK: - Calendar Grid
    
    @ViewBuilder
    private var calendarGrid: some View {
        VStack(spacing: 6) {
            // Weekday headers
            HStack {
                ForEach(["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"], id: \.self) { day in
                    Text(day)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Calendar days
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible()), count: 7),
                spacing: 6
            ) {
                ForEach(calendarDays, id: \.self) { date in
                    calendarDayView(for: date)
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .background(colorScheme == .dark ? Color.gray.opacity(0.15) : .white)
        .cornerRadius(14)
    }
    
    private var calendarDays: [Date] {
        let calendar = Calendar.current
        let startOfMonth = calendar.dateInterval(of: .month, for: currentCalendarMonth)?.start ?? currentCalendarMonth
        let startOfCalendar = calendar.dateInterval(of: .weekOfYear, for: startOfMonth)?.start ?? startOfMonth
        
        var days: [Date] = []
        var currentDate = startOfCalendar
        
        for _ in 0..<42 {
            days.append(currentDate)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        return days
    }
    
    @ViewBuilder
    private func calendarDayView(for date: Date) -> some View {
        let calendar = Calendar.current
        let isCurrentMonth = calendar.isDate(date, equalTo: currentCalendarMonth, toGranularity: .month)
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(date)
        let visitsForDay = visitsForDate(date)
        let visitCount = visitsForDay.count
        
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedDate = date
            }
        }) {
            VStack(spacing: 2) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                    .foregroundColor(
                        dayTextColor(isCurrentMonth: isCurrentMonth, isSelected: isSelected, isToday: isToday)
                    )
                
                // Visit dots
                HStack(spacing: 2) {
                    ForEach(0..<min(visitCount, 3), id: \.self) { _ in
                        Circle()
                            .fill(Color.purple.opacity(0.9))
                            .frame(width: 3.5, height: 3.5)
                    }
                    if visitCount > 3 {
                        Text("+")
                            .font(.system(size: 5, weight: .bold))
                            .foregroundColor(.purple.opacity(0.9))
                    }
                }
                .frame(height: 5)
            }
            .frame(width: 34, height: 34)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(dayBackgroundColor(visitCount: visitCount, isSelected: isSelected, isToday: isToday))
            )
        }
        .buttonStyle(PlainButtonStyle())
        .opacity(isCurrentMonth ? 1.0 : 0.3)
    }
    
    // MARK: - Selected Date Visits Header
    
    @ViewBuilder
    private var selectedDateVisitsHeader: some View {
        let visitsForSelectedDate = visitsForDate(selectedDate)
        
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(Self.selectedDateFormatter.string(from: selectedDate))
                    .font(.headline)
                    .foregroundColor(Color.adaptiveText(scheme: colorScheme))
                
                if visitsForSelectedDate.isEmpty {
                    Text("No visits planned")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    Text("\(visitsForSelectedDate.count) visit\(visitsForSelectedDate.count == 1 ? "" : "s") planned")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button(action: {
                Task {
                    await dataManager.refreshTheaterVisits()
                    showingAddVisit = true
                }
            }) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(.purple)
            }
        }
        .padding(.top, 8)
    }
    
    // MARK: - Selected Date Visits List
    
    @ViewBuilder
    private var selectedDateVisitsList: some View {
        let visitsForSelectedDate = visitsForDate(selectedDate).sorted { a, b in
            (a.showtime ?? "") < (b.showtime ?? "")
        }
        
        if visitsForSelectedDate.isEmpty {
            emptyStateView
                .padding(.horizontal, 20)
        } else {
            List {
                ForEach(visitsForSelectedDate) { visit in
                    TheaterVisitRow(
                        visit: visit,
                        locationHelper: locationHelper,
                        onEdit: { visitToEdit = visit },
                        onDelete: {
                            visitToDelete = visit
                            showingDeleteAlert = true
                        },
                        onToggleComplete: {
                            Task {
                                try? await dataManager.toggleTheaterVisitCompleted(
                                    id: visit.id,
                                    completed: !visit.completed
                                )
                            }
                        },
                        onCompleteAndLog: {
                            // Mark as completed first, then open AddMoviesView
                            if !visit.completed {
                                Task {
                                    try? await dataManager.toggleTheaterVisitCompleted(
                                        id: visit.id,
                                        completed: true
                                    )
                                }
                            }
                            visitToLog = visit
                            showingLogFilm = true
                        }
                    )
                    .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 4, trailing: 20))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }
    
    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 10) {
            Image(systemName: "ticket")
                .font(.system(size: 32))
                .foregroundColor(.gray.opacity(0.4))
            
            Text("No visits planned for this day")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: {
                Task {
                    await dataManager.refreshTheaterVisits()
                    showingAddVisit = true
                }
            }) {
                Text("Plan a Visit")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(Color.purple)
                    .cornerRadius(8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
    
    // MARK: - Helper Functions
    
    private func visitsForDate(_ date: Date) -> [TheaterVisit] {
        let dateString = Self.dateStringFormatter.string(from: date)
        return dataManager.theaterVisits.filter { $0.visit_date == dateString }
    }
    
    private func visitsInMonth(_ month: Date) -> Int {
        let calendar = Calendar.current
        return dataManager.theaterVisits.filter { visit in
            guard let visitDate = visit.visitDate else { return false }
            return calendar.isDate(visitDate, equalTo: month, toGranularity: .month)
        }.count
    }
    
    private func visitsInNext7Days() -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let sevenDaysLater = calendar.date(byAdding: .day, value: 7, to: today) else { return 0 }
        let todayString = Self.dateStringFormatter.string(from: today)
        let endString = Self.dateStringFormatter.string(from: sevenDaysLater)
        return dataManager.theaterVisits.filter { visit in
            visit.visit_date >= todayString && visit.visit_date <= endString && !visit.completed
        }.count
    }
    
    private func dayTextColor(isCurrentMonth: Bool, isSelected: Bool, isToday: Bool) -> Color {
        if isSelected { return .white }
        if isToday { return .white }
        if isCurrentMonth { return Color.adaptiveText(scheme: colorScheme) }
        return .gray
    }
    
    private func dayBackgroundColor(visitCount: Int, isSelected: Bool, isToday: Bool) -> Color {
        if isSelected { return .purple }
        if isToday { return .purple.opacity(0.5) }
        if visitCount > 0 {
            return .purple.opacity(min(0.15 + Double(visitCount) * 0.1, 0.4))
        }
        return .clear
    }
    
    private func returnToCurrentDate() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentCalendarMonth = Date()
            selectedDate = Date()
        }
    }
}

// MARK: - Theater Visit Row

struct TheaterVisitRow: View {
    let visit: TheaterVisit
    @ObservedObject var locationHelper: LocationHelper
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onToggleComplete: () -> Void
    let onCompleteAndLog: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var drivingTime: String?
    @State private var isLoadingDrivingTime = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                // Poster
                if let posterURL = visit.posterURL {
                    WebImage(url: posterURL)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 50, height: 75)
                        .cornerRadius(8)
                        .clipped()
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 50, height: 75)
                        .overlay(
                            Image(systemName: "film")
                                .foregroundColor(.gray)
                        )
                }
                
                // Info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(visit.title)
                            .font(.headline)
                            .foregroundColor(Color.adaptiveText(scheme: colorScheme))
                            .strikethrough(visit.completed, color: .gray)
                            .lineLimit(2)
                        
                        if !visit.formattedReleaseYear.isEmpty {
                            Text("(\(visit.formattedReleaseYear))")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        // Completion toggle
                        Button(action: onToggleComplete) {
                            Image(systemName: visit.completed ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(visit.completed ? .green : .gray)
                                .font(.title3)
                        }
                    }
                    
                    // Showtime
                    if let showtime = visit.formattedShowtime {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.caption)
                                .foregroundColor(.purple)
                            Text(showtime)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.purple)
                        }
                    }
                    
                    // Location
                    if let locationName = visit.location_name {
                        Button(action: { openDirections() }) {
                            HStack(spacing: 4) {
                                Image(systemName: "location.fill")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                Text(locationName)
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                    .lineLimit(1)
                            }
                        }
                        
                        // Driving time
                        if let drivingTime = drivingTime {
                            HStack(spacing: 4) {
                                Image(systemName: "car.fill")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text(drivingTime)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        } else if isLoadingDrivingTime {
                            HStack(spacing: 4) {
                                ProgressView()
                                    .scaleEffect(0.6)
                                Text("Calculating drive...")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    // Notes preview
                    if let notes = visit.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .padding(.top, 2)
                    }
                }
            }
            .padding(12)
        }
        .background(colorScheme == .dark ? Color.gray.opacity(0.15) : Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        .opacity(visit.completed ? 0.6 : 1.0)
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
            Button(action: onEdit) {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.orange)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(action: onCompleteAndLog) {
                Label("Log Film", systemImage: "plus.square.on.square")
            }
            .tint(.blue)
            Button(action: onToggleComplete) {
                Label(
                    visit.completed ? "Undo" : "Complete",
                    systemImage: visit.completed ? "arrow.uturn.backward" : "checkmark.circle.fill"
                )
            }
            .tint(.green)
        }
        .contextMenu {
            Button(action: onEdit) {
                Label("Edit Visit", systemImage: "pencil")
            }
            Button(action: onToggleComplete) {
                Label(
                    visit.completed ? "Mark Incomplete" : "Mark Complete",
                    systemImage: visit.completed ? "circle" : "checkmark.circle"
                )
            }
            Button(action: onCompleteAndLog) {
                Label("Complete & Log Film", systemImage: "plus.square.on.square")
            }
            if visit.hasLocation {
                Button(action: openDirections) {
                    Label("Get Directions", systemImage: "map")
                }
            }
            Divider()
            Button(role: .destructive, action: onDelete) {
                Label("Delete Visit", systemImage: "trash")
            }
        }
        .task {
            if visit.hasLocation && !visit.completed {
                await loadDrivingTime()
            }
        }
    }
    
    private func loadDrivingTime() async {
        guard let lat = visit.location_latitude,
              let lon = visit.location_longitude else { return }
        
        await MainActor.run { isLoadingDrivingTime = true }
        
        let time = await locationHelper.getDrivingTime(
            to: CLLocationCoordinate2D(latitude: lat, longitude: lon)
        )
        
        await MainActor.run {
            drivingTime = time
            isLoadingDrivingTime = false
        }
    }
    
    private func openDirections() {
        guard let lat = visit.location_latitude,
              let lon = visit.location_longitude else { return }
        
        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = visit.location_name
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }
}

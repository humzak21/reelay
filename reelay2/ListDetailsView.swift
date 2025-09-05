//
//  ListDetailsView.swift
//  reelay2
//
//  Created by Humza Khalil on 8/4/25.
//

import SwiftUI

struct ListDetailsView: View {
    let list: MovieList
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var dataManager = DataManager.shared
    @State private var isLoading = false
    @State private var showingAddMovies = false
    @State private var showingEditList = false
    @State private var showingEditWatchlist = false
    @State private var showingDeleteAlert = false
    @State private var errorMessage: String?
    @State private var showWatchedFaded = false
    @State private var watchedCount = 0
    @State private var isLoadingProgress = false
    @State private var watchedTmdbIds: Set<Int> = []
    @State private var showSpecialLayout = true
    @State private var currentSortOption: ListSortOption = .sortOrder
    @State private var showingSortMenu = false
    @State private var selectedMovie: Movie?
    @State private var showingMovieDetails = false
    
    private var currentList: MovieList {
        dataManager.movieLists.first(where: { $0.id == list.id }) ?? list
    }

    private var listItems: [ListItem] {
        let items = dataManager.getListItems(currentList)
        return items.sorted(by: currentSortOption, watchedTmdbIds: watchedTmdbIds)
    }
    
    private var isTheaterList: Bool {
        currentList.name.lowercased().contains("theater") || currentList.name.lowercased().contains("theatre")
    }
    
    private var isLookingForwardList: Bool {
        currentList.name.lowercased().contains("looking forward")
    }
    
    private var firstMovieBackdropURL: URL? {
        // Always prefer the list item's stored backdrop path for the hero image
        return listItems.first?.backdropURL
    }
    
    private var watchProgress: Double {
        guard !listItems.isEmpty else { return 0.0 }
        return Double(watchedCount) / Double(listItems.count)
    }
    
    private var watchProgressPercentage: Int {
        return Int(watchProgress * 100)
    }
    
    private var appBackground: Color {
        colorScheme == .dark ? .black : Color(.systemBackground)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 0) {
                    // Backdrop Section
                    backdropSection
                    
                    // List Info Section (similar to watch date section)
                    listInfoSection
                    
                    // Progress Section
                    progressSection
                    
                    // Tags Section
                    if !currentList.tagsArray.isEmpty {
                        tagsSection
                    }
                    
                    // Content Section
                    VStack(spacing: 16) {
                        if listItems.isEmpty {
                            emptyStateView
                        } else {
                            if (isLookingForwardList || isTheaterList) && showSpecialLayout {
                                if isLookingForwardList {
                                    lookingForwardCalendarView
                                } else {
                                    theaterTicketsView
                                }
                            } else {
                                moviesGridView
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(appBackground)
                    
                    Spacer(minLength: 100)
                }
            }
            .background(appBackground.ignoresSafeArea())
            .ignoresSafeArea(edges: .top)
            
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close", systemImage: "xmark") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                    .fontWeight(.medium)
                }

                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    if isLookingForwardList || isTheaterList {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                showSpecialLayout.toggle()
                            }
                        }) {
                            Image(systemName: showSpecialLayout ? "square.grid.3x3" : (isLookingForwardList ? "calendar" : "ticket"))
                                .foregroundColor(.white)
                                .fontWeight(.medium)
                        }
                        .accessibilityLabel(showSpecialLayout ? "Show Classic View" : (isLookingForwardList ? "Show Calendar View" : "Show Ticket View"))
                    }

                    Button(action: {
                        showWatchedFaded.toggle()
                    }) {
                        Image(systemName: showWatchedFaded ? "eye.slash.fill" : "eye.fill")
                            .foregroundColor(.white)
                            .fontWeight(.medium)
                    }

                    Menu {
                        ForEach(ListSortOption.allCases) { option in
                            Button(action: {
                                currentSortOption = option
                            }) {
                                Label(option.displayName, systemImage: option.systemImage)
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                            .foregroundColor(.white)
                            .fontWeight(.medium)
                    }

                    Menu {
                        if currentList.id != SupabaseWatchlistService.watchlistListId {
                            Button("Add Movies", systemImage: "plus") {
                                showingAddMovies = true
                            }
                            Button("Edit List", systemImage: "pencil") {
                                showingEditList = true
                            }
                            if list.pinned {
                                Button("Unpin List", systemImage: "pin.slash") {
                                    Task { await unpinList() }
                                }
                            } else {
                                Button("Pin List", systemImage: "pin.fill") {
                                    Task { await pinList() }
                                }
                            }
                            Divider()
                            Button("Delete List", role: .destructive) {
                                showingDeleteAlert = true
                            }
                        } else {
                            // Watchlist actions
                            Button("Edit Watchlist", systemImage: "pencil") {
                                showingEditWatchlist = true
                            }
                            Button("Refresh", systemImage: "arrow.clockwise") {
                                Task { await dataManager.refreshWatchlist() }
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundColor(.white)
                            .fontWeight(.medium)
                    }
                }
            }
            .sheet(isPresented: $showingAddMovies) {
                AddMoviesToListView(list: currentList)
            }
            .sheet(isPresented: $showingEditList) {
                EditListView(list: currentList)
            }
            .sheet(isPresented: $showingEditWatchlist) {
                WatchlistEditView()
            }
            .sheet(isPresented: $showingMovieDetails) {
                if let selectedMovie = selectedMovie {
                    MovieDetailsView(movie: selectedMovie)
                }
            }
            .alert("Delete List", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    Task {
                        await deleteList()
                    }
                }
            } message: {
                Text("Are you sure you want to delete '\(currentList.name)'? This action cannot be undone.")
            }
            .task {
                // Force-reload items from Supabase to capture new movie_release_date values
                _ = try? await dataManager.reloadItemsForList(list.id)
                await loadWatchedCount()
            }
        }
    }
    
    // MARK: - Looking Forward Calendar State
    @State private var lfSelectedDate: Date = Date()
    @State private var lfCurrentCalendarMonth: Date = Date()
    
    // MARK: - Looking Forward Calendar View
    @ViewBuilder
    private var lookingForwardCalendarView: some View {
        VStack(spacing: 16) {
            // Calendar header
            lfCalendarHeader
            
            // Calendar grid
            lfCalendarGrid
                .gesture(
                    DragGesture()
                        .onEnded { value in
                            let threshold: CGFloat = 50
                            if value.translation.width > threshold {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    lfCurrentCalendarMonth = Calendar.current.date(byAdding: .month, value: -1, to: lfCurrentCalendarMonth) ?? lfCurrentCalendarMonth
                                }
                            } else if value.translation.width < -threshold {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    lfCurrentCalendarMonth = Calendar.current.date(byAdding: .month, value: 1, to: lfCurrentCalendarMonth) ?? lfCurrentCalendarMonth
                                }
                            }
                        }
                )
            
            // Monthly releases section
            lfMonthlyReleasesSection
        }
        .padding(.horizontal, 20)
    }
    
    @ViewBuilder
    private var lfCalendarHeader: some View {
        HStack(alignment: .center) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    lfCurrentCalendarMonth = Calendar.current.date(byAdding: .month, value: -1, to: lfCurrentCalendarMonth) ?? lfCurrentCalendarMonth
                }
            }) {
                Image(systemName: "chevron.left")
                    .foregroundColor(.white)
                    .font(.title2)
            }
            
            Spacer()
            
            VStack(spacing: 6) {
                Text(lfMonthYearFormatter.string(from: lfCurrentCalendarMonth))
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .onTapGesture(count: 2) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            lfCurrentCalendarMonth = Date()
                            lfSelectedDate = Date()
                        }
                    }
                lfMonthCountPill
            }
            
            Spacer()
            
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    lfCurrentCalendarMonth = Calendar.current.date(byAdding: .month, value: 1, to: lfCurrentCalendarMonth) ?? lfCurrentCalendarMonth
                }
            }) {
                Image(systemName: "chevron.right")
                    .foregroundColor(.white)
                    .font(.title2)
            }
        }
        .padding(.horizontal, 8)
    }
    
    @ViewBuilder
    private var lfCalendarGrid: some View {
        VStack(spacing: 8) {
            // Weekday headers
            HStack {
                ForEach(["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"], id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Calendar days
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                ForEach(lfCalendarDays, id: \.self) { date in
                    lfCalendarDayView(for: date)
                }
            }
        }
        .padding(.vertical, 12)
        .background(Color(.secondarySystemFill))
        .cornerRadius(16)
    }
    
    private var lfCalendarDays: [Date] {
        let calendar = Calendar.current
        let startOfMonth = calendar.dateInterval(of: .month, for: lfCurrentCalendarMonth)?.start ?? lfCurrentCalendarMonth
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
    private func lfCalendarDayView(for date: Date) -> some View {
        let calendar = Calendar.current
        let isCurrentMonth = calendar.isDate(date, equalTo: lfCurrentCalendarMonth, toGranularity: .month)
        let isSelected = calendar.isDate(date, inSameDayAs: lfSelectedDate)
        let isToday = calendar.isDateInToday(date)
        let itemsForDay = listItemsForDate(date)
        let count = itemsForDay.count
        
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                lfSelectedDate = date
            }
        }) {
            VStack(spacing: 2) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 14, weight: isSelected ? .bold : .medium))
                    .foregroundColor(lfDayTextColor(isCurrentMonth: isCurrentMonth, isSelected: isSelected, isToday: isToday))
                HStack(spacing: 2) {
                    ForEach(0..<min(count, 3), id: \.self) { _ in
                        Circle()
                            .fill(Color.white.opacity(0.8))
                            .frame(width: 3, height: 3)
                    }
                    if count > 3 {
                        Text("+")
                            .font(.system(size: 6, weight: .bold))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .frame(height: 6)
            }
            .frame(width: 36, height: 36)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(lfDayBackgroundColor(count: count, isSelected: isSelected, isToday: isToday))
            )
        }
        .buttonStyle(PlainButtonStyle())
        .opacity(isCurrentMonth ? 1.0 : 0.3)
    }
    
    @ViewBuilder
    private var lfMonthlyReleasesSection: some View {
        let monthlyItems = listItemsForMonth(lfCurrentCalendarMonth).sorted { a, b in
            // Sort by release date first, then by title
            if let dateA = a.movieReleaseDate, let dateB = b.movieReleaseDate,
               let parsedDateA = DateFormatter.movieDateFormatter.date(from: dateA),
               let parsedDateB = DateFormatter.movieDateFormatter.date(from: dateB) {
                return parsedDateA < parsedDateB
            }
            return a.movieTitle < b.movieTitle
        }
        
        let unknownItems = listItems.filter {
            guard let s = $0.movieReleaseDate?.trimmingCharacters(in: .whitespacesAndNewlines) else { return true }
            return s.isEmpty
        }
        
        VStack(alignment: .leading, spacing: 16) {
            // Monthly releases
            if !monthlyItems.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Releasing in \(lfMonthYearFormatter.string(from: lfCurrentCalendarMonth))")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        Spacer()
                        Text("\(monthlyItems.count)")
                            .foregroundColor(.gray)
                    }
                    
                    LazyVStack(spacing: 8) {
                        ForEach(monthlyItems) { item in
                            lfTappableReleaseRow(item: item)
                        }
                    }
                }
            }
            
            // Items without release dates
            if !unknownItems.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("No Release Date Yet")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        Spacer()
                        Text("\(unknownItems.count)")
                            .foregroundColor(.gray)
                    }
                    
                    LazyVStack(spacing: 8) {
                        ForEach(unknownItems) { item in
                            lfTappableReleaseRow(item: item)
                        }
                    }
                }
            }
        }
        .padding(.top, 8)
    }
    
    @ViewBuilder
    private func lfTappableReleaseRow(item: ListItem) -> some View {
        Button(action: {
            Task {
                await loadMovieDetailsForItem(item)
            }
        }) {
            HStack(spacing: 12) {
                AsyncImage(url: URL(string: item.moviePosterUrl ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle().fill(Color.gray.opacity(0.3))
                }
                .frame(width: 40, height: 60)
                .cornerRadius(6)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.movieTitle)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    if let year = item.movieYear {
                        Text(String(year))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    if let releaseDate = item.movieReleaseDate,
                       let date = DateFormatter.movieDateFormatter.date(from: releaseDate) {
                        Text(DateFormatter.shortDateFormatter.string(from: date))
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                }
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.secondarySystemFill))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    
    // MARK: - LF Helpers
    private var lfMonthYearFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f
    }
    
    private var lfSelectedDateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f
    }
    
    private func listItemsCountInMonth(for monthDate: Date, in source: [ListItem]) -> Int {
        let calendar = Calendar.current
        var total = 0
        for item in source {
            guard let dateString = item.movieReleaseDate,
                  let date = DateFormatter.movieDateFormatter.date(from: dateString) else { continue }
            if calendar.isDate(date, equalTo: monthDate, toGranularity: .month) {
                total += 1
            }
        }
        return total
    }
    
    @ViewBuilder
    private var lfMonthCountPill: some View {
        let count = listItemsCountInMonth(for: lfCurrentCalendarMonth, in: listItems)
        HStack(spacing: 6) {
            Image(systemName: "film.fill").font(.system(size: 12, weight: .semibold))
            Text("\(count) releasing")
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundColor(.black)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
    }
    
    private func listItemsForDate(_ date: Date) -> [ListItem] {
        let calendar = Calendar.current
        return listItems.filter { item in
            guard let s = item.movieReleaseDate,
                  let d = DateFormatter.movieDateFormatter.date(from: s) else { return false }
            return calendar.isDate(d, inSameDayAs: date)
        }
    }
    
    private func listItemsForMonth(_ monthDate: Date) -> [ListItem] {
        let calendar = Calendar.current
        return listItems.filter { item in
            guard let dateString = item.movieReleaseDate,
                  let date = DateFormatter.movieDateFormatter.date(from: dateString) else { return false }
            return calendar.isDate(date, equalTo: monthDate, toGranularity: .month)
        }
    }
    
    private func lfDayTextColor(isCurrentMonth: Bool, isSelected: Bool, isToday: Bool) -> Color {
        if isSelected { return .black }
        if isToday { return .white }
        if isCurrentMonth { return .white }
        return .gray
    }
    
    private func lfDayBackgroundColor(count: Int, isSelected: Bool, isToday: Bool) -> Color {
        if isSelected { return .white }
        if isToday { return .blue.opacity(0.7) }
        if count > 0 {
            switch count {
            case 1: return .yellow.opacity(0.4)
            case 2: return .orange.opacity(0.6)
            case 3: return .orange.opacity(0.8)
            case 4: return .red.opacity(0.7)
            default: return .red.opacity(0.9)
            }
        }
        return .clear
    }
    
    private var listInfoSection: some View {
        VStack(spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                Text(currentList.name.uppercased())
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .tracking(1)
                
                if currentList.pinned {
                    Image(systemName: "pin.fill")
                        .foregroundColor(.yellow)
                        .font(.body)
                }
            }
            
            if let description = currentList.description, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
            
            Text("\(currentList.itemCount) FILMS")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white.opacity(0.7))
                .textCase(.uppercase)
                .tracking(1.2)
        }
        .padding(.top, 20)
        .padding(.bottom, 4)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.8), Color.black],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    private var backdropSection: some View {
        AsyncImage(url: firstMovieBackdropURL) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            case .failure(_):
                // Fallback to default gradient when backdrop fails
                LinearGradient(
                    colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            case .empty:
                // Loading state
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
            @unknown default:
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
            }
        }
        .frame(height: 300)
        .clipped()
        .overlay(
            // Enhanced gradient overlay for recessed appearance
            LinearGradient(
                colors: [
                    Color.black.opacity(0.1), 
                    Color.black.opacity(0.3),
                    Color.black.opacity(0.6),
                    Color.black.opacity(0.9)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    private var progressSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("PROGRESS")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white.opacity(0.7))
                    .textCase(.uppercase)
                    .tracking(1.2)
                
                Spacer()
                
                if isLoadingProgress {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.6)
                } else {
                    Text("\(watchedCount) / \(listItems.count) WATCHED")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.7))
                        .textCase(.uppercase)
                        .tracking(1.2)
                }
            }
            
            // Progress Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.2))
                        .frame(height: 8)
                    
                    // Progress Fill
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: watchProgress >= 1.0 ?
                                    [Color.green, Color.green.opacity(0.8)] :
                                    [Color.blue, Color.blue.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * watchProgress, height: 8)
                        .animation(.easeInOut(duration: 0.5), value: watchProgress)
                }
            }
            .frame(height: 8)
            
            // Percentage Text
            HStack {
                Spacer()
                Text("\(watchProgressPercentage)% COMPLETE")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(watchProgress >= 1.0 ? .green : .blue)
                    .tracking(1)
                Spacer()
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.8), Color.black],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    @ViewBuilder
    private var tagsSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text("TAGS")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white.opacity(0.7))
                    .textCase(.uppercase)
                    .tracking(1.2)
                
                Spacer()
            }
            
            // Tags Flow Layout
            HStack(alignment: .top) {
                LazyVStack(alignment: .leading, spacing: 8) {
                    let rows = createTagRows(tags: currentList.tagsArray)
                    ForEach(0..<rows.count, id: \.self) { rowIndex in
                        HStack(spacing: 6) {
                            ForEach(rows[rowIndex], id: \.self) { tag in
                                tagView(for: tag)
                            }
                            Spacer()
                        }
                    }
                }
                Spacer()
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.6), Color.black.opacity(0.4)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    @ViewBuilder
    private func tagView(for tag: String) -> some View {
        Text(tag)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(tagColor(for: tag))
                    .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
            )
            .lineLimit(1)
    }
    
    private func tagColor(for tag: String) -> Color {
        // Generate consistent colors based on tag name
        let tagHash = tag.lowercased().hash
        let colors: [Color] = [
            .blue.opacity(0.8),
            .green.opacity(0.8),
            .orange.opacity(0.8),
            .purple.opacity(0.8),
            .red.opacity(0.8),
            .yellow.opacity(0.8),
            .pink.opacity(0.8),
            .cyan.opacity(0.8),
            .indigo.opacity(0.8),
            .mint.opacity(0.8)
        ]
        return colors[abs(tagHash) % colors.count]
    }
    
    private func createTagRows(tags: [String]) -> [[String]] {
        var rows: [[String]] = []
        var currentRow: [String] = []
        var currentRowWidth: CGFloat = 0
        let maxRowWidth: CGFloat = 300 // Approximate max width
        
        for tag in tags {
            // Estimate tag width (rough calculation)
            let tagWidth = CGFloat(tag.count) * 8 + 24 // Character width + padding
            
            if currentRowWidth + tagWidth > maxRowWidth && !currentRow.isEmpty {
                rows.append(currentRow)
                currentRow = [tag]
                currentRowWidth = tagWidth
            } else {
                currentRow.append(tag)
                currentRowWidth += tagWidth + 6 // Add spacing
            }
        }
        
        if !currentRow.isEmpty {
            rows.append(currentRow)
        }
        
        return rows
    }
    
    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "film.stack")
                .font(.system(size: 64))
                .foregroundColor(.gray)
            
            Text("No Movies Yet")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            Text("Add movies to this list to get started.")
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            
            Button("Add Movies") {
                showingAddMovies = true
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    @ViewBuilder
    private var moviesGridView: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
            ForEach(Array(listItems.enumerated()), id: \.element.id) { index, item in
                 MoviePosterView(item: item, list: currentList, rank: currentList.ranked ? index + 1 : nil, showWatchedFaded: showWatchedFaded, hasWatchedEntries: watchedTmdbIds.contains(item.tmdbId))
            }
        }
    }
    
    @ViewBuilder
    private var theaterTicketsView: some View {
        LazyVStack(spacing: 16) {
            ForEach(Array(listItems.enumerated()), id: \.element.id) { index, item in
                TheaterTicketView(item: item, list: currentList, rank: currentList.ranked ? index + 1 : nil, showSpecialLayout: showSpecialLayout)
            }
        }
    }
    
    private func pinList() async {
        do {
            try await dataManager.pinList(currentList)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func unpinList() async {
        do {
            try await dataManager.unpinList(currentList)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func deleteList() async {
        do {
            try await dataManager.deleteList(currentList)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    
    
    private func loadWatchedCount() async {
        await MainActor.run {
            isLoadingProgress = true
        }
        
        do {
            // Extract all TMDB IDs from list items
            let tmdbIds = listItems.map { $0.tmdbId }
            
            // Get watched status for all movies in a single batch query
            let watchedIds = try await dataManager.checkWatchedStatusForTmdbIds(tmdbIds: tmdbIds)
            
            await MainActor.run {
                watchedTmdbIds = watchedIds
                watchedCount = watchedIds.count
                isLoadingProgress = false
            }
        } catch {
            await MainActor.run {
                watchedTmdbIds = []
                watchedCount = 0
                isLoadingProgress = false
            }
        }
    }
    
    private func loadMovieDetailsForItem(_ item: ListItem) async {
        do {
            let movies = try await dataManager.getMoviesByTmdbId(tmdbId: item.tmdbId)
            
            if movies.isEmpty {
                // No entries exist, fetch movie details from TMDB and create a placeholder movie
                let tmdbService = TMDBService.shared
                let movieDetails = try await tmdbService.getMovieDetails(movieId: item.tmdbId)
                
                let placeholderMovie = Movie(
                    id: -1, // Use -1 to indicate this is a placeholder
                    title: item.movieTitle,
                    release_year: item.movieYear,
                    release_date: movieDetails.releaseDate,
                    rating: nil,
                    detailed_rating: nil,
                    review: nil,
                    tags: nil,
                    watch_date: nil,
                    is_rewatch: nil,
                    tmdb_id: item.tmdbId,
                    overview: movieDetails.overview,
                    poster_url: item.moviePosterUrl,
                    backdrop_path: item.movieBackdropPath,
                    director: nil,
                    runtime: movieDetails.runtime,
                    vote_average: movieDetails.voteAverage,
                    vote_count: movieDetails.voteCount,
                    popularity: movieDetails.popularity,
                    original_language: movieDetails.originalLanguage,
                    original_title: movieDetails.originalTitle,
                    tagline: movieDetails.tagline,
                    status: movieDetails.status,
                    budget: movieDetails.budget,
                    revenue: movieDetails.revenue,
                    imdb_id: movieDetails.imdbId,
                    homepage: movieDetails.homepage,
                    genres: movieDetails.genreNames,
                    created_at: nil,
                    updated_at: nil,
                    favorited: nil
                )
                
                await MainActor.run {
                    selectedMovie = placeholderMovie
                    showingMovieDetails = true
                }
            } else {
                // Find the latest entry (most recent watch_date or created_at)
                let latestMovie = movies.max { movie1, movie2 in
                    let date1 = movie1.watch_date ?? movie1.created_at ?? ""
                    let date2 = movie2.watch_date ?? movie2.created_at ?? ""
                    return date1 < date2
                }
                
                await MainActor.run {
                    selectedMovie = latestMovie
                    if latestMovie != nil {
                        showingMovieDetails = true
                    }
                }
            }
        } catch {
            // Silently handle error
        }
    }
}

struct MoviePosterView: View {
    let item: ListItem
    let list: MovieList
    let rank: Int?
    let showWatchedFaded: Bool
    let hasWatchedEntries: Bool
    @StateObject private var dataManager = DataManager.shared
    @State private var showingRemoveAlert = false
    @State private var selectedMovie: Movie?
    @State private var showingMovieDetails = false
    @State private var isLoadingMovie = false
    @State private var showingPosterChange = false
    @State private var showingBackdropChange = false
    
    var body: some View {
        Button(action: {
            Task {
                await loadLatestMovieEntry()
            }
        }) {
            AsyncImage(url: URL(string: item.moviePosterUrl ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(2/3, contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .aspectRatio(2/3, contentMode: .fill)
                    .overlay(
                        VStack {
                            Image(systemName: "photo")
                                .foregroundColor(.gray)
                            Text(item.movieTitle)
                                .font(.caption)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .lineLimit(3)
                        }
                    )
            }
            .clipped()
            .cornerRadius(12)
            .overlay(
                Group {
                    if isLoadingMovie {
                        Color.black.opacity(0.6)
                            .cornerRadius(12)
                            .overlay(
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            )
                    } else if showWatchedFaded && hasWatchedEntries {
                        Color.black.opacity(0.5)
                            .cornerRadius(12)
                            .overlay(
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundColor(.blue)
                                    .background(
                                        Circle()
                                            .fill(Color.white)
                                            .frame(width: 28, height: 28)
                                    )
                            )
                    }
                }
            )
            .overlay(
                // Rank number overlay
                Group {
                    if let rank = rank {
                        VStack {
                            HStack {
                                Text("\(rank)")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(
                                        .ultraThinMaterial.opacity(0.6),
                                        in: RoundedRectangle(cornerRadius: 6)
                                    )
                                    .shadow(color: .black.opacity(0.4), radius: 3, x: 0, y: 1)
                                
                                Spacer()
                            }
                            
                            Spacer()
                        }
                        .padding(6)
                    }
                }, alignment: .topLeading
            )
            .contextMenu {
                Button("Change Poster", systemImage: "photo") {
                    showingPosterChange = true
                }
                Button("Change Backdrop", systemImage: "rectangle.on.rectangle") {
                    showingBackdropChange = true
                }
                Button("Remove from List", systemImage: "trash", role: .destructive) {
                    showingRemoveAlert = true
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .alert("Remove Movie", isPresented: $showingRemoveAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) {
                Task {
                    await removeMovie()
                }
            }
        } message: {
            Text("Remove '\(item.movieTitle)' from '\(list.name)'?")
        }
        .sheet(isPresented: $showingMovieDetails) {
            if let selectedMovie = selectedMovie {
                MovieDetailsView(movie: selectedMovie)
            }
        }
        .sheet(isPresented: $showingPosterChange) {
            PosterChangeView(
                tmdbId: item.tmdbId,
                currentPosterUrl: item.moviePosterUrl,
                movieTitle: item.movieTitle
            ) { newPosterUrl in
                // The poster will be updated automatically through the data manager
            }
        }
        .sheet(isPresented: $showingBackdropChange) {
            BackdropChangeView(
                tmdbId: item.tmdbId,
                currentBackdropUrl: item.movieBackdropPath,
                movieTitle: item.movieTitle
            ) { newBackdropUrl in
                // The backdrop will be updated automatically through the data manager
            }
        }
    }
    
    private func removeMovie() async {
        do {
            try await dataManager.removeMovieFromList(tmdbId: item.tmdbId, listId: list.id)
        } catch {
            // Silently handle error
        }
    }
    
    private func loadLatestMovieEntry() async {
        isLoadingMovie = true
        
        do {
            let movies = try await dataManager.getMoviesByTmdbId(tmdbId: item.tmdbId)
            
            if movies.isEmpty {
                // No entries exist, fetch movie details from TMDB and create a placeholder movie
                let tmdbService = TMDBService.shared
                let movieDetails = try await tmdbService.getMovieDetails(movieId: item.tmdbId)
                
                let placeholderMovie = Movie(
                    id: -1, // Use -1 to indicate this is a placeholder
                    title: item.movieTitle,
                    release_year: item.movieYear,
                    release_date: movieDetails.releaseDate,
                    rating: nil,
                    detailed_rating: nil,
                    review: nil,
                    tags: nil,
                    watch_date: nil,
                    is_rewatch: nil,
                    tmdb_id: item.tmdbId,
                    overview: movieDetails.overview,
                    poster_url: item.moviePosterUrl,
                    backdrop_path: item.movieBackdropPath,
                    director: nil,
                    runtime: movieDetails.runtime,
                    vote_average: movieDetails.voteAverage,
                    vote_count: movieDetails.voteCount,
                    popularity: movieDetails.popularity,
                    original_language: movieDetails.originalLanguage,
                    original_title: movieDetails.originalTitle,
                    tagline: movieDetails.tagline,
                    status: movieDetails.status,
                    budget: movieDetails.budget,
                    revenue: movieDetails.revenue,
                    imdb_id: movieDetails.imdbId,
                    homepage: movieDetails.homepage,
                    genres: movieDetails.genreNames,
                    created_at: nil,
                    updated_at: nil,
                    favorited: nil
                )
                
                await MainActor.run {
                    selectedMovie = placeholderMovie
                    showingMovieDetails = true
                    isLoadingMovie = false
                }
            } else {
                // Find the latest entry (most recent watch_date or created_at)
                let latestMovie = movies.max { movie1, movie2 in
                    let date1 = movie1.watch_date ?? movie1.created_at ?? ""
                    let date2 = movie2.watch_date ?? movie2.created_at ?? ""
                    return date1 < date2
                }
                
                await MainActor.run {
                    selectedMovie = latestMovie
                    if latestMovie != nil {
                        showingMovieDetails = true
                    }
                    isLoadingMovie = false
                }
            }
        } catch {
            await MainActor.run {
                isLoadingMovie = false
            }
        }
    }
}

// Add Movies to List View with TMDB Search
struct AddMoviesToListView: View {
    let list: MovieList
    @Environment(\.dismiss) private var dismiss
    @StateObject private var dataManager = DataManager.shared
    @StateObject private var tmdbService = TMDBService.shared
    
    @State private var searchText = ""
    @State private var searchResults: [TMDBMovie] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?
    @State private var errorMessage: String?
    @State private var addingMovieIds: Set<Int> = []
    
    var body: some View {
        NavigationView {
            VStack {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    
                    TextField("Search movies or enter TMDB ID...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .foregroundColor(.white)
                        .onSubmit {
                            performSearch()
                        }
                        .onChange(of: searchText) { _, newValue in
                            searchTask?.cancel()
                            if !newValue.isEmpty {
                                searchTask = Task {
                                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
                                    if !Task.isCancelled {
                                        await performSearchDelayed()
                                    }
                                }
                            } else {
                                searchResults = []
                            }
                        }
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                            searchResults = []
                            searchTask?.cancel()
                        }) {
                            Image(systemName: "xmark")
                                .foregroundColor(.gray)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    if isSearching {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(10)
                .padding(.horizontal)
                
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.horizontal)
                }
                
                // Search results
                if searchResults.isEmpty && !searchText.isEmpty && !isSearching {
                    VStack(spacing: 16) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        
                        Text("No Results")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        
                        Text("Try searching with different keywords.")
                            .font(.body)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if searchResults.isEmpty && searchText.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "film")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        
                        Text("Search Movies")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        
                        Text("Search for movies to add to your list.")
                            .font(.body)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(searchResults) { movie in
                                MovieSearchResultView(
                                    movie: movie,
                                    list: list,
                                    isAdding: addingMovieIds.contains(movie.id)
                                ) {
                                    await addMovie(movie)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                Spacer()
            }
            .background(Color(.systemBackground))
            .navigationTitle("Add Movies")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done", systemImage: "checkmark") {
                        dismiss()
                    }
                }
            }
            .onDisappear {
                searchTask?.cancel()
            }
        }
    }
    
    private func performSearch() {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            return
        }
        
        Task {
            await performSearchAsync()
        }
    }
    
    private func performSearchDelayed() async {
        await performSearchAsync()
    }
    
    @MainActor
    private func performSearchAsync() async {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            return
        }
        
        isSearching = true
        errorMessage = nil
        
        do {
            let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Check if the input is a TMDB ID (all digits)
            if let tmdbId = Int(trimmedQuery), tmdbId > 0 {
                // Search by TMDB ID
                let movieDetails = try await tmdbService.getMovieDetails(movieId: tmdbId)
                
                // Convert TMDBMovieDetails to TMDBMovie for consistency
                let tmdbMovie = TMDBMovie(
                    id: movieDetails.id,
                    title: movieDetails.title,
                    originalTitle: movieDetails.originalTitle,
                    overview: movieDetails.overview,
                    releaseDate: movieDetails.releaseDate,
                    posterPath: movieDetails.posterPath,
                    backdropPath: movieDetails.backdropPath,
                    voteAverage: movieDetails.voteAverage,
                    voteCount: movieDetails.voteCount,
                    popularity: movieDetails.popularity,
                    originalLanguage: movieDetails.originalLanguage,
                    genreIds: [],
                    adult: movieDetails.adult,
                    video: movieDetails.video
                )
                
                // Filter out if already in the list
                let existingTmdbIds = Set(dataManager.getListItems(list).map { $0.tmdbId })
                if !existingTmdbIds.contains(tmdbMovie.id) {
                    searchResults = [tmdbMovie]
                } else {
                    searchResults = []
                    errorMessage = "Movie is already in this list"
                }
            } else {
                // Regular text search
                let response = try await tmdbService.searchMovies(query: trimmedQuery)
                // Filter out movies already in the list and limit to 30 results
                let existingTmdbIds = Set(dataManager.getListItems(list).map { $0.tmdbId })
                searchResults = Array(response.results.filter { !existingTmdbIds.contains($0.id) }.prefix(30))
            }
        } catch {
            errorMessage = error.localizedDescription
            searchResults = []
        }
        
        isSearching = false
    }
    
    private func addMovie(_ movie: TMDBMovie) async {
        addingMovieIds.insert(movie.id)
        
        do {
            try await dataManager.addMovieToList(
                tmdbId: movie.id,
                title: movie.title,
                posterUrl: movie.posterURL?.absoluteString,
                backdropPath: movie.backdropPath,
                year: movie.releaseYear,
                listId: list.id
            )
            
            // Remove from search results since it's now added
            searchResults.removeAll { $0.id == movie.id }
        } catch {
            errorMessage = error.localizedDescription
        }
        
        addingMovieIds.remove(movie.id)
    }
}

struct MovieSearchResultView: View {
    let movie: TMDBMovie
    let list: MovieList
    let isAdding: Bool
    let onAddMovie: () async -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Movie poster
            AsyncImage(url: movie.posterURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
            }
            .frame(width: 60, height: 90)
            .cornerRadius(8)
            .clipped()
            
            // Movie details
            VStack(alignment: .leading, spacing: 4) {
                Text(movie.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .lineLimit(2)
                
                if let year = movie.releaseYear {
                    Text(String(year))
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                if let overview = movie.overview, !overview.isEmpty {
                    Text(overview)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(3)
                }
            }
            
            Spacer()
            
            // Add button
            Button(action: {
                Task {
                    await onAddMovie()
                }
            }) {
                Group {
                    if isAdding {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                }
            }
            .disabled(isAdding)
            .buttonStyle(PlainButtonStyle())
        }
        .padding()
        .background(Color.gray.opacity(0.15))
        .cornerRadius(12)
    }
}

struct EditListView: View {
    let list: MovieList
    @Environment(\.dismiss) private var dismiss
    @StateObject private var dataManager = DataManager.shared
    @State private var listName: String
    @State private var listDescription: String
    @State private var isRanked: Bool
    @State private var selectedTags: [String]
    @State private var isUpdating = false
    @State private var hasOrderChanges = false
    @State private var errorMessage: String?
    @State private var listItems: [ListItem] = []
    @State private var isReordering = false
    @State private var showingTagSelector = false
    @State private var newTagName = ""
    @State private var isThemedMonth: Bool
    @State private var themedMonthDate: Date
    
    // Predefined tags for selection
    private let predefinedTags = [
        "Action", "Comedy", "Drama", "Horror", "Thriller", "Romance", "Sci-Fi", "Fantasy",
        "Animation", "Documentary", "Biography", "Crime", "Mystery", "Adventure", "Family",
        "History", "War", "Western", "Musical", "Sport", "Favorites", "Watchlist", "Classics",
        "Recent", "Rewatches", "Theater", "Awards", "Foreign", "Indie", "Blockbuster"
    ]
    
    init(list: MovieList) {
        self.list = list
        self._listName = State(initialValue: list.name)
        self._listDescription = State(initialValue: list.description ?? "")
        self._isRanked = State(initialValue: list.ranked)
        self._selectedTags = State(initialValue: list.tagsArray)
        self._isThemedMonth = State(initialValue: list.themedMonthDate != nil)
        self._themedMonthDate = State(initialValue: list.themedMonthDate ?? {
            // Default to first day of current month if no themed month date exists
            let calendar = Calendar.current
            let now = Date()
            let components = calendar.dateComponents([.year, .month], from: now)
            return calendar.date(from: DateComponents(year: components.year, month: components.month, day: 1)) ?? now
        }())
    }
    
    var body: some View {
        NavigationView {
            List {
                // List Details Section
                Section {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("List Details")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("List Name")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            TextField("Enter list name", text: $listName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .onChange(of: listName) { _, _ in
                                    checkAutoRanking()
                                }
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Description (Optional)")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            TextField("Enter description", text: $listDescription, axis: .vertical)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .lineLimit(3, reservesSpace: true)
                                .onChange(of: listDescription) { _, _ in
                                    checkAutoRanking()
                                }
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Ranked List")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                Toggle("", isOn: $isRanked)
                                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                            }
                            
                            Text("Show numbers 1, 2, 3... next to movies to indicate ranking order")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        // Tags Section
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Tags")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                Button("Add Tag", systemImage: "plus.circle") {
                                    showingTagSelector = true
                                }
                                .foregroundColor(.blue)
                                .font(.subheadline)
                            }
                            
                            Text("Categorize your list with tags for better organization")
                                .font(.caption)
                                .foregroundColor(.gray)
                            
                            // Selected Tags Display
                            if !selectedTags.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(selectedTags, id: \.self) { tag in
                                            HStack(spacing: 4) {
                                                Text(tag)
                                                    .font(.caption)
                                                    .foregroundColor(.white)
                                                
                                                Button(action: {
                                                    selectedTags.removeAll { $0 == tag }
                                                }) {
                                                    Image(systemName: "xmark.circle.fill")
                                                        .font(.caption)
                                                        .foregroundColor(.white.opacity(0.7))
                                                }
                                            }
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(
                                                Capsule()
                                                    .fill(tagColor(for: tag))
                                            )
                                        }
                                    }
                                    .padding(.horizontal, 4)
                                }
                            } else {
                                Text("No tags selected")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .italic()
                            }
                        }
                        
                        // Themed Movie Months Section
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Themed Movie Months")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                Toggle("", isOn: $isThemedMonth)
                                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                            }
                            
                            Text("Create a monthly movie challenge with a specific theme or goal")
                                .font(.caption)
                                .foregroundColor(.gray)
                            
                            if isThemedMonth {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Select Month")
                                        .font(.subheadline)
                                        .foregroundColor(.white)
                                    
                                    DatePicker(
                                        "Themed Month",
                                        selection: $themedMonthDate,
                                        displayedComponents: [.date]
                                    )
                                    .datePickerStyle(.compact)
                                    .colorScheme(.dark)
                                    .accentColor(.blue)
                                    
                                    Text("This list will appear in your goals during the selected month")
                                        .font(.caption2)
                                        .foregroundColor(.gray.opacity(0.8))
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.white.opacity(0.1))
                                )
                            }
                        }
                    }
                }
                
                // List Items Section
                if !listItems.isEmpty {
                    Section(header:
                        HStack {
                            Text("Movies")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                            Spacer()
                            Button(isReordering ? "Done" : "Reorder") {
                                withAnimation {
                                    isReordering.toggle()
                                }
                            }
                            .foregroundColor(.blue)
                        }
                    ) {
                        ForEach(listItems) { item in
                            EditableListItemView(
                                item: item,
                                isReordering: isReordering,
                                onRemove: {
                                    await removeItem(item)
                                }
                            )
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                        }
                        .onMove(perform: isReordering ? moveItems : nil)
                    }
                }
                
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.black)
            .preferredColorScheme(.dark)
            .environment(\.editMode, isReordering ? .constant(.active) : .constant(.inactive))
            .navigationTitle("Edit List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", systemImage: "xmark") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save", systemImage: "checkmark") {
                        Task {
                            await saveAllChanges()
                        }
                    }
                    .disabled(isUpdating)
                }
            }
            .onAppear {
                loadListItems()
            }
            .sheet(isPresented: $showingTagSelector) {
                TagSelectorView(
                    selectedTags: $selectedTags,
                    predefinedTags: predefinedTags,
                    newTagName: $newTagName
                )
            }
        }
    }
    
    private func loadListItems() {
        listItems = dataManager.getListItems(list)
    }
    
    private func moveItems(from source: IndexSet, to destination: Int) {
        listItems.move(fromOffsets: source, toOffset: destination)
        hasOrderChanges = true
    }
    
    private func removeItem(_ item: ListItem) async {
        do {
            try await dataManager.removeMovieFromList(tmdbId: item.tmdbId, listId: list.id)
            loadListItems()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    @MainActor
    private func saveAllChanges() async {
        isUpdating = true
        errorMessage = nil
        
        do {
            // Compute metadata change flags
            let name = listName.trimmingCharacters(in: .whitespacesAndNewlines)
            let description = listDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            let nameChanged = name != list.name
            let descriptionChanged = description != (list.description ?? "")
            let rankedChanged = isRanked != list.ranked
            let tagsChanged = selectedTags != list.tagsArray
            
            // Check themed month changes
            let currentThemedDate = isThemedMonth ? {
                let calendar = Calendar.current
                let components = calendar.dateComponents([.year, .month], from: themedMonthDate)
                return calendar.date(from: DateComponents(year: components.year, month: components.month, day: 1))
            }() : nil
            let themedMonthChanged = currentThemedDate != list.themedMonthDate

            // If nothing changed, just close
            if !hasOrderChanges && !nameChanged && !descriptionChanged && !rankedChanged && !tagsChanged && !themedMonthChanged {
                isUpdating = false
                dismiss()
                return
            }

            // Persist ordering if changed
            if hasOrderChanges {
                try await dataManager.reorderListItems(list.id, items: listItems)
                hasOrderChanges = false
            }
            
            // Persist list metadata changes (name/description/ranked/tags/themedMonthDate)
            if nameChanged || descriptionChanged || rankedChanged || tagsChanged || themedMonthChanged {
                // Pass updateThemedMonthDate as true when themed month has changed to ensure it gets updated
                _ = try await dataManager.updateList(
                    list,
                    name: nameChanged ? name : nil,
                    description: descriptionChanged ? (description.isEmpty ? nil : description) : nil,
                    ranked: rankedChanged ? isRanked : nil,
                    tags: tagsChanged ? selectedTags : nil,
                    themedMonthDate: currentThemedDate,
                    updateThemedMonthDate: themedMonthChanged
                )
            }
            
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isUpdating = false
    }
    
    private func checkAutoRanking() {
        // Only auto-enable if currently disabled to avoid overriding user choice
        if !isRanked && MovieList.shouldAutoEnableRanking(name: listName, description: listDescription) {
            isRanked = true
        }
    }
    
    private func tagColor(for tag: String) -> Color {
        // Generate consistent colors based on tag name (same as in ListDetailsView)
        let tagHash = tag.lowercased().hash
        let colors: [Color] = [
            .blue.opacity(0.8),
            .green.opacity(0.8),
            .orange.opacity(0.8),
            .purple.opacity(0.8),
            .red.opacity(0.8),
            .yellow.opacity(0.8),
            .pink.opacity(0.8),
            .cyan.opacity(0.8),
            .indigo.opacity(0.8),
            .mint.opacity(0.8)
        ]
        return colors[abs(tagHash) % colors.count]
    }
}

struct TagSelectorView: View {
    @Binding var selectedTags: [String]
    let predefinedTags: [String]
    @Binding var newTagName: String
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    
    private var filteredTags: [String] {
        if searchText.isEmpty {
            return predefinedTags.filter { !selectedTags.contains($0) }
        } else {
            return predefinedTags.filter { tag in
                !selectedTags.contains(tag) && tag.lowercased().contains(searchText.lowercased())
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    
                    TextField("Search tags or create new...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .foregroundColor(.white)
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding()
                .background(Color(.secondarySystemFill))
                .cornerRadius(12)
                .padding(.horizontal)
                .padding(.top)
                
                // Create custom tag button
                if !searchText.isEmpty && !predefinedTags.contains(searchText) && !selectedTags.contains(searchText) {
                    Button(action: {
                        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty && !selectedTags.contains(trimmed) {
                            selectedTags.append(trimmed)
                            searchText = ""
                        }
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.green)
                            Text("Create \"\(searchText)\"")
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .padding()
                        .background(Color(.tertiarySystemFill))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
                
                // Tag list
                List {
                    if !selectedTags.isEmpty {
                        Section("Selected Tags") {
                            ForEach(selectedTags, id: \.self) { tag in
                                HStack {
                                    Text(tag)
                                        .foregroundColor(.white)
                                    Spacer()
                                    Button(action: {
                                        selectedTags.removeAll { $0 == tag }
                                    }) {
                                        Image(systemName: "minus.circle.fill")
                                            .foregroundColor(.red)
                                    }
                                }
                                .listRowBackground(Color(.secondarySystemFill))
                            }
                        }
                    }
                    
                    Section("Available Tags") {
                        ForEach(filteredTags, id: \.self) { tag in
                            Button(action: {
                                if !selectedTags.contains(tag) {
                                    selectedTags.append(tag)
                                }
                            }) {
                                HStack {
                                    Text(tag)
                                        .foregroundColor(.white)
                                    Spacer()
                                    Image(systemName: "plus.circle")
                                        .foregroundColor(.blue)
                                }
                            }
                            .listRowBackground(Color(.secondarySystemFill))
                        }
                        
                        if filteredTags.isEmpty && searchText.isEmpty {
                            Text("All tags are already selected")
                                .foregroundColor(.gray)
                                .italic()
                                .listRowBackground(Color(.secondarySystemFill))
                        } else if filteredTags.isEmpty && !searchText.isEmpty {
                            Text("No matching tags found")
                                .foregroundColor(.gray)
                                .italic()
                                .listRowBackground(Color(.secondarySystemFill))
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Color.black)
            }
            .background(Color.black)
            .navigationTitle("Select Tags")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done", systemImage: "checkmark") {
                        dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct EditableListItemView: View {
    let item: ListItem
    let isReordering: Bool
    let onRemove: () async -> Void
    @State private var showingRemoveAlert = false
    @StateObject private var dataManager = DataManager.shared
    @State private var loadedRating: Double? = nil
    @State private var loadedDetailedRating: Double? = nil
    @State private var hasLoadedRatings: Bool = false
    
    var body: some View {
        HStack(spacing: 12) {
            
            // Movie poster
            AsyncImage(url: URL(string: item.moviePosterUrl ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.gray)
                    )
            }
            .frame(width: 50, height: 75)
            .cornerRadius(8)
            .clipped()
            
            // Movie details
            VStack(alignment: .leading, spacing: 4) {
                Text(item.movieTitle)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .lineLimit(2)
                
                if let year = item.movieYear {
                    Text(String(year))
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }

                // Ratings row
                if loadedRating != nil || loadedDetailedRating != nil {
                    HStack(spacing: 8) {
                        if let rating = loadedRating {
                            HStack(spacing: 2) {
                                ForEach(0..<5, id: \.self) { index in
                                    Image(systemName: starType(for: index, rating: rating))
                                        .foregroundColor(starColor(for: rating))
                                        .font(.system(size: 12, weight: .regular))
                                }
                            }
                        }
                        
                        if let detailed = loadedDetailedRating {
                            Text(String(format: "%.0f", detailed))
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundColor(.purple)
                        }
                    }
                }
            }
            
            Spacer()
            
            // Remove button (only show when not reordering)
            if !isReordering {
                Button(action: {
                    showingRemoveAlert = true
                }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.red)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding()
        .background(Color.gray.opacity(0.15))
        .cornerRadius(12)
        .alert("Remove Movie", isPresented: $showingRemoveAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) {
                Task {
                    await onRemove()
                }
            }
        } message: {
            Text("Remove '\(item.movieTitle)' from this list?")
        }
        .onAppear {
            if !hasLoadedRatings {
                Task {
                    await loadLatestMovieRatings()
                }
            }
        }
    }
    
    private func starType(for index: Int, rating: Double?) -> String {
        guard let rating = rating else { return "star" }
        if rating >= Double(index + 1) {
            return "star.fill"
        } else if rating >= Double(index) + 0.5 {
            return "star.leadinghalf.filled"
        } else {
            return "star"
        }
    }
    
    private func starColor(for rating: Double?) -> Color {
        guard let rating = rating else { return .blue }
        return rating == 5.0 ? .yellow : .blue
    }
    
    @MainActor
    private func loadLatestMovieRatings() async {
        do {
            let movies = try await dataManager.getMoviesByTmdbId(tmdbId: item.tmdbId)
            // Find the latest entry (most recent watch_date or created_at)
            let latest = movies.max { movie1, movie2 in
                let date1 = movie1.watch_date ?? movie1.created_at ?? ""
                let date2 = movie2.watch_date ?? movie2.created_at ?? ""
                return date1 < date2
            }
            loadedRating = latest?.rating
            loadedDetailedRating = latest?.detailed_rating
            hasLoadedRatings = true
        } catch {
            hasLoadedRatings = true
        }
    }
}

#Preview {
    // Preview wrapper that connects to your actual database
    PreviewWrapper()
}

// MARK: - DateFormatter Extension
extension DateFormatter {
    static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter
    }()
}

struct PreviewWrapper: View {
    @StateObject private var dataManager = DataManager.shared
    @State private var targetList: MovieList?
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        Group {
            if isLoading {
                VStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    Text("Loading database connection...")
                        .foregroundColor(.white)
                        .padding(.top)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
                .preferredColorScheme(.dark)
            } else if let errorMessage = errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)
                    
                    Text("Preview Error")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text(errorMessage)
                        .font(.body)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button("Retry") {
                        Task {
                            await loadTheaterList()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
                .preferredColorScheme(.dark)
            } else if let targetList = targetList {
                ListDetailsView(list: targetList)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "film.stack")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    
                    Text("Theater List Not Found")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text("The 'Films Watched in Theaters' list was not found in your account.")
                        .font(.body)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button("Retry") {
                        Task {
                            await loadTheaterList()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
                .preferredColorScheme(.dark)
            }
        }
        .task {
            await authenticateAndLoadList()
        }
    }
    
    private func authenticateAndLoadList() async {
        // Note: Authentication is handled automatically by the Config.swift file
        // which contains your Supabase URL and API key. The services are already
        // configured to use your database credentials.
        
        
        
        // Load the theater list directly since auth is automatic
        await loadTheaterList()
    }
    
    @MainActor
    private func loadTheaterList() async {
        isLoading = true
        errorMessage = nil
        
        // Try to find the "Films Watched in Theaters" list
        // First, refresh lists from Supabase to ensure we have the latest data
        await dataManager.refreshLists()
        
        // Look for the theater list by name (case-insensitive)
        let theaterList = dataManager.movieLists.first { list in
            list.name.lowercased().contains("theaters") || 
            list.name.lowercased().contains("theatre") ||
            list.name.lowercased() == "films watched in theaters"
        }
        
        if let theaterList = theaterList {
            targetList = theaterList
        } else {
            // If not found, create a fallback for preview
            targetList = nil
            errorMessage = "No theater list found. Make sure you have a list with 'theater' or 'theatre' in the name."
        }
        
        isLoading = false
    }
}

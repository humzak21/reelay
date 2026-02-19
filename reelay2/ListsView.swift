//
//  ListsView.swift
//  reelay2
//
//  Created by Humza Khalil on 7/21/25.
//

import SwiftUI
import SDWebImageSwiftUI

struct ListsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var dataManager = DataManager.shared
    @ObservedObject private var movieService = SupabaseMovieService.shared
    @State private var showingCreateList = false
    @State private var showingAddTelevision = false
    @State private var showingEditWatchlist = false
    @State private var selectedList: MovieList?
    @State private var listToEdit: MovieList?
    @State private var listToDelete: MovieList?
    @State private var showingDeleteListAlert = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingCSVImport = false
    @State private var showingRandomizer = false
    
    private var toolbarTrailingPlacement: ToolbarItemPlacement {
        #if os(iOS)
        .navigationBarTrailing
        #else
        .automatic
        #endif
    }

    // MARK: - Efficient Loading States
    @State private var hasLoadedInitially = false
    @State private var isInitialLoad = true
    @State private var lastRefreshTime: Date = Date.distantPast
    @State private var isRefreshing = false

    private let refreshInterval: TimeInterval = 300 // 5 minutes
    
    #if os(macOS)
    @EnvironmentObject private var navigationCoordinator: NavigationCoordinator
    #endif

    private var appBackground: Color {
        #if canImport(UIKit)
        colorScheme == .dark ? .black : Color(.systemGroupedBackground)
        #else
        colorScheme == .dark ? .black : Color(.windowBackgroundColor)
        #endif
    }

    var body: some View {
        contentView
            .navigationTitle("Lists")
            #if canImport(UIKit)
            .toolbarTitleDisplayMode(.inlineLarge)
            #endif
            #if canImport(UIKit)
            .background(Color(.systemGroupedBackground))
            #else
            .background(Color(.windowBackgroundColor))
            #endif
            .toolbar {
                ToolbarItemGroup {
                    Button(action: {
                        showingRandomizer = true
                    }) {
                        Image(systemName: "dice")
                    }
                    
                    Button(action: {
                        showingCSVImport = true
                    }) {
                        Image(systemName: "square.and.arrow.down")
                    }
                }
                
                ToolbarSpacer(.fixed)
                
                ToolbarItem(placement: toolbarTrailingPlacement) {
                    Menu {
                        Button("Create New List", systemImage: "list.bullet") {
                            showingCreateList = true
                        }
                        Button("Add TV Show", systemImage: "tv") {
                            showingAddTelevision = true
                        }
                        Button("Add to Watchlist", systemImage: "bookmark") {
                            showingEditWatchlist = true
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .task {
                if movieService.isLoggedIn && !hasLoadedInitially {
                    isLoading = true
                    await loadListsIfNeeded(force: true)
                    hasLoadedInitially = true
                }
            }
            .onChange(of: movieService.isLoggedIn) { _, isLoggedIn in
                if isLoggedIn {
                    isLoading = true
                    Task {
                        await loadListsIfNeeded(force: true)
                        hasLoadedInitially = true
                    }
                } else {
                    hasLoadedInitially = false
                    isInitialLoad = true
                    lastRefreshTime = Date.distantPast
                }
            }
            .onAppear {
                // Only load if we haven't loaded initially or data is stale
                if movieService.isLoggedIn && shouldRefreshData() {
                    isLoading = true
                    Task {
                        await loadListsIfNeeded(force: false)
                    }
                }
            }
            .sheet(isPresented: $showingCreateList) {
                CreateListView()
            }
            .sheet(isPresented: $showingAddTelevision) {
                AddTelevisionView()
            }
            .sheet(isPresented: $showingCSVImport) {
                CSVImportTabbedView()
            }
            .sheet(isPresented: $showingRandomizer) {
                WatchlistRandomizerView()
            }
            .sheet(isPresented: $showingEditWatchlist) {
                WatchlistEditView()
            }
            #if os(iOS)
            .sheet(item: $selectedList) { list in
                ListDetailsView(list: list)
            }
            #else
            .onChange(of: selectedList) { _, list in
                if let list = list {
                    navigationCoordinator.showListDetails(list)
                    selectedList = nil
                }
            }
            #endif
            .sheet(item: $listToEdit) { list in
                EditListView(list: list)
            }
            .alert("Delete List", isPresented: $showingDeleteListAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    if let list = listToDelete {
                        Task { await deleteList(list) }
                    }
                }
            } message: {
                if let list = listToDelete {
                    Text("Are you sure you want to delete '\(list.name)'? This action cannot be undone.")
                } else {
                    Text("")
                }
            }
            .refreshable {
                await refreshLists()
            }
    }
    
    @ViewBuilder
    private var contentView: some View {
        Group {
            if !movieService.isLoggedIn {
                notLoggedInView
            } else if isInitialLoad {
                SkeletonListsContent()
            } else if isLoading {
                loadingView
            } else if dataManager.movieLists.isEmpty && !isLoading {
                emptyStateView
            } else {
                listsGridView
            }
        }
    }
    
    @ViewBuilder
    private var notLoggedInView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.system(size: 64))
                .foregroundColor(.gray)

            Text("Sign In Required")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)

            Text("Please sign in to view and manage your movie lists.")
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()

            Text("Go to the Profile tab to sign in")
                .font(.caption)
                .foregroundColor(.blue)
                .padding(.bottom, 100)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private var loadingView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.2)
            Text("Finishing a film...")
                .font(.headline)
                .foregroundColor(Color.adaptiveText(scheme: colorScheme))
            Spacer()
        }
    }
    
    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            if let errorMessage = errorMessage {
                errorStateView(errorMessage: errorMessage)
            } else {
                noListsView
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }
    
    @ViewBuilder
    private func errorStateView(errorMessage: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            Text("Error Loading Lists")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            Text(errorMessage)
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
    
    @ViewBuilder
    private var noListsView: some View {
        VStack(spacing: 8) {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            Text("No Lists Yet")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            Text("Create your first movie list to get started.")
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
    
    @ViewBuilder
    private var listsGridView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                Color.clear
                    .frame(height: 1)
                
                LazyVStack(spacing: 16) {
                    ForEach(dataManager.movieLists) { list in
                        ListCardView(list: list) {
                            selectedList = list
                        }
                        .contextMenu {
                            if list.pinned {
                                Button("Unpin List", systemImage: "pin.slash") {
                                    Task {
                                        do {
                                            try await dataManager.unpinList(list)
                                        } catch {
                                            await MainActor.run {
                                                errorMessage = error.localizedDescription
                                            }
                                        }
                                    }
                                }
                            } else {
                                Button("Pin List", systemImage: "pin.fill") {
                                    Task {
                                        do {
                                            try await dataManager.pinList(list)
                                        } catch {
                                            await MainActor.run {
                                                errorMessage = error.localizedDescription
                                            }
                                        }
                                    }
                                }
                            }
                            Button("Edit List", systemImage: "pencil") {
                                listToEdit = list
                            }
                            Button("Remove List", systemImage: "trash", role: .destructive) {
                                listToDelete = list
                                showingDeleteListAlert = true
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.vertical, 16)
            }
        }
        .scrollContentBackground(.hidden)
    }
    
    // MARK: - Efficient Loading Functions
    
    private func shouldRefreshData() -> Bool {
        return Date().timeIntervalSince(lastRefreshTime) > refreshInterval || !hasLoadedInitially
    }
    
    private func loadListsIfNeeded(force: Bool) async {
        // If force is false and data is still fresh, skip loading
        if !force && !shouldRefreshData() && !dataManager.movieLists.isEmpty {
            isLoading = false
            return
        }

        // Only show loading spinner on non-initial loads
        if !isInitialLoad && !isLoading {
            isLoading = true
        }

        errorMessage = nil

        // Use optimized refresh which uses batch database function
        await dataManager.refreshListsOptimized()

        lastRefreshTime = Date()

        await MainActor.run {
            isInitialLoad = false
            isLoading = false
        }
    }
    
    private func refreshLists() async {
        guard !isRefreshing else { 
            return 
        }
        
        isRefreshing = true
        errorMessage = nil
        
        // Use optimized refresh
        await dataManager.refreshListsOptimized()
        
        lastRefreshTime = Date()
        isRefreshing = false
    }
    
    private func loadLists() async {
        await loadListsIfNeeded(force: true)
    }
    
    private func deleteList(_ list: MovieList) async {
        do {
            try await dataManager.deleteList(list)
            await MainActor.run {
                listToDelete = nil
                showingDeleteListAlert = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                listToDelete = nil
                showingDeleteListAlert = false
            }
        }
    }
}

struct ListCardView: View {
    @Environment(\.colorScheme) private var colorScheme
    let list: MovieList
    let onTap: () -> Void
    @ObservedObject private var dataManager = DataManager.shared
    
    private var listItems: [ListItem] {
        dataManager.getListItems(list)
    }
    
    private var firstSixPosters: [String] {
        Array(listItems.prefix(6).compactMap { $0.moviePosterUrl })
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                listHeaderView
                posterPreviewSection
            }
            .padding(16)
            .background(colorScheme == .dark ? Color.gray.opacity(0.15) : .white)
            .cornerRadius(16)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var listHeaderView: some View {
        HStack {
            leftHeaderSection
            Spacer()
            rightHeaderSection
        }
    }
    
    private var leftHeaderSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(list.name)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(Color.adaptiveText(scheme: colorScheme))
                    .lineLimit(2)
                
                if list.pinned {
                    Image(systemName: "pin.fill")
                        .foregroundColor(.yellow)
                        .font(.caption)
                }
            }
            
            if let description = list.description, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .lineLimit(2)
            }
        }
    }
    
    private var rightHeaderSection: some View {
        VStack(alignment: .trailing, spacing: 4) {
            HStack {
                Text("\(list.itemCount)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(Color.adaptiveText(scheme: colorScheme))
            }
            
            Text("films")
                .font(.caption)
                .foregroundColor(.gray)
                .textCase(.uppercase)
        }
    }
    
    private var posterPreviewSection: some View {
        HStack(spacing: 6) {
            ForEach(Array(listItems.prefix(6).enumerated()), id: \.offset) { index, item in
                posterImageView(for: item)
            }
            
            // Add empty placeholders for remaining slots
            ForEach(0..<max(0, 6 - listItems.count), id: \.self) { _ in
                emptyPosterPlaceholder
            }
        }
    }
    
    @ViewBuilder
    private func posterImageView(for item: ListItem) -> some View {
        if let posterUrl = item.moviePosterUrl, !posterUrl.isEmpty {
            WebImage(url: URL(string: posterUrl))
                .resizable()
                .indicator(.activity)
                .transition(.fade(duration: 0.2))
                .scaledToFill()
                .frame(width: 50, height: 75)
                .cornerRadius(8)
                .clipped()
        } else {
            emptyPosterView
        }
    }
    
    
    private var emptyPosterView: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.2))
            .frame(width: 50, height: 75)
            .cornerRadius(8)
            .overlay(
                Image(systemName: "photo")
                    .foregroundColor(.gray.opacity(0.5))
                    .font(.caption)
            )
    }
    
    private var emptyPosterPlaceholder: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: 50, height: 75)
            .cornerRadius(8)
    }
}

// Placeholder for CreateListView
struct CreateListView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var dataManager = DataManager.shared
    @State private var listName = ""
    @State private var listDescription = ""
    @State private var isRanked = false
    @State private var selectedTags: [String] = []
    @State private var isCreating = false
    @State private var errorMessage: String?
    @State private var showingTagSelector = false
    @State private var newTagName = ""
    @State private var isThemedMonth = false
    @State private var themedMonthDate: Date = {
        // Default to first day of current month
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.year, .month], from: now)
        return calendar.date(from: DateComponents(year: components.year, month: components.month, day: 1)) ?? now
    }()
    
    // Predefined tags for selection (same as EditListView)
    private let predefinedTags = [
        "Action", "Comedy", "Drama", "Horror", "Thriller", "Romance", "Sci-Fi", "Fantasy",
        "Animation", "Documentary", "Biography", "Crime", "Mystery", "Adventure", "Family",
        "History", "War", "Western", "Musical", "Sport", "Favorites", "Watchlist", "Classics",
        "Recent", "Rewatches", "Theater", "Awards", "Foreign", "Indie", "Blockbuster"
    ]
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("List Name")
                        .font(.headline)
                        .foregroundColor(Color.adaptiveText(scheme: colorScheme))
                    
                    TextField("Enter list name", text: $listName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onChange(of: listName) { _, newValue in
                            checkAutoRanking()
                        }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Description (Optional)")
                        .font(.headline)
                        .foregroundColor(Color.adaptiveText(scheme: colorScheme))
                    
                    TextField("Enter description", text: $listDescription, axis: .vertical)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .lineLimit(3, reservesSpace: true)
                        .onChange(of: listDescription) { _, newValue in
                            checkAutoRanking()
                        }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Ranked List")
                            .font(.headline)
                            .foregroundColor(Color.adaptiveText(scheme: colorScheme))
                        
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
                            .foregroundColor(Color.adaptiveText(scheme: colorScheme))
                        
                        Spacer()
                        
                        Button("Add Tags", systemImage: "plus.circle") {
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
                                            .foregroundColor(Color.adaptiveText(scheme: colorScheme))
                                        
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
                                            .fill(AppColorHelpers.tagColor(for: tag))
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
                            .foregroundColor(Color.adaptiveText(scheme: colorScheme))
                        
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
                                .foregroundColor(Color.adaptiveText(scheme: colorScheme))
                            
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
                
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                }
                
                Spacer()
            }
            .padding()
            .background(Color.black)
            .navigationTitle("Create List")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Create", systemImage: "checkmark") {
                        Task {
                            await createList()
                        }
                    }
                    .disabled(listName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCreating)
                }
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
    
    private func createList() async {
        guard !listName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isCreating = true
        errorMessage = nil
        
        do {
            let description = listDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Create date for first day of selected month if themed month is enabled
            let finalThemedMonthDate: Date? = isThemedMonth ? {
                let calendar = Calendar.current
                let components = calendar.dateComponents([.year, .month], from: themedMonthDate)
                return calendar.date(from: DateComponents(year: components.year, month: components.month, day: 1))
            }() : nil
            
            _ = try await dataManager.createList(
                name: listName.trimmingCharacters(in: .whitespacesAndNewlines),
                description: description.isEmpty ? nil : description,
                ranked: isRanked,
                tags: selectedTags,
                themedMonthDate: finalThemedMonthDate
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isCreating = false
    }
    
    private func checkAutoRanking() {
        // Only auto-enable if currently disabled to avoid overriding user choice
        if !isRanked && MovieList.shouldAutoEnableRanking(name: listName, description: listDescription) {
            isRanked = true
        }
    }
}

// We can reuse the TagSelectorView from ListDetailsView.swift
// Note: In a real app, you'd want to extract this to a shared component file

#Preview {
    ListsView()
}

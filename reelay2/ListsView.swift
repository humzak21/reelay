//
//  ListsView.swift
//  reelay2
//
//  Created by Humza Khalil on 7/21/25.
//

import SwiftUI

struct ListsView: View {
    @StateObject private var dataManager = DataManager.shared
    @StateObject private var movieService = SupabaseMovieService.shared
    @State private var showingCreateList = false
    @State private var showingEditWatchlist = false
    @State private var selectedList: MovieList?
    @State private var listToEdit: MovieList?
    @State private var listToDelete: MovieList?
    @State private var showingDeleteListAlert = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingCSVImport = false
    
    // MARK: - Efficient Loading States
    @State private var hasLoadedInitially = false
    @State private var lastRefreshTime: Date = Date.distantPast
    @State private var isRefreshing = false
    
    private let refreshInterval: TimeInterval = 300 // 5 minutes
    
    var body: some View {
        contentView
            .navigationTitle("Lists")
            .navigationBarTitleDisplayMode(.large)
            .background(Color(.systemBackground))
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showingCSVImport = true
                    }) {
                        Image(systemName: "square.and.arrow.down")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Create New List", systemImage: "list.bullet") {
                            showingCreateList = true
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
                    // Test Railway cache performance and health for lists
                    Task {
                        print("🔍 [LISTSVIEW] Running Railway cache diagnostics for lists...")
                        await DataManagerRailway.shared.enableDetailedLogging()
                        
                        let healthStatus = await DataManagerRailway.shared.testCacheHealth()
                        print("🏥 [LISTSVIEW] Cache Health: \(healthStatus.isConnected ? "✅ Connected" : "❌ Disconnected")")
                        print("🏥 [LISTSVIEW] Response Time: \(String(format: "%.3f", healthStatus.responseTime))s")
                        
                        if let performanceReport = await DataManagerRailway.shared.runCachePerformanceTest() {
                            print("⚡ [LISTSVIEW] Cache Performance Report:")
                            print("📊 [LISTSVIEW] Average Response: \(String(format: "%.3f", performanceReport.averageResponseTime))s")
                            print("🎯 [LISTSVIEW] Cache Hit Rate: \(String(format: "%.1f", performanceReport.cacheHitRate * 100))%")
                            print("📦 [LISTSVIEW] Data Transferred: \(performanceReport.totalDataTransferred) bytes")
                        }
                    }
                    
                    await loadListsIfNeeded(force: true)
                    hasLoadedInitially = true
                }
            }
            .onChange(of: movieService.isLoggedIn) { _, isLoggedIn in
                if isLoggedIn {
                    Task {
                        await loadListsIfNeeded(force: true)
                        hasLoadedInitially = true
                    }
                } else {
                    hasLoadedInitially = false
                    lastRefreshTime = Date.distantPast
                }
            }
            .onAppear {
                // Only load if we haven't loaded initially or data is stale
                if movieService.isLoggedIn && shouldRefreshData() {
                    Task {
                        await loadListsIfNeeded(force: false)
                    }
                }
            }
            .sheet(isPresented: $showingCreateList) {
                CreateListView()
            }
            .sheet(isPresented: $showingCSVImport) {
                CSVImportTabbedView()
            }
            .sheet(isPresented: $showingEditWatchlist) {
                WatchlistEditView()
            }
            .sheet(item: $selectedList) { list in
                ListDetailsView(list: list)
            }
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
        VStack {
            Spacer()
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
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
            print("🔄 [LISTSVIEW] Skipping load - lists data is fresh (last refresh: \(lastRefreshTime))")
            return
        }
        
        guard !isLoading else { 
            print("⏳ [LISTSVIEW] Already loading lists, skipping duplicate request")
            return 
        }
        
        let startTime = Date()
        print("📋 [LISTSVIEW] Starting lists load - force: \(force)")
        print("🚂 [LISTSVIEW] Testing Railway cache for lists...")
        
        isLoading = true
        errorMessage = nil
        
        // First try Railway cache
        await DataManagerRailway.shared.loadListsFromCache()
        let duration = Date().timeIntervalSince(startTime)
        
        if !dataManager.movieLists.isEmpty {
            print("✅ [LISTSVIEW] SUCCESS: Got \(dataManager.movieLists.count) lists from Railway cache in \(String(format: "%.3f", duration))s")
            print("🎯 [LISTSVIEW] Railway cache HIT - No Supabase fallback needed for lists")
        } else {
            print("⚠️ [LISTSVIEW] Railway cache returned empty - using DataManager fallback")
            await dataManager.refreshLists()
            let fallbackDuration = Date().timeIntervalSince(startTime)
            print("🔄 [LISTSVIEW] DataManager fallback completed in \(String(format: "%.3f", fallbackDuration))s with \(dataManager.movieLists.count) lists")
        }
        
        lastRefreshTime = Date()
        let totalDuration = Date().timeIntervalSince(startTime)
        print("📊 [LISTSVIEW] Total lists load operation completed in \(String(format: "%.3f", totalDuration))s")
        
        isLoading = false
    }
    
    private func refreshLists() async {
        guard !isRefreshing else { 
            print("⏳ [LISTSVIEW] Already refreshing lists, skipping duplicate refresh request")
            return 
        }
        
        let startTime = Date()
        print("🔄 [LISTSVIEW] Manual lists refresh triggered by user pull-to-refresh")
        print("🚂 [LISTSVIEW] Attempting Railway cache refresh for lists...")
        
        isRefreshing = true
        errorMessage = nil
        
        // Try Railway cache refresh first
        await DataManagerRailway.shared.loadListsFromCache()
        let duration = Date().timeIntervalSince(startTime)
        
        if !dataManager.movieLists.isEmpty {
            print("✅ [LISTSVIEW] REFRESH SUCCESS: Got \(dataManager.movieLists.count) lists from Railway cache in \(String(format: "%.3f", duration))s")
            print("🎯 [LISTSVIEW] Railway cache HIT during refresh - No Supabase needed")
        } else {
            print("⚠️ [LISTSVIEW] Railway cache refresh returned empty - using DataManager fallback")
            await dataManager.refreshLists()
            let fallbackDuration = Date().timeIntervalSince(startTime)
            print("🔄 [LISTSVIEW] DataManager refresh fallback completed in \(String(format: "%.3f", fallbackDuration))s")
        }
        
        lastRefreshTime = Date()
        let totalDuration = Date().timeIntervalSince(startTime)
        print("📊 [LISTSVIEW] Total lists refresh operation completed in \(String(format: "%.3f", totalDuration))s")
        
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
    let list: MovieList
    let onTap: () -> Void
    @StateObject private var dataManager = DataManager.shared
    
    private var listItems: [ListItem] {
        dataManager.getListItems(list)
    }
    
    private var firstSixPosters: [String] {
        Array(listItems.prefix(6).compactMap { $0.moviePosterUrl })
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // List header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(list.name)
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
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
                    
                    Spacer()
                    
                    VStack {
                        Text("\(list.itemCount)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("films")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .textCase(.uppercase)
                    }
                }
                
                // Movie posters preview
                HStack(spacing: 6) {
                    ForEach(0..<6, id: \.self) { index in
                        if index < listItems.count {
                            let item = listItems[index]
                            if let posterUrl = item.moviePosterUrl, !posterUrl.isEmpty {
                                AsyncImage(url: URL(string: posterUrl)) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.3))
                                }
                                .frame(width: 50, height: 75)
                                .cornerRadius(8)
                                .clipped()
                            } else {
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
                        } else {
                            Rectangle()
                                .fill(Color.clear)
                                .frame(width: 50, height: 75)
                                .cornerRadius(8)
                        }
                    }
                }
            }
            .padding(16)
            .background(Color(.secondarySystemFill))
            .cornerRadius(16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// Placeholder for CreateListView
struct CreateListView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var dataManager = DataManager.shared
    @State private var listName = ""
    @State private var listDescription = ""
    @State private var isRanked = false
    @State private var isCreating = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("List Name")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    TextField("Enter list name", text: $listName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onChange(of: listName) { _, newValue in
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
                        .onChange(of: listDescription) { _, newValue in
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", systemImage: "xmark") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create", systemImage: "checkmark") {
                        Task {
                            await createList()
                        }
                    }
                    .disabled(listName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCreating)
                }
            }
        }
    }
    
    private func createList() async {
        guard !listName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isCreating = true
        errorMessage = nil
        
        do {
            let description = listDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            _ = try await dataManager.createList(
                name: listName.trimmingCharacters(in: .whitespacesAndNewlines),
                description: description.isEmpty ? nil : description,
                ranked: isRanked
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

#Preview {
    ListsView()
}

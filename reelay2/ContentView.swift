//
//  ContentView.swift
//  reelay2
//
//  Created by Humza Khalil on 7/19/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    
    #if os(macOS)
    @StateObject private var navigationCoordinator = NavigationCoordinator()
    #endif

    var body: some View {
        #if os(macOS)
        macOSBody
        #else
        iOSBody
        #endif
    }
    
    // MARK: - iOS Body (TabView - unchanged)
    #if !os(macOS)
    private var iOSBody: some View {
        TabView {
            Tab("Home", systemImage: "house") {
                NavigationView {
                    HomeView()
                }
            }
            
            Tab("Movies", systemImage: "film") {
                NavigationView {
                    MoviesView()
                }
            }
            
            Tab("Lists", systemImage: "list.bullet") {
                NavigationView {
                    ListsView()
                }
            }
            
            Tab("Profile", systemImage: "person.circle") {
                NavigationView {
                    ProfileView()
                }
            }
            
            Tab(role: .search) {
                NavigationView {
                    SearchView()
                }
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .background(Color(.systemGroupedBackground))
    }
    #endif
    
    // MARK: - macOS Body (NavigationSplitView)
    #if os(macOS)
    @State private var showingAddMovie = false
    @State private var showingCSVImport = false

    private var macOSBody: some View {
        NavigationSplitView {
            sidebarContent
        } content: {
            contentPane
        } detail: {
            detailPane
        }
        .frame(minWidth: 900, minHeight: 600)
        .environmentObject(navigationCoordinator)
        .onReceive(NotificationCenter.default.publisher(for: .switchSidebar)) { notification in
            if let item = notification.object as? SidebarItem {
                navigationCoordinator.selectedSidebarItem = item
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openAddMovie)) { _ in
            showingAddMovie = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .openCSVImport)) { _ in
            showingCSVImport = true
        }
        .sheet(isPresented: $showingAddMovie) {
            AddMoviesView()
        }
        .sheet(isPresented: $showingCSVImport) {
            CSVImportTabbedView()
        }
    }
    
    private var sidebarContent: some View {
        List(SidebarItem.allCases, selection: $navigationCoordinator.selectedSidebarItem) { item in
            Label(item.title, systemImage: item.systemImage)
                .tag(item)
        }
        .navigationTitle("Reelay")
        .listStyle(.sidebar)
    }
    
    @ViewBuilder
    private var contentPane: some View {
        switch navigationCoordinator.selectedSidebarItem {
        case .home:
            NavigationStack {
                HomeView()
            }
        case .movies:
            NavigationStack {
                MoviesView()
            }
        case .lists:
            NavigationStack {
                ListsView()
            }
        case .statistics:
            NavigationStack {
                StatisticsView()
            }
        case .search:
            NavigationStack {
                SearchView()
            }
        case .profile:
            NavigationStack {
                ProfileView()
            }
        case .none:
            NavigationStack {
                HomeView()
            }
        }
    }
    
    @ViewBuilder
    private var detailPane: some View {
        if let destination = navigationCoordinator.detailDestination {
            switch destination {
            case .movieDetails(let movie):
                MovieDetailsView(movie: movie)
            case .listDetails(let list):
                ListDetailsView(list: list)
            case .televisionDetails(let show):
                TelevisionDetailsView(televisionShow: show)
            case .albumDetails(let album):
                AlbumDetailsView(album: album)
            }
        } else {
            ContentUnavailableView {
                Label("No Selection", systemImage: "sidebar.right")
            } description: {
                Text("Select an item to view its details")
            }
        }
    }
    #endif

    private func addItem() {
        withAnimation {
            let newItem = Item(timestamp: Date())
            modelContext.insert(newItem)
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(items[index])
            }
        }
    }
}


#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}

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

    var body: some View {
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
        .background(Color(.systemBackground))
    }

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

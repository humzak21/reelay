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
    @State private var selectedList: MovieList?
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        contentView
            .navigationTitle("Lists")
            .navigationBarTitleDisplayMode(.large)
            .background(Color.black)
            .preferredColorScheme(.dark)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingCreateList = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .task {
                if movieService.isLoggedIn {
                    await loadLists()
                }
            }
            .onChange(of: movieService.isLoggedIn) { _, isLoggedIn in
                if isLoggedIn {
                    Task {
                        await loadLists()
                    }
                }
            }
            .sheet(isPresented: $showingCreateList) {
                CreateListView()
            }
            .sheet(item: $selectedList) { list in
                ListDetailsView(list: list)
            }
            .refreshable {
                await loadLists()
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
                .foregroundColor(.white)

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
                .foregroundColor(.white)
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
                .foregroundColor(.white)
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
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.vertical, 16)
            }
        }
        .scrollContentBackground(.hidden)
    }
    
    private func loadLists() async {
        print("📋 ListsView: Starting to load lists...")
        isLoading = true
        errorMessage = nil
        
        await dataManager.refreshLists()
        print("📋 ListsView: Lists loaded, count: \(dataManager.movieLists.count)")
        
        isLoading = false
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
            .background(Color.gray.opacity(0.15))
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
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Description (Optional)")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    TextField("Enter description", text: $listDescription, axis: .vertical)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .lineLimit(3, reservesSpace: true)
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
            .preferredColorScheme(.dark)
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
                description: description.isEmpty ? nil : description
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isCreating = false
    }
}

#Preview {
    ListsView()
}
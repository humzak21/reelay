//
//  ThemedMonthDebugView.swift
//  reelay2
//
//  Debug view to test themed month functionality
//

import SwiftUI

struct ThemedMonthDebugView: View {
    @StateObject private var dataManager = DataManager.shared
    @State private var debugOutput: String = ""
    @State private var selectedList: MovieList?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Current date info
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Current Date Info")
                            .font(.headline)
                        Text("Today: \(Date().description)")
                        Text("Current Month: \(currentMonthString())")
                    }
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
                    
                    // All lists with themed dates
                    VStack(alignment: .leading, spacing: 8) {
                        Text("All Lists with Themed Dates")
                            .font(.headline)
                        
                        ForEach(dataManager.getAllThemedLists(), id: \.id) { list in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(list.name)
                                    .fontWeight(.semibold)
                                if let date = list.themedMonthDate {
                                    Text("Themed Date: \(date.description)")
                                        .font(.caption)
                                    Text("Month: \(monthString(from: date))")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding(8)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(6)
                        }
                        
                        if dataManager.getAllThemedLists().isEmpty {
                            Text("No lists have themed dates set")
                                .foregroundColor(.gray)
                                .italic()
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
                    
                    // Current month themed lists
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Current Month Themed Lists")
                            .font(.headline)
                        
                        ForEach(dataManager.getThemedLists(), id: \.id) { list in
                            Text(list.name)
                                .padding(8)
                                .background(Color.green.opacity(0.2))
                                .cornerRadius(6)
                        }
                        
                        if dataManager.getThemedLists().isEmpty {
                            Text("No themed lists for current month")
                                .foregroundColor(.gray)
                                .italic()
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
                    
                    // Test buttons
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Test Actions")
                            .font(.headline)
                        
                        Button("Refresh Lists") {
                            Task {
                                await dataManager.refreshLists()
                                debugOutput = "Lists refreshed at \(Date().description)"
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button("Test Create List with Themed Date") {
                            Task {
                                await testCreateThemedList()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        
                        if let selectedList = selectedList {
                            Button("Test Update \(selectedList.name)") {
                                Task {
                                    await testUpdateThemedDate(for: selectedList)
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
                    
                    // Debug output
                    if !debugOutput.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Debug Output")
                                .font(.headline)
                            Text(debugOutput)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.green)
                        }
                        .padding()
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(8)
                    }
                }
                .padding()
            }
            .navigationTitle("Themed Month Debug")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Select List") {
                        // In a real app, show a picker
                        selectedList = dataManager.movieLists.first
                    }
                }
            }
        }
    }
    
    private func currentMonthString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: Date())
    }
    
    private func monthString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
    
    private func testCreateThemedList() async {
        do {
            let calendar = Calendar.current
            let now = Date()
            let components = calendar.dateComponents([.year, .month], from: now)
            let firstOfMonth = calendar.date(from: DateComponents(year: components.year, month: components.month, day: 1))!
            
            let list = try await dataManager.createList(
                name: "Test Themed List \(Int.random(in: 1000...9999))",
                description: "Testing themed month functionality",
                ranked: false,
                tags: ["test"],
                themedMonthDate: firstOfMonth
            )
            
            debugOutput = """
            Created list: \(list.name)
            ID: \(list.id)
            Themed Date: \(list.themedMonthDate?.description ?? "nil")
            """
            
            await dataManager.refreshLists()
        } catch {
            debugOutput = "Error creating list: \(error.localizedDescription)"
        }
    }
    
    private func testUpdateThemedDate(for list: MovieList) async {
        do {
            let calendar = Calendar.current
            let nextMonth = calendar.date(byAdding: .month, value: 1, to: Date())!
            let components = calendar.dateComponents([.year, .month], from: nextMonth)
            let firstOfNextMonth = calendar.date(from: DateComponents(year: components.year, month: components.month, day: 1))!
            
            let updated = try await dataManager.updateList(
                list,
                themedMonthDate: firstOfNextMonth,
                updateThemedMonthDate: true
            )
            
            debugOutput = """
            Updated list: \(updated.name)
            New Themed Date: \(updated.themedMonthDate?.description ?? "nil")
            """
            
            await dataManager.refreshLists()
        } catch {
            debugOutput = "Error updating list: \(error.localizedDescription)"
        }
    }
}

#Preview {
    ThemedMonthDebugView()
}
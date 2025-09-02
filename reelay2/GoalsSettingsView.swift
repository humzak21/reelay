//
//  GoalsSettingsView.swift
//  reelay2
//
//  Created by Claude on 8/28/25.
//

import SwiftUI

struct GoalsSettingsView: View {
    @StateObject private var dataManager = DataManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var yearlyFilmGoal: String = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Annual Film Goal")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Set how many films you want to watch this calendar year.")
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        TextField("0", text: $yearlyFilmGoal)
                            .keyboardType(.numberPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(maxWidth: 100)
                        
                        Text("films this year")
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                }
                
                Spacer()
                
                Text("More goals coming soon...")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Goals")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", systemImage: "xmark") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save", systemImage: "checkmark") {
                        saveGoals()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            yearlyFilmGoal = dataManager.yearlyFilmGoal > 0 ? String(dataManager.yearlyFilmGoal) : ""
        }
    }
    
    private func saveGoals() {
        if let goal = Int(yearlyFilmGoal), goal > 0 {
            dataManager.saveYearlyFilmGoal(goal)
        } else {
            dataManager.saveYearlyFilmGoal(0)
        }
    }
}

#Preview {
    GoalsSettingsView()
}
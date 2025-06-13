//
//  SettingsView.swift
//  reelay
//
//  Created by Humza Khalil on 6/11/25.
//

import SwiftUI

struct SettingsView: View {
    @Binding var showingAddMovie: Bool
    
    var body: some View {
        NavigationView {
            List {
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Build")
                        Spacer()
                        Text("1")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Support") {
                    Link("Contact Support", destination: URL(string: "mailto:support@example.com")!)
                    Link("Privacy Policy", destination: URL(string: "https://example.com/privacy")!)
                    Link("Terms of Service", destination: URL(string: "https://example.com/terms")!)
                }
                
                Section("Data") {
                    Button("Export Data") {
                        // TODO: Implement data export
                    }
                    
                    Button("Reset All Data") {
                        // TODO: Implement data reset
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showingAddMovie = true
                        } label: {
                            Label("Add Film", systemImage: "film")
                        }
                        
                        Button {
                            // TODO: Add TV show functionality
                        } label: {
                            Label("Add TV Show", systemImage: "tv")
                        }
                        
                        Button {
                            // TODO: Add music functionality
                        } label: {
                            Label("Add Music", systemImage: "music.note")
                        }
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
        }
    }
} 
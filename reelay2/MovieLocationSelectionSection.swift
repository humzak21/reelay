//
//  MovieLocationSelectionSection.swift
//  reelay2
//

import SwiftUI
import MapKit

struct MovieLocationSelectionSection: View {
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    @Binding var searchText: String
    let isSearching: Bool
    let isResolvingSelection: Bool
    let searchResults: [MKLocalSearchCompletion]

    let selectedLocationName: String?
    let selectedLocationAddress: String?
    let selectedLatitude: Double?
    let selectedLongitude: Double?

    let groups: [LocationGroup]
    @Binding var selectedGroupId: Int?
    @Binding var isCreatingNewGroup: Bool
    @Binding var newGroupName: String

    let onSearchTextChanged: (String) -> Void
    let onSelectSearchResult: (MKLocalSearchCompletion) -> Void
    let onClearSearch: () -> Void
    let onClearLocation: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(Color.adaptiveText(scheme: colorScheme))

            if let selectedLocationName {
                selectedLocationCard(name: selectedLocationName)
                groupSelector
            } else {
                searchField
                searchResultsList
            }
        }
    }

    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)

            TextField("Search for address or place...", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .foregroundColor(Color.adaptiveText(scheme: colorScheme))
                .onChange(of: searchText) { _, newValue in
                    onSearchTextChanged(newValue)
                }

            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                    onClearSearch()
                }) {
                    Image(systemName: "xmark")
                        .foregroundColor(.gray)
                }
                .buttonStyle(PlainButtonStyle())
            }

            if isSearching {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(10)
    }

    @ViewBuilder
    private var searchResultsList: some View {
        if !searchResults.isEmpty {
            let results = Array(searchResults.prefix(5))
            VStack(spacing: 0) {
                ForEach(Array(results.enumerated()), id: \.offset) { index, completion in
                    Button(action: {
                        onSelectSearchResult(completion)
                    }) {
                        HStack(spacing: 10) {
                            Image(systemName: "mappin.circle")
                                .foregroundColor(.blue)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(completion.title)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(Color.adaptiveText(scheme: colorScheme))
                                    .lineLimit(1)

                                if !completion.subtitle.isEmpty {
                                    Text(completion.subtitle)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            }

                            Spacer()
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                    }
                    .buttonStyle(PlainButtonStyle())

                    if index < results.count - 1 {
                        Divider().padding(.leading, 42)
                    }
                }
            }
            .background(colorScheme == .dark ? Color.gray.opacity(0.2) : Color.white)
            .cornerRadius(10)
        }
    }

    @ViewBuilder
    private func selectedLocationCard(name: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "mappin.circle.fill")
                    .foregroundColor(.blue)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(Color.adaptiveText(scheme: colorScheme))
                        .lineLimit(2)

                    if let selectedLocationAddress, !selectedLocationAddress.isEmpty {
                        Text(selectedLocationAddress)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer()

                if isResolvingSelection {
                    ProgressView()
                        .scaleEffect(0.8)
                }

                Button(action: onClearLocation) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .font(.title3)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(12)
            .background(colorScheme == .dark ? Color.gray.opacity(0.2) : Color.white)
            .cornerRadius(10)

            if let selectedLatitude, let selectedLongitude {
                Map(initialPosition: .region(MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: selectedLatitude, longitude: selectedLongitude),
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                ))) {
                    Marker(name, coordinate: CLLocationCoordinate2D(latitude: selectedLatitude, longitude: selectedLongitude))
                        .tint(.purple)
                }
                .frame(height: 150)
                .cornerRadius(10)
                .allowsHitTesting(false)
            }
        }
    }

    private var groupSelector: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Location Group")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(Color.adaptiveText(scheme: colorScheme))

            Picker("Location Group", selection: $selectedGroupId) {
                Text("No Group").tag(Optional<Int>.none)
                ForEach(groups) { group in
                    Text(group.name).tag(Optional(group.id))
                }
            }
            .pickerStyle(.menu)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.gray.opacity(0.15))
            .cornerRadius(8)

            Button(isCreatingNewGroup ? "Use Existing Group" : "Create New Group") {
                isCreatingNewGroup.toggle()
                if !isCreatingNewGroup {
                    newGroupName = ""
                }
            }
            .font(.caption)
            .buttonStyle(.plain)
            .foregroundColor(.blue)

            if isCreatingNewGroup {
                TextField("New group name", text: $newGroupName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    #if os(iOS)
                    .autocapitalization(.words)
                    #endif
            }
        }
    }
}

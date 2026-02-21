//
//  LocationHelper.swift
//  reelay2
//
//  Location search, driving time estimates, and Apple Maps integration
//

import Foundation
import MapKit
import CoreLocation
import Combine

@MainActor
class LocationHelper: NSObject, ObservableObject {
    @Published var searchResults: [MKLocalSearchCompletion] = []
    @Published var isSearching = false
    @Published var userLocation: CLLocationCoordinate2D?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    private var searchCompleter: MKLocalSearchCompleter
    private var locationManager: CLLocationManager
    private var completerDelegate: CompleterDelegate?
    private var locationDelegate: LocationDelegate?
    
    override init() {
        self.searchCompleter = MKLocalSearchCompleter()
        self.locationManager = CLLocationManager()
        
        super.init()
        
        // Set up search completer
        let completerDel = CompleterDelegate()
        self.completerDelegate = completerDel
        self.searchCompleter.delegate = completerDel
        self.searchCompleter.resultTypes = [.pointOfInterest, .address]
        
        // Set up location manager
        let locationDel = LocationDelegate()
        self.locationDelegate = locationDel
        self.locationManager.delegate = locationDel
        self.locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        
        // Forward delegate callbacks
        completerDel.onResultsUpdate = { [weak self] results in
            Task { @MainActor in
                self?.searchResults = results
                self?.isSearching = false
            }
        }
        
        completerDel.onError = { [weak self] _ in
            Task { @MainActor in
                self?.isSearching = false
            }
        }
        
        locationDel.onLocationUpdate = { [weak self] location in
            Task { @MainActor in
                self?.userLocation = location.coordinate
            }
        }
        
        locationDel.onAuthorizationChange = { [weak self] status in
            Task { @MainActor in
                self?.authorizationStatus = status
            }
        }
    }
    
    // MARK: - Location Authorization
    
    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func requestCurrentLocation() {
        locationManager.requestLocation()
    }
    
    // MARK: - Location Search
    
    func searchLocations(query: String) {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            searchResults = []
            isSearching = false
            return
        }
        isSearching = true
        searchCompleter.queryFragment = query
    }
    
    func clearSearch() {
        searchResults = []
        searchCompleter.queryFragment = ""
        isSearching = false
    }
    
    /// Resolve a search completion to a full map item with coordinates
    func resolveLocation(_ completion: MKLocalSearchCompletion) async -> MKMapItem? {
        let request = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: request)
        
        do {
            let response = try await search.start()
            return response.mapItems.first
        } catch {
            print("Error resolving location: \(error)")
            return nil
        }
    }
    
    // MARK: - Driving Time
    
    /// Get driving time from current location to a destination
    func getDrivingTime(to destination: CLLocationCoordinate2D) async -> String? {
        // Try to get current location
        requestCurrentLocation()
        
        // Wait briefly for location
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        
        guard let userCoord = userLocation else {
            return nil
        }
        
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: userCoord))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        request.transportType = .automobile
        
        let directions = MKDirections(request: request)
        
        do {
            let response = try await directions.calculate()
            if let route = response.routes.first {
                let minutes = Int(route.expectedTravelTime / 60)
                if minutes < 60 {
                    return "~\(minutes) min drive"
                } else {
                    let hours = minutes / 60
                    let remainingMin = minutes % 60
                    return "~\(hours)h \(remainingMin)m drive"
                }
            }
        } catch {
            print("Error calculating driving time: \(error)")
        }
        
        return nil
    }
}

// MARK: - MKLocalSearchCompleter Delegate

private class CompleterDelegate: NSObject, MKLocalSearchCompleterDelegate {
    var onResultsUpdate: (([MKLocalSearchCompletion]) -> Void)?
    var onError: ((Error) -> Void)?
    
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        onResultsUpdate?(completer.results)
    }
    
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        onError?(error)
    }
}

// MARK: - CLLocationManager Delegate

private class LocationDelegate: NSObject, CLLocationManagerDelegate {
    var onLocationUpdate: ((CLLocation) -> Void)?
    var onAuthorizationChange: ((CLAuthorizationStatus) -> Void)?
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            onLocationUpdate?(location)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error)")
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        onAuthorizationChange?(manager.authorizationStatus)
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        }
    }
}

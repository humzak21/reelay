//
//  SearchView.swift
//  reelay2
//
//  Created by Humza Khalil on 7/21/25.
//

import SwiftUI

struct SearchView: View {
    @State private var searchString = ""
    
    var body: some View {
        NavigationView {
            Text("Search")
                .navigationTitle("Search")
                .searchable(text: $searchString)
        }
    }
}

#Preview {
    SearchView()
}
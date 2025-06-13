//
//  GenreStatsChartView.swift
//  reelay
//
//  Created by Humza Khalil on 6/11/25.
//

import SwiftUI
import Charts

struct GenreStatsChartView: View {
    let data: [GenreStats]
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Genres")
                .font(.title2)
                .fontWeight(.bold)
            
            Chart(data.prefix(10), id: \.genreName) { item in
                BarMark(
                    x: .value("Count", item.filmCount),
                    y: .value("Genre", item.genreName)
                )
                .foregroundStyle(.green)
            }
            .frame(height: 300)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
} 
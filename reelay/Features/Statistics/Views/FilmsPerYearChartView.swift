//
//  FilmsPerYearChartView.swift
//  reelay
//
//  Created by Humza Khalil on 6/11/25.
//

import SwiftUI
import Charts

struct FilmsPerYearChartView: View {
    let data: [FilmsPerYear]
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Films Per Year")
                .font(.title2)
                .fontWeight(.bold)
            
            Chart(data, id: \.year) { item in
                LineMark(
                    x: .value("Year", item.year),
                    y: .value("Films", item.filmCount)
                )
                .foregroundStyle(.purple)
                .interpolationMethod(.catmullRom)
                
                PointMark(
                    x: .value("Year", item.year),
                    y: .value("Films", item.filmCount)
                )
                .foregroundStyle(.purple)
            }
            .frame(height: 200)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
} 
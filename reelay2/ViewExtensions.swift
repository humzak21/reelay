//
//  ViewExtensions.swift
//  reelay2
//
//  Created by Humza Khalil on 8/1/25.
//

import SwiftUI

extension View {
    func glassEffect(in shape: some InsettableShape) -> some View {
        self
            .background {
                shape
                    .fill(.ultraThinMaterial, style: FillStyle())
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
            }
    }
}
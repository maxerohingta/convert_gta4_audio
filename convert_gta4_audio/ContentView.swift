//
//  ContentView.swift
//  convert_gta4_audio
//
//  Created by Alexey Vorobyov on 31.07.2025.
//

import SwiftUI

struct ContentView: View {
    @State var viewModel = ViewModel()
    var body: some View {
        Button(
            action: {
                viewModel.doTheHarlemShake()
            },
            label: {
                Text("Пыщь")
                    .font(.title)
                    .padding(40)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .clipShape(Circle())
                    .shadow(radius: 10)
            }
        )
        .onAppear {
            viewModel.doTheHarlemShake()
        }
    }
}

#Preview {
    ContentView()
}

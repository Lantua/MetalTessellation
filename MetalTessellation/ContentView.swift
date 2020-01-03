//
//  ContentView.swift
//  MetalTessellation
//
//  Created by Natchanon Luangsomboon on 10/11/2562 BE.
//  Copyright © 2562 Natchanon Luangsomboon. All rights reserved.
//

import SwiftUI
import Metal

struct TessellationConfiguration {
    var patchType = MTLPatchType.triangle
    var wireframe = false
    var edgeFactor: Float = 2.0
    var insideFactor: Float = 2.0
}

struct ContentView: View {
    @State var configuration = TessellationConfiguration()

    var body: some View {
        HStack {
            TessellationView(configuration: $configuration)
            ConfigurationView(configuration: $configuration)
        }
    .frame(minWidth: 800, minHeight: 500)
    }
}

struct ConfigurationView: View {
    @Binding var configuration: TessellationConfiguration

    var body: some View {
        VStack(alignment: .leading) {
            Picker("Patch Type", selection: $configuration.patchType) {
                Text("Triangle").tag(MTLPatchType.triangle)
                Text("Quad").tag(MTLPatchType.quad)
            }
            .pickerStyle(SegmentedPickerStyle())
            Toggle(isOn: $configuration.wireframe) {
                Text("Wireframe")
            }
            HStack {
                Slider(value: $configuration.edgeFactor, in: 2...64) {
                    Text("Edge Factor")
                }
                Text("\(configuration.edgeFactor, specifier: "%.2f")")
            }
            HStack {
                Slider(value: $configuration.insideFactor, in: 2...64) {
                    Text("Inside Factor")
                }
                Text("\(configuration.insideFactor, specifier: "%.2f")")
            }
        }
        .frame(maxWidth: 300)
    }
}

struct ConfigurationView_Previews: PreviewProvider {
    static var previews: some View {
        var configuration = TessellationConfiguration()
        let binding = Binding(get: { configuration }, set: { configuration = $0 })

        return ConfigurationView(configuration: binding)
    }
}

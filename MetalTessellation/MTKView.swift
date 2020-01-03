//
//  MTKView.swift
//  MetalTessellation
//
//  Created by Natchanon Luangsomboon on 10/11/2562 BE.
//  Copyright © 2562 Natchanon Luangsomboon. All rights reserved.
//

import Foundation
import SwiftUI
import MetalKit

struct TessellationView: NSViewRepresentable {
    @Binding var configuration: TessellationConfiguration

    func makeNSView(context: Context) -> MTKView {
        let coordinator = context.coordinator, view = MTKView()
        view.delegate = coordinator
        view.device = coordinator.device
        try! coordinator.createRenderPipeline(for: view)
        return view
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        let coordinator = context.coordinator
        coordinator.patchType = configuration.patchType
        coordinator.edgeFactor = configuration.edgeFactor
        coordinator.insideFactor = configuration.insideFactor
        coordinator.wireframe = configuration.wireframe
    }

    static func dismantleNSView(_ nsView: MTKView, coordinator: TessellationPipeline) { }

    func makeCoordinator() -> TessellationPipeline {
        try! TessellationPipeline(device: MTLCreateSystemDefaultDevice()!)
    }
}

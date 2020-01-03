//
//  TessellationPipeline.swift
//  MetalTessellation
//
//  Created by Natchanon Luangsomboon on 10/11/2562 BE.
//  Copyright © 2562 Natchanon Luangsomboon. All rights reserved.
//

import Foundation
import MetalKit

class TessellationPipeline: NSObject, MTKViewDelegate {
    var patchType = MTLPatchType.triangle
    var wireframe = true
    var edgeFactor: Float = 2.0, insideFactor: Float = 2.0

    let device: MTLDevice
    private let commandQueue: MTLCommandQueue, library: MTLLibrary
    private let computePipelineTriangle, computePipelineQuad: MTLComputePipelineState
    private let tessellationFactorBuffer, controlPointsBufferTriangle, controlPointsBufferQuad: MTLBuffer

    private var renderPipelineTriangle, renderPipelineQuad: MTLRenderPipelineState?

    init(device: MTLDevice) throws {
        precondition(device.supportsFeatureSet(.macOS_GPUFamily1_v1), "Tessellation required.")

        self.device = device
        commandQueue = device.makeCommandQueue()!
        library = device.makeDefaultLibrary()!

        do {
            let kernelFunctionTriangle = library.makeFunction(name: "tessellation_kernel_triangle")!
            computePipelineTriangle = try device.makeComputePipelineState(function: kernelFunctionTriangle)

            let kernelFunctionQuad = library.makeFunction(name: "tessellation_kernel_quad")!
            computePipelineQuad = try device.makeComputePipelineState(function: kernelFunctionQuad)
        }

        do {
            tessellationFactorBuffer = device.makeBuffer(length: 256, options: .storageModePrivate)!
            tessellationFactorBuffer.label = "Tessellation Factors"

            let controlPointPositionsTriangle: [Float] = [
                -0.8, -0.8, 0.0, 1.0,   // lower-left
                0.0,  0.8, 0.0, 1.0,   // upper-middle
                0.8, -0.8, 0.0, 1.0,   // lower-right
            ]
            controlPointsBufferTriangle = device.makeBuffer(bytes: controlPointPositionsTriangle, length: controlPointPositionsTriangle.count * MemoryLayout<Float>.stride, options: .storageModeManaged)!
            controlPointsBufferTriangle.label = "Control Points Triangle"

            let controlPointPositionsQuad: [Float] = [
                -0.8,  0.8, 0.0, 1.0,   // upper-left
                0.8,  0.8, 0.0, 1.0,   // upper-right
                0.8, -0.8, 0.0, 1.0,   // lower-right
                -0.8, -0.8, 0.0, 1.0,   // lower-left
            ]
            controlPointsBufferQuad = device.makeBuffer(bytes: controlPointPositionsQuad, length: controlPointPositionsQuad.count * MemoryLayout<Float>.stride, options: .storageModeManaged)!
            controlPointsBufferQuad.label = "Control Points Quad"
        }

        super.init()
    }

    func createRenderPipeline(for mtkView: MTKView) throws {
        assert(renderPipelineTriangle == nil && renderPipelineQuad == nil)
        let vertexDescriptor = MTLVertexDescriptor()
        vertexDescriptor.attributes[0].format = .float4
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0
        vertexDescriptor.layouts[0].stepFunction = .perPatchControlPoint
        vertexDescriptor.layouts[0].stepRate = 1
        vertexDescriptor.layouts[0].stride = 4 * MemoryLayout<Float>.stride

        let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
        renderPipelineDescriptor.vertexDescriptor = vertexDescriptor;
        renderPipelineDescriptor.sampleCount = mtkView.sampleCount;
        renderPipelineDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat;
        renderPipelineDescriptor.fragmentFunction = library.makeFunction(name: "tessellation_fragment")!

        // Configure common tessellation properties
        renderPipelineDescriptor.isTessellationFactorScaleEnabled = false
        renderPipelineDescriptor.tessellationFactorFormat = .half
        renderPipelineDescriptor.tessellationControlPointIndexType = .none
        renderPipelineDescriptor.tessellationFactorStepFunction = .constant
        renderPipelineDescriptor.tessellationOutputWindingOrder = .clockwise
        renderPipelineDescriptor.tessellationPartitionMode = .fractionalEven
        renderPipelineDescriptor.maxTessellationFactor = 64

        renderPipelineDescriptor.vertexFunction = library.makeFunction(name: "tessellation_vertex_triangle")!
        renderPipelineTriangle = try device.makeRenderPipelineState(descriptor: renderPipelineDescriptor)

        renderPipelineDescriptor.vertexFunction = library.makeFunction(name: "tessellation_vertex_quad")!
        renderPipelineQuad = try device.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
    }

    func computeTessellationFactors(commandBuffer: MTLCommandBuffer) {
        let computeCommandEncoder = commandBuffer.makeComputeCommandEncoder()!
        computeCommandEncoder.label = "Compute Command Encoder"

        computeCommandEncoder.pushDebugGroup("Compute Tessellation Factors")

        switch patchType {
        case .triangle: computeCommandEncoder.setComputePipelineState(computePipelineTriangle)
        case .quad: computeCommandEncoder.setComputePipelineState(computePipelineQuad)
        default: fatalError("Invalid patch type")
        }

        // Bind the user-selected edge and inside factor values to the compute kernel
        computeCommandEncoder.setBytes([edgeFactor], length: MemoryLayout<Float>.size, index: 0)
        computeCommandEncoder.setBytes([insideFactor], length: MemoryLayout<Float>.size, index: 1)

        // Bind the tessellation factors buffer to the compute kernel
        computeCommandEncoder.setBuffer(tessellationFactorBuffer, offset: 0, index: 2)

        // Dispatch threadgroups
        computeCommandEncoder.dispatchThreadgroups(MTLSize(width: 1, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))

        // All compute commands have been encoded
        computeCommandEncoder.popDebugGroup()
        computeCommandEncoder.endEncoding()
    }

    func tessellateAndRender(in view: MTKView, commandBuffer: MTLCommandBuffer) {
        guard let renderPassDescriptor = view.currentRenderPassDescriptor else {
            return
        }

        let renderCommandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
        renderCommandEncoder.label = "Render Command Encoder"

        renderCommandEncoder.pushDebugGroup("Tessellate and Render")
        switch patchType {
        case .triangle:
            renderCommandEncoder.setRenderPipelineState(renderPipelineTriangle!)
            renderCommandEncoder.setVertexBuffer(controlPointsBufferTriangle, offset: 0, index: 0)
        case .quad:
            renderCommandEncoder.setRenderPipelineState(renderPipelineQuad!)
            renderCommandEncoder.setVertexBuffer(controlPointsBufferQuad, offset: 0, index: 0)
        default: fatalError("Unreachable")
        }

        if wireframe {
            renderCommandEncoder.setTriangleFillMode(.lines)
        }

        // Encode tessellation-specific commands
        renderCommandEncoder.setTessellationFactorBuffer(tessellationFactorBuffer, offset: 0, instanceStride: 0)
        let patchControlPoints: Int
        switch patchType {
        case .triangle: patchControlPoints = 3
        case .quad: patchControlPoints = 4
        default: fatalError("Unreachable")
        }
        renderCommandEncoder.drawPatches(numberOfPatchControlPoints: patchControlPoints, patchStart: 0, patchCount: 1, patchIndexBuffer: nil, patchIndexBufferOffset: 0, instanceCount: 1, baseInstance: 0)

        // All render commands have been encoded
        renderCommandEncoder.popDebugGroup()
        renderCommandEncoder.endEncoding()

        // Schedule a present once the drawable has been completely rendered to
        if let drawable = view.currentDrawable {
            commandBuffer.present(drawable)

        }
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) { }

    func draw(in view: MTKView) {
        // Create a new command buffer for each tessellation pass
        let commandBuffer = commandQueue.makeCommandBuffer()!
        commandBuffer.label = "Tessellation Pass"

        computeTessellationFactors(commandBuffer: commandBuffer)
        tessellateAndRender(in: view, commandBuffer: commandBuffer)

        // Finalize tessellation pass and commit the command buffer to the GPU
        commandBuffer.commit()
    }
}

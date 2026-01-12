// The Swift Programming Language
// https://docs.swift.org/swift-book

import AVFoundation
import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI

// MARK: - Julia Set Filter
class JuliaSetFilter: CIFilter {
  var inputImage: CIImage?

  private static let kernel: CIWarpKernel? = {
    try? CIWarpKernel(source: """
      kernel vec2 juliaWarp(vec2 extent) {
        // Get current pixel position
        vec2 pos = destCoord();

        // Transform to centered coordinates (-1 to 1 range)
        vec2 center = extent / 2.0;
        vec2 normalized = (pos - center) / min(center.x, center.y);

        // Apply z² in complex plane: (x² - y², 2xy)
        float x = normalized.x;
        float y = normalized.y;
        vec2 transformed = vec2(x*x - y*y, 2.0*x*y);

        // Transform back to image coordinates
        vec2 result = transformed * min(center.x, center.y) + center;

        return result;
      }
      """)
  }()

  override var outputImage: CIImage? {
    guard let inputImage = inputImage,
          let kernel = Self.kernel else { return nil }

    let extent = inputImage.extent
    return kernel.apply(
      extent: extent,
      roiCallback: { _, rect in rect },
      image: inputImage,
      arguments: [CIVector(x: extent.width, y: extent.height)]
    )
  }
}

// MARK: - Video Capture Manager
@available(macOS 14.0, *)
@MainActor
final class CameraManager: NSObject, ObservableObject {
  // MARK: Public
  @Published var ciImage: CIImage? = nil

  // MARK: Private
  private let session = AVCaptureSession()
  private let queue = DispatchQueue(label: "cameraQueue")
  private let ciContext = CIContext()

  // MARK: Init
  override init() {
    super.init()
    setupSession()
    session.startRunning()
  }

  private func bestVideoDevice() -> AVCaptureDevice? {
    // // Prefer the built‑in camera (if you’re on a MacBook)
    if let builtIn = AVCaptureDevice.default(
      .builtInWideAngleCamera,
      for: .video,
      position: .unspecified)
    {
      return builtIn
    }

    // Fallback to a Continuity Camera (iPhone/iPad, or USB camera that Apple recognises)
    return AVCaptureDevice.default(
      .continuityCamera,
      for: .video,
      position: .unspecified)
  }

  private func setupSession() {
    guard let device = bestVideoDevice() else {
      print("❌ No suitable camera found")
      return
    }

    guard let input = try? AVCaptureDeviceInput(device: device) else {
      print("❌ Cannot create input from \(device.localizedName)")
      return
    }

    if session.canAddInput(input) { session.addInput(input) }

    let output = AVCaptureVideoDataOutput()
    output.videoSettings = [
      kCVPixelBufferPixelFormatTypeKey as String:
        kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
    ]
    output.setSampleBufferDelegate(self, queue: queue)
    if session.canAddOutput(output) { session.addOutput(output) }

    // Keep 30 fps
    session.sessionPreset = .hd1920x1080
  }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
@available(macOS 14.0, *)
extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
  nonisolated func captureOutput(
    _ output: AVCaptureOutput,
    didOutput sampleBuffer: CMSampleBuffer,
    from connection: AVCaptureConnection
  ) {
    guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

    // Convert to CIImage
    let inputImage = CIImage(cvPixelBuffer: pixelBuffer)

    // Apply Julia set transformation
    let juliaFilter = JuliaSetFilter()
    juliaFilter.inputImage = inputImage
    let finalImage = juliaFilter.outputImage ?? inputImage
    Task { @MainActor [weak self] in
      self?.ciImage = finalImage
    }
  }
}

// MARK: - SwiftUI View
@available(macOS 14.0, *)
struct CameraView: View {
  @StateObject private var camera = CameraManager()
  private let ciContext = CIContext()

  var body: some View {
    GeometryReader { geo in
      if let ciImage = camera.ciImage,
         let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) {

        let nsSize = NSSize(width: ciImage.extent.width, height: ciImage.extent.height)
        let nsImage = NSImage(cgImage: cgImage, size: nsSize)

        Image(nsImage: nsImage)
          .resizable()
          .scaledToFit()
      } else {
        Color.black
      }
    }
    .background(Color.black)
  }
}

// MARK: - App Entry Point

@main
struct JuliaSetCameraDemo: App {
  var body: some Scene {
    WindowGroup {
      if #available(macOS 14.0, *) {
        CameraView()
      } else {
        // break or do something?
      }
    }
  }
}

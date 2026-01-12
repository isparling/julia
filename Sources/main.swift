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
  @Published var availableCameras: [AVCaptureDevice] = []
  @Published var selectedCamera: AVCaptureDevice?

  // MARK: Private
  private let session = AVCaptureSession()
  private let queue = DispatchQueue(label: "cameraQueue")
  private let ciContext = CIContext()
  private var currentInput: AVCaptureDeviceInput?

  // MARK: Init
  override init() {
    super.init()
    refreshCameraList()
    setupSession()
    session.startRunning()
  }

  func refreshCameraList() {
    let discoverySession = AVCaptureDevice.DiscoverySession(
      deviceTypes: [.builtInWideAngleCamera, .continuityCamera, .external],
      mediaType: .video,
      position: .unspecified
    )
    availableCameras = discoverySession.devices
    if selectedCamera == nil {
      selectedCamera = availableCameras.first
    }
  }

  func selectCamera(_ device: AVCaptureDevice) {
    guard device.uniqueID != selectedCamera?.uniqueID else { return }
    selectedCamera = device

    session.beginConfiguration()

    // Remove existing input
    if let currentInput = currentInput {
      session.removeInput(currentInput)
    }

    // Add new input
    guard let newInput = try? AVCaptureDeviceInput(device: device) else {
      print("Cannot create input from \(device.localizedName)")
      session.commitConfiguration()
      return
    }

    if session.canAddInput(newInput) {
      session.addInput(newInput)
      currentInput = newInput
    }

    session.commitConfiguration()
  }

  private func setupSession() {
    guard let device = selectedCamera ?? availableCameras.first else {
      print("No suitable camera found")
      return
    }

    guard let input = try? AVCaptureDeviceInput(device: device) else {
      print("Cannot create input from \(device.localizedName)")
      return
    }

    currentInput = input
    if session.canAddInput(input) { session.addInput(input) }

    let output = AVCaptureVideoDataOutput()
    output.videoSettings = [
      kCVPixelBufferPixelFormatTypeKey as String:
        kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
    ]
    output.setSampleBufferDelegate(self, queue: queue)
    if session.canAddOutput(output) { session.addOutput(output) }

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
    VStack(spacing: 0) {
      // Camera picker
      HStack {
        Picker("Camera", selection: Binding(
          get: { camera.selectedCamera?.uniqueID ?? "" },
          set: { newID in
            if let device = camera.availableCameras.first(where: { $0.uniqueID == newID }) {
              camera.selectCamera(device)
            }
          }
        )) {
          ForEach(camera.availableCameras, id: \.uniqueID) { device in
            Text(device.localizedName).tag(device.uniqueID)
          }
        }
        .pickerStyle(.menu)
        .frame(maxWidth: 300)

        Spacer()
      }
      .padding(8)
      .background(Color.black.opacity(0.8))

      // Camera feed
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

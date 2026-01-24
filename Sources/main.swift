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

// MARK: - Pixel Format Options
enum PixelFormat: String, CaseIterable, Identifiable {
  case ycbcr420 = "YCbCr 4:2:0"
  case bgra = "BGRA (32-bit)"
  case ycbcr420Video = "YCbCr 4:2:0 (Video Range)"

  var id: String { rawValue }

  var cvPixelFormat: OSType {
    switch self {
    case .ycbcr420: return kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
    case .bgra: return kCVPixelFormatType_32BGRA
    case .ycbcr420Video: return kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
    }
  }
}

// MARK: - Video Capture Manager
@MainActor
final class CameraManager: NSObject, ObservableObject {
  // MARK: Public
  @Published var ciImage: CIImage? = nil
  @Published var availableCameras: [AVCaptureDevice] = []
  @Published var selectedCamera: AVCaptureDevice?
  @Published var pixelFormat: PixelFormat = .ycbcr420 {
    didSet { reconfigureOutput() }
  }
  @Published var temperatureTintEnabled: Bool = false

  // MARK: Private
  private let session = AVCaptureSession()
  private let queue = DispatchQueue(label: "cameraQueue")
  private let ciContext = CIContext()
  private var currentInput: AVCaptureDeviceInput?
  private var currentOutput: AVCaptureVideoDataOutput?

  // MARK: Init
  override init() {
    super.init()
    refreshCameraList()
    setupSession()
    session.startRunning()
  }

  func refreshCameraList() {
    #if os(macOS)
    let deviceTypes: [AVCaptureDevice.DeviceType] = [.builtInWideAngleCamera, .continuityCamera, .external]
    let position: AVCaptureDevice.Position = .unspecified
    #else
    let deviceTypes: [AVCaptureDevice.DeviceType] = [.builtInWideAngleCamera, .builtInUltraWideCamera, .builtInTelephotoCamera]
    let position: AVCaptureDevice.Position = .back
    #endif

    let discoverySession = AVCaptureDevice.DiscoverySession(
      deviceTypes: deviceTypes,
      mediaType: .video,
      position: position
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
      kCVPixelBufferPixelFormatTypeKey as String: pixelFormat.cvPixelFormat
    ]
    output.setSampleBufferDelegate(self, queue: queue)
    if session.canAddOutput(output) { session.addOutput(output) }
    currentOutput = output

    session.sessionPreset = .hd1920x1080
  }

  private func reconfigureOutput() {
    session.beginConfiguration()
    if let currentOutput = currentOutput {
      session.removeOutput(currentOutput)
    }
    let output = AVCaptureVideoDataOutput()
    output.videoSettings = [
      kCVPixelBufferPixelFormatTypeKey as String: pixelFormat.cvPixelFormat
    ]
    output.setSampleBufferDelegate(self, queue: queue)
    if session.canAddOutput(output) { session.addOutput(output) }
    currentOutput = output
    session.commitConfiguration()
  }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
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
    let warpedImage = juliaFilter.outputImage ?? inputImage
    Task { @MainActor [weak self] in
      guard let self = self else { return }
      if self.temperatureTintEnabled {
        let tempFilter = CIFilter.temperatureAndTint()
        tempFilter.inputImage = warpedImage
        tempFilter.neutral = CIVector(x: 6500, y: 0)
        tempFilter.targetNeutral = CIVector(x: 6500, y: 0)
        self.ciImage = tempFilter.outputImage ?? warpedImage
      } else {
        self.ciImage = warpedImage
      }
    }
  }
}

// MARK: - SwiftUI View
struct CameraView: View {
  @StateObject private var camera = CameraManager()
  private let ciContext = CIContext()

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        // Camera picker (only show if multiple cameras available)
        if camera.availableCameras.count > 1 {
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
          #if os(macOS)
          .pickerStyle(.menu)
          #endif
          .frame(maxWidth: 300)
        }

        // Pixel format picker
        Picker("Format", selection: $camera.pixelFormat) {
          ForEach(PixelFormat.allCases) { format in
            Text(format.rawValue).tag(format)
          }
        }
        #if os(macOS)
        .pickerStyle(.menu)
        #endif
        .frame(maxWidth: 220)

        // Temperature/Tint filter toggle
        Toggle("Neutral Tint", isOn: $camera.temperatureTintEnabled)
          .frame(maxWidth: 150)

        Spacer()
      }
      .padding(8)
      .background(Color.black.opacity(0.8))

      // Camera feed
      GeometryReader { geo in
        if let ciImage = camera.ciImage,
           let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) {
          #if os(macOS)
          let nsSize = NSSize(width: ciImage.extent.width, height: ciImage.extent.height)
          let nsImage = NSImage(cgImage: cgImage, size: nsSize)
          Image(nsImage: nsImage)
            .resizable()
            .scaledToFit()
          #else
          let uiImage = UIImage(cgImage: cgImage)
          Image(uiImage: uiImage)
            .resizable()
            .scaledToFit()
          #endif
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
  init() {
    #if os(macOS)
    NSApplication.shared.setActivationPolicy(.regular)
    NSApplication.shared.activate(ignoringOtherApps: true)
    #endif
  }

  var body: some Scene {
    WindowGroup {
      CameraView()
    }
  }
}

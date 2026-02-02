import AVFoundation
import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI
import Metal
import Foundation

// MARK: - Video Capture Manager
@MainActor
public final class CameraManager: NSObject, ObservableObject {
  // MARK: Public
  @Published public var ciImage: CIImage? = nil
  @Published public var availableCameras: [AVCaptureDevice] = []
  @Published public var selectedCamera: AVCaptureDevice?
  @Published public var pixelFormat: PixelFormat = .ycbcr420 {
    didSet { reconfigureOutput() }
  }
  @Published public var captureResolution: CaptureResolution = .uhd4K {
    didSet { applyResolution() }
  }
  @Published public var upscaleFactor: UpscaleFactor = .none {
    didSet {
      filterParamsLock.lock()
      filterParams.upscale = upscaleFactor.scale
      filterParamsLock.unlock()
    }
  }
  @Published public var center: CGPoint = CGPoint(x: 0.5, y: 0.5) {
    didSet {
      filterParamsLock.lock()
      filterParams.center = center
      filterParamsLock.unlock()
    }
  }
  @Published public var warpFunction: WarpFunction = .z2 {
    didSet {
      filterParamsLock.lock()
      filterParams.warpFunction = warpFunction
      filterParamsLock.unlock()
    }
  }
  @Published public var chromaticAberrationEnabled: Bool = false {
    didSet {
      filterParamsLock.lock()
      filterParams.chromaEnabled = chromaticAberrationEnabled
      filterParamsLock.unlock()
    }
  }
  @Published public var antialiasingMode: AntialiasingMode = .adaptive {
    didSet {
      filterParamsLock.lock()
      filterParams.aaMode = antialiasingMode
      filterParamsLock.unlock()
    }
  }
  @Published public var zoomLevel: CGFloat = 1.0 {
    didSet {
      filterParamsLock.lock()
      filterParams.zoom = zoomLevel
      filterParamsLock.unlock()
    }
  }
  @Published public var temperatureTintEnabled: Bool = false

  // MARK: Private
  private let session = AVCaptureSession()
  private let queue = DispatchQueue(label: "cameraQueue")
  private var currentInput: AVCaptureDeviceInput?
  private var currentOutput: AVCaptureVideoDataOutput?

  // Thread-safe filter parameters using NSLock
  // Note: filterParams is protected by filterParamsLock, so nonisolated(unsafe) is safe here
  private struct FilterParams {
    var upscale: CGFloat = 1.0
    var center: CGPoint = CGPoint(x: 0.5, y: 0.5)
    var warpFunction: WarpFunction = .z2
    var chromaEnabled: Bool = false
    var aaMode: AntialiasingMode = .adaptive
    var zoom: CGFloat = 1.0
  }
  private nonisolated(unsafe) var filterParams = FilterParams()
  private let filterParamsLock = NSLock()

  // MARK: Init
  override public init() {
    super.init()
    logSystemInfo()
    refreshCameraList()
    setupSession()
    session.startRunning()
  }

  private func logSystemInfo() {
    print("=== CAMERA MANAGER INIT ===")

    // macOS version - CRITICAL for Tahoe 26.x debugging
    let version = ProcessInfo.processInfo.operatingSystemVersion
    print("macOS Version: \(version.majorVersion).\(version.minorVersion).\(version.patchVersion)")

    #if arch(arm64)
    print("Architecture: Apple Silicon (ARM64)")
    #elseif arch(x86_64)
    print("Architecture: Intel (x86_64)")
    #else
    print("Architecture: Unknown")
    #endif

    if let device = MTLCreateSystemDefaultDevice() {
      print("Metal Device: \(device.name)")
      print("Metal GPU Family: \(device.supportsFamily(.apple7) ? "Apple7+" : "Older")")
    } else {
      print("⚠️ WARNING: No Metal device found")
    }

    // Test CIContext creation - may fail on Tahoe 26.x with strict thread checks
    let context = CIContext()
    print("CIContext created successfully: \(context)")

    print("===========================")
  }

  public func refreshCameraList() {
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
    print("Discovered \(availableCameras.count) camera(s):")
    for device in availableCameras {
      print("  - \(device.localizedName) [\(device.deviceType)]")
    }
    if selectedCamera == nil {
      selectedCamera = availableCameras.first
    }
  }

  public func selectCamera(_ device: AVCaptureDevice) {
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

    if session.canSetSessionPreset(captureResolution.sessionPreset) {
      session.sessionPreset = captureResolution.sessionPreset
    }
  }

  private func applyResolution() {
    session.beginConfiguration()
    if session.canSetSessionPreset(captureResolution.sessionPreset) {
      session.sessionPreset = captureResolution.sessionPreset
    }
    session.commitConfiguration()
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
  nonisolated public func captureOutput(
    _ output: AVCaptureOutput,
    didOutput sampleBuffer: CMSampleBuffer,
    from connection: AVCaptureConnection
  ) {
    // Log first frame details only (protected by lock)
    struct FirstFrame {
      static nonisolated(unsafe) var isFirst = true
      static let lock = NSLock()
    }

    guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
      print("⚠️ Failed to extract pixel buffer from sample")
      return
    }

    // Read filter parameters atomically
    filterParamsLock.lock()
    let params = filterParams
    filterParamsLock.unlock()

    // Log first frame only
    FirstFrame.lock.lock()
    let isFirstFrame = FirstFrame.isFirst
    if FirstFrame.isFirst {
      FirstFrame.isFirst = false
      let width = CVPixelBufferGetWidth(pixelBuffer)
      let height = CVPixelBufferGetHeight(pixelBuffer)
      print("📹 First frame received: \(width)x\(height)")
    }
    FirstFrame.lock.unlock()

    // Convert to CIImage
    let inputImage = CIImage(cvPixelBuffer: pixelBuffer)
    if isFirstFrame {
      print("✅ Created CIImage: \(inputImage.extent)")
    }

    // Apply Julia set transformation with optional supersampling
    let juliaFilter = JuliaSetFilter()
    if isFirstFrame {
      print("✅ Created JuliaSetFilter")
    }

    juliaFilter.inputImage = inputImage
    juliaFilter.scale = params.upscale
    juliaFilter.center = params.center
    juliaFilter.warpFunction = params.warpFunction
    juliaFilter.antialiasingMode = params.aaMode
    juliaFilter.zoomLevel = params.zoom

    guard let juliaOutput = juliaFilter.outputImage else {
      print("⚠️ JuliaSetFilter returned nil output - using original")
      Task { @MainActor [weak self] in
        self?.ciImage = inputImage
      }
      return
    }
    if isFirstFrame {
      print("✅ Filter produced output: \(juliaOutput.extent)")
    }

    var processedImage = juliaOutput

    // Apply chromatic aberration if enabled
    if params.chromaEnabled {
      let chromaFilter = ChromaticAberrationFilter()
      chromaFilter.inputImage = processedImage
      if let chromaOutput = chromaFilter.outputImage {
        processedImage = chromaOutput
        if isFirstFrame {
          print("✅ ChromaticAberration applied")
        }
      } else {
        print("⚠️ ChromaticAberration failed - skipping")
      }
    }

    Task { @MainActor [weak self] in
      guard let self = self else { return }
      if self.temperatureTintEnabled {
        let tempFilter = CIFilter.temperatureAndTint()
        tempFilter.inputImage = processedImage
        tempFilter.neutral = CIVector(x: 6500, y: 0)
        tempFilter.targetNeutral = CIVector(x: 6500, y: 0)
        self.ciImage = tempFilter.outputImage ?? processedImage
      } else {
        self.ciImage = processedImage
      }
    }
  }
}

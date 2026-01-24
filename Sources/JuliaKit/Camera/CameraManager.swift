import AVFoundation
import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI

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
    didSet { _upscaleValue = upscaleFactor.scale }
  }
  @Published public var temperatureTintEnabled: Bool = false

  // MARK: Private
  private let session = AVCaptureSession()
  private let queue = DispatchQueue(label: "cameraQueue")
  private let ciContext = CIContext()
  private var currentInput: AVCaptureDeviceInput?
  private var currentOutput: AVCaptureVideoDataOutput?
  private nonisolated(unsafe) var _upscaleValue: CGFloat = 1.0

  // MARK: Init
  override public init() {
    super.init()
    refreshCameraList()
    setupSession()
    session.startRunning()
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
    guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

    // Convert to CIImage
    let inputImage = CIImage(cvPixelBuffer: pixelBuffer)

    // Apply Julia set transformation with optional supersampling
    let juliaFilter = JuliaSetFilter()
    juliaFilter.inputImage = inputImage
    juliaFilter.scale = _upscaleValue
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

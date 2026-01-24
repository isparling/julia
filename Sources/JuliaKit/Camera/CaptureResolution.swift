import AVFoundation

// MARK: - Capture Resolution Options
public enum CaptureResolution: String, CaseIterable, Identifiable, Sendable {
  case hd720 = "720p"
  case hd1080 = "1080p"
  case uhd4K = "4K"

  public var id: String { rawValue }

  public var sessionPreset: AVCaptureSession.Preset {
    switch self {
    case .hd720: return .hd1280x720
    case .hd1080: return .hd1920x1080
    case .uhd4K: return .hd4K3840x2160
    }
  }
}

import AVFoundation

// MARK: - Pixel Format Options
public enum PixelFormat: String, CaseIterable, Identifiable, Sendable {
  case ycbcr420 = "YCbCr 4:2:0"
  case bgra = "BGRA (32-bit)"
  case ycbcr420Video = "YCbCr 4:2:0 (Video Range)"

  public var id: String { rawValue }

  public var cvPixelFormat: OSType {
    switch self {
    case .ycbcr420: return kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
    case .bgra: return kCVPixelFormatType_32BGRA
    case .ycbcr420Video: return kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
    }
  }
}

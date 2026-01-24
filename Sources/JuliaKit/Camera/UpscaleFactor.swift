import CoreGraphics

// MARK: - Pre-filter Upscale Options
public enum UpscaleFactor: String, CaseIterable, Identifiable, Sendable {
  case none = "1×"
  case onePointFive = "1.5×"
  case two = "2×"
  case three = "3×"

  public var id: String { rawValue }

  public var scale: CGFloat {
    switch self {
    case .none: return 1.0
    case .onePointFive: return 1.5
    case .two: return 2.0
    case .three: return 3.0
    }
  }
}

public enum AntialiasingMode: String, CaseIterable, Identifiable, Sendable {
  case none = "None"
  case msaa4x = "4x MSAA"
  case adaptive = "Adaptive"

  public var id: String { rawValue }

  public var kernelValue: Float {
    switch self {
    case .none: return 0
    case .msaa4x: return 1
    case .adaptive: return 2
    }
  }
}

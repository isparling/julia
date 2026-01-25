/// Complex plane transformation functions for Julia set warping
public enum WarpFunction: String, CaseIterable, Identifiable, Sendable {
    case z2 = "z²"
    case z3 = "z³"
    case z4 = "z⁴"
    case sinZ = "sin(z)"

    public var id: String { rawValue }

    /// Value passed to Metal kernel to select the function
    public var kernelValue: Float {
        switch self {
        case .z2: return 0
        case .z3: return 1
        case .z4: return 2
        case .sinZ: return 3
        }
    }
}

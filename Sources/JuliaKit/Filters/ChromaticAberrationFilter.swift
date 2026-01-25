import CoreImage

// MARK: - Chromatic Aberration Filter
public class ChromaticAberrationFilter: CIFilter {
    public var inputImage: CIImage?
    /// Strength of the chromatic aberration effect (pixel offset amount)
    public var strength: CGFloat = 8.0

    private static let kernel: CIKernel? = {
        guard let url = Bundle.module.url(forResource: "ChromaticAberration.ci", withExtension: "metallib"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? CIKernel(functionName: "chromaticAberration", fromMetalLibraryData: data)
    }()

    override public var outputImage: CIImage? {
        guard let inputImage = inputImage,
              let kernel = Self.kernel else { return nil }

        let extent = inputImage.extent
        let center = CIVector(x: extent.midX, y: extent.midY)

        return kernel.apply(
            extent: extent,
            roiCallback: { _, rect in rect.insetBy(dx: -self.strength, dy: -self.strength) },
            arguments: [
                inputImage,
                center,
                Float(strength),
            ]
        )
    }
}

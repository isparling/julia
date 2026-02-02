import CoreImage

// MARK: - Chromatic Aberration Filter
public class ChromaticAberrationFilter: CIFilter {
    public var inputImage: CIImage?
    /// Strength of the chromatic aberration effect (pixel offset amount)
    public var strength: CGFloat = 8.0

    private static let kernel: CIKernel? = {
        guard let url = Bundle.module.url(forResource: "ChromaticAberration.ci", withExtension: "metallib") else {
            print("❌ ERROR: ChromaticAberration.ci.metallib not found in bundle")
            print("Bundle URL: \(Bundle.module.bundleURL)")
            return nil
        }
        print("✅ Found ChromaticAberration metallib at: \(url.path)")

        guard let data = try? Data(contentsOf: url) else {
            print("❌ ERROR: Failed to load ChromaticAberration.ci.metallib from \(url.path)")
            return nil
        }
        print("✅ Loaded ChromaticAberration metallib data: \(data.count) bytes")

        do {
            let kernel = try CIKernel(functionName: "chromaticAberration", fromMetalLibraryData: data)
            print("✅ SUCCESS: Loaded ChromaticAberration kernel from metallib")
            return kernel
        } catch {
            print("❌ ERROR: Failed to create ChromaticAberration CIKernel: \(error)")
            return nil
        }
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

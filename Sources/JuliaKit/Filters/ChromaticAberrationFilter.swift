import CoreImage
import Foundation

// MARK: - Chromatic Aberration Filter
public class ChromaticAberrationFilter: CIFilter {
    public var inputImage: CIImage?
    /// Strength of the chromatic aberration effect (pixel offset amount)
    public var strength: CGFloat = 8.0

    private static let kernel: CIKernel? = {
        // Use safe bundle accessor instead of Bundle.module to avoid fatal errors
        guard let bundle = BundleResources.resourceBundle else {
            print("❌ ChromaticAberrationFilter ERROR: JuliaKit resource bundle not available")
            return nil
        }

        guard let url = bundle.url(forResource: "ChromaticAberration.ci", withExtension: "metallib") else {
            print("❌ ChromaticAberrationFilter ERROR: ChromaticAberration.ci.metallib not found in bundle")
            print("Bundle path: \(bundle.bundlePath)")
            if let resourcePath = bundle.resourcePath {
                print("Resource path: \(resourcePath)")
                let metallibs = (try? FileManager.default.contentsOfDirectory(atPath: resourcePath))?
                    .filter { $0.hasSuffix(".metallib") } ?? []
                print("Found metallibs: \(metallibs)")
            }
            return nil
        }
        print("✅ ChromaticAberrationFilter: Found metallib at: \(url.path)")

        guard let data = try? Data(contentsOf: url) else {
            print("❌ ChromaticAberrationFilter ERROR: Failed to load metallib from \(url.path)")
            return nil
        }
        print("✅ ChromaticAberrationFilter: Loaded metallib data: \(data.count) bytes")

        do {
            let kernel = try CIKernel(functionName: "chromaticAberration", fromMetalLibraryData: data)
            print("✅ ChromaticAberrationFilter SUCCESS: Loaded ChromaticAberration kernel")
            return kernel
        } catch {
            print("❌ ChromaticAberrationFilter ERROR: Failed to create CIKernel: \(error)")
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

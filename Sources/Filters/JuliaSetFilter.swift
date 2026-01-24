import CoreImage

// MARK: - Julia Set Filter
class JuliaSetFilter: CIFilter {
  var inputImage: CIImage?

  private static let kernel: CIWarpKernel? = {
    try? CIWarpKernel(source: """
      kernel vec2 juliaWarp(vec2 extent) {
        // Get current pixel position
        vec2 pos = destCoord();

        // Transform to centered coordinates (-1 to 1 range)
        vec2 center = extent / 2.0;
        vec2 normalized = (pos - center) / min(center.x, center.y);

        // Apply z² in complex plane: (x² - y², 2xy)
        float x = normalized.x;
        float y = normalized.y;
        vec2 transformed = vec2(x*x - y*y, 2.0*x*y);

        // Transform back to image coordinates
        vec2 result = transformed * min(center.x, center.y) + center;

        return result;
      }
      """)
  }()

  override var outputImage: CIImage? {
    guard let inputImage = inputImage,
          let kernel = Self.kernel else { return nil }

    let extent = inputImage.extent
    return kernel.apply(
      extent: extent,
      roiCallback: { _, rect in rect },
      image: inputImage,
      arguments: [CIVector(x: extent.width, y: extent.height)]
    )
  }
}

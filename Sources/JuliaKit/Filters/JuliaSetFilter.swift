import CoreImage

// MARK: - Julia Set Filter
public class JuliaSetFilter: CIFilter {
  public var inputImage: CIImage?
  public var scale: CGFloat = 1.0

  private static let kernel: CIWarpKernel? = {
    try? CIWarpKernel(source: """
      kernel vec2 juliaWarp(vec2 outputExtent, vec2 sourceExtent) {
        vec2 pos = destCoord();

        // Normalize output position to -1..1
        vec2 outCenter = outputExtent / 2.0;
        vec2 normalized = (pos - outCenter) / min(outCenter.x, outCenter.y);

        // z² in complex plane
        float x = normalized.x;
        float y = normalized.y;
        vec2 transformed = vec2(x*x - y*y, 2.0*x*y);

        // Map back to source image coordinates
        vec2 srcCenter = sourceExtent / 2.0;
        vec2 result = transformed * min(srcCenter.x, srcCenter.y) + srcCenter;
        return result;
      }
      """)
  }()

  override public var outputImage: CIImage? {
    guard let inputImage = inputImage,
          let kernel = Self.kernel else { return nil }

    let sourceExtent = inputImage.extent
    let outputExtent = CGRect(
      x: sourceExtent.origin.x, y: sourceExtent.origin.y,
      width: sourceExtent.width * scale, height: sourceExtent.height * scale
    )
    return kernel.apply(
      extent: outputExtent,
      roiCallback: { _, _ in sourceExtent },
      image: inputImage,
      arguments: [
        CIVector(x: outputExtent.width, y: outputExtent.height),
        CIVector(x: sourceExtent.width, y: sourceExtent.height),
      ]
    )
  }
}

import CoreImage

// MARK: - Julia Set Filter
public class JuliaSetFilter: CIFilter {
  public var inputImage: CIImage?
  public var scale: CGFloat = 1.0
  public var center: CGPoint = CGPoint(x: 0.5, y: 0.5)

  private static let kernel: CIWarpKernel? = {
    guard let url = Bundle.module.url(forResource: "JuliaWarp.ci", withExtension: "metallib"),
          let data = try? Data(contentsOf: url) else { return nil }
    return try? CIWarpKernel(functionName: "juliaWarp", fromMetalLibraryData: data)
  }()

  override public var outputImage: CIImage? {
    guard let inputImage = inputImage,
          let kernel = Self.kernel else { return nil }

    let sourceExtent = inputImage.extent
    let outputExtent = CGRect(
      x: sourceExtent.origin.x, y: sourceExtent.origin.y,
      width: sourceExtent.width * scale, height: sourceExtent.height * scale
    )
    let centerPixel = CIVector(
      x: outputExtent.width * center.x,
      y: outputExtent.height * center.y
    )
    return kernel.apply(
      extent: outputExtent,
      roiCallback: { _, _ in sourceExtent },
      image: inputImage,
      arguments: [
        CIVector(x: outputExtent.width, y: outputExtent.height),
        CIVector(x: sourceExtent.width, y: sourceExtent.height),
        centerPixel,
      ]
    )
  }
}

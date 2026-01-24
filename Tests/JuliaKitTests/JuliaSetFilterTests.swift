import CoreImage
import Foundation
import JuliaKit

// MARK: - Test Harness

@MainActor
final class TestContext {
  static let shared = TestContext()
  var passed = 0
  var failed = 0

  func test(_ name: String, _ body: () -> Void) {
    print("  \(name)...", terminator: " ")
    body()
  }

  func pass() {
    passed += 1
    print("PASS")
  }

  func fail(_ message: String = "") {
    failed += 1
    let suffix = message.isEmpty ? "" : " (\(message))"
    print("FAIL\(suffix)")
  }

  func expect(_ condition: Bool, _ message: String = "") {
    if condition { pass() } else { fail(message) }
  }
}

// MARK: - Test Utilities

private let ciContext = CIContext(options: [.useSoftwareRenderer: true])

private func makeCheckerboard(width: Int = 1920, height: Int = 1080) -> CIImage {
  let filter = CIFilter(name: "CICheckerboardGenerator")!
  filter.setValue(CIColor.black, forKey: "inputColor0")
  filter.setValue(CIColor.white, forKey: "inputColor1")
  filter.setValue(50.0 as NSNumber, forKey: "inputWidth")
  return filter.outputImage!
    .cropped(to: CGRect(x: 0, y: 0, width: width, height: height))
}

private func makeSolidColor(_ color: CIColor, width: Int = 1920, height: Int = 1080) -> CIImage {
  let filter = CIFilter(name: "CIConstantColorGenerator")!
  filter.setValue(color, forKey: kCIInputColorKey)
  return filter.outputImage!
    .cropped(to: CGRect(x: 0, y: 0, width: width, height: height))
}

private func render(_ ciImage: CIImage) -> CGImage? {
  ciContext.createCGImage(ciImage, from: ciImage.extent)
}

private func pixelData(of cgImage: CGImage) -> [UInt8]? {
  let width = cgImage.width
  let height = cgImage.height
  let bytesPerPixel = 4
  let bytesPerRow = width * bytesPerPixel
  var data = [UInt8](repeating: 0, count: height * bytesPerRow)

  guard let context = CGContext(
    data: &data,
    width: width,
    height: height,
    bitsPerComponent: 8,
    bytesPerRow: bytesPerRow,
    space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
  ) else { return nil }

  context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
  return data
}

private func pixelColor(of cgImage: CGImage, at point: (x: Int, y: Int)) -> (r: UInt8, g: UInt8, b: UInt8, a: UInt8)? {
  guard let data = pixelData(of: cgImage) else { return nil }
  let bytesPerRow = cgImage.width * 4
  let offset = point.y * bytesPerRow + point.x * 4
  guard offset + 3 < data.count else { return nil }
  return (data[offset], data[offset + 1], data[offset + 2], data[offset + 3])
}

// MARK: - Tests

@main
struct TestRunner {
  @MainActor
  static func main() {
    let ctx = TestContext.shared
    print("JuliaSetFilter Tests")
    print("====================")

    ctx.test("output not nil for valid input") {
      let filter = JuliaSetFilter()
      filter.inputImage = makeCheckerboard()
      ctx.expect(filter.outputImage != nil, "outputImage was nil")
    }

    ctx.test("output extent matches input") {
      let input = makeCheckerboard(width: 1920, height: 1080)
      let filter = JuliaSetFilter()
      filter.inputImage = input
      guard let output = filter.outputImage else { ctx.fail("output was nil"); return }
      ctx.expect(output.extent == input.extent, "extent mismatch: \(output.extent) != \(input.extent)")
    }

    ctx.test("nil input produces nil output") {
      let filter = JuliaSetFilter()
      ctx.expect(filter.outputImage == nil, "expected nil output")
    }

    ctx.test("transformation alters pixels") {
      let input = makeCheckerboard()
      let filter = JuliaSetFilter()
      filter.inputImage = input
      guard let output = filter.outputImage else { ctx.fail("output was nil"); return }
      guard let inputCG = render(input),
            let outputCG = render(output) else { ctx.fail("render failed"); return }
      guard let inputData = pixelData(of: inputCG),
            let outputData = pixelData(of: outputCG) else { ctx.fail("pixel extraction failed"); return }
      ctx.expect(inputData != outputData, "output pixels identical to input")
    }

    ctx.test("center pixel maps to center (z²(0,0) = (0,0))") {
      let width = 100
      let height = 100
      let centerX = width / 2
      let centerY = height / 2

      let redImage = makeSolidColor(CIColor(red: 1, green: 0, blue: 0), width: width, height: height)
      let filter = JuliaSetFilter()
      filter.inputImage = redImage
      guard let output = filter.outputImage,
            let outputCG = render(output) else { ctx.fail("render failed"); return }
      guard let color = pixelColor(of: outputCG, at: (x: centerX, y: centerY)) else { ctx.fail("pixel read failed"); return }
      ctx.expect(color.r > 200 && color.g < 50 && color.b < 50,
                 "center RGBA=(\(color.r),\(color.g),\(color.b),\(color.a))")
    }

    ctx.test("deterministic output") {
      let input = makeCheckerboard(width: 200, height: 200)

      let filter1 = JuliaSetFilter()
      filter1.inputImage = input
      let filter2 = JuliaSetFilter()
      filter2.inputImage = input

      guard let out1 = filter1.outputImage, let out2 = filter2.outputImage,
            let cg1 = render(out1), let cg2 = render(out2),
            let data1 = pixelData(of: cg1), let data2 = pixelData(of: cg2)
      else { ctx.fail("render failed"); return }
      ctx.expect(data1 == data2, "outputs differ between two applications")
    }

    ctx.test("processes CVPixelBuffer (BGRA)") {
      let width = 100
      let height = 100
      var pixelBuffer: CVPixelBuffer?
      let status = CVPixelBufferCreate(
        kCFAllocatorDefault,
        width, height,
        kCVPixelFormatType_32BGRA,
        [kCVPixelBufferWidthKey: width, kCVPixelBufferHeightKey: height] as CFDictionary,
        &pixelBuffer
      )
      guard status == kCVReturnSuccess, let buffer = pixelBuffer else { ctx.fail("CVPixelBuffer creation failed"); return }

      CVPixelBufferLockBaseAddress(buffer, [])
      if let base = CVPixelBufferGetBaseAddress(buffer) {
        memset(base, 128, CVPixelBufferGetDataSize(buffer))
      }
      CVPixelBufferUnlockBaseAddress(buffer, [])

      let ciImage = CIImage(cvPixelBuffer: buffer)
      let filter = JuliaSetFilter()
      filter.inputImage = ciImage
      ctx.expect(filter.outputImage != nil, "filter returned nil for CVPixelBuffer input")
    }

    // Summary
    print("--------------------")
    print("\(ctx.passed + ctx.failed) tests: \(ctx.passed) passed, \(ctx.failed) failed")

    if ctx.failed > 0 {
      exit(1)
    }
  }
}

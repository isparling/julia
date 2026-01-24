import CoreImage
import Foundation
import JuliaKit
import Testing

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

@Suite("JuliaSetFilter")
struct JuliaSetFilterTests {

  @Test("output not nil for valid input")
  func outputNotNil() {
    let filter = JuliaSetFilter()
    filter.inputImage = makeCheckerboard()
    #expect(filter.outputImage != nil)
  }

  @Test("output extent matches input")
  func outputExtentMatchesInput() {
    let input = makeCheckerboard(width: 1920, height: 1080)
    let filter = JuliaSetFilter()
    filter.inputImage = input
    let output = try! #require(filter.outputImage)
    #expect(output.extent == input.extent)
  }

  @Test("nil input produces nil output")
  func nilInputProducesNilOutput() {
    let filter = JuliaSetFilter()
    #expect(filter.outputImage == nil)
  }

  @Test("transformation alters pixels")
  func transformationAltersPixels() throws {
    let input = makeCheckerboard()
    let filter = JuliaSetFilter()
    filter.inputImage = input
    let output = try #require(filter.outputImage)
    let inputCG = try #require(render(input))
    let outputCG = try #require(render(output))
    let inputData = try #require(pixelData(of: inputCG))
    let outputData = try #require(pixelData(of: outputCG))
    #expect(inputData != outputData)
  }

  @Test("center pixel maps to center (z²(0,0) = (0,0))")
  func centerPixelMapsToCenter() throws {
    let width = 100
    let height = 100
    let centerX = width / 2
    let centerY = height / 2

    let redImage = makeSolidColor(CIColor(red: 1, green: 0, blue: 0), width: width, height: height)
    let filter = JuliaSetFilter()
    filter.inputImage = redImage
    let output = try #require(filter.outputImage)
    let outputCG = try #require(render(output))
    let color = try #require(pixelColor(of: outputCG, at: (x: centerX, y: centerY)))
    #expect(color.r > 200 && color.g < 50 && color.b < 50)
  }

  @Test("deterministic output")
  func deterministicOutput() throws {
    let input = makeCheckerboard(width: 200, height: 200)

    let filter1 = JuliaSetFilter()
    filter1.inputImage = input
    let filter2 = JuliaSetFilter()
    filter2.inputImage = input

    let out1 = try #require(filter1.outputImage)
    let out2 = try #require(filter2.outputImage)
    let cg1 = try #require(render(out1))
    let cg2 = try #require(render(out2))
    let data1 = try #require(pixelData(of: cg1))
    let data2 = try #require(pixelData(of: cg2))
    #expect(data1 == data2)
  }

  @Test("processes CVPixelBuffer (BGRA)")
  func processesCVPixelBuffer() throws {
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
    let buffer = try #require(status == kCVReturnSuccess ? pixelBuffer : nil)

    CVPixelBufferLockBaseAddress(buffer, [])
    if let base = CVPixelBufferGetBaseAddress(buffer) {
      memset(base, 128, CVPixelBufferGetDataSize(buffer))
    }
    CVPixelBufferUnlockBaseAddress(buffer, [])

    let ciImage = CIImage(cvPixelBuffer: buffer)
    let filter = JuliaSetFilter()
    filter.inputImage = ciImage
    #expect(filter.outputImage != nil)
  }
}

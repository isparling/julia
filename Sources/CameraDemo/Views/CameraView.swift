import CoreImage
import JuliaKit
import SwiftUI

// MARK: - SwiftUI View
struct CameraView: View {
  @StateObject private var camera = CameraManager()
  @State private var showCrosshair = true
  private let ciContext = CIContext()

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        // Camera picker (only show if multiple cameras available)
        if camera.availableCameras.count > 1 {
          Picker(
            "Camera",
            selection: Binding(
              get: { camera.selectedCamera?.uniqueID ?? "" },
              set: { newID in
                if let device = camera.availableCameras.first(where: { $0.uniqueID == newID }) {
                  camera.selectCamera(device)
                }
              }
            )
          ) {
            ForEach(camera.availableCameras, id: \.uniqueID) { device in
              Text(device.localizedName).tag(device.uniqueID)
            }
          }
          #if os(macOS)
            .pickerStyle(.menu)
          #endif
          .frame(maxWidth: 300)
        }

        // Pixel format picker
        Picker("Format", selection: $camera.pixelFormat) {
          ForEach(PixelFormat.allCases) { format in
            Text(format.rawValue).tag(format)
          }
        }
        #if os(macOS)
          .pickerStyle(.menu)
        #endif
        .frame(maxWidth: 220)

        // Resolution picker
        Picker("Resolution", selection: $camera.captureResolution) {
          ForEach(CaptureResolution.allCases) { res in
            Text(res.rawValue).tag(res)
          }
        }
        #if os(macOS)
          .pickerStyle(.menu)
        #endif
        .frame(maxWidth: 150)

        // Upscale picker
        Picker("Upscale", selection: $camera.upscaleFactor) {
          ForEach(UpscaleFactor.allCases) { factor in
            Text(factor.rawValue).tag(factor)
          }
        }
        #if os(macOS)
          .pickerStyle(.menu)
        #endif
        .frame(maxWidth: 150)

        // Temperature/Tint filter toggle
        Toggle("Neutral Tint", isOn: $camera.temperatureTintEnabled)
          .frame(maxWidth: 150)

        Toggle("Center Crosshair", isOn: $showCrosshair)
          .frame(maxWidth: 120)

        Spacer()
      }
      .padding(8)
      .background(Color.black.opacity(0.8))

      // Camera feed with crosshair overlay
      GeometryReader { geo in
        if let ciImage = camera.ciImage,
          let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent)
        {
          let imageSize = CGSize(width: ciImage.extent.width, height: ciImage.extent.height)
          let fittedRect = fittedImageRect(imageSize: imageSize, in: geo.size)

          ZStack {
            #if os(macOS)
              let nsSize = NSSize(width: ciImage.extent.width, height: ciImage.extent.height)
              let nsImage = NSImage(cgImage: cgImage, size: nsSize)
              Image(nsImage: nsImage)
                .resizable()
                .scaledToFit()
            #else
              let uiImage = UIImage(cgImage: cgImage)
              Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
            #endif

            if showCrosshair {
              CrosshairView(center: camera.center, fittedRect: fittedRect)
            }
          }
          .contentShape(Rectangle())
          .gesture(
            DragGesture(minimumDistance: 0)
              .onChanged { value in
                camera.center = normalizedPoint(
                  from: value.location,
                  in: geo.size,
                  fittedRect: fittedRect
                )
              }
          )
        } else {
          Color.black
        }
      }
    }
    .background(Color.black)
  }

  private func fittedImageRect(imageSize: CGSize, in viewSize: CGSize) -> CGRect {
    let imageAspect = imageSize.width / imageSize.height
    let viewAspect = viewSize.width / viewSize.height

    let fittedSize: CGSize
    if imageAspect > viewAspect {
      fittedSize = CGSize(width: viewSize.width, height: viewSize.width / imageAspect)
    } else {
      fittedSize = CGSize(width: viewSize.height * imageAspect, height: viewSize.height)
    }

    let origin = CGPoint(
      x: (viewSize.width - fittedSize.width) / 2,
      y: (viewSize.height - fittedSize.height) / 2
    )
    return CGRect(origin: origin, size: fittedSize)
  }

  private func normalizedPoint(from viewPoint: CGPoint, in viewSize: CGSize, fittedRect: CGRect)
    -> CGPoint
  {
    let x = (viewPoint.x - fittedRect.origin.x) / fittedRect.width
    // Flip Y: SwiftUI top-left origin → CoreImage bottom-left origin
    let y = 1.0 - (viewPoint.y - fittedRect.origin.y) / fittedRect.height
    return CGPoint(
      x: min(max(x, 0), 1),
      y: min(max(y, 0), 1)
    )
  }
}

// MARK: - Crosshair Overlay
struct CrosshairView: View {
  let center: CGPoint
  let fittedRect: CGRect

  var body: some View {
    let viewX = fittedRect.origin.x + center.x * fittedRect.width
    let viewY = fittedRect.origin.y + (1.0 - center.y) * fittedRect.height

    ZStack {
      Rectangle()
        .fill(Color.white.opacity(0.7))
        .frame(width: 30, height: 1)
      Rectangle()
        .fill(Color.white.opacity(0.7))
        .frame(width: 1, height: 30)
      Circle()
        .stroke(Color.white.opacity(0.7), lineWidth: 1)
        .frame(width: 10, height: 10)
    }
    .position(x: viewX, y: viewY)
    .allowsHitTesting(false)
  }
}

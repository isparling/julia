import CoreImage
import JuliaKit
import SwiftUI

// MARK: - SwiftUI View
struct CameraView: View {
  @StateObject private var camera = CameraManager()
  private let ciContext = CIContext()

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        // Camera picker (only show if multiple cameras available)
        if camera.availableCameras.count > 1 {
          Picker("Camera", selection: Binding(
            get: { camera.selectedCamera?.uniqueID ?? "" },
            set: { newID in
              if let device = camera.availableCameras.first(where: { $0.uniqueID == newID }) {
                camera.selectCamera(device)
              }
            }
          )) {
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

        // Temperature/Tint filter toggle
        Toggle("Neutral Tint", isOn: $camera.temperatureTintEnabled)
          .frame(maxWidth: 150)

        Spacer()
      }
      .padding(8)
      .background(Color.black.opacity(0.8))

      // Camera feed
      GeometryReader { geo in
        if let ciImage = camera.ciImage,
           let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) {
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
        } else {
          Color.black
        }
      }
    }
    .background(Color.black)
  }
}

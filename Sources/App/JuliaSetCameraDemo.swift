import SwiftUI
#if os(macOS)
import AppKit
#endif

// MARK: - App Entry Point

@main
struct JuliaSetCameraDemo: App {
  init() {
    #if os(macOS)
    NSApplication.shared.setActivationPolicy(.regular)
    NSApplication.shared.activate(ignoringOtherApps: true)
    #endif
  }

  var body: some Scene {
    WindowGroup {
      CameraView()
    }
  }
}

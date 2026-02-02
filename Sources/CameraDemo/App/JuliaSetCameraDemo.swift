import SwiftUI
#if os(macOS)
import AppKit
#endif
import Metal

// MARK: - App Entry Point

@main
struct JuliaSetCameraDemo: App {
  init() {
    #if os(macOS)
    NSApplication.shared.setActivationPolicy(.regular)
    NSApplication.shared.activate(ignoringOtherApps: true)
    #endif

    validateEnvironment()
  }

  private func validateEnvironment() {
    print("=== APP STARTUP ===")

    #if arch(arm64)
    print("🖥️  Running on Apple Silicon (ARM64)")
    #elseif arch(x86_64)
    print("🖥️  Running on Intel (x86_64)")
    #else
    print("🖥️  Running on unknown architecture")
    #endif

    // Verify Metal support
    guard let device = MTLCreateSystemDefaultDevice() else {
      print("⚠️  WARNING: No Metal device available")
      return
    }
    print("✅ Metal GPU available: \(device.name)")
    print("===================")
  }

  var body: some Scene {
    WindowGroup {
      CameraView()
    }
  }
}

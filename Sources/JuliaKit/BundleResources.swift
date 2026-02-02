import Foundation

/// Safe bundle resource accessor that doesn't throw fatal errors
/// Replaces SPM's Bundle.module which calls fatalError() if bundle not found
enum BundleResources {
  /// Safely find the JuliaKit resource bundle
  /// Returns nil instead of fatalError() if bundle not found
  static let resourceBundle: Bundle? = {
    // Strategy 1: Try finding bundle by looking for the metallib resource
    // This works in all contexts: swift run, .app, and swift test
    for bundle in Bundle.allBundles {
      if let url = bundle.url(forResource: "JuliaWarp.ci", withExtension: "metallib") {
        print("✅ BundleResources: Found metallib in bundle: \(bundle.bundlePath)")
        print("  Resource URL: \(url.path)")
        return bundle
      }
    }

    // Strategy 1b: Look for JuliaKit-specific bundle names (including CameraDemo_JuliaKit for SPM)
    let candidateBundles = Bundle.allBundles.filter { bundle in
      bundle.bundlePath.hasSuffix("JuliaKit_JuliaKit.bundle") ||
      bundle.bundlePath.hasSuffix("CameraDemo_JuliaKit.bundle") ||
      bundle.bundlePath.contains("JuliaKit")
    }

    print("📦 BundleResources: Found \(candidateBundles.count) candidate bundles:")
    for bundle in candidateBundles {
      print("  - \(bundle.bundlePath)")
      if let resourcePath = bundle.resourcePath {
        if let contents = try? FileManager.default.contentsOfDirectory(atPath: resourcePath) {
          for item in contents.prefix(5) {
            print("    - \(item)")
          }
        }
      }
    }

    // Check if any candidate has our metallib
    for bundle in candidateBundles {
      if bundle.url(forResource: "JuliaWarp.ci", withExtension: "metallib") != nil {
        print("✅ BundleResources: Using JuliaKit bundle: \(bundle.bundlePath)")
        return bundle
      }
    }

    // Strategy 2: Try main bundle resources (for .app bundles)
    // Resources might be copied directly to main bundle's Resources folder
    if let mainBundleURL = Bundle.main.url(forResource: "JuliaWarp.ci", withExtension: "metallib") {
      print("✅ BundleResources: Found resources in main bundle: \(Bundle.main.bundlePath)")
      print("  Resource URL: \(mainBundleURL.path)")
      return Bundle.main
    }

    // Strategy 3: Try resources in main bundle's Resources subdirectory
    if let resourcePath = Bundle.main.resourcePath {
      let resourceBundle = Bundle(path: resourcePath)
      if resourceBundle?.url(forResource: "JuliaWarp.ci", withExtension: "metallib") != nil {
        print("✅ BundleResources: Found resources in main bundle Resources: \(resourcePath)")
        return resourceBundle
      }
    }

    // Strategy 4: Search filesystem for bundle (test context)
    // In test context, bundles might not be in Bundle.allBundles yet
    let searchPaths = [
      ".build/arm64-apple-macosx/debug",
      ".build/arm64-apple-macosx/release",
      ".build/x86_64-apple-macosx/debug",
      ".build/x86_64-apple-macosx/release",
    ]

    for searchPath in searchPaths {
      let bundlePath = "\(searchPath)/CameraDemo_JuliaKit.bundle"
      if let bundle = Bundle(path: bundlePath),
         bundle.url(forResource: "JuliaWarp.ci", withExtension: "metallib") != nil {
        print("✅ BundleResources: Found bundle via filesystem search: \(bundlePath)")
        return bundle
      }
    }

    // All strategies failed - log diagnostics
    print("❌ BundleResources ERROR: Could not locate JuliaKit resource bundle")
    print("Main bundle: \(Bundle.main.bundlePath)")
    if let resourcePath = Bundle.main.resourcePath {
      print("Main bundle resources: \(resourcePath)")
      if let contents = try? FileManager.default.contentsOfDirectory(atPath: resourcePath) {
        print("Resource directory contents:")
        for item in contents.prefix(20) {
          print("  - \(item)")
        }
      }
    }
    print("All loaded bundles:")
    for bundle in Bundle.allBundles.prefix(10) {
      print("  - \(bundle.bundlePath)")
    }

    return nil
  }()
}

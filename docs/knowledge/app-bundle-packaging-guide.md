# .app Bundle Packaging Guide for Swift Packages

**Context:** How to correctly package Swift package resources (Metal shaders) in macOS .app bundles
**Created:** 2026-02-01

## TL;DR - The Critical Fix

When packaging Swift package resources in .app bundles, you MUST explicitly search for the package bundle in the .app's Resources folder:

```swift
if let resourcePath = Bundle.main.resourcePath {
  let bundlePath = "\(resourcePath)/PackageName_TargetName.bundle"
  if let bundle = Bundle(path: bundlePath),
     bundle.url(forResource: "resource", withExtension: "ext") != nil {
    // Use this bundle!
  }
}
```

## .app Bundle Structure

### Standard macOS .app Layout
```
MyApp.app/
├── Contents/
│   ├── Info.plist
│   ├── PkgInfo
│   ├── MacOS/
│   │   └── MyExecutable           # The main binary
│   └── Resources/                  # ALL resources go here
│       ├── Assets.xcassets/
│       └── PackageName_TargetName.bundle/  # ← SPM resource bundle
│           ├── resource1.metallib
│           └── resource2.json
```

### Key Points
- **Resources location:** Always `Contents/Resources/`
- **Bundle.main:** Points to `MyApp.app/`
- **Bundle.main.resourcePath:** Points to `MyApp.app/Contents/Resources/`
- **SPM bundles:** Copied into Resources folder, NOT flattened

## Swift Package Manager Resource Bundles

### How SPM Creates Resource Bundles

In `Package.swift`:
```swift
.target(
    name: "MyLibrary",
    resources: [
        .copy("Shaders/MyShader.metallib"),
        .process("Assets/icon.png"),
    ]
)
```

SPM creates: `MyPackageName_MyLibrary.bundle/` containing the resources

### Bundle Naming Convention
Format: `{PackageName}_{TargetName}.bundle`

Examples:
- Package: "CameraDemo", Target: "JuliaKit" → `CameraDemo_JuliaKit.bundle`
- Package: "MyApp", Target: "Rendering" → `MyApp_Rendering.bundle`

## Makefile Integration

### Copying Resources to .app Bundle

```makefile
# Create bundle structure
mkdir -p MyApp.app/Contents/MacOS
mkdir -p MyApp.app/Contents/Resources

# Copy executable
cp .build/release/MyExecutable MyApp.app/Contents/MacOS/

# CRITICAL: Copy SPM resource bundle
cp -R .build/release/PackageName_TargetName.bundle \
      MyApp.app/Contents/Resources/
```

### Common Mistake: Flattening Resources
```makefile
# ❌ WRONG - Don't flatten the bundle
cp .build/release/PackageName_TargetName.bundle/* \
   MyApp.app/Contents/Resources/

# ✅ CORRECT - Copy the whole bundle
cp -R .build/release/PackageName_TargetName.bundle \
      MyApp.app/Contents/Resources/
```

## Bundle Loading Code

### Multi-Strategy Approach

```swift
enum BundleResources {
  static let resourceBundle: Bundle? = {
    // Strategy 1: Search loaded bundles (works in `swift run`)
    for bundle in Bundle.allBundles {
      if bundle.url(forResource: "MyResource", withExtension: "ext") != nil {
        return bundle
      }
    }

    // Strategy 2: Try main bundle directly
    if Bundle.main.url(forResource: "MyResource", withExtension: "ext") != nil {
      return Bundle.main
    }

    // Strategy 2.5: CRITICAL - .app bundle path
    if let resourcePath = Bundle.main.resourcePath {
      let bundlePath = "\(resourcePath)/PackageName_TargetName.bundle"
      if let bundle = Bundle(path: bundlePath),
         bundle.url(forResource: "MyResource", withExtension: "ext") != nil {
        return bundle
      }
    }

    // Strategy 3: Try loading Resources folder as bundle (usually fails)
    if let resourcePath = Bundle.main.resourcePath {
      let resourceBundle = Bundle(path: resourcePath)
      if resourceBundle?.url(forResource: "MyResource", withExtension: "ext") != nil {
        return resourceBundle
      }
    }

    // Strategy 4: Filesystem search for development/test
    let searchPaths = [
      ".build/arm64-apple-macosx/debug",
      ".build/arm64-apple-macosx/release",
    ]
    for searchPath in searchPaths {
      let bundlePath = "\(searchPath)/PackageName_TargetName.bundle"
      if let bundle = Bundle(path: bundlePath),
         bundle.url(forResource: "MyResource", withExtension: "ext") != nil {
        return bundle
      }
    }

    return nil
  }()
}
```

### Why Each Strategy Is Needed

| Strategy | Context | Why It Works |
|----------|---------|--------------|
| 1. allBundles | `swift run` | Bundles loaded by runtime |
| 2. main bundle | Flattened resources | Resources copied directly to main |
| **2.5. Explicit .app path** | **.app bundles** | **Matches actual .app structure** |
| 3. Resources as bundle | Edge cases | Sometimes Resources folder is a bundle |
| 4. Filesystem search | Tests | Bundles may not be loaded yet |

## Common Pitfalls

### ❌ Using Bundle.module Directly
```swift
// NEVER DO THIS - crashes in .app bundles
let url = Bundle.module.url(forResource: "MyShader", withExtension: "metallib")
```

**Problem:** `Bundle.module` calls `fatalError()` if bundle not found. No recovery possible.

### ❌ Assuming Resources Are Flattened
```swift
// WRONG - assumes resources are in main bundle
Bundle.main.url(forResource: "MyShader", withExtension: "metallib")
```

**Problem:** Resources are inside the package bundle, not main bundle.

### ❌ Relative Paths in .app Context
```swift
// WRONG - relative paths don't work in .app
let bundle = Bundle(path: ".build/release/MyPackage_MyTarget.bundle")
```

**Problem:** .app bundles don't have `.build` directories.

### ❌ Skipping Resource Verification
```swift
// WRONG - doesn't verify bundle contents
if let bundle = Bundle(path: bundlePath) {
  return bundle  // Might be empty!
}
```

**Problem:** `Bundle(path:)` succeeds even if bundle is invalid/empty.

## Testing Checklist

When implementing .app bundle packaging:

- [ ] `swift test` passes (Strategy 4 works)
- [ ] `swift run` shows expected behavior (Strategy 1 works)
- [ ] Build .app bundle with Makefile
- [ ] Verify bundle structure with `ls -R MyApp.app/Contents/Resources/`
- [ ] Launch .app bundle
- [ ] **Visual verification** - feature actually works, not just "doesn't crash"
- [ ] Check Console.app for bundle loading logs
- [ ] Test on target platform (M1, Intel, etc.)

## Reference: Bundle.main Properties in Different Contexts

### In `swift run`:
```
Bundle.main.bundlePath: /Applications/Xcode.app/.../swift-build-tool
Bundle.main.resourcePath: /Applications/Xcode.app/.../swift-build-tool
```

### In .app bundle:
```
Bundle.main.bundlePath: /path/to/MyApp.app
Bundle.main.resourcePath: /path/to/MyApp.app/Contents/Resources
```

### In tests:
```
Bundle.main.bundlePath: /Applications/Xcode.app/.../swift-pm
Bundle.main.resourcePath: /Applications/Xcode.app/.../swift-pm
```

**Key insight:** `Bundle.main.resourcePath` in .app context reliably points to `Contents/Resources/` - use this!

## Code Signing Considerations

After creating the .app bundle:

```bash
# Ad-hoc signing (development)
codesign --force --deep --sign - MyApp.app

# Developer ID signing (distribution)
codesign --force --deep --sign "Developer ID Application: Your Name" MyApp.app

# Verify signature
codesign --verify --verbose MyApp.app
```

**Note:** Code signing AFTER copying all resources and bundles.

## Related Documentation

- `docs/knowledge/swift-bundle-loading-patterns.md` - Comprehensive bundle loading guide
- `docs/debugging/bundle-module-fix-regression.md` - Investigation notes
- `Makefile` - Current implementation of .app bundle creation

## Quick Command Reference

```bash
# Build release binary
swift build -c release

# Create .app structure
mkdir -p MyApp.app/Contents/{MacOS,Resources}

# Copy executable
cp .build/release/MyExecutable MyApp.app/Contents/MacOS/

# Copy SPM resource bundle (CRITICAL!)
cp -R .build/release/PackageName_TargetName.bundle \
      MyApp.app/Contents/Resources/

# Create Info.plist (required for .app)
# ... create Info.plist with CFBundleIdentifier, etc.

# Create PkgInfo (optional but traditional)
echo -n "APPL????" > MyApp.app/Contents/PkgInfo

# Code sign
codesign --force --deep --sign - MyApp.app

# Launch
open MyApp.app
```

## Debugging Bundle Loading Issues

### 1. Verify bundle exists
```bash
ls -la MyApp.app/Contents/Resources/
# Should show: PackageName_TargetName.bundle/
```

### 2. Verify bundle contents
```bash
ls -la MyApp.app/Contents/Resources/PackageName_TargetName.bundle/
# Should show: MyResource.ext
```

### 3. Check bundle can be loaded
```swift
let path = "/path/to/MyApp.app/Contents/Resources/PackageName_TargetName.bundle"
if let bundle = Bundle(path: path) {
  print("Bundle loaded: \(bundle.bundlePath)")
  if let url = bundle.url(forResource: "MyResource", withExtension: "ext") {
    print("Resource found: \(url.path)")
  }
}
```

### 4. Check Console.app
- Filter by process name
- Look for bundle loading log messages
- Check for file access errors

## Summary

**The One Thing to Remember:**

In .app bundles, SPM resource bundles live at:
```
Bundle.main.resourcePath + "/PackageName_TargetName.bundle"
```

Always construct this path explicitly in your bundle discovery code.

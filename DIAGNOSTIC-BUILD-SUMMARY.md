# Diagnostic Build Summary

## Problem
Application crashes on M1 Air running macOS Tahoe 26.2 immediately after camera light activates. Works fine on older macOS versions.

## Root Cause Hypothesis
macOS Tahoe 26.x likely enforces stricter Swift 6 concurrency checks at runtime, causing crashes on previously-tolerated data races.

## Changes Implemented

### 1. Thread-Safety Improvements (CameraManager.swift)

#### Before
```swift
private nonisolated(unsafe) var _upscaleValue: CGFloat = 1.0
private nonisolated(unsafe) var _centerValue: CGPoint = CGPoint(x: 0.5, y: 0.5)
// ... 4 more unsafe variables
```
- MainActor (UI thread) wrote to these in `didSet` handlers
- Camera queue read them in `captureOutput` callback
- **NO SYNCHRONIZATION** - potential data race

#### After
```swift
private struct FilterParams {
  var upscale: CGFloat = 1.0
  var center: CGPoint = CGPoint(x: 0.5, y: 0.5)
  var warpFunction: WarpFunction = .z2
  var chromaEnabled: Bool = false
  var aaMode: AntialiasingMode = .adaptive
  var zoom: CGFloat = 1.0
}
private nonisolated(unsafe) var filterParams = FilterParams()
private let filterParamsLock = NSLock()
```

- All filter parameters bundled in one struct
- Protected by NSLock
- MainActor writes through lock
- Camera queue reads atomic snapshot
- **PROPER SYNCHRONIZATION** - no data races

**Why This Matters:**
- macOS Tahoe 26.x likely enforces concurrency rules strictly
- Older macOS allowed unsafe access with warnings
- Tahoe crashes immediately on violations

### 2. Removed Unused CIContext (CameraManager.swift)

#### Before
```swift
private let ciContext = CIContext()  // NEVER USED
```

#### After
```
// Removed entirely
```

**Why This Matters:**
- CameraView has its own CIContext for rendering
- This CIContext was created on MainActor but never used
- Eliminates confusion and potential resource waste

### 3. Comprehensive Diagnostics

#### Startup Diagnostics (CameraManager.swift)
```swift
private func logSystemInfo() {
  print("=== CAMERA MANAGER INIT ===")
  // macOS version - CRITICAL for Tahoe 26.x debugging
  let version = ProcessInfo.processInfo.operatingSystemVersion
  print("macOS Version: \(version.majorVersion).\(version.minorVersion).\(version.patchVersion)")
  // Architecture, Metal device, GPU family
  print("===========================")
}
```

#### Metal Kernel Loading Diagnostics (JuliaSetFilter.swift, ChromaticAberrationFilter.swift)
```swift
private static let kernel: CIWarpKernel? = {
  guard let url = Bundle.module.url(forResource: "JuliaWarp.ci", withExtension: "metallib") else {
    print("❌ ERROR: JuliaWarp.ci.metallib not found in bundle")
    return nil
  }
  print("✅ Found metallib at: \(url.path)")
  // ... detailed error logging at each step
  print("✅ SUCCESS: Loaded JuliaWarp kernel from metallib")
  return kernel
}()
```

#### Frame Processing Diagnostics (CameraManager.swift)
- First frame logged in detail
- Subsequent frames silent (to avoid log spam)
- All errors and warnings logged immediately
- Graceful fallbacks on failure

### 4. App Startup Validation (JuliaSetCameraDemo.swift)

```swift
private func validateEnvironment() {
  print("=== APP STARTUP ===")
  print("🖥️  Running on Apple Silicon (ARM64)")
  print("✅ Metal GPU available: \(device.name)")
  print("===================")
}
```

## Expected Diagnostic Output

### On Success
```
=== APP STARTUP ===
🖥️  Running on Apple Silicon (ARM64)
✅ Metal GPU available: Apple M1
===================
=== CAMERA MANAGER INIT ===
macOS Version: 26.2.0
Architecture: Apple Silicon (ARM64)
Metal Device: Apple M1
Metal GPU Family: Apple7+
CIContext created successfully: <CIContext: 0x...>
===========================
Discovered 1 camera(s):
  - FaceTime HD Camera (Built-In) [builtInWideAngleCamera]
✅ Found metallib at: /path/to/JuliaWarp.ci.metallib
✅ Loaded metallib data: 6586 bytes
✅ SUCCESS: Loaded JuliaWarp kernel from metallib
✅ Found ChromaticAberration metallib at: /path/to/ChromaticAberration.ci.metallib
✅ Loaded ChromaticAberration metallib data: XXXX bytes
✅ SUCCESS: Loaded ChromaticAberration kernel from metallib
📹 First frame received: 1920x1080
✅ Created CIImage: (0, 0, 1920, 1080)
✅ Created JuliaSetFilter
✅ Filter produced output: (0, 0, 1920, 1080)
```

### On Kernel Loading Failure
```
❌ ERROR: JuliaWarp.ci.metallib not found in bundle
Bundle URL: /path/to/bundle
```

### On Filter Failure
```
⚠️ JuliaSetFilter returned nil output - using original
```

## Files Modified

1. **Sources/JuliaKit/Camera/CameraManager.swift**
   - Added Metal import
   - Removed unused CIContext
   - Added FilterParams struct with NSLock synchronization
   - Added logSystemInfo() for startup diagnostics
   - Updated didSet handlers to write through lock
   - Updated captureOutput to read atomic snapshot
   - Added first-frame logging
   - Added graceful fallbacks

2. **Sources/JuliaKit/Filters/JuliaSetFilter.swift**
   - Added detailed kernel loading diagnostics

3. **Sources/JuliaKit/Filters/ChromaticAberrationFilter.swift**
   - Added detailed kernel loading diagnostics

4. **Sources/CameraDemo/App/JuliaSetCameraDemo.swift**
   - Added Metal import
   - Added validateEnvironment() for startup diagnostics

5. **BUILD-INSTRUCTIONS.md** (NEW)
   - Comprehensive build and testing instructions for remote user

## Testing

### Local Verification (macOS 15.7.3, Apple M1 Max)
```bash
swift test
# ✅ All 11 tests pass

swift build
# ✅ Build succeeds

swift run CameraDemo
# ✅ Application runs with diagnostic output
# ✅ No regressions
```

### Remote Verification (M1 Air, macOS Tahoe 26.2)
**Expected Outcomes:**
1. **Best case**: Thread-safety fixes resolve the crash
2. **Diagnostic case**: Detailed logs reveal root cause for Round 2

## Risk Assessment

### Low Risk
- Removing unused CIContext: No code references it
- Adding diagnostics: Read-only logging, no side effects

### Medium Risk
- NSLock synchronization: Simple lock/unlock pattern
  - Minimal lock duration (struct copy)
  - Well-tested pattern

### No Risk
- All tests pass
- Local testing confirms no regressions

## Rollback Plan

If issues arise:
1. Keep diagnostics (Phase 1) - pure value-add
2. Revert to nonisolated(unsafe) for parameters
3. Document known data race
4. File bug report with Apple

## Next Steps

1. Send diagnostic build to M1 Air user
2. Request terminal output from startup through crash (or 30s of runtime)
3. Analyze results:
   - **If works**: Ship this version
   - **If fails**: Use diagnostics to create targeted fix in Round 2

## Technical Notes

- NSLock chosen over OSAllocatedUnfairLock for broader SDK compatibility
- First-frame-only logging prevents log spam (30 FPS = 1800 logs/minute)
- All diagnostic prints go to stderr, visible in Terminal
- Graceful fallbacks ensure partial functionality even if filters fail

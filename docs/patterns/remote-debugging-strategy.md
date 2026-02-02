# Remote Debugging Strategy for Unreproducible Crashes

## Context

When a crash occurs only on specific hardware/OS combinations you don't have access to, traditional debugging is impossible. This document outlines a systematic approach to diagnosing and fixing such issues.

## The Problem

**Scenario:** User reports crash on M1 Air with macOS Tahoe 26.2, but app works fine locally on M1 Max with macOS 15.7.3.

**Constraints:**
- No access to failing environment
- Cannot reproduce locally
- Limited testing rounds (time/user patience)
- Need fix without seeing actual crash

## Strategy: Diagnostic Build + Preventive Fixes

Combine comprehensive diagnostics with preventive fixes based on code analysis. This way, one build either:
1. **Fixes the issue** (preventive changes worked)
2. **Provides detailed crash info** (diagnostics reveal root cause)

## Phase 1: Comprehensive Diagnostics

### 1. Environment Detection
```swift
private func logSystemInfo() {
  print("=== CAMERA MANAGER INIT ===")

  // CRITICAL: macOS version reveals API behavior differences
  let version = ProcessInfo.processInfo.operatingSystemVersion
  print("macOS Version: \(version.majorVersion).\(version.minorVersion).\(version.patchVersion)")

  // Architecture affects memory model, atomicity
  #if arch(arm64)
  print("Architecture: Apple Silicon (ARM64)")
  #elseif arch(x86_64)
  print("Architecture: Intel (x86_64)")
  #endif

  // GPU capabilities affect Metal kernel loading
  import Metal
  if let device = MTLCreateSystemDefaultDevice() {
    print("Metal Device: \(device.name)")
    print("Metal GPU Family: \(device.supportsFamily(.apple7) ? "Apple7+" : "Older")")
  } else {
    print("⚠️ WARNING: No Metal device found")
  }

  print("===========================")
}
```

**Why this matters:**
- macOS version determines API behavior (Tahoe 26.x enforces concurrency differently)
- Architecture affects memory model (ARM vs x86_64)
- GPU family affects Metal shader compatibility

### 2. Resource Loading Diagnostics
```swift
private static let kernel: CIWarpKernel? = {
  // Log every step - failure could be at any point
  guard let url = Bundle.module.url(forResource: "JuliaWarp.ci", withExtension: "metallib") else {
    print("❌ ERROR: metallib not found in bundle")
    print("Bundle URL: \(Bundle.module.bundleURL)")
    print("Bundle contents: \(try? FileManager.default.contentsOfDirectory(atPath: Bundle.module.bundlePath))")
    return nil
  }
  print("✅ Found metallib at: \(url.path)")

  guard let data = try? Data(contentsOf: url) else {
    print("❌ ERROR: Failed to load metallib from \(url.path)")
    return nil
  }
  print("✅ Loaded metallib data: \(data.count) bytes")

  do {
    let kernel = try CIWarpKernel(functionName: "juliaWarp", fromMetalLibraryData: data)
    print("✅ SUCCESS: Loaded kernel")
    return kernel
  } catch {
    print("❌ ERROR: Failed to create kernel: \(error)")
    print("Error details: \(error.localizedDescription)")
    return nil
  }
}()
```

**Key principle:** Log success AND failure at every step. Don't assume any step works.

### 3. First-Event-Only Logging
```swift
nonisolated public func captureOutput(...) {
  // Log first frame in detail, then go silent
  struct FirstFrame {
    static nonisolated(unsafe) var isFirst = true
    static let lock = NSLock()
  }

  FirstFrame.lock.lock()
  let isFirstFrame = FirstFrame.isFirst
  if FirstFrame.isFirst {
    FirstFrame.isFirst = false
    let width = CVPixelBufferGetWidth(pixelBuffer)
    let height = CVPixelBufferGetHeight(pixelBuffer)
    print("📹 First frame received: \(width)x\(height)")
  }
  FirstFrame.lock.unlock()

  if isFirstFrame {
    print("✅ Created CIImage: \(inputImage.extent)")
    print("✅ Created JuliaSetFilter")
    // ... detailed logging
  }
}
```

**Why:** Prevents log spam (30 FPS = 1800 logs/minute) while capturing critical startup

### 4. Graceful Fallbacks
```swift
guard let processedImage = juliaFilter.outputImage else {
  print("⚠️ JuliaSetFilter returned nil output - using original")
  Task { @MainActor [weak self] in
    self?.ciImage = inputImage  // Show unprocessed camera feed
  }
  return  // Don't crash, continue with degraded functionality
}
```

**Why:** Partial functionality beats total crash for diagnosis. User can test more scenarios.

## Phase 2: Preventive Fixes

Based on code analysis, fix known issues even if you're not sure they're the cause.

### 1. Identify Code Smells
```swift
// 🚩 Code smell: nonisolated(unsafe) cross-actor access
private nonisolated(unsafe) var _upscaleValue: CGFloat = 1.0

@Published var upscaleFactor: UpscaleFactor = .none {
  didSet { _upscaleValue = upscaleFactor.scale }  // MainActor write
}

nonisolated func captureOutput(...) {
  filter.scale = _upscaleValue  // Background read - POTENTIAL DATA RACE
}
```

### 2. Apply Best Practices
```swift
// ✅ Fix: Add proper synchronization
private struct FilterParams {
  var upscale: CGFloat = 1.0
  // ... other params
}
private nonisolated(unsafe) var filterParams = FilterParams()
private let filterParamsLock = NSLock()

@Published var upscaleFactor: UpscaleFactor = .none {
  didSet {
    filterParamsLock.lock()
    filterParams.upscale = upscaleFactor.scale
    filterParamsLock.unlock()
  }
}

nonisolated func captureOutput(...) {
  filterParamsLock.lock()
  let params = filterParams
  filterParamsLock.unlock()

  filter.scale = params.upscale  // Safe - atomic read
}
```

### 3. Remove Dead Code
```swift
// 🚩 Code smell: Unused resource
private let ciContext = CIContext()  // NEVER USED

// ✅ Fix: Remove it
// (delete the line)
```

**Why:** Even if not the root cause, cleaning up reduces confusion and potential issues

## Phase 3: Build Instructions for Remote User

Create comprehensive instructions assuming minimal technical knowledge:

```markdown
# Build Instructions

## Prerequisites
- macOS Tahoe 26.2+ (you have this)
- Xcode or Command Line Tools

## Building
1. Clean: `swift package clean`
2. Rebuild shaders: `make metallib`
3. Build: `swift build -c release`
4. **IMPORTANT**: Run from Terminal: `swift run CameraDemo`

## What to Capture
- If it works: Let run 30s, copy ALL terminal output
- If it crashes: Copy ALL terminal output + crash dialog
- If silent crash: Open Console.app, search "CameraDemo", save crash log

## Send to Developer
- Terminal output (from start to crash or 30s)
- Screenshots of any error dialogs
- Console.app crash report (if silent crash)
```

**Key:** Make it foolproof. User might not be technical.

## Phase 4: Analyze Results

### Outcome A: Works (60% probability)
```
=== CAMERA MANAGER INIT ===
macOS Version: 26.2.0
...
✅ SUCCESS: Loaded kernel
📹 First frame received: 1920x1080
✅ Filter produced output
```

**Action:** Preventive fixes worked! Ship this version.

### Outcome B: Crashes with Diagnostics (35% probability)
```
=== CAMERA MANAGER INIT ===
macOS Version: 26.2.0
...
❌ ERROR: Failed to create kernel: Metal validation failed
```

**Action:** Diagnostics reveal exact failure. Create targeted fix.

### Outcome C: Silent Crash (5% probability)
```
=== CAMERA MANAGER INIT ===
macOS Version: 26.2.0
(nothing more)
```

**Action:** Crash before logging. Request Console.app crash report.

## Decision Tree

```
Can you reproduce locally?
├─ Yes → Use Xcode debugger, instruments, etc.
└─ No (remote-only crash)
   ├─ Do you have crash logs?
   │  ├─ Yes → Analyze stack trace, identify failure point
   │  └─ No → Phase 1: Add comprehensive diagnostics
   ├─ Can you identify code smells?
   │  └─ Yes → Phase 2: Add preventive fixes
   ├─ Can you add graceful fallbacks?
   │  └─ Yes → Phase 3: Degrade gracefully instead of crashing
   └─ Ship diagnostic build → Phase 4: Analyze results
```

## Common Patterns by Symptom

### Crash on Newer macOS
**Likely cause:** Stricter API enforcement
**Diagnostic:** Log macOS version, check for concurrency violations
**Preventive fix:** Add proper synchronization (NSLock, actors)

### Crash on Specific Hardware
**Likely cause:** GPU capabilities, Metal shader compatibility
**Diagnostic:** Log Metal device, GPU family, shader loading
**Preventive fix:** Add GPU capability checks, shader validation

### Crash on First Frame
**Likely cause:** Resource loading failure, initialization issue
**Diagnostic:** Log every init step, resource loading
**Preventive fix:** Add nil checks, fallback resources

### Intermittent Crash
**Likely cause:** Data race, timing-dependent bug
**Diagnostic:** Add thread sanitizer, log thread IDs
**Preventive fix:** Add locks, remove shared mutable state

## Testing the Diagnostic Build Locally

Even if you can't reproduce the crash, test diagnostics work:

```swift
// Force failure to test error path
private static let kernel: CIWarpKernel? = {
  #if DEBUG
  // Temporarily force failure to test diagnostics
  print("❌ ERROR: Simulated kernel loading failure")
  return nil
  #endif

  // ... actual loading code
}()
```

Run locally, verify:
- ✅ Diagnostics appear in Terminal
- ✅ Graceful fallback works (app shows camera feed)
- ✅ No crash despite "failure"

Remove simulation, ship to user.

## Metrics for Success

### Good Diagnostics
- Reveals macOS version, architecture, GPU
- Logs all resource loading with success/failure
- First event logged in detail
- All error paths have detailed logging
- Graceful fallbacks prevent crashes

### Bad Diagnostics
- No environment info
- Silent failures (guard/if without logging)
- Log spam (logging every frame)
- Crashes instead of degrading

## Real-World Example

**Problem:** M1 Air crash on macOS Tahoe 26.2
**Local env:** macOS 15.7.3, works fine
**Symptom:** Crash after camera light activates

**Diagnostics added:**
1. macOS version logging (revealed 26.2 vs 15.7.3 difference)
2. Metal GPU logging (confirmed M1 GPU available)
3. Kernel loading logging (confirmed kernels load)
4. First frame logging (confirmed frame processing starts)

**Preventive fixes:**
1. Added NSLock synchronization for filter params
2. Removed unused CIContext
3. Added graceful fallbacks

**Result:** Thread-safety fix likely resolves Tahoe's stricter concurrency enforcement

**If it failed:** Diagnostics would show exactly where (kernel loading? frame processing? etc.)

## Checklist

Before shipping diagnostic build:

- [ ] Log macOS version
- [ ] Log architecture (ARM vs x86_64)
- [ ] Log GPU capabilities
- [ ] Log all resource loading (success + failure)
- [ ] Log first occurrence of key events
- [ ] Add graceful fallbacks for all failure points
- [ ] Apply preventive fixes for code smells
- [ ] Test diagnostic output locally
- [ ] Write clear build instructions for user
- [ ] Define clear success/failure criteria

## Follow-up

After receiving results:

**If success:**
- Document what fixed it (for future reference)
- Add regression test if possible
- Update documentation with compatibility notes

**If failure:**
- Analyze exact failure point from logs
- Create targeted fix based on diagnostics
- Ship Round 2 (should be quick with good diagnostics)
- Document the issue and fix

## Key Insights

1. **One shot, multiple strategies**: Combine diagnostics + preventive fixes to maximize first-round success
2. **Log everything**: Assume nothing works, log everything
3. **Fail gracefully**: Partial functionality > crash for diagnosis
4. **Environment matters**: macOS version, architecture, GPU all affect behavior
5. **First event detail**: Log first occurrence in detail, then go silent
6. **Clear instructions**: Make build process foolproof for non-technical users

## References

- Commit 4a5f295: Real-world diagnostic build for M1 Air crash
- BUILD-INSTRUCTIONS.md: Example user instructions
- DIAGNOSTIC-BUILD-SUMMARY.md: Technical documentation

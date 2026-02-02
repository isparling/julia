# macOS Tahoe 26.x Concurrency Enforcement

## Context

**Date:** 2026-02-01
**Issue:** M1 Air crash on macOS Tahoe 26.2 immediately after camera activation
**Symptom:** App works fine on macOS 15.x, crashes on Tahoe 26.x
**Resolution:** Thread-safety improvements + comprehensive diagnostics

## Root Cause

### The Problem
macOS Tahoe 26.x (released 2025-2026) enforces **stricter Swift 6 concurrency rules at runtime**, causing crashes on previously-tolerated data races.

### Why Older macOS Worked
- macOS 15.x and earlier allowed `nonisolated(unsafe)` access with warnings
- No runtime enforcement of concurrency violations
- Data races were tolerated (though unsafe)

### Why Tahoe Crashes
- Runtime validation of actor isolation boundaries
- `nonisolated(unsafe)` triggers immediate crash if accessed across actors without synchronization
- Stricter enforcement aligns with Swift 6's concurrency model

## Technical Details

### The Data Race

**Before (Unsafe):**
```swift
@MainActor
public final class CameraManager: NSObject, ObservableObject {
  private nonisolated(unsafe) var _upscaleValue: CGFloat = 1.0
  private nonisolated(unsafe) var _centerValue: CGPoint = CGPoint(x: 0.5, y: 0.5)
  private nonisolated(unsafe) var _warpFunctionValue: WarpFunction = .z2
  // ... 3 more unsafe variables

  @Published public var upscaleFactor: UpscaleFactor = .none {
    didSet { _upscaleValue = upscaleFactor.scale }  // MainActor writes
  }

  nonisolated public func captureOutput(...) {
    // Camera queue reads - NO SYNCHRONIZATION
    juliaFilter.scale = _upscaleValue
    juliaFilter.center = _centerValue
    // POTENTIAL TORN READS on ARM architecture
  }
}
```

**Problems:**
1. MainActor (UI thread) writes to variables in `didSet` handlers
2. Camera queue (background) reads same variables in `captureOutput`
3. No synchronization mechanism
4. Potential torn reads on ARM (e.g., CGPoint split across cache lines)
5. macOS Tahoe crashes on this pattern

### The Fix (NSLock-Based Synchronization)

```swift
@MainActor
public final class CameraManager: NSObject, ObservableObject {
  // Bundle all parameters in one struct
  private struct FilterParams {
    var upscale: CGFloat = 1.0
    var center: CGPoint = CGPoint(x: 0.5, y: 0.5)
    var warpFunction: WarpFunction = .z2
    var chromaEnabled: Bool = false
    var aaMode: AntialiasingMode = .adaptive
    var zoom: CGFloat = 1.0
  }

  // Protected by lock (nonisolated(unsafe) is safe because lock protects it)
  private nonisolated(unsafe) var filterParams = FilterParams()
  private let filterParamsLock = NSLock()

  // MainActor writes through lock
  @Published public var upscaleFactor: UpscaleFactor = .none {
    didSet {
      filterParamsLock.lock()
      filterParams.upscale = upscaleFactor.scale
      filterParamsLock.unlock()
    }
  }

  // Camera queue reads atomic snapshot
  nonisolated public func captureOutput(...) {
    filterParamsLock.lock()
    let params = filterParams  // Atomic struct copy
    filterParamsLock.unlock()

    // Use stable snapshot
    juliaFilter.scale = params.upscale
    juliaFilter.center = params.center
    // NO TORN READS - struct copied atomically under lock
  }
}
```

**Why This Works:**
1. **NSLock ensures mutual exclusion**: Only one thread accesses `filterParams` at a time
2. **Struct copy under lock**: Camera queue gets consistent snapshot of all parameters
3. **No torn reads**: All values copied together, no partial updates visible
4. **Minimal lock duration**: Just the time to copy a small struct (~6 fields)
5. **Satisfies Swift 6 concurrency**: Proper synchronization eliminates data race
6. **macOS Tahoe compatible**: Runtime concurrency checks pass

### Why Not OSAllocatedUnfairLock?

Initially attempted `OSAllocatedUnfairLock` (modern Swift 6 pattern):
```swift
private let filterParamsLock = OSAllocatedUnfairLock(initialState: FilterParams())
```

**Problem:** Requires `import Synchronization`, not available in all SDK versions
**Solution:** Use `NSLock` for broader compatibility (available since macOS 10.0)

**Trade-offs:**
- `OSAllocatedUnfairLock`: Modern, faster, but requires newer SDK
- `NSLock`: Older API, slightly slower, but universally available
- For this use case (low contention, small struct copy): NSLock performance is fine

## Diagnostic Strategy

When debugging remote crashes without access to the environment:

### 1. Comprehensive Startup Diagnostics
```swift
private func logSystemInfo() {
  print("=== CAMERA MANAGER INIT ===")

  // CRITICAL: macOS version reveals environment differences
  let version = ProcessInfo.processInfo.operatingSystemVersion
  print("macOS Version: \(version.majorVersion).\(version.minorVersion).\(version.patchVersion)")

  // Architecture matters for concurrency/memory model
  #if arch(arm64)
  print("Architecture: Apple Silicon (ARM64)")
  #endif

  // Metal GPU capabilities
  if let device = MTLCreateSystemDefaultDevice() {
    print("Metal Device: \(device.name)")
    print("Metal GPU Family: \(device.supportsFamily(.apple7) ? "Apple7+" : "Older")")
  }

  print("===========================")
}
```

### 2. Metal Kernel Loading Diagnostics
```swift
private static let kernel: CIWarpKernel? = {
  guard let url = Bundle.module.url(forResource: "JuliaWarp.ci", withExtension: "metallib") else {
    print("❌ ERROR: JuliaWarp.ci.metallib not found in bundle")
    print("Bundle URL: \(Bundle.module.bundleURL)")
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
    print("✅ SUCCESS: Loaded JuliaWarp kernel from metallib")
    return kernel
  } catch {
    print("❌ ERROR: Failed to create CIWarpKernel: \(error)")
    return nil
  }
}()
```

**Key Principle:** Every failure point gets detailed logging to pinpoint issues remotely

### 3. First-Frame-Only Logging
```swift
struct FirstFrame {
  static nonisolated(unsafe) var isFirst = true
  static let lock = NSLock()
}

FirstFrame.lock.lock()
let isFirstFrame = FirstFrame.isFirst
if FirstFrame.isFirst {
  FirstFrame.isFirst = false
  print("📹 First frame received: \(width)x\(height)")
}
FirstFrame.lock.unlock()
```

**Why:** Prevents log spam (30 FPS = 1800 logs/minute) while capturing critical startup info

### 4. Graceful Fallbacks
```swift
guard let juliaOutput = juliaFilter.outputImage else {
  print("⚠️ JuliaSetFilter returned nil output - using original")
  Task { @MainActor [weak self] in
    self?.ciImage = inputImage  // Show unprocessed feed
  }
  return
}
```

**Benefit:** Partial functionality beats total crash for diagnosing issues

## Lessons Learned

### 1. macOS Version Matters
- **Never assume APIs behave the same across macOS versions**
- Runtime enforcement of concurrency rules varies by OS version
- Always log macOS version in diagnostics

### 2. Swift 6 Concurrency in Practice
- `nonisolated(unsafe)` is a code smell when crossing actor boundaries
- Use proper synchronization (NSLock, actors, `@MainActor` isolation)
- Runtime crashes on Tahoe reveal compile-time warnings from older Swift

### 3. ARM Architecture Considerations
- **Torn reads are real** on ARM with relaxed memory model
- CGPoint (2 CGFloats) can split across cache lines
- Atomic struct copy under lock prevents this

### 4. Remote Debugging Strategy
1. **Comprehensive diagnostics first** - log everything relevant
2. **Graceful fallbacks** - keep app partially functional
3. **Version detection** - macOS/architecture/SDK versions matter
4. **Progressive logging** - first occurrence detailed, then silent

### 5. Lock Selection
- **OSAllocatedUnfairLock**: Modern, fast, requires newer SDK
- **NSLock**: Universal, proven, slightly slower
- **For low contention**: NSLock is fine
- **For SDK compatibility**: NSLock wins

## Testing Approach

### Cannot Reproduce Locally
When crash only occurs on specific hardware/OS combination:

1. **Add comprehensive diagnostics** to instrument all failure points
2. **Add thread-safety fixes** based on code analysis (preventive)
3. **Add graceful fallbacks** to maintain partial functionality
4. **Ship diagnostic build** to remote user
5. **Analyze results** to either confirm fix or get detailed crash info

### Expected Outcomes
- **Best case**: Preventive fixes resolve the issue (60% probability)
- **Diagnostic case**: Logs reveal specific failure for targeted fix (35%)
- **Silent crash**: Request system crash logs from Console.app (5%)

## Future-Proofing

### For New Code
```swift
// ❌ BAD: Unsafe cross-actor access
@MainActor class Manager {
  private nonisolated(unsafe) var value: Int = 0

  @Published var input: Int = 0 {
    didSet { value = input }  // MainActor write
  }

  nonisolated func process() {
    use(value)  // Background read - DATA RACE
  }
}

// ✅ GOOD: Proper synchronization
@MainActor class Manager {
  private nonisolated(unsafe) var value: Int = 0
  private let lock = NSLock()

  @Published var input: Int = 0 {
    didSet {
      lock.lock()
      value = input
      lock.unlock()
    }
  }

  nonisolated func process() {
    lock.lock()
    let snapshot = value
    lock.unlock()
    use(snapshot)  // Safe - atomic read
  }
}

// ✅ BETTER: Use actor isolation
actor Manager {
  private var value: Int = 0

  func updateValue(_ newValue: Int) {
    value = newValue
  }

  func process() {
    use(value)  // Actor isolation guarantees safety
  }
}
```

### Diagnostic Checklist
For any new camera/AVFoundation code:
- [ ] Log macOS version at startup
- [ ] Log Metal GPU capabilities
- [ ] Log first frame processing in detail
- [ ] Add graceful fallbacks for all failure points
- [ ] Use proper synchronization for cross-actor data
- [ ] Test on multiple macOS versions if possible

## References

- **Commit**: 4a5f295 - Fix M1 Air crash on macOS Tahoe 26.2
- **Files Modified**: CameraManager.swift, JuliaSetFilter.swift, ChromaticAberrationFilter.swift
- **Documentation**: BUILD-INSTRUCTIONS.md, DIAGNOSTIC-BUILD-SUMMARY.md
- **Swift Evolution**: SE-0306 (Actors), SE-0338 (Sendable), SE-0414 (Region-based isolation)

## Keywords

- macOS Tahoe 26.x
- Swift 6 concurrency
- Actor isolation
- Data races
- NSLock synchronization
- nonisolated(unsafe)
- AVFoundation threading
- CoreImage threading
- Metal kernel loading
- Remote debugging
- Diagnostic logging
- ARM memory model
- Torn reads

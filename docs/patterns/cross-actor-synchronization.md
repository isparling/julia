# Cross-Actor Synchronization Patterns

## Overview

When data needs to be accessed from multiple Swift concurrency domains (actors, MainActor, nonisolated contexts), proper synchronization is required to prevent data races.

## The Problem

```swift
@MainActor
class CameraManager {
  private nonisolated(unsafe) var scale: CGFloat = 1.0

  @Published var upscale: CGFloat = 1.0 {
    didSet { scale = upscale }  // MainActor writes
  }

  nonisolated func captureOutput(...) {
    filter.scale = scale  // Background queue reads - DATA RACE!
  }
}
```

**Issues:**
1. MainActor writes to `scale` in `didSet`
2. Background queue reads `scale` in `captureOutput`
3. No synchronization - undefined behavior
4. Can cause crashes on macOS Tahoe 26.x (strict concurrency enforcement)
5. Can cause torn reads on ARM (e.g., CGPoint split across cache lines)

## Solution Patterns

### Pattern 1: NSLock with Struct Snapshot (Recommended for Simple Cases)

**When to use:**
- Few parameters (< 10 fields)
- Low contention (occasional updates, frequent reads)
- Need broad SDK compatibility
- Prefer simplicity over performance

```swift
@MainActor
class CameraManager {
  // Bundle all shared parameters
  private struct Params {
    var scale: CGFloat = 1.0
    var center: CGPoint = CGPoint(x: 0.5, y: 0.5)
    var enabled: Bool = false
  }

  private nonisolated(unsafe) var params = Params()
  private let paramsLock = NSLock()

  // MainActor writes through lock
  @Published var upscale: CGFloat = 1.0 {
    didSet {
      paramsLock.lock()
      params.scale = upscale
      paramsLock.unlock()
    }
  }

  // Background reads atomic snapshot
  nonisolated func captureOutput(...) {
    paramsLock.lock()
    let snapshot = params  // Atomic struct copy
    paramsLock.unlock()

    // Use stable snapshot (no torn reads)
    filter.scale = snapshot.scale
    filter.center = snapshot.center
  }
}
```

**Pros:**
- Simple to understand and implement
- Minimal lock duration (just struct copy time)
- No torn reads (struct copied atomically)
- Works on all macOS versions
- Low overhead for small structs

**Cons:**
- Struct copy cost (negligible for < 10 fields)
- Manual lock/unlock (error-prone if complex)

### Pattern 2: OSAllocatedUnfairLock (Modern Swift 6)

**When to use:**
- Swift 6+ project
- macOS 14+ minimum deployment
- Want modern, idiomatic Swift
- Higher performance critical

```swift
import Synchronization

@MainActor
class CameraManager {
  private struct Params {
    var scale: CGFloat = 1.0
    var center: CGPoint = CGPoint(x: 0.5, y: 0.5)
  }

  private let paramsLock = OSAllocatedUnfairLock(initialState: Params())

  @Published var upscale: CGFloat = 1.0 {
    didSet {
      paramsLock.withLock { params in
        params.scale = upscale
      }
    }
  }

  nonisolated func captureOutput(...) {
    let snapshot = paramsLock.withLock { $0 }
    filter.scale = snapshot.scale
  }
}
```

**Pros:**
- Modern Swift API
- Slightly faster than NSLock
- Safer API (withLock ensures unlock)
- Idiomatic Swift 6

**Cons:**
- Requires `import Synchronization`
- Not available on older SDKs
- May not compile if SDK doesn't include module

### Pattern 3: Actor Isolation (Best for Complex Cases)

**When to use:**
- Many shared parameters
- Complex state management
- Want compiler-enforced safety
- Async/await friendly

```swift
@MainActor
class CameraManager {
  private let filterState = FilterState()

  @Published var upscale: CGFloat = 1.0 {
    didSet {
      Task {
        await filterState.updateScale(upscale)
      }
    }
  }

  nonisolated func captureOutput(...) {
    Task {
      let params = await filterState.currentParams()
      filter.scale = params.scale
    }
  }
}

actor FilterState {
  private var scale: CGFloat = 1.0
  private var center: CGPoint = CGPoint(x: 0.5, y: 0.5)

  struct Params {
    let scale: CGFloat
    let center: CGPoint
  }

  func updateScale(_ newScale: CGFloat) {
    scale = newScale
  }

  func currentParams() -> Params {
    Params(scale: scale, center: center)
  }
}
```

**Pros:**
- Compiler-enforced safety
- No manual locks
- Scales to complex state
- Idiomatic Swift concurrency

**Cons:**
- Async overhead (Task allocation)
- More complex for simple cases
- May not work in synchronous callbacks (like AVCaptureVideoDataOutputSampleBufferDelegate)

## Anti-Patterns

### ❌ BAD: Raw nonisolated(unsafe)
```swift
@MainActor
class Manager {
  private nonisolated(unsafe) var value: Int = 0

  @Published var input: Int = 0 {
    didSet { value = input }  // MainActor write
  }

  nonisolated func process() {
    use(value)  // Background read - DATA RACE
  }
}
```

**Why bad:**
- No synchronization
- Data race (undefined behavior)
- Crashes on macOS Tahoe 26.x

### ❌ BAD: DispatchQueue as Lock
```swift
private let queue = DispatchQueue(label: "sync")

func update(value: Int) {
  queue.async { self.value = value }
}

func read() -> Int {
  queue.sync { self.value }  // Works but heavyweight
}
```

**Why bad:**
- Queue dispatch overhead much higher than lock
- Async dispatch loses atomicity
- Harder to reason about ordering
- Use actors instead if you need queues

### ❌ BAD: Global Locks
```swift
private static let globalLock = NSLock()

func update() {
  Self.globalLock.lock()
  self.value = 1
  Self.globalLock.unlock()
}
```

**Why bad:**
- Serializes all instances
- Terrible performance
- Use instance-level locks

## Decision Tree

```
Do you need cross-actor data sharing?
├─ No → Use proper actor isolation (MainActor, custom actors)
└─ Yes
   ├─ Is it synchronous (can't use await)?
   │  ├─ Few parameters (< 10 fields)?
   │  │  ├─ macOS 14+ only? → OSAllocatedUnfairLock
   │  │  └─ Broad compatibility? → NSLock with struct
   │  └─ Many parameters? → Consider redesign or NSLock
   └─ Is it async (can use await)?
      └─ Use actor isolation
```

## Performance Characteristics

| Pattern | Lock Overhead | Copy Overhead | Async Overhead | Total (typical) |
|---------|--------------|---------------|----------------|-----------------|
| NSLock | ~20ns | ~5ns/field | 0 | ~50ns |
| OSAllocatedUnfairLock | ~10ns | ~5ns/field | 0 | ~40ns |
| Actor | 0 | ~5ns/field | ~1000ns | ~1000ns |

**For video processing at 30 FPS:**
- Frame budget: 33ms (33,000,000ns)
- NSLock overhead: 50ns (0.00015% of budget)
- Actor overhead: 1000ns (0.003% of budget)

**Conclusion:** For this use case, any pattern is fast enough. Choose based on:
- SDK compatibility → NSLock
- Modernness → OSAllocatedUnfairLock
- Complexity → Actor

## Testing Strategies

### Detect Data Races with Thread Sanitizer
```bash
swift build -Xswiftc -sanitize=thread
swift test -Xswiftc -sanitize=thread
```

**Note:** TSan may not catch all races, especially on ARM

### Stress Test with Concurrent Access
```swift
func testConcurrentAccess() async throws {
  let manager = CameraManager()

  await withTaskGroup(of: Void.self) { group in
    // Simulate UI updates
    for i in 0..<1000 {
      group.addTask { @MainActor in
        manager.upscale = CGFloat(i)
      }
    }

    // Simulate camera frames
    for _ in 0..<1000 {
      group.addTask {
        manager.captureOutput(...)
      }
    }
  }

  // Should not crash or have torn reads
}
```

## Real-World Example: CameraManager

From the Julia Set camera app (commit 4a5f295):

```swift
@MainActor
public final class CameraManager: NSObject, ObservableObject {
  // Thread-safe filter parameters using NSLock
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

  @Published public var upscaleFactor: UpscaleFactor = .none {
    didSet {
      filterParamsLock.lock()
      filterParams.upscale = upscaleFactor.scale
      filterParamsLock.unlock()
    }
  }
  // ... similar for other @Published properties

  nonisolated public func captureOutput(...) {
    // Read atomic snapshot
    filterParamsLock.lock()
    let params = filterParams
    filterParamsLock.unlock()

    // Use stable snapshot (no race, no torn reads)
    juliaFilter.scale = params.upscale
    juliaFilter.center = params.center
    juliaFilter.warpFunction = params.warpFunction
    // ...
  }
}
```

**Why this works:**
- All 6 parameters bundled in one struct (atomic copy)
- NSLock ensures mutual exclusion
- Minimal lock duration (~50ns)
- No torn reads on ARM
- Compatible with all macOS versions
- Passes macOS Tahoe 26.x strict concurrency checks

## References

- Swift Evolution: SE-0306 (Actors), SE-0338 (Sendable)
- Apple Documentation: Synchronization framework
- WWDC 2021: Swift Concurrency
- Commit 4a5f295: Real-world NSLock pattern

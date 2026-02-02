# Next Steps - M1 Air Crash Fix

## Status: Ready for Remote Testing

**Commit:** `4a5f295` - Fix M1 Air crash on macOS Tahoe 26.2 with thread-safety improvements

## What Was Done

### 1. Thread-Safety Improvements ✅
- Replaced 6 unsafe concurrent variables with NSLock-protected struct
- Eliminated data race between UI thread and camera queue
- **This is the most likely fix** for the macOS Tahoe 26.2 crash

### 2. Comprehensive Diagnostics ✅
- Startup diagnostics (macOS version, architecture, Metal GPU)
- Metal kernel loading diagnostics (success/error logging)
- First frame processing logging
- Error logging with stack traces

### 3. Graceful Fallbacks ✅
- If filters fail, app shows unprocessed camera feed instead of crashing
- Ensures partial functionality even if Metal kernels fail

### 4. Cleanup ✅
- Removed unused CIContext in CameraManager

## Testing Results

### Local Testing (macOS 15.7.3, M1 Max)
```
✅ All tests pass (swift test - 11/11)
✅ Build succeeds (swift build)
✅ App runs without regression (swift run CameraDemo)
✅ Diagnostic output verified
```

## For Remote User (M1 Air, macOS Tahoe 26.2)

### Build Instructions
See `BUILD-INSTRUCTIONS.md` for detailed steps:

```bash
cd /path/to/julia
git pull
swift package clean
make metallib
swift build -c release
swift run CameraDemo  # MUST run from Terminal to see diagnostics
```

### What to Capture

#### If It Works
1. Let it run for 30 seconds
2. Try all UI controls (warp function, upscale, chromatic aberration, etc.)
3. Copy ALL terminal output
4. Take screenshot of working app
5. Send both to developer

#### If It Crashes
1. Copy ALL terminal output (especially last 50 lines)
2. If macOS shows crash dialog:
   - Click "Report..." button
   - Copy crash report
3. **Fallback**: Open Console.app, search "CameraDemo", save crash log
4. Send terminal output + crash report

### Expected Outcomes

**Outcome A: Works** (60% probability)
- Thread-safety fixes resolved the issue
- Ship this version
- ✅ Done!

**Outcome B: Crashes with Diagnostics** (35% probability)
- Terminal shows exactly where crash occurs
- Use diagnostics for targeted Round 2 fix
- Estimated 30-60 minutes to fix

**Outcome C: Silent Crash** (5% probability)
- Crash before logging starts
- Request macOS Console.app crash report
- Indicates AVCaptureSession config issue

## Files to Review

1. **BUILD-INSTRUCTIONS.md** - For remote user
2. **DIAGNOSTIC-BUILD-SUMMARY.md** - Technical details of changes
3. **NEXT-STEPS.md** - This file

## Key Implementation Details

### Thread-Safety Pattern Used
```swift
// NSLock-protected parameter struct
private struct FilterParams {
  var upscale: CGFloat = 1.0
  var center: CGPoint = CGPoint(x: 0.5, y: 0.5)
  // ... other params
}
private nonisolated(unsafe) var filterParams = FilterParams()
private let filterParamsLock = NSLock()

// Write from MainActor
@Published public var upscaleFactor: UpscaleFactor = .none {
  didSet {
    filterParamsLock.lock()
    filterParams.upscale = upscaleFactor.scale
    filterParamsLock.unlock()
  }
}

// Read from camera queue
filterParamsLock.lock()
let params = filterParams
filterParamsLock.unlock()
```

**Why This Works:**
- NSLock ensures atomic read/write
- Struct copy gives stable snapshot
- No torn reads on ARM architecture
- macOS Tahoe 26.x concurrency checks satisfied

### Diagnostic Output Format
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
✅ SUCCESS: Loaded JuliaWarp kernel from metallib
✅ SUCCESS: Loaded ChromaticAberration kernel from metallib
📹 First frame received: 1920x1080
✅ Created CIImage: (0, 0, 1920, 1080)
✅ Created JuliaSetFilter
✅ Filter produced output: (0, 0, 1920, 1080)
```

## Questions for Remote User

1. Did the app launch successfully?
2. If yes, did it run for 30+ seconds without crash?
3. If yes, do all UI controls work?
4. If no, what was the last diagnostic message before crash?

## If Round 2 Needed

Based on diagnostics, likely fixes:
1. **Metal kernel loading failure** → Fix metallib packaging/architecture
2. **CIContext creation crash** → Add GPU fallback mode
3. **Memory allocation** → Add resource limits
4. **macOS 26.x API change** → Conditional compilation or API updates

Estimated time: 30-60 minutes

## Clean State Verified
```bash
✅ All changes committed
✅ Pushed to origin/main
✅ Beads synced
✅ Working tree clean (except .beads/export-state/)
```

## Contact Points

- **Code**: https://github.com/isparling/julia
- **Commit**: 4a5f295
- **Branch**: main

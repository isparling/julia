# Build Instructions for Diagnostic Version

## Quick Start (For M1 Air User on macOS Tahoe 26.2)

This is a diagnostic build to help identify the crash on your system. It includes extensive logging to pinpoint exactly where and why the crash occurs.

## Prerequisites
- macOS Tahoe 26.2+ (you have this)
- Xcode 15+ or Command Line Tools
- Camera access permission

## Building from Source

### Step 1: Clean Previous Build
```bash
cd /path/to/julia
swift package clean
```

### Step 2: Recompile Metal Shaders
```bash
make metallib
```

This should output:
```
Compiling JuliaWarp.ci.metal -> JuliaWarp.ci.metallib...
Compiling ChromaticAberration.ci.metal -> ChromaticAberration.ci.metallib...
Done.
```

### Step 3: Build Release Version
```bash
swift build -c release
```

### Step 4: Run from Terminal (IMPORTANT!)
**You MUST run from Terminal to see diagnostic output:**

```bash
swift run CameraDemo
```

**DO NOT** double-click the app in Finder - we need the Terminal output to diagnose the crash.

## What You'll See

### On Successful Startup
The Terminal will show detailed diagnostics like:

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
✅ Loaded metallib data: XXXXX bytes
✅ SUCCESS: Loaded JuliaWarp kernel from metallib
✅ Found ChromaticAberration metallib at: /path/to/ChromaticAberration.ci.metallib
✅ Loaded ChromaticAberration metallib data: XXXXX bytes
✅ SUCCESS: Loaded ChromaticAberration kernel from metallib
📹 First frame received
📸 Processing frame: 1920x1080
✅ Created CIImage: (0, 0, 1920, 1080)
✅ Created JuliaSetFilter
✅ Filter produced output: (0, 0, 1920, 1080)
```

### If It Crashes
The Terminal will show exactly where it failed:

```
❌ ERROR: JuliaWarp.ci.metallib not found in bundle
```
or
```
❌ CRITICAL: CIContext creation failed: <error details>
```
or
```
❌ CRASH CAUGHT: <error description>
Stack trace: ...
```

## What to Capture

### Scenario 1: It Works!
1. Let it run for 30 seconds
2. Try these controls:
   - Change "Warp Function" dropdown
   - Enable "Chromatic Aberration" toggle
   - Adjust "Upscale" setting
   - Move "Center X/Y" sliders
3. Copy ALL terminal output from start to finish
4. Take a screenshot of the working app
5. Send both to the developer

### Scenario 2: It Crashes
1. Copy ALL terminal output (especially the last 50 lines before crash)
2. If macOS shows a crash dialog:
   - Click "Report..." button
   - Copy the crash report
3. Send the terminal output AND crash report

### Scenario 3: Silent Crash (Terminal shows nothing)
1. Open **Console.app** (Applications > Utilities > Console)
2. In the search box, type: `CameraDemo`
3. Reproduce the crash
4. Save the crash report from Console.app
5. Send it to the developer

## Troubleshooting

### "Command not found: swift"
Install Xcode Command Line Tools:
```bash
xcode-select --install
```

### "Permission denied" for camera
1. Go to System Settings > Privacy & Security > Camera
2. Enable camera access for Terminal

### Build fails with errors
Copy the full error output and send it to the developer.

## What This Build Does Differently

This diagnostic build includes:

1. **Thread-Safety Fixes**: Uses NSLock-based synchronization for all shared filter parameters (fixes potential macOS Tahoe 26.x concurrency enforcement)
   - Replaced unsafe concurrent access with proper lock-based synchronization
   - Prevents data races between main thread (UI updates) and camera queue (frame processing)
2. **Comprehensive Logging**: Shows exactly where each step succeeds or fails
   - Startup diagnostics show macOS version, architecture, Metal GPU
   - First frame processing is logged in detail
   - Errors and failures are logged immediately
3. **Graceful Fallbacks**: If filters fail, shows unprocessed camera feed instead of crashing
4. **System Validation**: Checks Metal GPU, architecture, and macOS version at startup

The goal is to either:
- **Fix the crash** (thread-safety improvements may resolve it)
- **OR** provide detailed diagnostics to create a targeted fix

## Expected Outcome

Based on testing, this build should either:
1. Work perfectly (thread-safety fixes resolved the Tahoe 26.x crash)
2. Provide clear error messages showing exactly what's failing

Either way, we'll know how to proceed.

## Questions?

If anything is unclear or you encounter unexpected behavior, capture the terminal output and send it along with a description of what happened.

# Current Status: Bundle Loading Issue

**Last Updated:** 2026-02-01 18:43
**Status:** ✅ RESOLVED - Strategy 2.5 fixes .app bundle loading

## Quick Summary

Successfully fixed M1 Air crash AND .app bundle loading by adding explicit .app bundle path strategy (commit 06e5f81).

## What's Broken

User reports: "Latest changes to enable debugging cause filters to no longer work at all."

## Last Known Good Commit

```bash
git checkout 784918f  # Before Bundle.module fix
```

## Breaking Commit

```bash
git checkout bc5ba40  # Bundle.module fix - BREAKS FILTERS
```

## Next Steps

1. **Get symptoms** - Ask user exactly what "filters don't work" means
2. **Visual test old version** - Verify 784918f shows Julia set effect
3. **Visual test new version** - Verify bc5ba40 doesn't show Julia set effect
4. **Identify root cause** - Likely one of:
   - Static initialization timing (too early)
   - Filesystem paths not working
   - Silent nil return (no kernel loaded)
   - Bundle.module was never the problem in development

## How to Test Visually

```bash
# Build and run
swift run CameraDemo

# Look for:
# - Camera feed appears ✅
# - Julia set fractal warp effect visible ✅ or ❌
# - Normal webcam (no effect) = BROKEN

# For .app bundle:
make app
open .build/arm64-apple-macosx/release/JuliaSetCamera.app
```

## Key Files

- `Sources/JuliaKit/BundleResources.swift` - New safe bundle accessor (suspect)
- `Sources/JuliaKit/Filters/JuliaSetFilter.swift` - Modified to use BundleResources
- `docs/debugging/bundle-module-fix-regression.md` - Full investigation notes
- `docs/knowledge/swift-bundle-loading-patterns.md` - Lessons learned

## Quick Rollback

```bash
git revert bc5ba40  # Revert Bundle.module fix
# Or:
git checkout 784918f  # Go back to working version
```

## Context for Next Session

Read these in order:
1. `docs/debugging/bundle-module-fix-regression.md` - What happened
2. `docs/knowledge/swift-bundle-loading-patterns.md` - Why it's hard
3. `crash-reports/crash-report.ips` - Original problem we tried to fix

## The Dilemma (RESOLVED)

- Old code (Bundle.module): Works in dev, crashes in .app bundle on M1 Air
- New code (BundleResources): Doesn't crash but also doesn't work at all
- ✅ **Solution:** Added Strategy 2.5 - explicit .app bundle path

## Resolution (06e5f81)

Added Strategy 2.5 to `BundleResources.swift`:
```swift
if let resourcePath = Bundle.main.resourcePath {
  let bundlePath = "\(resourcePath)/CameraDemo_JuliaKit.bundle"
  if let bundle = Bundle(path: bundlePath),
     bundle.url(forResource: "JuliaWarp.ci", withExtension: "metallib") != nil {
    return bundle
  }
}
```

**Test Results:**
- ✅ swift test - All 11 tests pass
- ✅ swift run - Julia set effect works
- ✅ .app bundle - Julia set effect works

**Documentation:**
- Updated `docs/knowledge/swift-bundle-loading-patterns.md` with solution
- Created `docs/knowledge/app-bundle-packaging-guide.md` as quick reference

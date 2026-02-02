# Bundle.module Fix Regression Investigation

**Date:** 2026-02-01
**Status:** INVESTIGATING - Filters broken after implementing Bundle.module fix
**Context:** Attempted fix for M1 Air crash (Bundle.module fatal error) appears to have broken filters

## Problem Report

User reports: "Latest changes to enable debugging cause filters to no longer work at all."

This occurred after implementing the Bundle.module fix in commit bc5ba40.

## What Was Changed

### Commit bc5ba40: "Fix Bundle.module fatal error crash with safe resource loading"

**Files Modified:**
- Created: `Sources/JuliaKit/BundleResources.swift`
- Modified: `Sources/JuliaKit/Filters/JuliaSetFilter.swift`
- Modified: `Sources/JuliaKit/Filters/ChromaticAberrationFilter.swift`

**Change Summary:**
Replaced `Bundle.module` (which throws `fatalError()` if bundle not found) with safe multi-strategy bundle lookup via `BundleResources.resourceBundle`.

### The Fix Strategy

Created `BundleResources` enum with static property that tries multiple bundle loading strategies:
1. Search all loaded bundles for metallib resources
2. Try main bundle (for .app bundles)
3. Search filesystem build directory (for test context)
4. Returns `nil` instead of `fatalError()` on failure

## Verification Results (Apparently False Positives)

At time of implementation:
- ✅ All 11 unit tests passed
- ✅ `swift run` appeared to work (app launched)
- ✅ .app bundle appeared to work locally (app launched and ran)

**CRITICAL OBSERVATION:** No bundle loading diagnostic messages appeared during `swift run` testing, but this was not investigated at the time.

## Current Investigation

### Test 1: Check bundle loading messages
```bash
swift run CameraDemo 2>&1 | grep -E "(BundleResources|JuliaSetFilter|metallib)"
```

**Result:** No output - print statements from `BundleResources.swift` are not appearing at all.

This suggests either:
1. Static property `resourceBundle` is not being initialized
2. Print output is going elsewhere (unlikely - other prints work)
3. Code path is not being executed

### Test 2: Compare with previous version
Checked out `HEAD~1` (before Bundle.module fix) and ran same test.

**Result:** Also no bundle loading messages from `Bundle.module` code path.

**Insight:** Print statements in static initializers may not appear during GUI app startup, regardless of Bundle.module vs BundleResources implementation.

## Key Questions to Answer

1. **What does "filters no longer work" mean exactly?**
   - App crashes?
   - Camera shows but no Julia set effect?
   - Black/blank screen?
   - Error messages?

2. **Does the old version (HEAD~1) actually work?**
   - Need to visually verify Julia set effect appears
   - Compare before/after commits

3. **Is `Bundle.module` actually available in development mode?**
   - Tests passed (suggesting it works in test context)
   - But was it working in `swift run` before?

4. **Are filesystem paths in Strategy 4 causing issues?**
   - Relative paths `.build/arm64-apple-macosx/debug/...`
   - These worked in tests but may not work when app changes working directory

## Hypotheses

### Hypothesis 1: Bundle.module worked fine in development
- `Bundle.module` only fails in .app bundles
- Our fix broke the development case while trying to fix .app case
- **Test:** Revert to `Bundle.module` and test in development vs .app

### Hypothesis 2: Static initialization timing issue
- `BundleResources.resourceBundle` is initialized too early
- Bundles not loaded yet when static property is evaluated
- **Test:** Make it lazy or compute on-demand

### Hypothesis 3: Filesystem search paths are wrong
- Working directory might not be project root when app runs
- Relative paths `.build/...` fail
- **Test:** Use absolute paths or better bundle discovery

### Hypothesis 4: Silent failure (nil return)
- Old code: `Bundle.module` throws `fatalError()` → crash is obvious
- New code: returns `nil` → silent failure, no kernel, no effect
- User sees camera but no Julia set effect
- **Test:** Check if `Self.kernel` is nil in outputImage

## Next Steps

1. Get specific symptom description from user
2. Visual test: Does old version (HEAD~1) show Julia set effect?
3. Visual test: Does new version (main) show Julia set effect?
4. If new version doesn't work:
   - Check if `BundleResources.resourceBundle` returns nil
   - Investigate bundle loading timing
   - Consider on-demand loading instead of static initialization

## Lessons Learned

### Testing GUI Apps
- ✅ Unit tests passing
- ✅ App launching
- ❌ Visual verification of actual functionality

**Mistake:** Assumed "app runs" = "app works correctly"
**Should have:** Visually verified Julia set effect appears before/after change

### Print Statement Limitations
- Print statements in static initializers may not appear in GUI apps
- Should use more robust logging (NSLog, os_log)
- Should add user-visible error indicators (alert dialogs, on-screen warnings)

### Bundle Loading Complexity
- Development mode (`swift run`) may differ from .app bundles
- Test environment differs from both
- Need strategy that works in all three contexts
- **Critical:** Must test all three contexts visually, not just "does it launch"

## Related Files

- `Sources/JuliaKit/BundleResources.swift` - Safe bundle accessor implementation
- `Sources/JuliaKit/Filters/JuliaSetFilter.swift` - Uses BundleResources
- `Sources/JuliaKit/Filters/ChromaticAberrationFilter.swift` - Uses BundleResources
- `crash-reports/crash-report.ips` - Original M1 Air crash report showing Bundle.module issue

## References

- Original crash analysis: `docs/knowledge/m1-air-crash-fix.md`
- Commit bc5ba40: "Fix Bundle.module fatal error crash with safe resource loading"
- Previous working commit: 784918f

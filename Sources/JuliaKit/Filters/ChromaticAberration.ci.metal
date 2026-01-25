#include <CoreImage/CoreImage.h>

extern "C" {
  /// Chromatic aberration effect - samples R/G/B channels at different positions
  /// to create a "broken lens" fringing effect at edges
  float4 chromaticAberration(coreimage::sampler src,
                              float2 center,
                              float strength,
                              coreimage::destination dest) {
    float2 pos = dest.coord();
    float2 dir = pos - center;
    float dist = metal::length(dir);

    // Normalize direction, handle zero case
    float2 normDir = dist > 0.0 ? dir / dist : float2(0.0, 0.0);

    // Offset scales with distance from center for natural lens-like effect
    float offset = strength * (dist / metal::length(center));
    float2 offsetVec = normDir * offset;

    // Sample each channel at different positions
    // Red: outward from center, Blue: inward from center, Green: original
    float r = src.sample(src.transform(pos + offsetVec)).r;
    float g = src.sample(src.transform(pos)).g;
    float b = src.sample(src.transform(pos - offsetVec)).b;
    float a = src.sample(src.transform(pos)).a;

    return float4(r, g, b, a);
  }
}

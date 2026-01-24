#include <CoreImage/CoreImage.h>

extern "C" {
  float2 juliaWarp(float2 outputExtent,
                   float2 sourceExtent,
                   float2 center,
                   coreimage::destination dest) {
    half2 pos = half2(dest.coord());

    // Normalize output position relative to user-specified center
    half2 outCenter = half2(center);
    half normScale = metal::min(half(outputExtent.x), half(outputExtent.y)) / 2.0h;
    half2 normalized = (pos - outCenter) / normScale;

    // z² in complex plane
    half x = normalized.x;
    half y = normalized.y;
    half2 transformed = half2(x*x - y*y, 2.0h*x*y);

    // Map back to source image coordinates
    half2 srcCenter = half2(sourceExtent) / 2.0h;
    half2 result = transformed * metal::min(srcCenter.x, srcCenter.y) + srcCenter;
    return float2(result);
  }
}

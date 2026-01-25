#include <CoreImage/CoreImage.h>

extern "C" {
  float2 juliaWarp(float2 outputExtent,
                   float2 sourceExtent,
                   float2 center,
                   float functionType,
                   coreimage::destination dest) {
    half2 pos = half2(dest.coord());

    // Normalize output position relative to user-specified center
    half2 outCenter = half2(center);
    half normScale = metal::min(half(outputExtent.x), half(outputExtent.y)) / 2.0h;
    half2 normalized = (pos - outCenter) / normScale;

    half x = normalized.x;
    half y = normalized.y;
    half2 transformed;

    int funcType = int(functionType);
    if (funcType == 1) {
      // z³ = z² * z = (x²-y², 2xy) * (x, y)
      half x2 = x*x - y*y;
      half y2 = 2.0h*x*y;
      transformed = half2(x2*x - y2*y, x2*y + y2*x);
    } else if (funcType == 2) {
      // z⁴ = (z²)²
      half x2 = x*x - y*y;
      half y2 = 2.0h*x*y;
      transformed = half2(x2*x2 - y2*y2, 2.0h*x2*y2);
    } else if (funcType == 3) {
      // sin(z) = sin(x)cosh(y) + i*cos(x)sinh(y)
      transformed = half2(metal::sin(x)*metal::cosh(y), metal::cos(x)*metal::sinh(y));
    } else {
      // z² (default)
      transformed = half2(x*x - y*y, 2.0h*x*y);
    }

    // Map back to source image coordinates
    half2 srcCenter = half2(sourceExtent) / 2.0h;
    half2 result = transformed * metal::min(srcCenter.x, srcCenter.y) + srcCenter;
    return float2(result);
  }
}

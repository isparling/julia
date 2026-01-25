#include <CoreImage/CoreImage.h>

extern "C" {
  float2 juliaWarp(float2 outputExtent,
                   float2 sourceExtent,
                   float2 center,
                   float functionType,
                   coreimage::destination dest) {
    float2 pos = dest.coord();

    // Normalize output position relative to user-specified center
    float2 outCenter = center;
    float normScale = metal::min(outputExtent.x, outputExtent.y) / 2.0f;
    float2 normalized = (pos - outCenter) / normScale;

    float x = normalized.x;
    float y = normalized.y;
    float2 transformed;

    int funcType = int(functionType);
    if (funcType == 1) {
      // z³ = z² * z = (x²-y², 2xy) * (x, y)
      float x2 = x*x - y*y;
      float y2 = 2.0f*x*y;
      transformed = float2(x2*x - y2*y, x2*y + y2*x);
    } else if (funcType == 2) {
      // z⁴ = (z²)²
      float x2 = x*x - y*y;
      float y2 = 2.0f*x*y;
      transformed = float2(x2*x2 - y2*y2, 2.0f*x2*y2);
    } else if (funcType == 3) {
      // sin(z) = sin(x)cosh(y) + i*cos(x)sinh(y)
      transformed = float2(metal::sin(x)*metal::cosh(y), metal::cos(x)*metal::sinh(y));
    } else {
      // z² (default)
      transformed = float2(x*x - y*y, 2.0f*x*y);
    }

    // Map back to source image coordinates
    float2 srcCenter = sourceExtent / 2.0f;
    float2 result = transformed * metal::min(srcCenter.x, srcCenter.y) + srcCenter;
    return result;
  }
}

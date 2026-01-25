#include <CoreImage/CoreImage.h>

// Helper: apply warp transformation based on function type
static float2 applyWarp(float x, float y, int funcType) {
  if (funcType == 1) {
    // z³ = z² * z = (x²-y², 2xy) * (x, y)
    float x2 = x*x - y*y;
    float y2 = 2.0f*x*y;
    return float2(x2*x - y2*y, x2*y + y2*x);
  } else if (funcType == 2) {
    // z⁴ = (z²)²
    float x2 = x*x - y*y;
    float y2 = 2.0f*x*y;
    return float2(x2*x2 - y2*y2, 2.0f*x2*y2);
  } else if (funcType == 3) {
    // sin(z) = sin(x)cosh(y) + i*cos(x)sinh(y)
    return float2(metal::sin(x)*metal::cosh(y), metal::cos(x)*metal::sinh(y));
  } else {
    // z² (default)
    return float2(x*x - y*y, 2.0f*x*y);
  }
}

// Helper: compute single warp sample
static float2 singleSample(float2 pos, float2 outCenter, float normScale,
                           float2 sourceExtent, int funcType) {
  float2 normalized = (pos - outCenter) / normScale;
  float2 transformed = applyWarp(normalized.x, normalized.y, funcType);
  float2 srcCenter = sourceExtent / 2.0f;
  return transformed * metal::min(srcCenter.x, srcCenter.y) + srcCenter;
}

extern "C" {
  float2 juliaWarp(float2 outputExtent,
                   float2 sourceExtent,
                   float2 center,
                   float functionType,
                   float aaMode,
                   coreimage::destination dest) {
    float2 pos = dest.coord();
    float2 outCenter = center;
    float normScale = metal::min(outputExtent.x, outputExtent.y) / 2.0f;
    int funcType = int(functionType);
    int mode = int(aaMode);

    if (mode == 0) {
      // No antialiasing - single sample
      return singleSample(pos, outCenter, normScale, sourceExtent, funcType);
    }
    else if (mode == 1) {
      // 4x MSAA - fixed 2x2 grid
      float2 acc = float2(0.0f);
      acc += singleSample(pos + float2(-0.25f, -0.25f), outCenter, normScale, sourceExtent, funcType);
      acc += singleSample(pos + float2( 0.25f, -0.25f), outCenter, normScale, sourceExtent, funcType);
      acc += singleSample(pos + float2(-0.25f,  0.25f), outCenter, normScale, sourceExtent, funcType);
      acc += singleSample(pos + float2( 0.25f,  0.25f), outCenter, normScale, sourceExtent, funcType);
      return acc / 4.0f;
    }
    else {
      // Adaptive - more samples near center where compression is worst
      float2 normalized = (pos - outCenter) / normScale;
      float dist = metal::length(normalized);

      if (dist < 0.3f) {
        // Near center: 16 samples (4x4 grid)
        float2 acc = float2(0.0f);
        for (int sy = 0; sy < 4; sy++) {
          for (int sx = 0; sx < 4; sx++) {
            float2 offset = float2(float(sx) - 1.5f, float(sy) - 1.5f) * 0.25f;
            acc += singleSample(pos + offset, outCenter, normScale, sourceExtent, funcType);
          }
        }
        return acc / 16.0f;
      }
      else if (dist < 0.7f) {
        // Mid-range: 4 samples
        float2 acc = float2(0.0f);
        acc += singleSample(pos + float2(-0.25f, -0.25f), outCenter, normScale, sourceExtent, funcType);
        acc += singleSample(pos + float2( 0.25f, -0.25f), outCenter, normScale, sourceExtent, funcType);
        acc += singleSample(pos + float2(-0.25f,  0.25f), outCenter, normScale, sourceExtent, funcType);
        acc += singleSample(pos + float2( 0.25f,  0.25f), outCenter, normScale, sourceExtent, funcType);
        return acc / 4.0f;
      }
      else {
        // Edges: single sample
        return singleSample(pos, outCenter, normScale, sourceExtent, funcType);
      }
    }
  }
}

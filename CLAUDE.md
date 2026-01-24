# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a macOS SwiftUI application that generates Julia set visual effects by transforming live webcam video frames. Each frame undergoes a complex plane transformation (z² mapping) to create a fractal-like visual effect.

## Build Commands

```bash
# Build the project
swift build

# Recompile Metal shader (after editing JuliaWarp.ci.metal)
make metallib

# Run the application
swift run CameraDemo

# Run tests (headless, no camera needed)
swift test

# Build for release
swift build -c release
```

## Architecture

The project is split into two modules:

### JuliaKit (library, `Sources/JuliaKit/`)
- **Filters/JuliaSetFilter**: CIWarpKernel-based z² transformation (Metal shader, half precision)
- **Filters/JuliaWarp.ci.metal**: Metal warp kernel source (compiled to .metallib via Makefile)
- **Camera/CameraManager**: AVFoundation video capture, processes frames through CoreImage filters
- **Camera/PixelFormat**: Pixel format options enum

### CameraDemo (executable, `Sources/CameraDemo/`)
- **Views/CameraView**: Renders processed frames using SwiftUI
- **App/JuliaSetCameraDemo**: App entry point

### Tests (`Tests/JuliaKitTests/`)
Swift Testing suite that verifies the filter pipeline with synthetic images (checkerboard patterns, solid colors, CVPixelBuffers) rendered via CPU-only CIContext. No camera or display needed.

The Julia set transformation maps each pixel coordinate (x,y) to a new lookup position using z² in the complex plane: `(x² - y², 2xy)`. This lookup determines where to sample the original image for each output pixel.

## Requirements

- macOS 14+
- Swift 6.1+
- Camera access permission (configured in Info.plist)

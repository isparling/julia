# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a macOS SwiftUI application that generates Julia set visual effects by transforming live webcam video frames. Each frame undergoes a complex plane transformation (z² mapping) to create a fractal-like visual effect.

## Build Commands

```bash
# Build the project
swift build

# Run the application
swift run CameraDemo

# Build for release
swift build -c release
```

## Architecture

The app is a single-file SwiftUI application (`Sources/main.swift`) with these components:

- **CameraManager**: Captures video from the webcam using AVFoundation, processes frames through CoreImage filters, and publishes CIImage frames to SwiftUI
- **CameraView**: Renders the processed frames using SwiftUI
- **JuliaSetCameraDemo**: App entry point

The Julia set transformation (described in README.md) maps each pixel coordinate (x,y) to a new lookup position using z² in the complex plane: `(x² - y², 2xy)`. This lookup determines where to sample the original image for each output pixel.

## Requirements

- macOS 13+ (Package.swift), but CameraView requires macOS 14+
- Swift 6.1+
- Camera access permission (configured in Info.plist)

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a macOS SwiftUI application that generates Julia set visual effects by transforming live webcam video frames. Each frame undergoes a complex plane transformation (z² mapping) to create a fractal-like visual effect.

## Knowledge and Context retrieval
This project uses QMD to store more general context between sessions. 

```sh
qmd collection add . --name <n>   # Create/index collection
qmd collection list               # List all collections with details
qmd collection remove <name>      # Remove a collection by name
qmd collection rename <old> <new> # Rename a collection
qmd ls [collection[/path]]        # List collections or files in a collection
qmd context add [path] "text"     # Add context for path (defaults to current dir)
qmd context list                  # List all contexts
qmd context check                 # Check for collections/paths missing context
qmd context rm <path>             # Remove context
qmd get <file>                    # Get document by path or docid (#abc123)
qmd multi-get <pattern>           # Get multiple docs by glob or comma-separated list
qmd status                        # Show index status and collections
qmd update [--pull]               # Re-index all collections (--pull: git pull first)
qmd embed                         # Generate vector embeddings (uses node-llama-cpp)
qmd search <query>                # BM25 full-text search
qmd vsearch <query>               # Vector similarity search
qmd query <query>                 # Hybrid search with reranking (best quality)
```

### Document IDs (docid)

Each document has a unique short ID (docid) - the first 6 characters of its content hash.
Docids are shown in search results as `#abc123` and can be used with `get` and `multi-get`:

```sh
# Search returns docid in results
qmd search "query" --json
# Output: [{"docid": "#abc123", "score": 0.85, "file": "docs/readme.md", ...}]

# Get document by docid
qmd get "#abc123"
qmd get abc123              # Leading # is optional

# Docids also work in multi-get comma-separated lists
qmd multi-get "#abc123, #def456"
```

### Options

```sh
# Search & retrieval
-c, --collection <name>  # Restrict search to a collection (matches pwd suffix)
-n <num>                 # Number of results
--all                    # Return all matches
--min-score <num>        # Minimum score threshold
--full                   # Show full document content
--line-numbers           # Add line numbers to output

# Multi-get specific
-l <num>                 # Maximum lines per file
--max-bytes <num>        # Skip files larger than this (default 10KB)

# Output formats (search and multi-get)
--json, --csv, --md, --xml, --files
```




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

## Interaction patterns
Since validating the quality of an implementation requires human user to run the application and make an aesthetic judgment, when proposing implementation fixes **ALWAYS** include an option to implement all suggestions, toggleable via a menu.
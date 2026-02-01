# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a macOS SwiftUI application that generates Julia set visual effects by transforming live webcam video frames. Each frame undergoes a complex plane transformation (z² mapping) to create a fractal-like visual effect.

# WORKFLOW GUIDANCE
This project uses **bd** (beads) for issue tracking. Run `bd onboard` to get started.

## Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --status in_progress  # Claim work
bd close <id>         # Complete work
bd sync               # Sync with git
```

## Landing the Plane (Session Completion)

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
   bd sync
   git push
   git status  # MUST show "up to date with origin"
   ```
5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**
- Work is NOT complete until `git push` succeeds
- Work is NOT complete until tests have been run and passed.
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds


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
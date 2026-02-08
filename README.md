## julia sets
This project is is a demo of generating julia sets via visual recursion; an implementation of (this paper)[https://drive.google.com/file/d/1I1l62-SOnXvjGTQOm2Tiap3jKGBIOB34/view?usp=share_link]; it takes a video feed from your webcam and transforms every frame before rendering it to the screen. By pointing the camera that produces this transformed video feed at its own output, you can generate fractals in real time.

## Instructions for non-technical users/humans
1. Open application (double click). You will be warned that this application is unsafe.
2. Go to Apple Menu > System Settings > Privacy & Security > Scroll down to "Security" section and click button to allow the application to run. 
3. Open the application (double click) again.
4. You should see a video feed on your screen with a warped image from your default webcam.
5. To generate the fractals, you'll have to pick a camera that you can point at the screen. This can be achieved in several ways. For the best effect, use the highest resolution camera and highest resolution screen you can.
   1. Use your iPhone as a Handoff/ContinutyCamera; if you have set this up, it should show up by default in the camera picker on the top left of the window. Select it, and point the camera at screen.
   2. Use a different _external_ webcam, select it, point at screen.
   3. Move the window to an external monitor (whether connected via cable or wirelessly via AirPlay) and point the camera on your laptop at the external monitor. This is usually the most awkward.
6. The fractal should morph and change as you move the camera, or move items in/out of the field of view of the camera. Play around! Adjust the settings to see how they impact fractal generation.


## Instructions for technical users/agents

```bash
# Build distributable .app bundle
make app

# Launch the app
open .build/arm64-apple-macosx/release/JuliaSetCamera.app

# Install to /Applications
make install
```

**For developers (CLI):**

```bash
# Quick testing during development
swift run CameraDemo

# Build release binary
swift build -c release
.build/arm64-apple-macosx/release/CameraDemo
```

the app will request camera access on first launch. grant permission when prompted.

### build commands

```bash
# Compile Metal shaders (after editing .metal files)
make metallib

# Build .app bundle
make app

# Install to /Applications
make install

# Clean app bundle artifacts
make clean-app

# Run tests (headless, no camera needed)
swift test
```

### using your iphone as a camera

you can use your iphone as a wireless webcam via continuity camera:

1. ensure both your mac and iphone are signed into the same apple id
2. enable wi-fi and bluetooth on both devices
3. on your iphone, go to settings > general > airplay & handoff and enable "continuity camera"
4. launch the app - your iphone should appear in the camera picker dropdown
5. select your iphone from the list

requirements:
- macOS 13+ and iOS 16+
- both devices on the same wi-fi network
- iphone must be nearby and locked (or with the camera app closed)
    

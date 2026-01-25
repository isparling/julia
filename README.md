### julia sets
This project is is a demo of generating julia sets via visual recursion; an implementation of the paper titled `JuliaReprintAuthorCopy.pdf`.

It takes a video feed from your webcam and provides transforms every frame before rendering it to the screen.

the transformation is a simple julia set transformation, z^2 in the complex plane.

for every frame:
  1. transform the coordinate space of the image to the complex plane. most importantly, the center of the image must be the origin of the two axes x,y.
  2. for each pixel z, with coordinates (x,y) in the original frame
     1. calculate lookup_point by running this function: [x^2+y^2 + 2xyi], where i is the imaginary number
     2. find the color from the original image that is at the lookup_point and write it to the location of pixel z in the new image

### running the app

```bash
# build and run
swift run CameraDemo

# or build for release
swift build -c release
.build/release/CameraDemo
```

the app will request camera access on first launch. grant permission when prompted.

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
    

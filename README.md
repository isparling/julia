### julia sets
this project is is a demo of generating julia sets via visual recursion.

it takes a video feed from your webcam and provides transforms every frame before rendering it to the screen.

the transformation is a simple julia set transformation, z^2 in the complex plane.

for every frame:
  1. transform the coordinate space of the image to the complex plane. most importantly, the center of the image must be the origin of the two axes x,y.
  2. for each pixel z, with coordinates (x,y) in the original frame
     1. calculate lookup_point by running this function: [x^2+y^2 + 2xyi], where i is the imaginary number
     2. find the color from the original image that is at the lookup_point and write it to the location of pixel z in the new image
    
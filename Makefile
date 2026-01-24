metallib:
	mkdir -p .build
	xcrun metal -fcikernel -c Sources/JuliaKit/Filters/JuliaWarp.ci.metal \
		-o .build/JuliaWarp.air
	xcrun metallib --cikernel .build/JuliaWarp.air \
		-o Sources/JuliaKit/Filters/JuliaWarp.ci.metallib

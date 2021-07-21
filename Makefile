test:
	xcodebuild -project "Pareto Security.xcodeproj" -scheme "Pareto Security" -destination platform=macOS test

build:
	xcodebuild -project "Pareto Security.xcodeproj" -scheme "Pareto Security" -destination platform=macOS build

lint:
	swiftlint .

fmt:
	swiftformat --swiftversion 5 .
	swiftlint . --fix
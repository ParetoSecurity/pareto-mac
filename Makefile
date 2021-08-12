test:
	xcodebuild -project "Pareto Security.xcodeproj" -scheme "Pareto Security" -destination platform=macOS test

build:
	xcodebuild -project "Pareto Security.xcodeproj" -scheme "Pareto Security" -destination platform=macOS build

archive:
	xcodebuild -project "Pareto Security.xcodeproj" -scheme "Pareto Security" -destination platform=macOS archive -archivePath build/app.xcarchive -allowProvisioningUpdates
	xcodebuild -exportArchive -archivePath build/app.xcarchive -exportPath build/mac -exportOptionsPlist exportOptions.plist

lint:
	swiftlint .

fmt:
	swiftformat --swiftversion 5 .
	swiftlint . --fix